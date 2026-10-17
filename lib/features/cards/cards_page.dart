import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/ui.dart';
import '../finance_view_model.dart';

class CardsPage extends StatelessWidget {
  const CardsPage({required this.vm, super.key});
  final FinanceViewModel vm;

  Future<void> _addCard(BuildContext context) async {
    final data = await showDataForm(context, 'Cadastrar cartão', [
      (
        key: 'name',
        label: 'Nome do cartão',
        initial: '',
        keyboard: TextInputType.text,
      ),
      (
        key: 'limit',
        label: 'Limite total do cartão (R\$)',
        initial: '',
        keyboard: TextInputType.number,
      ),
    ]);
    if (data != null &&
        data['name']!.isNotEmpty &&
        centsFrom(data['limit']!) > 0) {
      await vm.addCard(data['name']!, centsFrom(data['limit']!));
    }
  }

  Future<void> _editCard(
    BuildContext context,
    Map<String, Object?> card,
  ) async {
    final data = await showDataForm(context, 'Editar cartão', [
      (
        key: 'name',
        label: 'Nome do cartão',
        initial: FinanceViewModel.string(card['name']),
        keyboard: TextInputType.text,
      ),
      (
        key: 'limit',
        label: 'Limite mensal do cartão (R\$)',
        initial: (FinanceViewModel.integer(card['limit_cents']) / 100)
            .toStringAsFixed(2)
            .replaceAll('.', ','),
        keyboard: TextInputType.number,
      ),
    ]);
    if (data == null ||
        data['name']!.isEmpty ||
        centsFrom(data['limit']!) <= 0) {
      return;
    }
    await vm.updateCard(
      id: FinanceViewModel.integer(card['id']),
      name: data['name']!,
      limitCents: centsFrom(data['limit']!),
    );
  }

  Future<void> _deleteCard(
    BuildContext context,
    Map<String, Object?> card,
  ) async {
    final deleted = await confirmDeleteRecord(
      context,
      title: 'Apagar cartão?',
      message:
          'O cartão e todas as compras e parcelas vinculadas a ele serão removidos.',
    );
    if (!deleted || !context.mounted) return;
    await vm.delete('cards', FinanceViewModel.integer(card['id']));
  }

  Future<void> _editCardExpense(
    BuildContext context,
    Map<String, Object?> expense,
  ) async {
    final options = vm
        .categoriesFor('cards')
        .map(
          (category) => (
            value: FinanceViewModel.string(category['name']),
            label: FinanceViewModel.string(category['name']),
          ),
        )
        .toList();
    final selectedCategory = FinanceViewModel.string(expense['category']);
    if (selectedCategory.isNotEmpty &&
        !options.any((option) => option.value == selectedCategory)) {
      options.add((value: selectedCategory, label: selectedCategory));
    }
    final data = await showSmartForm(context, 'Editar parcela', [
      SmartFieldSpec(
        key: 'category',
        label: 'Categoria',
        initial: selectedCategory,
        kind: SmartFieldKind.dropdown,
        options: options,
        onCreateOption: (dialogContext) => createCategoryOption(
          dialogContext,
          (name) => vm.addCategory(name, 'cards'),
        ),
        onDeleteOption: (dialogContext, name) => deleteCategoryOption(
          dialogContext,
          name,
          vm.categoriesFor('cards'),
          vm.deleteCategory,
        ),
      ),
      SmartFieldSpec(
        key: 'title',
        label: 'Descrição da compra',
        initial: FinanceViewModel.string(expense['title']),
      ),
      SmartFieldSpec(
        key: 'amount',
        label: 'Valor desta parcela (R\$)',
        initial: (FinanceViewModel.integer(expense['amount_cents']) / 100)
            .toStringAsFixed(2)
            .replaceAll('.', ','),
        keyboard: TextInputType.number,
      ),
    ]);
    if (data == null ||
        data['category'] == null ||
        data['title'].toString().trim().isEmpty ||
        centsFrom(data['amount'].toString()) <= 0) {
      return;
    }
    await vm.updateCardExpense(
      id: FinanceViewModel.integer(expense['id']),
      title: data['title'].toString().trim(),
      category: data['category'].toString(),
      amountCents: centsFrom(data['amount'].toString()),
    );
  }

  Future<void> _deleteCardExpense(
    BuildContext context,
    Map<String, Object?> expense,
  ) async {
    final deleted = await confirmDeleteRecord(
      context,
      title: 'Apagar parcela?',
      message: 'Somente esta parcela será removida da fatura.',
    );
    if (!deleted || !context.mounted) return;
    await vm.delete('card_expenses', FinanceViewModel.integer(expense['id']));
  }

  Future<void> _addExpense(BuildContext context) async {
    if (vm.cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastre um cartão primeiro.')),
      );
      return;
    }
    final cardOptions = vm.cards
        .map(
          (c) =>
              (value: '${c['id']}', label: FinanceViewModel.string(c['name'])),
        )
        .toList();
    final categoryOptions = vm
        .categoriesFor('cards')
        .map(
          (c) => (
            value: FinanceViewModel.string(c['name']),
            label: FinanceViewModel.string(c['name']),
          ),
        )
        .toList();
    final data = await showSmartForm(context, 'Lançar compra', [
      SmartFieldSpec(
        key: 'card',
        label: 'Cartão',
        kind: SmartFieldKind.dropdown,
        options: cardOptions,
      ),
      const SmartFieldSpec(key: 'title', label: 'Descrição da compra'),
      SmartFieldSpec(
        key: 'category',
        label: 'Categoria',
        kind: SmartFieldKind.dropdown,
        options: categoryOptions,
        onCreateOption: (dialogContext) => createCategoryOption(
          dialogContext,
          (name) => vm.addCategory(name, 'cards'),
        ),
        onDeleteOption: (dialogContext, name) => deleteCategoryOption(
          dialogContext,
          name,
          vm.categoriesFor('cards'),
          vm.deleteCategory,
        ),
      ),
      const SmartFieldSpec(
        key: 'amount',
        label: 'Valor total',
        keyboard: TextInputType.number,
      ),
      const SmartFieldSpec(
        key: 'count',
        label: 'Quantidade de parcelas',
        initial: '1',
        keyboard: TextInputType.number,
      ),
      SmartFieldSpec(
        key: 'month',
        label: 'Mês da primeira parcela',
        initial: vm.month,
        kind: SmartFieldKind.dropdown,
        options: monthOptions(),
      ),
      const SmartFieldSpec(
        key: 'recurring',
        label: 'Assinatura mensal',
        kind: SmartFieldKind.toggle,
      ),
    ]);
    if (data == null ||
        data['category'] == null ||
        data['title'].toString().trim().isEmpty ||
        centsFrom(data['amount'].toString()) <= 0) {
      return;
    }
    final date = DateTime.tryParse('${data['month']}-01') ?? DateTime.now();
    await vm.addCardPurchase(
      cardId:
          int.tryParse(data['card'].toString()) ??
          FinanceViewModel.integer(vm.cards.first['id']),
      title: data['title'].toString().trim(),
      category: data['category']?.toString() ?? 'Outros',
      totalCents: centsFrom(data['amount'].toString()),
      count: (int.tryParse(data['count'].toString()) ?? 1).clamp(1, 60),
      start: date,
      recurring: data['recurring'] == true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthItems = vm.cardExpenses
        .where((e) => e['month'] == vm.month)
        .toList();
    final grouped = <String, List<Map<String, Object?>>>{};
    for (final item in monthItems) {
      grouped
          .putIfAbsent(FinanceViewModel.string(item['category']), () => [])
          .add(item);
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        const PageHeading(
          'Cartões',
          subtitle: 'Veja a fatura mensal e o limite de crédito disponível.',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _monthPicker(),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AmountCard(
            label: 'Fatura prevista • ${monthLabel(vm.month)}',
            value: money(vm.cardTotal),
            highlight: true,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _addCard(context),
                icon: const Icon(Icons.add_card),
                label: const Text('Novo cartão'),
              ),
              FilledButton.icon(
                onPressed: () => _addExpense(context),
                icon: const Icon(Icons.add),
                label: const Text('Lançar compra'),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: Text(
            'Seus cartões',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ...vm.cards.map((card) {
          final id = FinanceViewModel.integer(card['id']);
          final limit = FinanceViewModel.integer(card['limit_cents']);
          final outstanding = vm.cardOutstanding(id);
          final available = (limit - outstanding).clamp(0, limit);
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.credit_card, color: AppTheme.lime),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          FinanceViewModel.string(card['name']),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        'Limite ${money(limit)}',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Ações do cartão',
                        onSelected: (action) {
                          if (action == 'edit') {
                            _editCard(context, card);
                          } else if (action == 'delete') {
                            _deleteCard(context, card);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Editar')),
                          PopupMenuItem(value: 'delete', child: Text('Apagar')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Disponível',
                          style: const TextStyle(color: AppTheme.muted),
                        ),
                      ),
                      Text(
                        money(available),
                        style: const TextStyle(
                          color: AppTheme.lime,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: limit == 0
                        ? 0
                        : (outstanding / limit).clamp(0.0, 1.0),
                    color: AppTheme.lime,
                    backgroundColor: AppTheme.surface2,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${money(outstanding)} comprometidos em parcelas ainda não pagas',
                    style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: Text(
            'Fatura por categoria',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        if (grouped.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Sem compras previstas neste mês.',
              style: TextStyle(color: AppTheme.muted),
            ),
          ),
        ...grouped.entries.map((group) {
          final subtotal = group.value.fold(
            0,
            (sum, e) => sum + FinanceViewModel.integer(e['amount_cents']),
          );
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surface2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.key,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        money(subtotal),
                        style: const TextStyle(
                          color: AppTheme.lime,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ...group.value.map((entry) {
                  final id = FinanceViewModel.integer(entry['id']);
                  final paid = FinanceViewModel.integer(entry['paid']) == 1;
                  final recurring =
                      FinanceViewModel.integer(entry['recurring']) == 1;
                  final description = recurring
                      ? 'Assinatura • ${monthLabel(vm.month)}'
                      : 'Parcela ${entry['installment_index']} de ${entry['installment_count']} • ${monthLabel(vm.month)}';
                  return Card(
                    child: CheckboxListTile(
                      value: paid,
                      onChanged: (value) =>
                          vm.setCardInstallmentPaid(id, value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(FinanceViewModel.string(entry['title'])),
                      subtitle: Text(
                        paid ? 'Pago • $description' : description,
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                      secondary: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            money(
                              FinanceViewModel.integer(entry['amount_cents']),
                            ),
                            style: const TextStyle(
                              color: AppTheme.lime,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Ações da parcela',
                            onSelected: (action) {
                              if (action == 'edit') {
                                _editCardExpense(context, entry);
                              } else if (action == 'delete') {
                                _deleteCardExpense(context, entry);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar parcela'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Apagar parcela'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }),
        if (vm.cards.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Cadastre seu primeiro cartão para acompanhar gastos e limite.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted),
            ),
          ),
        if (vm.cards.isNotEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              'O limite é reservado pelo saldo total das parcelas em aberto. Marque cada parcela paga na fatura para liberar novamente esse valor. Assinaturas futuras só comprometem o limite no mês correspondente.',
              style: TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _monthPicker() {
    return MonthCarousel(
      selectedMonth: vm.month,
      onChanged: vm.setMonthValue,
      label: 'Mês da fatura',
    );
  }
}
