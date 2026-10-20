import '../../../core/models/finance_record.dart';

class CardModel extends FinanceRecord {
  CardModel(super.data);
  int get id => intValue('id');
  String get name => stringValue('name');
  int get limitCents => intValue('limit_cents');
}

class CardExpenseModel extends FinanceRecord {
  CardExpenseModel(super.data);
  int get id => intValue('id');
  int get cardId => intValue('card_id');
  String get title => stringValue('title');
  String get category => stringValue('category');
  int get amountCents => intValue('amount_cents');
  String get month => stringValue('month');
  int get installmentIndex => intValue('installment_index');
  int get installmentCount => intValue('installment_count');
  bool get recurring => intValue('recurring') == 1;
  bool get paid => intValue('paid') == 1;
  String get purchaseId => stringValue('purchase_id');
}
