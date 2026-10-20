import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/finance_state.dart';
import '../models/category_model.dart';
import '../../features/planning/model/expense_model.dart';
import '../../features/income/model/income_model.dart';
import '../../features/income/model/investment_model.dart';
import '../../features/cards/model/card_model.dart';
import '../../features/goals/model/goal_model.dart';
import '../utils/finance_math.dart';
import '../utils/finance_values.dart';
import '../../features/finance_commands.dart';
import 'app_providers.dart';

class FinanceController extends Notifier<FinanceState> {
  late FinanceCommands _commands;
  @override
  FinanceState build() {
    _commands = ref.watch(financeCommandsProvider);
    Future<void>.microtask(() => load());
    return FinanceState.initial();
  }

  bool get loading => state.loading;
  String get month => state.month;
  List<Map<String, Object?>> get expenses => state.expenses;
  List<Map<String, Object?>> get incomes => state.incomes;
  List<Map<String, Object?>> get services => state.services;
  List<Map<String, Object?>> get cards => state.cards;
  List<Map<String, Object?>> get cardExpenses => state.cardExpenses;
  List<Map<String, Object?>> get goals => state.goals;
  List<Map<String, Object?>> get categories => state.categories;
  List<Map<String, Object?>> get investments => state.investments;
  double get taxPercent => state.taxPercent;
  int get plannedTotal => state.plannedTotal;
  int get paidTotal => state.paidTotal;
  int get incomeTotal => state.incomeTotal;
  List<String> get incomeMonths => state.incomeMonths;
  int get monthlyTaxAmount => state.monthlyTaxAmount;
  int get cardTotal => state.cardTotal;
  int get goalTotal => state.goalTotal;
  bool get isEmptyForTaxInvestmentTour => state.isEmptyForTaxInvestmentTour;
  int taxAmountForYear(int year) => state.taxAmountForYear(year);
  int taxAmountForMonth(String m) => state.taxAmountForMonth(m);
  int monthlyInvestmentAmount(int id, {String? forMonth}) =>
      state.monthlyInvestmentAmount(id, forMonth: forMonth);
  int cardOutstanding(int id) => state.cardOutstanding(id);
  int incomeValue(Map<String, Object?> entry) =>
      FinanceMath.incomeValue(entry, taxPercent, investments);
  static String _monthOf(DateTime date) => FinanceValues.monthFromDate(date);
  static String monthFromDate(DateTime date) =>
      FinanceValues.monthFromDate(date);
  static int integer(Object? value) => FinanceValues.integer(value);
  static double decimal(Object? value) => FinanceValues.decimal(value);
  static String string(Object? value) => FinanceValues.string(value);

  Future<void> load({bool showLoading = true}) async {
    if (showLoading) state = state.copyWith(loading: true);
    final db = ref.read(appDatabaseProvider);
    final rows = await Future.wait([
      db.rows('expenses', orderBy: 'month DESC'),
      db.rows('incomes', orderBy: 'date DESC'),
      db.rows('services', orderBy: 'name'),
      db.rows('cards', orderBy: 'name'),
      db.rows('card_expenses', orderBy: 'month DESC'),
      db.rows('goals', orderBy: 'title'),
      db.rows('categories', orderBy: 'name'),
      db.rows('investments', orderBy: 'name'),
    ]);
    final tax =
        double.tryParse(
          (await db.getSetting('tax_percent')).replaceAll(',', '.'),
        ) ??
        0;
    final lightTheme = await db.getSetting('light_theme') == '1';
    state = state.copyWith(
      loading: false,
      lightTheme: lightTheme,
      expenses: List.unmodifiable(rows[0].map(ExpenseModel.new)),
      incomes: List.unmodifiable(rows[1].map(IncomeModel.new)),
      services: List.unmodifiable(rows[2].map(ServiceModel.new)),
      cards: List.unmodifiable(rows[3].map(CardModel.new)),
      cardExpenses: List.unmodifiable(rows[4].map(CardExpenseModel.new)),
      goals: List.unmodifiable(rows[5].map(GoalModel.new)),
      categories: List.unmodifiable(rows[6].map(CategoryModel.new)),
      investments: List.unmodifiable(rows[7].map(InvestmentModel.new)),
      taxPercent: tax,
    );
  }

  Future<bool> refreshExpenseNotifications() =>
      _commands.notifications.replaceAllExpenseReminders(expenses);
  Future<bool> addExpense({
    required String title,
    required String category,
    required int cents,
    required String month,
    required DateTime? dueDate,
    required int repeatCount,
  }) async {
    final result = await _commands.run(
      AddExpenseCommand(
        title: title,
        category: category,
        cents: cents,
        month: month,
        dueDate: dueDate,
        repeatCount: repeatCount,
      ),
    );
    await load(showLoading: false);
    return result;
  }

  Future<bool> updateExpense({
    required int id,
    required String title,
    required String category,
    required int cents,
    required DateTime? dueDate,
  }) async {
    final result = await _commands.run(
      UpdateExpenseCommand(
        id: id,
        title: title,
        category: category,
        cents: cents,
        dueDate: dueDate,
      ),
    );
    await load(showLoading: false);
    return result;
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
    await _commands.run(
      AddIncomeCommand(
        service: service,
        quantity: quantity,
        unitCents: unitCents,
        date: date,
        receiveMonth: receiveMonth,
        tax: tax,
        investmentIds: investmentIds,
      ),
    );
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
    await _commands.run(
      UpdateIncomeCommand(
        id: id,
        service: service,
        quantity: quantity,
        unitCents: unitCents,
        date: date,
        receiveMonth: receiveMonth,
        tax: tax,
        investmentIds: investmentIds,
      ),
    );
    await load(showLoading: false);
  }

  List<Map<String, Object?>> categoriesFor(String scope) =>
      state.categories.where((item) => string(item['scope']) == scope).toList();
  Future<void> addCategory(String name, String scope) async {
    await _commands.run(AddCategoryCommand(name, scope));
    await load(showLoading: false);
  }

  Future<void> deleteCategory(int id) async {
    await _commands.run(DeleteRecordCommand('categories', id));
    await load(showLoading: false);
  }

  Future<void> addCard(String name, int limitCents) async {
    await _commands.run(AddCardCommand(name, limitCents));
    await load(showLoading: false);
  }

  Future<void> updateCard({
    required int id,
    required String name,
    required int limitCents,
  }) async {
    await _commands.run(UpdateCardCommand(id, name, limitCents));
    await load(showLoading: false);
  }

  Future<void> deleteCard(int id) async {
    await _commands.run(DeleteRecordCommand('cards', id));
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
    await _commands.run(
      AddCardPurchaseCommand(
        cardId: cardId,
        title: title,
        category: category,
        totalCents: totalCents,
        count: count,
        start: start,
        recurring: recurring,
      ),
    );
    await load(showLoading: false);
  }

  Future<void> updateCardExpense({
    required int id,
    required String title,
    required String category,
    required int amountCents,
  }) async {
    await _commands.run(
      UpdateCardExpenseCommand(id, title, category, amountCents),
    );
    await load(showLoading: false);
  }

  Future<void> updateCardPurchase({
    required String purchaseId,
    required int expenseId,
    required String title,
    required String category,
    required int totalCents,
    required String firstMonth,
    required int installmentCount,
  }) async {
    await _commands.run(
      UpdateCardPurchaseCommand(
        purchaseId,
        expenseId,
        title,
        category,
        totalCents,
        firstMonth,
        installmentCount,
      ),
    );
    await load(showLoading: false);
  }

  Future<void> deleteCardPurchase(String id) async {
    await _commands.run(DeleteCardPurchaseCommand(id));
    await load(showLoading: false);
  }

  Future<void> addGoal({
    required String title,
    required String category,
    required String description,
    required int unitCents,
    required int quantity,
  }) async {
    await _commands.run(
      AddGoalCommand(title, category, description, unitCents, quantity),
    );
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
    await _commands.run(
      UpdateGoalCommand(id, title, category, description, unitCents, quantity),
    );
    await load(showLoading: false);
  }

  Future<bool> setPaid(String table, int id, bool paid) async {
    final result = await _commands.run(SetPaidCommand(table, id, paid));
    await load(showLoading: false);
    return result;
  }

  Future<void> setCardInstallmentPaid(int id, bool paid) async {
    await _commands.run(SetCardInstallmentPaidCommand(id, paid));
    await load(showLoading: false);
  }

  Future<void> delete(String table, int id) async {
    await _commands.run(DeleteRecordCommand(table, id));
    await load(showLoading: false);
  }

  Future<void> saveTax(double value) async {
    await _commands.run(SaveTaxCommand(value));
    await load(showLoading: false);
  }

  Future<void> setLightTheme(bool enabled) async {
    await ref.read(appDatabaseProvider).setting('light_theme', enabled ? '1' : '0');
    state = state.copyWith(lightTheme: enabled);
  }

  Future<void> addInvestment(String name, String mode, int value) async {
    await _commands.run(AddInvestmentCommand(name, mode, value));
    await load(showLoading: false);
  }

  Future<void> deleteInvestment(int id) async {
    await _commands.run(DeleteRecordCommand('investments', id));
    await load(showLoading: false);
  }

  Future<Map<String, List<Map<String, Object?>>>> exportAll() =>
      _commands.run(ExportDatabaseCommand());
  Future<void> restoreAll(Map<String, dynamic> data) async {
    await _commands.run(RestoreBackupCommand(data));
    await load();
  }

  Future<bool> shouldShowTaxInvestmentTour() async =>
      state.isEmptyForTaxInvestmentTour &&
      await ref
              .read(appDatabaseProvider)
              .getSetting('tax_investment_tour_seen', '0') !=
          '1';
  Future<void> markTaxInvestmentTourSeen() =>
      _commands.run(MarkTaxInvestmentTourSeenCommand());
  Future<void> setMonth(DateTime date) async => setMonthValue(_monthOf(date));
  Future<void> setMonthValue(String value) async {
    state = state.copyWith(month: value);
  }
}
