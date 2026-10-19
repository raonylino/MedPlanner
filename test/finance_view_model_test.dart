import 'package:flutter_test/flutter_test.dart';
import 'package:med_planner/core/database/app_database.dart';
import 'package:med_planner/features/finance_view_model.dart';

void main() {
  group('fractional shift quantities', () {
    late FinanceViewModel viewModel;

    setUp(() {
      viewModel = FinanceViewModel(AppDatabase.instance);
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('calculates a half shift proportionally', () {
      final income = viewModel.incomeValue({
        'unit_cents': 12000,
        'quantity': 0.5,
        'tax_applies': 0,
        'investment_ids': '',
      });

      expect(income, 6000);
    });

    test('calculates multiple fractional shifts proportionally', () {
      final income = viewModel.incomeValue({
        'unit_cents': 12000,
        'quantity': 1.5,
        'tax_applies': 0,
        'investment_ids': '',
      });

      expect(income, 18000);
    });
  });
}
