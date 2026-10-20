import 'finance_values.dart';

abstract final class FinanceMath {
  static int grossIncome(Map<String, Object?> entry) =>
      (FinanceValues.integer(entry['unit_cents']) *
              FinanceValues.decimal(entry['quantity']))
          .round();
  static int netIncome(Map<String, Object?> entry, double taxPercent) {
    final gross = grossIncome(entry);
    return FinanceValues.integer(entry['tax_applies']) == 1
        ? (gross * (100 - taxPercent) / 100).round()
        : gross;
  }

  static List<Map<String, Object?>> investmentRulesFor(
    Map<String, Object?> entry,
    List<Map<String, Object?>> investments,
  ) {
    final raw = FinanceValues.string(entry['investment_ids']);
    final ids = raw == '*'
        ? null
        : raw.split(',').where((id) => id.isNotEmpty).toSet();
    return ids == null
        ? investments
        : investments
              .where((item) => ids.contains(FinanceValues.string(item['id'])))
              .toList();
  }

  static int incomeValue(
    Map<String, Object?> entry,
    double taxPercent,
    List<Map<String, Object?>> investments,
  ) {
    final net = netIncome(entry, taxPercent);
    final rules = investmentRulesFor(entry, investments);
    final percent = rules
        .where((rule) => rule['mode'] == 'percent')
        .fold(0, (sum, rule) => sum + FinanceValues.integer(rule['value']));
    var fixed = 0;
    var remaining = net - (net * percent ~/ 100);
    for (final rule in rules.where((item) => item['mode'] == 'fixed')) {
      final amount = FinanceValues.integer(rule['value']).clamp(0, remaining);
      fixed += amount;
      remaining -= amount;
    }
    return (net - (net * percent ~/ 100) - fixed).clamp(0, net);
  }
}
