import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/app_database.dart';
import '../core/notifications/expense_notification_service.dart';

/// Coordinates use cases for the presentation layer (MVVM ViewModel).
class FinanceViewModel extends ChangeNotifier {
  FinanceViewModel(this.db) : notifications = ExpenseNotificationService();
  final AppDatabase db;
  final ExpenseNotificationService notifications;
  bool loading = true;
  String month = _monthOf(DateTime.now());
  List<Map<String, Object?>> expenses = [],
      incomes = [],
      services = [],
      cards = [],
      cardExpenses = [],
      goals = [],
      categories = [],
      investments = [];
  double taxPercent = 0;
  static String _monthOf(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';
  static String monthFromDate(DateTime d) => _monthOf(d);
  static int integer(Object? x) => (x as num?)?.toInt() ?? 0;
  static double decimal(Object? x) => (x as num?)?.toDouble() ?? 0;
  static String string(Object? x) => x?.toString() ?? '';

  Future<void> load({bool showLoading = true}) async {
    if (showLoading) {
      loading = true;
      notifyListeners();
    }
    expenses = await db.rows('expenses', orderBy: 'month DESC');
    incomes = await db.rows('incomes', orderBy: 'date DESC');
    services = await db.rows('services', orderBy: 'name');
    cards = await db.rows('cards', orderBy: 'name');
    cardExpenses = await db.rows('card_expenses', orderBy: 'month DESC');
    goals = await db.rows('goals', orderBy: 'title');
    categories = await db.rows('categories', orderBy: 'name');
    investments = await db.rows('investments', orderBy: 'name');
    taxPercent =
        double.tryParse(
          (await db.getSetting('tax_percent')).replaceAll(',', '.'),
        ) ??
        0;
    loading = false;
    notifyListeners();
  }

  Future<bool> refreshExpenseNotifications() =>
      notifications.replaceAllExpenseReminders(expenses);

  Future<bool> addExpense({
    required String title,
    required String category,
    required int cents,
    required String month,
    required DateTime? dueDate,
    required int repeatCount,
  }) async {
    final start = dueDate ?? DateTime.tryParse('$month-01') ?? DateTime.now();
    final created = <Map<String, Object?>>[];
    final database = await db.database;
    await database.transaction((transaction) async {
      for (var index = 0; index < repeatCount; index++) {
        final occurrenceMonth = DateTime(start.year, start.month + index, 1);
        final day = dueDate == null
            ? null
            : DateTime(
                occurrenceMonth.year,
                occurrenceMonth.month,
                dueDate.day.clamp(
                  1,
                  DateTime(
                    occurrenceMonth.year,
                    occurrenceMonth.month + 1,
                    0,
                  ).day,
                ),
              );
        final row = <String, Object?>{
          'title': title,
          'category': category,
          'amount_cents': cents,
          'month': _monthOf(occurrenceMonth),
          'paid': 0,
          'due_date': day == null
              ? null
              : '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
        };
        row['id'] = await transaction.insert('expenses', row);
        created.add(row);
      }
    });
    var remindersEnabled = true;
    for (final expense in created) {
      remindersEnabled =
          await notifications.syncExpense(expense) && remindersEnabled;
    }
    await load(showLoading: false);
    return remindersEnabled;
  }

  Future<bool> updateExpense({
    required int id,
    required String title,
    required String category,
    required int cents,
    required DateTime? dueDate,
  }) async {
    await db.update('expenses', {
      'title': title,
      'category': category,
      'amount_cents': cents,
      'due_date': dueDate == null
          ? null
          : '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}',
    }, id);
    final updated = await db.rows('expenses', where: 'id = ?', args: [id]);
    final remindersEnabled = await notifications.syncExpense(updated.single);
    await load(showLoading: false);
    return remindersEnabled;
  }

  Future<void> addIncome({
    required String service,
    required double quantity,
    required int unitCents,
    required DateTime date,
    required String receiveMonth,
    required bool tax,
    required String investmentIds,
  }) async {
    final database = await db.database;
    await database.insert('services', {
      'name': service,
      'unit_cents': unitCents,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.add('incomes', {
      'service': service,
      'quantity': quantity,
      'unit_cents': unitCents,
      'date': date.toIso8601String(),
      'receive_month': receiveMonth,
      'tax_applies': tax ? 1 : 0,
      'received': 0,
      'investment_ids': investmentIds,
    });
    await load(showLoading: false);
  }

  Future<void> updateIncome({
    required int id,
    required String service,
    required double quantity,
    required int unitCents,
    required DateTime date,
    required String receiveMonth,
    required bool tax,
    required String investmentIds,
  }) async {
    final database = await db.database;
    await database.insert('services', {
      'name': service,
      'unit_cents': unitCents,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.update('incomes', {
      'service': service,
      'quantity': quantity,
      'unit_cents': unitCents,
      'date': date.toIso8601String(),
      'receive_month': receiveMonth,
      'tax_applies': tax ? 1 : 0,
      'investment_ids': investmentIds,
    }, id);
    await load(showLoading: false);
  }

  List<Map<String, Object?>> categoriesFor(String scope) => categories
      .where((category) => string(category['scope']) == scope)
      .toList();

  Future<void> addCategory(String name, String scope) async {
    await (await db.database).insert('categories', {
      'name': name.trim(),
      'scope': scope,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    categories = await db.rows('categories', orderBy: 'name');
    notifyListeners();
  }

  Future<void> deleteCategory(int id) async {
    await db.remove('categories', id);
    categories = await db.rows('categories', orderBy: 'name');
    notifyListeners();
  }

  Future<void> addCard(String name, int limitCents) async {
    await db.add('cards', {'name': name, 'limit_cents': limitCents});
    await load(showLoading: false);
  }

  Future<void> updateCard({
    required int id,
    required String name,
    required int limitCents,
  }) async {
    await db.update('cards', {'name': name, 'limit_cents': limitCents}, id);
    await load(showLoading: false);
  }

  Future<void> addCardPurchase({
    required int cardId,
    required String title,
    required String category,
    required int totalCents,
    required int count,
    required DateTime start,
    required bool recurring,
  }) async {
    final months = recurring ? 12 : count;
    final per = recurring ? totalCents : totalCents ~/ count,
        remainder = recurring ? 0 : totalCents % count;
    final currentMonth = _monthOf(DateTime.now());
    final database = await db.database;
    await database.transaction((transaction) async {
      String? purchaseId;
      for (var i = 0; i < months; i++) {
        final d = DateTime(start.year, start.month + i, 1);
        final row = <String, Object?>{
          'card_id': cardId,
          'title': title,
          'category': category,
          'amount_cents': per + (!recurring && i == count - 1 ? remainder : 0),
          'installment_count': recurring ? 1 : count,
          'installment_index': recurring ? 1 : i + 1,
          'month': _monthOf(d),
          'recurring': recurring ? 1 : 0,
          'paid': _monthOf(d).compareTo(currentMonth) < 0 ? 1 : 0,
        };
        if (purchaseId != null) row['purchase_id'] = purchaseId;
        final id = await transaction.insert('card_expenses', row);
        purchaseId ??= '$id';
        if (i == 0) {
          await transaction.update(
            'card_expenses',
            {'purchase_id': purchaseId},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
    });
    await load(showLoading: false);
  }

  Future<void> updateCardExpense({
    required int id,
    required String title,
    required String category,
    required int amountCents,
  }) async {
    await db.update('card_expenses', {
      'title': title,
      'category': category,
      'amount_cents': amountCents,
    }, id);
    await load(showLoading: false);
  }

  Future<void> updateCardPurchase({
    required String purchaseId,
    required String title,
    required String category,
    required int totalCents,
  }) async {
    final database = await db.database;
    final purchase = await db.rows(
      'card_expenses',
      where: 'purchase_id = ?',
      args: [purchaseId],
      orderBy: 'installment_index',
    );
    if (purchase.isEmpty) {
      throw StateError('A compra não existe mais.');
    }
    final recurring = integer(purchase.first['recurring']) == 1;
    final count = integer(purchase.first['installment_count']).clamp(1, 1000);
    final installmentValue = recurring ? totalCents : totalCents ~/ count;
    final remainder = recurring ? 0 : totalCents % count;
    await database.transaction((transaction) async {
      for (final installment in purchase) {
        final index = integer(installment['installment_index']);
        await transaction.update(
          'card_expenses',
          {
            'title': title,
            'category': category,
            'amount_cents':
                installmentValue +
                (!recurring && index == count ? remainder : 0),
          },
          where: 'id = ?',
          whereArgs: [installment['id']],
        );
      }
    });
    await load(showLoading: false);
  }

  Future<void> deleteCardPurchase(String purchaseId) async {
    await (await db.database).delete(
      'card_expenses',
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
    );
    await load(showLoading: false);
  }

  Future<void> addGoal({
    required String title,
    required String category,
    required String description,
    required int unitCents,
    required int quantity,
  }) async {
    await db.add('goals', {
      'title': title,
      'category': category,
      'description': description,
      'unit_cents': unitCents,
      'quantity': quantity,
    });
    await load(showLoading: false);
  }

  Future<void> updateGoal({
    required int id,
    required String title,
    required String category,
    required String description,
    required int unitCents,
    required int quantity,
  }) async {
    await db.update('goals', {
      'title': title,
      'category': category,
      'description': description,
      'unit_cents': unitCents,
      'quantity': quantity,
    }, id);
    await load(showLoading: false);
  }

  Future<bool> setPaid(String table, int id, bool paid) async {
    await db.update(table, {
      table == 'expenses' ? 'paid' : 'received': paid ? 1 : 0,
    }, id);
    var remindersEnabled = true;
    if (table == 'expenses') {
      final expense = await db.rows('expenses', where: 'id = ?', args: [id]);
      if (expense.isNotEmpty) {
        remindersEnabled = await notifications.syncExpense(expense.single);
      }
    }
    await load(showLoading: false);
    return remindersEnabled;
  }

  Future<void> setCardInstallmentPaid(int id, bool paid) async {
    await db.update('card_expenses', {'paid': paid ? 1 : 0}, id);
    await load(showLoading: false);
  }

  Future<void> delete(String table, int id) async {
    if (table == 'expenses') await notifications.cancelExpense(id);
    await db.remove(table, id);
    await load(showLoading: false);
  }

  Future<void> saveTax(double value) async {
    taxPercent = value;
    await db.setting('tax_percent', '$value');
    await load(showLoading: false);
  }

  Future<void> addInvestment(String name, String mode, int value) async {
    await db.add('investments', {'name': name, 'mode': mode, 'value': value});
    await load(showLoading: false);
  }

  Future<void> deleteInvestment(int id) async {
    await db.remove('investments', id);
    await load(showLoading: false);
  }

  bool get isEmptyForTaxInvestmentTour {
    final hasFinancialRows =
        expenses.isNotEmpty ||
        incomes.isNotEmpty ||
        services.isNotEmpty ||
        cards.isNotEmpty ||
        cardExpenses.isNotEmpty ||
        goals.isNotEmpty;
    final hasCustomInvestment = investments.any(
      (item) =>
          string(item['name']) != 'Reserva' ||
          string(item['mode']) != 'percent' ||
          integer(item['value']) != 10,
    );
    return !hasFinancialRows && !hasCustomInvestment;
  }

  Future<bool> shouldShowTaxInvestmentTour() async =>
      isEmptyForTaxInvestmentTour &&
      await db.getSetting('tax_investment_tour_seen', '0') != '1';

  Future<void> markTaxInvestmentTourSeen() =>
      db.setting('tax_investment_tour_seen', '1');

  Future<void> setMonth(DateTime d) async {
    month = _monthOf(d);
    notifyListeners();
  }

  Future<void> setMonthValue(String value) async {
    month = value;
    notifyListeners();
  }

  int get plannedTotal => expenses
      .where((e) => e['month'] == month)
      .fold(0, (a, e) => a + integer(e['amount_cents']));
  int get paidTotal => expenses
      .where((e) => e['month'] == month && integer(e['paid']) == 1)
      .fold(0, (a, e) => a + integer(e['amount_cents']));
  int get incomeTotal => incomes
      .where((e) => string(e['receive_month']) == month)
      .fold(0, (sum, entry) => sum + incomeValue(entry));
  List<String> get incomeMonths =>
      incomes
          .map((entry) => string(entry['receive_month']))
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  int get monthlyTaxAmount => taxAmountForMonth(month);

  int taxAmountForYear(int year) => incomes
      .where((entry) => integer(entry['tax_applies']) == 1)
      .where((entry) => string(entry['receive_month']).startsWith('$year-'))
      .fold(0, (sum, entry) => sum + _grossIncome(entry) - _netIncome(entry));

  int taxAmountForMonth(String targetMonth) => incomes
      .where(
        (entry) =>
            string(entry['receive_month']) == targetMonth &&
            integer(entry['tax_applies']) == 1,
      )
      .fold(0, (sum, entry) => sum + _grossIncome(entry) - _netIncome(entry));

  int monthlyInvestmentAmount(int investmentId, {String? forMonth}) {
    var total = 0;
    for (final entry in incomes.where(
      (item) => string(item['receive_month']) == (forMonth ?? month),
    )) {
      final net = _netIncome(entry);
      final rules = _investmentRulesFor(entry);
      final percentRules = rules
          .where((rule) => rule['mode'] == 'percent')
          .toList();
      final percent = percentRules.fold(
        0,
        (sum, rule) => sum + integer(rule['value']),
      );
      final totalPercentAmount = net * percent ~/ 100;
      var attributedPercent = 0;
      for (var index = 0; index < percentRules.length; index++) {
        final rule = percentRules[index];
        final amount = index == percentRules.length - 1
            ? totalPercentAmount - attributedPercent
            : net * integer(rule['value']) ~/ 100;
        attributedPercent += amount;
        if (integer(rule['id']) == investmentId) total += amount;
      }

      var remaining = net - totalPercentAmount;
      for (final rule in rules.where((item) => item['mode'] == 'fixed')) {
        final amount = integer(rule['value']).clamp(0, remaining);
        if (integer(rule['id']) == investmentId) total += amount;
        remaining -= amount;
      }
    }
    return total;
  }

  int get cardTotal => cardExpenses
      .where((e) => e['month'] == month)
      .fold(0, (a, e) => a + integer(e['amount_cents']));
  int get goalTotal => goals.fold(
    0,
    (a, e) => a + integer(e['unit_cents']) * integer(e['quantity']),
  );

  int cardOutstanding(int cardId) => cardExpenses
      .where((entry) {
        if (integer(entry['card_id']) != cardId ||
            integer(entry['paid']) == 1) {
          return false;
        }
        final isRecurring = integer(entry['recurring']) == 1;
        // Future subscription forecasts are not committed credit until that month arrives.
        return !isRecurring || string(entry['month']).compareTo(month) <= 0;
      })
      .fold(0, (sum, entry) => sum + integer(entry['amount_cents']));
  int incomeValue(Map<String, Object?> e) {
    final net = _netIncome(e);
    final selectedInvestments = _investmentRulesFor(e);
    final pct = selectedInvestments
        .where((x) => x['mode'] == 'percent')
        .fold(0, (n, x) => n + integer(x['value']));
    final fixed = selectedInvestments
        .where((x) => x['mode'] == 'fixed')
        .fold(0, (n, x) => n + integer(x['value']));
    return (net - (net * pct ~/ 100) - fixed).clamp(0, net);
  }

  int _grossIncome(Map<String, Object?> entry) =>
      (integer(entry['unit_cents']) * decimal(entry['quantity'])).round();

  int _netIncome(Map<String, Object?> entry) {
    final gross = _grossIncome(entry);
    return integer(entry['tax_applies']) == 1
        ? (gross * (100 - taxPercent) / 100).round()
        : gross;
  }

  List<Map<String, Object?>> _investmentRulesFor(Map<String, Object?> entry) {
    final rawSelection = string(entry['investment_ids']);
    final selectedIds = rawSelection == '*'
        ? null
        : rawSelection.split(',').where((id) => id.isNotEmpty).toSet();
    return selectedIds == null
        ? investments
        : investments
              .where(
                (investment) => selectedIds.contains(string(investment['id'])),
              )
              .toList();
  }
}
