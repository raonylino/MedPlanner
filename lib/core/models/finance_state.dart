import '../utils/finance_math.dart';
import '../utils/finance_values.dart';

/// Immutable snapshot exposed to widgets by Riverpod.
class FinanceState {
  const FinanceState({
    required this.loading,
    required this.lightTheme,
    required this.month,
    required this.expenses,
    required this.incomes,
    required this.services,
    required this.cards,
    required this.cardExpenses,
    required this.goals,
    required this.categories,
    required this.investments,
    required this.taxPercent,
  });

  factory FinanceState.initial() => FinanceState(
    loading: true,
    lightTheme: false,
    month: FinanceValues.monthFromDate(DateTime.now()),
    expenses: const [],
    incomes: const [],
    services: const [],
    cards: const [],
    cardExpenses: const [],
    goals: const [],
    categories: const [],
    investments: const [],
    taxPercent: 0,
  );

  final bool loading;
  final bool lightTheme;
  final String month;
  final List<Map<String, Object?>> expenses;
  final List<Map<String, Object?>> incomes;
  final List<Map<String, Object?>> services;
  final List<Map<String, Object?>> cards;
  final List<Map<String, Object?>> cardExpenses;
  final List<Map<String, Object?>> goals;
  final List<Map<String, Object?>> categories;
  final List<Map<String, Object?>> investments;
  final double taxPercent;

  FinanceState copyWith({
    bool? loading,
    bool? lightTheme,
    String? month,
    List<Map<String, Object?>>? expenses,
    List<Map<String, Object?>>? incomes,
    List<Map<String, Object?>>? services,
    List<Map<String, Object?>>? cards,
    List<Map<String, Object?>>? cardExpenses,
    List<Map<String, Object?>>? goals,
    List<Map<String, Object?>>? categories,
    List<Map<String, Object?>>? investments,
    double? taxPercent,
  }) => FinanceState(
    loading: loading ?? this.loading,
    lightTheme: lightTheme ?? this.lightTheme,
    month: month ?? this.month,
    expenses: expenses ?? this.expenses,
    incomes: incomes ?? this.incomes,
    services: services ?? this.services,
    cards: cards ?? this.cards,
    cardExpenses: cardExpenses ?? this.cardExpenses,
    goals: goals ?? this.goals,
    categories: categories ?? this.categories,
    investments: investments ?? this.investments,
    taxPercent: taxPercent ?? this.taxPercent,
  );

  int get plannedTotal => expenses
      .where((entry) => entry['month'] == month)
      .fold(
        0,
        (sum, entry) => sum + FinanceValues.integer(entry['amount_cents']),
      );

  int get paidTotal => expenses
      .where(
        (entry) =>
            entry['month'] == month &&
            FinanceValues.integer(entry['paid']) == 1,
      )
      .fold(
        0,
        (sum, entry) => sum + FinanceValues.integer(entry['amount_cents']),
      );

  int get incomeTotal => incomes
      .where((entry) => FinanceValues.string(entry['receive_month']) == month)
      .fold(
        0,
        (sum, entry) =>
            sum + FinanceMath.incomeValue(entry, taxPercent, investments),
      );

  List<String> get incomeMonths =>
      incomes
          .map((entry) => FinanceValues.string(entry['receive_month']))
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  int get monthlyTaxAmount => taxAmountForMonth(month);

  int taxAmountForYear(int year) => incomes
      .where((entry) => FinanceValues.integer(entry['tax_applies']) == 1)
      .where(
        (entry) =>
            FinanceValues.string(entry['receive_month']).startsWith('$year-'),
      )
      .fold(
        0,
        (sum, entry) =>
            sum +
            FinanceMath.grossIncome(entry) -
            FinanceMath.netIncome(entry, taxPercent),
      );

  int taxAmountForMonth(String targetMonth) => incomes
      .where(
        (entry) =>
            FinanceValues.string(entry['receive_month']) == targetMonth &&
            FinanceValues.integer(entry['tax_applies']) == 1,
      )
      .fold(
        0,
        (sum, entry) =>
            sum +
            FinanceMath.grossIncome(entry) -
            FinanceMath.netIncome(entry, taxPercent),
      );

  int monthlyInvestmentAmount(int investmentId, {String? forMonth}) {
    var total = 0;
    for (final entry in incomes.where(
      (item) =>
          FinanceValues.string(item['receive_month']) == (forMonth ?? month),
    )) {
      final net = FinanceMath.netIncome(entry, taxPercent);
      final rules = FinanceMath.investmentRulesFor(entry, investments);
      final percentageRules = rules
          .where((rule) => rule['mode'] == 'percent')
          .toList();
      final percentage = percentageRules.fold(
        0,
        (sum, rule) => sum + FinanceValues.integer(rule['value']),
      );
      final percentageTotal = net * percentage ~/ 100;
      var attributedPercentage = 0;
      for (var index = 0; index < percentageRules.length; index++) {
        final rule = percentageRules[index];
        final amount = index == percentageRules.length - 1
            ? percentageTotal - attributedPercentage
            : net * FinanceValues.integer(rule['value']) ~/ 100;
        attributedPercentage += amount;
        if (FinanceValues.integer(rule['id']) == investmentId) {
          total += amount;
        }
      }
      var remaining = net - percentageTotal;
      for (final rule in rules.where((item) => item['mode'] == 'fixed')) {
        final amount = FinanceValues.integer(rule['value']).clamp(0, remaining);
        if (FinanceValues.integer(rule['id']) == investmentId) {
          total += amount;
        }
        remaining -= amount;
      }
    }
    return total;
  }

  int get cardTotal => cardExpenses
      .where((entry) => entry['month'] == month)
      .fold(
        0,
        (sum, entry) => sum + FinanceValues.integer(entry['amount_cents']),
      );

  int get goalTotal => goals.fold(
    0,
    (sum, entry) =>
        sum +
        FinanceValues.integer(entry['unit_cents']) *
            FinanceValues.integer(entry['quantity']),
  );

  int cardOutstanding(int cardId) => cardExpenses
      .where((entry) {
        if (FinanceValues.integer(entry['card_id']) != cardId ||
            FinanceValues.integer(entry['paid']) == 1) {
          return false;
        }
        final recurring = FinanceValues.integer(entry['recurring']) == 1;
        return !recurring ||
            FinanceValues.string(entry['month']).compareTo(month) <= 0;
      })
      .fold(
        0,
        (sum, entry) => sum + FinanceValues.integer(entry['amount_cents']),
      );

  bool get isEmptyForTaxInvestmentTour {
    final hasRows =
        expenses.isNotEmpty ||
        incomes.isNotEmpty ||
        services.isNotEmpty ||
        cards.isNotEmpty ||
        cardExpenses.isNotEmpty ||
        goals.isNotEmpty;
    final hasCustomInvestment = investments.any(
      (item) =>
          FinanceValues.string(item['name']) != 'Reserva' ||
          FinanceValues.string(item['mode']) != 'percent' ||
          FinanceValues.integer(item['value']) != 10,
    );
    return !hasRows && !hasCustomInvestment;
  }
}
