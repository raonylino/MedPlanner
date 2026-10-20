import '../../../core/models/finance_record.dart';

class GoalModel extends FinanceRecord {
  GoalModel(super.data);
  int get id => intValue('id');
  String get title => stringValue('title');
  String get category => stringValue('category');
  String get description => stringValue('description');
  int get unitCents => intValue('unit_cents');
  int get quantity => intValue('quantity');
}
