import '../../../core/models/finance_record.dart';

class IncomeModel extends FinanceRecord {
  IncomeModel(super.data);
  int get id => intValue('id');
  String get service => stringValue('service');
  double get quantity => doubleValue('quantity');
  int get unitCents => intValue('unit_cents');
  String get receiveMonth => stringValue('receive_month');
  bool get taxApplies => intValue('tax_applies') == 1;
  String get investmentIds => stringValue('investment_ids');
}

class ServiceModel extends FinanceRecord {
  ServiceModel(super.data);
  int get id => intValue('id');
  String get name => stringValue('name');
  int get unitCents => intValue('unit_cents');
}
