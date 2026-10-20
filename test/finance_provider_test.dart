import 'package:flutter_test/flutter_test.dart';
import 'package:med_planner/features/finance_provider.dart';

void main() {
  group('fractional shift quantities', () {
    test('calculates a half shift proportionally', () {
      final income = FinanceMath.incomeValue(
        {
          'unit_cents': 12000,
          'quantity': 0.5,
          'tax_applies': 0,
          'investment_ids': '',
        },
        0,
        const [],
      );

      expect(income, 6000);
    });

    test('calculates multiple fractional shifts proportionally', () {
      final income = FinanceMath.incomeValue(
        {
          'unit_cents': 12000,
          'quantity': 1.5,
          'tax_applies': 0,
          'investment_ids': '',
        },
        0,
        const [],
      );

      expect(income, 18000);
    });
  });
}

