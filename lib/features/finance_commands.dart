import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../core/database/app_database.dart';
import '../core/notifications/expense_notification_service.dart';
import '../core/utils/finance_values.dart';

/// A command represents one user-requested write operation.
abstract interface class FinanceCommand<T> {
  Future<T> execute(FinanceCommands commands);
}

/// Runs commands with the app's persistence and notification dependencies.
class FinanceCommands {
  FinanceCommands(this.db, this.notifications, {this.afterLocalWrite});
  final AppDatabase db;
  final ExpenseNotificationService notifications;
  final Future<void> Function()? afterLocalWrite;

  Future<T> run<T>(FinanceCommand<T> command) async {
    final result = await command.execute(this);
    if (command is! ExportDatabaseCommand && afterLocalWrite != null) {
      unawaited(afterLocalWrite!());
    }
    return result;
  }

  Future<bool> _addExpense(AddExpenseCommand command) async {
    final start =
        command.dueDate ??
        DateTime.tryParse('${command.month}-01') ??
        DateTime.now();
    final created = <Map<String, Object?>>[];
    final database = await db.database;
    await database.transaction((transaction) async {
      for (var index = 0; index < command.repeatCount; index++) {
        final occurrenceMonth = DateTime(start.year, start.month + index, 1);
        final day = command.dueDate == null
            ? null
            : DateTime(
                occurrenceMonth.year,
                occurrenceMonth.month,
                command.dueDate!.day.clamp(
                  1,
                  DateTime(
                    occurrenceMonth.year,
                    occurrenceMonth.month + 1,
                    0,
                  ).day,
                ),
              );
        final row = <String, Object?>{
          'title': command.title,
          'category': command.category,
          'amount_cents': command.cents,
          'month': FinanceValues.monthFromDate(occurrenceMonth),
          'paid': 0,
          'due_date': day == null
              ? null
              : '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
        };
        row['id'] = await transaction.insert('expenses', row);
        created.add(row);
      }
    });
    var enabled = true;
    for (final expense in created) {
      enabled = await notifications.syncExpense(expense) && enabled;
    }
    return enabled;
  }

  Future<bool> _updateExpense(UpdateExpenseCommand command) async {
    await db.update('expenses', {
      'title': command.title,
      'category': command.category,
      'amount_cents': command.cents,
      'due_date': command.dueDate == null
          ? null
          : '${command.dueDate!.year}-${command.dueDate!.month.toString().padLeft(2, '0')}-${command.dueDate!.day.toString().padLeft(2, '0')}',
    }, command.id);
    final updated = await db.rows(
      'expenses',
      where: 'id = ?',
      args: [command.id],
    );
    return notifications.syncExpense(updated.single);
  }

  Future<void> _addIncome(AddIncomeCommand command) async {
    await db.saveService(command.service, command.unitCents);
    await db.add('incomes', {
      'service': command.service,
      'quantity': command.quantity,
      'unit_cents': command.unitCents,
      'date': command.date.toIso8601String(),
      'receive_month': command.receiveMonth,
      'tax_applies': command.tax ? 1 : 0,
      'received': 0,
      'investment_ids': command.investmentIds,
    });
  }

  Future<void> _updateIncome(UpdateIncomeCommand command) async {
    await db.saveService(command.service, command.unitCents);
    await db.update('incomes', {
      'service': command.service,
      'quantity': command.quantity,
      'unit_cents': command.unitCents,
      'date': command.date.toIso8601String(),
      'receive_month': command.receiveMonth,
      'tax_applies': command.tax ? 1 : 0,
      'investment_ids': command.investmentIds,
    }, command.id);
  }

  Future<void> _addCategory(AddCategoryCommand command) async =>
      (await db.database).insert('categories', {
        'name': command.name.trim(),
        'scope': command.scope,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

  Future<void> _addCard(AddCardCommand command) async => db.add('cards', {
    'name': command.name,
    'limit_cents': command.limitCents,
  });
  Future<void> _updateCard(UpdateCardCommand command) async => db.update(
    'cards',
    {'name': command.name, 'limit_cents': command.limitCents},
    command.id,
  );

  Future<void> _addCardPurchase(AddCardPurchaseCommand command) async {
    final count = command.recurring ? 12 : command.count;
    final per = command.recurring
        ? command.totalCents
        : command.totalCents ~/ command.count;
    final remainder = command.recurring
        ? 0
        : command.totalCents % command.count;
    final currentMonth = FinanceValues.monthFromDate(DateTime.now());
    final database = await db.database;
    await database.transaction((transaction) async {
      String? purchaseId;
      for (var index = 0; index < count; index++) {
        final date = DateTime(
          command.start.year,
          command.start.month + index,
          1,
        );
        final month = FinanceValues.monthFromDate(date);
        final row = <String, Object?>{
          'card_id': command.cardId,
          'title': command.title,
          'category': command.category,
          'amount_cents':
              per +
              (!command.recurring && index == command.count - 1
                  ? remainder
                  : 0),
          'installment_count': command.recurring ? 1 : command.count,
          'installment_index': command.recurring ? 1 : index + 1,
          'month': month,
          'recurring': command.recurring ? 1 : 0,
          'paid': month.compareTo(currentMonth) < 0 ? 1 : 0,
        };
        if (purchaseId != null) row['purchase_id'] = purchaseId;
        final id = await transaction.insert('card_expenses', row);
        purchaseId ??= '$id';
        if (index == 0) {
          await transaction.update(
            'card_expenses',
            {'purchase_id': purchaseId},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
    });
  }

  Future<void> _updateCardExpense(UpdateCardExpenseCommand command) async =>
      db.update('card_expenses', {
        'title': command.title,
        'category': command.category,
        'amount_cents': command.amountCents,
      }, command.id);

  Future<void> _updateCardPurchase(UpdateCardPurchaseCommand command) async {
    final database = await db.database;
    final purchase = await db.rows(
      'card_expenses',
      where: command.purchaseId.isEmpty ? 'id = ?' : 'purchase_id = ?',
      args: [
        command.purchaseId.isEmpty ? command.expenseId : command.purchaseId,
      ],
      orderBy: 'installment_index',
    );
    if (purchase.isEmpty) throw StateError('A compra não existe mais.');
    final recurring = FinanceValues.integer(purchase.first['recurring']) == 1;
    if (!recurring &&
        (command.installmentCount < 1 || command.installmentCount > 60)) {
      throw RangeError.range(
        command.installmentCount,
        1,
        60,
        'installmentCount',
      );
    }
    final firstDate = recurring
        ? null
        : DateTime.tryParse('${command.firstMonth}-01');
    if (!recurring && firstDate == null) {
      throw FormatException('Mês da primeira parcela inválido.');
    }
    final count = recurring ? purchase.length : command.installmentCount;
    final per = recurring ? command.totalCents : command.totalCents ~/ count;
    final remainder = recurring ? 0 : command.totalCents % count;
    final existingCount = purchase.fold<int>(
      0,
      (maxCount, installment) =>
          maxCount > FinanceValues.integer(installment['installment_count'])
          ? maxCount
          : FinanceValues.integer(installment['installment_count']),
    );
    final purchaseId = command.purchaseId.isEmpty
        ? '${command.expenseId}'
        : command.purchaseId;
    final installmentsByIndex = {
      for (final installment in purchase)
        FinanceValues.integer(installment['installment_index']): installment,
    };
    final currentMonth = FinanceValues.monthFromDate(DateTime.now());
    await database.transaction((transaction) async {
      if (recurring) {
        for (final installment in purchase) {
          await transaction.update(
            'card_expenses',
            {
              'title': command.title,
              'category': command.category,
              'amount_cents': command.totalCents,
            },
            where: 'id = ?',
            whereArgs: [installment['id']],
          );
        }
        return;
      }

      for (var index = 1; index <= count; index++) {
        final date = DateTime(firstDate!.year, firstDate.month + index - 1, 1);
        final month = FinanceValues.monthFromDate(date);
        final existing = installmentsByIndex[index];
        if (existing == null && index <= existingCount) continue;
        final row = <String, Object?>{
          'title': command.title,
          'category': command.category,
          'amount_cents': per + (index == count ? remainder : 0),
          'installment_count': count,
          'installment_index': index,
          'month': month,
          'purchase_id': purchaseId,
        };
        if (existing == null) {
          row.addAll({
            'card_id': FinanceValues.integer(purchase.first['card_id']),
            'recurring': 0,
            'paid': month.compareTo(currentMonth) < 0 ? 1 : 0,
          });
          await transaction.insert('card_expenses', row);
        } else {
          await transaction.update(
            'card_expenses',
            row,
            where: 'id = ?',
            whereArgs: [existing['id']],
          );
        }
      }

      for (final installment in purchase) {
        if (FinanceValues.integer(installment['installment_index']) > count) {
          await transaction.update(
            'card_expenses',
            {'deleted_at': DateTime.now().toUtc().toIso8601String()},
            where: 'id = ? AND deleted_at IS NULL',
            whereArgs: [installment['id']],
          );
        }
      }
    });
  }

  Future<bool> _setPaid(SetPaidCommand command) async {
    await db.update(command.table, {
      command.table == 'expenses' ? 'paid' : 'received': command.paid ? 1 : 0,
    }, command.id);
    var remindersEnabled = true;
    if (command.table == 'expenses') {
      final expense = await db.rows(
        'expenses',
        where: 'id = ?',
        args: [command.id],
      );
      if (expense.isNotEmpty) {
        remindersEnabled = await notifications.syncExpense(expense.single);
      }
    }
    return remindersEnabled;
  }

  Future<void> _delete(DeleteRecordCommand command) async {
    if (command.table == 'expenses') {
      await notifications.cancelExpense(command.id);
    }
    await db.remove(command.table, command.id);
  }

  Future<Map<String, List<Map<String, Object?>>>> _exportDatabase() =>
      db.exportAll();

  Future<void> _restoreDatabase(RestoreBackupCommand command) =>
      db.restoreAll(command.data);
}

class AddExpenseCommand implements FinanceCommand<bool> {
  AddExpenseCommand({
    required this.title,
    required this.category,
    required this.cents,
    required this.month,
    required this.dueDate,
    required this.repeatCount,
  });
  final String title, category, month;
  final int cents, repeatCount;
  final DateTime? dueDate;
  @override
  Future<bool> execute(FinanceCommands commands) => commands._addExpense(this);
}

class UpdateExpenseCommand implements FinanceCommand<bool> {
  UpdateExpenseCommand({
    required this.id,
    required this.title,
    required this.category,
    required this.cents,
    required this.dueDate,
  });
  final int id, cents;
  final String title, category;
  final DateTime? dueDate;
  @override
  Future<bool> execute(FinanceCommands commands) =>
      commands._updateExpense(this);
}

class AddIncomeCommand implements FinanceCommand<void> {
  AddIncomeCommand({
    required this.service,
    required this.quantity,
    required this.unitCents,
    required this.date,
    required this.receiveMonth,
    required this.tax,
    required this.investmentIds,
  });
  final String service, receiveMonth, investmentIds;
  final double quantity;
  final int unitCents;
  final DateTime date;
  final bool tax;
  @override
  Future<void> execute(FinanceCommands commands) => commands._addIncome(this);
}

class UpdateIncomeCommand extends AddIncomeCommand
    implements FinanceCommand<void> {
  UpdateIncomeCommand({
    required this.id,
    required super.service,
    required super.quantity,
    required super.unitCents,
    required super.date,
    required super.receiveMonth,
    required super.tax,
    required super.investmentIds,
  });
  final int id;
  @override
  Future<void> execute(FinanceCommands commands) =>
      commands._updateIncome(this);
}

class AddCategoryCommand implements FinanceCommand<void> {
  AddCategoryCommand(this.name, this.scope);
  final String name, scope;
  @override
  Future<void> execute(FinanceCommands commands) => commands._addCategory(this);
}

class AddCardCommand implements FinanceCommand<void> {
  AddCardCommand(this.name, this.limitCents);
  final String name;
  final int limitCents;
  @override
  Future<void> execute(FinanceCommands commands) => commands._addCard(this);
}

class UpdateCardCommand implements FinanceCommand<void> {
  UpdateCardCommand(this.id, this.name, this.limitCents);
  final int id, limitCents;
  final String name;
  @override
  Future<void> execute(FinanceCommands commands) => commands._updateCard(this);
}

class AddCardPurchaseCommand implements FinanceCommand<void> {
  AddCardPurchaseCommand({
    required this.cardId,
    required this.title,
    required this.category,
    required this.totalCents,
    required this.count,
    required this.start,
    required this.recurring,
  });
  final int cardId, totalCents, count;
  final String title, category;
  final DateTime start;
  final bool recurring;
  @override
  Future<void> execute(FinanceCommands commands) =>
      commands._addCardPurchase(this);
}

class UpdateCardExpenseCommand implements FinanceCommand<void> {
  UpdateCardExpenseCommand(
    this.id,
    this.title,
    this.category,
    this.amountCents,
  );
  final int id, amountCents;
  final String title, category;
  @override
  Future<void> execute(FinanceCommands commands) =>
      commands._updateCardExpense(this);
}

class UpdateCardPurchaseCommand implements FinanceCommand<void> {
  UpdateCardPurchaseCommand(
    this.purchaseId,
    this.expenseId,
    this.title,
    this.category,
    this.totalCents,
    this.firstMonth,
    this.installmentCount,
  );
  final String purchaseId, title, category, firstMonth;
  final int expenseId, totalCents, installmentCount;
  @override
  Future<void> execute(FinanceCommands commands) =>
      commands._updateCardPurchase(this);
}

class SetPaidCommand implements FinanceCommand<bool> {
  SetPaidCommand(this.table, this.id, this.paid);
  final String table;
  final int id;
  final bool paid;
  @override
  Future<bool> execute(FinanceCommands commands) => commands._setPaid(this);
}

class SetCardInstallmentPaidCommand implements FinanceCommand<void> {
  SetCardInstallmentPaidCommand(this.id, this.paid);
  final int id;
  final bool paid;
  @override
  Future<void> execute(FinanceCommands commands) => commands.db
      .update('card_expenses', {'paid': paid ? 1 : 0}, id)
      .then((_) {});
}

class DeleteCardPurchaseCommand implements FinanceCommand<void> {
  DeleteCardPurchaseCommand(this.purchaseId);
  final String purchaseId;
  @override
  Future<void> execute(FinanceCommands commands) async {
    final db = await commands.db.database;
    await db.update(
      'card_expenses',
      {'deleted_at': DateTime.now().toUtc().toIso8601String()},
      where: 'purchase_id = ? AND deleted_at IS NULL',
      whereArgs: [purchaseId],
    );
  }
}

class DeleteRecordCommand implements FinanceCommand<void> {
  DeleteRecordCommand(this.table, this.id);
  final String table;
  final int id;
  @override
  Future<void> execute(FinanceCommands commands) => commands._delete(this);
}

class ExportDatabaseCommand
    implements FinanceCommand<Map<String, List<Map<String, Object?>>>> {
  @override
  Future<Map<String, List<Map<String, Object?>>>> execute(
    FinanceCommands commands,
  ) => commands._exportDatabase();
}

class RestoreBackupCommand implements FinanceCommand<void> {
  RestoreBackupCommand(this.data);
  final Map<String, dynamic> data;
  @override
  Future<void> execute(FinanceCommands commands) =>
      commands._restoreDatabase(this);
}

class AddGoalCommand implements FinanceCommand<void> {
  AddGoalCommand(
    this.title,
    this.category,
    this.description,
    this.unitCents,
    this.quantity,
  );
  final String title, category, description;
  final int unitCents, quantity;
  @override
  Future<void> execute(FinanceCommands commands) async => commands.db
      .add('goals', {
        'title': title,
        'category': category,
        'description': description,
        'unit_cents': unitCents,
        'quantity': quantity,
      })
      .then((_) {});
}

class UpdateGoalCommand implements FinanceCommand<void> {
  UpdateGoalCommand(
    this.id,
    this.title,
    this.category,
    this.description,
    this.unitCents,
    this.quantity,
  );
  final int id, unitCents, quantity;
  final String title, category, description;
  @override
  Future<void> execute(FinanceCommands commands) async => commands.db
      .update('goals', {
        'title': title,
        'category': category,
        'description': description,
        'unit_cents': unitCents,
        'quantity': quantity,
      }, id)
      .then((_) {});
}

class SaveTaxCommand implements FinanceCommand<void> {
  SaveTaxCommand(this.value);
  final double value;
  @override
  Future<void> execute(FinanceCommands commands) =>
      commands.db.setting('tax_percent', '$value');
}

class AddInvestmentCommand implements FinanceCommand<void> {
  AddInvestmentCommand(this.name, this.mode, this.value);
  final String name, mode;
  final int value;
  @override
  Future<void> execute(FinanceCommands commands) async => commands.db
      .add('investments', {'name': name, 'mode': mode, 'value': value})
      .then((_) {});
}

class MarkTaxInvestmentTourSeenCommand implements FinanceCommand<void> {
  @override
  Future<void> execute(FinanceCommands commands) =>
      commands.db.setting('tax_investment_tour_seen', '1');
}
