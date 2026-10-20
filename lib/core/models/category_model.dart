import 'finance_record.dart';

class CategoryModel extends FinanceRecord {
  CategoryModel(super.data);
  int get id => intValue('id');
  String get name => stringValue('name');
  String get scope => stringValue('scope');
}
