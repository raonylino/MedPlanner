import '../../../core/models/finance_record.dart';

class ExpenseModel extends FinanceRecord {
  ExpenseModel(super.data);
  int get id => intValue('id');
  String get title => stringValue('title');
  String get category => stringValue('category');
  int get amountCents => intValue('amount_cents');
  String get month => stringValue('month');
  bool get paid => intValue('paid') == 1;
  DateTime? get dueDate => DateTime.tryParse(stringValue('due_date'));
}
