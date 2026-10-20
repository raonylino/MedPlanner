import '../../../core/models/finance_record.dart';

class InvestmentModel extends FinanceRecord {
  InvestmentModel(super.data);
  int get id => intValue('id');
  String get name => stringValue('name');
  String get mode => stringValue('mode');
  int get value => intValue('value');
}
