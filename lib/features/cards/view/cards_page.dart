import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/ui.dart';
import '../viewmodel/cards_view_model.dart';

class CardsPage extends StatelessWidget {
  const CardsPage({required this.vm, super.key});
  final FinanceController vm;

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
        initial: FinanceController.string(card['name']),
        keyboard: TextInputType.text,
      ),
      (
        key: 'limit',
        label: 'Limite mensal do cartão (R\$)',
        initial: (FinanceController.integer(card['limit_cents']) / 100)
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
      id: FinanceController.integer(card['id']),
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
    await vm.delete('cards', FinanceController.integer(card['id']));
  }

  Future<void> _editCardExpense(
    BuildContext context,
    Map<String, Object?> expense, {
    List<Map<String, Object?>>? purchase,
  }) async {
    final editPurchase = purchase != null;
    final recurring = FinanceController.integer(expense['recurring']) == 1;
    final amountCents = editPurchase
        ? recurring
              ? FinanceController.integer(expense['amount_cents'])
              : purchase.fold(
                  0,
                  (sum, item) =>
                      sum + FinanceController.integer(item['amount_cents']),
                )
        : FinanceController.integer(expense['amount_cents']);
    final options = vm
        .categoriesFor('cards')
        .map(
          (category) => (
            value: FinanceController.string(category['name']),
            label: FinanceController.string(category['name']),
          ),
        )
        .toList();
    final selectedCategory = FinanceController.string(expense['category']);
    if (selectedCategory.isNotEmpty &&
        !options.any((option) => option.value == selectedCategory)) {
      options.add((value: selectedCategory, label: selectedCategory));
    }
    final data = await showSmartForm(
      context,
      editPurchase ? 'Editar compra inteira' : 'Editar parcela',
      [
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
          initial: FinanceController.string(expense['title']),
        ),
        SmartFieldSpec(
          key: 'amount',
          label: editPurchase && !recurring
              ? 'Novo valor total da compra (R\$)'
              : editPurchase
              ? 'Valor mensal (R\$)'
              : 'Valor desta parcela (R\$)',
          initial: (amountCents / 100).toStringAsFixed(2).replaceAll('.', ','),
          keyboard: TextInputType.number,
        ),
      ],
    );
    if (data == null ||
        data['category'] == null ||
        data['title'].toString().trim().isEmpty ||
        centsFrom(data['amount'].toString()) <= 0) {
      return;
    }
    if (editPurchase &&
        purchase.length == 1 &&
        FinanceController.string(expense['purchase_id']).isEmpty) {
      await vm.updateCardExpense(
        id: FinanceController.integer(expense['id']),
        title: data['title'].toString().trim(),
        category: data['category'].toString(),
        amountCents: centsFrom(data['amount'].toString()),
      );
    } else if (editPurchase) {
      await vm.updateCardPurchase(
        purchaseId: FinanceController.string(expense['purchase_id']),
        title: data['title'].toString().trim(),
        category: data['category'].toString(),
        totalCents: centsFrom(data['amount'].toString()),
      );
    } else {
      await vm.updateCardExpense(
        id: FinanceController.integer(expense['id']),
        title: data['title'].toString().trim(),
        category: data['category'].toString(),
        amountCents: centsFrom(data['amount'].toString()),
      );
    }
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
    await vm.delete('card_expenses', FinanceController.integer(expense['id']));
  }

  Future<void> _deleteCardPurchase(
    BuildContext context,
    String purchaseId, {
    Map<String, Object?>? singleExpense,
  }) async {
    final deleted = await confirmDeleteRecord(
      context,
      title: 'Apagar compra inteira?',
      message: 'Todas as parcelas e previsões desta compra serão removidas.',
    );
    if (!deleted || !context.mounted) return;
    if (purchaseId.isEmpty && singleExpense != null) {
      await vm.delete(
        'card_expenses',
        FinanceController.integer(singleExpense['id']),
      );
    } else {
      await vm.deleteCardPurchase(purchaseId);
    }
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
              (value: '${c['id']}', label: FinanceController.string(c['name'])),
        )
        .toList();
    final categoryOptions = vm
        .categoriesFor('cards')
        .map(
          (c) => (
            value: FinanceController.string(c['name']),
            label: FinanceController.string(c['name']),
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
          FinanceController.integer(vm.cards.first['id']),
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
    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        const PageHeading(
          'Cartões',
          subtitle: 'Toque em um cartão para ver as compras e parcelas dele.',
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
          final id = FinanceController.integer(card['id']);
          final limit = FinanceController.integer(card['limit_cents']);
          final outstanding = vm.cardOutstanding(id);
          final available = (limit - outstanding).clamp(0, limit);
          final cardExpenses =
              vm.cardExpenses
                  .where(
                    (expense) =>
                        FinanceController.integer(expense['card_id']) == id,
                  )
                  .toList()
                ..sort(
                  (a, b) => FinanceController.string(
                    a['month'],
                  ).compareTo(FinanceController.string(b['month'])),
                );
          final purchases = <String, List<Map<String, Object?>>>{};
          for (final expense in cardExpenses) {
            final purchaseId = FinanceController.string(expense['purchase_id']);
            final key = purchaseId.isEmpty
                ? 'unlinked-${expense['id']}'
                : purchaseId;
            purchases.putIfAbsent(key, () => []).add(expense);
          }
          final monthPurchases = <String, List<Map<String, Object?>>>{};
          for (final entry in purchases.entries) {
            final installments = entry.value
                .where(
                  (expense) =>
                      FinanceController.string(expense['month']) == vm.month,
                )
                .toList();
            if (installments.isNotEmpty) {
              monthPurchases[entry.key] = installments;
            }
          }
          final categories = <String, List<String>>{};
          for (final entry in monthPurchases.entries) {
            final name = FinanceController.string(
              purchases[entry.key]!.first['category'],
            );
            final category = name.isEmpty ? 'Outros' : name;
            categories.putIfAbsent(category, () => []).add(entry.key);
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ExpansionTile(
                leading: const Icon(Icons.credit_card, color: AppTheme.lime),
                title: Text(
                  FinanceController.string(card['name']),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Disponível ${money(available)} • Limite ${money(limit)}',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                    const Icon(Icons.expand_more, color: AppTheme.muted),
                  ],
                ),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                children: [
                  LinearProgressIndicator(
                    value: limit == 0
                        ? 0
                        : (outstanding / limit).clamp(0.0, 1.0),
                    color: AppTheme.lime,
                    backgroundColor: AppTheme.surface2,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${money(outstanding)} comprometidos em parcelas ainda não pagas',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  if (monthPurchases.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Não há parcelas deste cartão nesta fatura.',
                        style: TextStyle(color: AppTheme.muted),
                      ),
                    ),
                  ...categories.entries.map(
                    (category) => _categorySection(
                      context,
                      category.key,
                      category.value,
                      purchases,
                      monthPurchases,
                    ),
                  ),
                ],
              ),
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

  Widget _categorySection(
    BuildContext context,
    String category,
    List<String> purchaseKeys,
    Map<String, List<Map<String, Object?>>> purchases,
    Map<String, List<Map<String, Object?>>> monthPurchases,
  ) {
    final total = purchaseKeys.fold<int>(
      0,
      (sum, key) =>
          sum +
          monthPurchases[key]!.fold<int>(
            0,
            (subtotal, installment) =>
                subtotal +
                FinanceController.integer(installment['amount_cents']),
          ),
    );
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: Text(
              category,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${purchaseKeys.length} ${purchaseKeys.length == 1 ? 'compra' : 'compras'} nesta fatura',
              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
            trailing: Text(
              money(total),
              style: const TextStyle(
                color: AppTheme.lime,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          for (final key in purchaseKeys)
            _purchaseSection(
              context,
              purchases[key]!,
              monthPurchases[key]!,
              key.startsWith('unlinked-') ? '' : key,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _purchaseSection(
    BuildContext context,
    List<Map<String, Object?>> purchase,
    List<Map<String, Object?>> visibleInstallments,
    String purchaseId,
  ) {
    final first = purchase.first;
    final recurring = FinanceController.integer(first['recurring']) == 1;
    final total = visibleInstallments.fold(
      0,
      (sum, item) => sum + FinanceController.integer(item['amount_cents']),
    );
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: Text(
              FinanceController.string(first['title']),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${FinanceController.string(first['category'])} • ${recurring ? 'Assinatura' : '${purchase.length} parcelas'}',
              style: const TextStyle(color: AppTheme.muted),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  money(
                    recurring
                        ? FinanceController.integer(first['amount_cents'])
                        : total,
                  ),
                  style: const TextStyle(
                    color: AppTheme.lime,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Ações da compra',
                  onSelected: (action) {
                    if (action == 'edit') {
                      _editCardExpense(context, first, purchase: purchase);
                    } else if (action == 'delete') {
                      _deleteCardPurchase(
                        context,
                        purchaseId,
                        singleExpense: purchase.length == 1 ? first : null,
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Editar todas as parcelas'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Apagar compra inteira'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          for (final installment in visibleInstallments)
            _installmentTile(context, installment),
        ],
      ),
    );
  }

  Widget _installmentTile(
    BuildContext context,
    Map<String, Object?> installment,
  ) {
    final id = FinanceController.integer(installment['id']);
    final purchaseId = FinanceController.string(installment['purchase_id']);
    final purchase = _installmentsFor(installment);
    final paid = FinanceController.integer(installment['paid']) == 1;
    final recurring = FinanceController.integer(installment['recurring']) == 1;
    final description = recurring
        ? 'Assinatura • ${monthLabel(FinanceController.string(installment['month']))}'
        : 'Parcela ${installment['installment_index']} de ${installment['installment_count']} • ${monthLabel(FinanceController.string(installment['month']))}';
    return ListTile(
      dense: true,
      leading: Checkbox(
        value: paid,
        onChanged: (value) => vm.setCardInstallmentPaid(id, value ?? false),
      ),
      title: Text(description, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        paid ? 'Pago' : 'Em aberto',
        style: const TextStyle(color: AppTheme.muted, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            money(FinanceController.integer(installment['amount_cents'])),
            style: const TextStyle(
              color: AppTheme.lime,
              fontWeight: FontWeight.bold,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Ações da parcela',
            onSelected: (action) {
              if (action == 'edit') {
                _editCardExpense(context, installment);
              } else if (action == 'edit-all') {
                _editCardExpense(context, installment, purchase: purchase);
              } else if (action == 'delete') {
                _deleteCardExpense(context, installment);
              } else if (action == 'delete-all') {
                _deleteCardPurchase(
                  context,
                  purchaseId,
                  singleExpense: purchase.length == 1 ? installment : null,
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Text('Editar somente esta parcela'),
              ),
              if (purchase.length > 1)
                const PopupMenuItem(
                  value: 'edit-all',
                  child: Text('Editar todas as parcelas'),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Apagar somente esta parcela'),
              ),
              if (purchase.length > 1)
                const PopupMenuItem(
                  value: 'delete-all',
                  child: Text('Apagar todas as parcelas'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<Map<String, Object?>> _installmentsFor(
    Map<String, Object?> installment,
  ) {
    final purchaseId = FinanceController.string(installment['purchase_id']);
    if (purchaseId.isEmpty) return [installment];
    return vm.cardExpenses
        .where(
          (item) => FinanceController.string(item['purchase_id']) == purchaseId,
        )
        .toList()
      ..sort(
        (a, b) => FinanceController.integer(
          a['installment_index'],
        ).compareTo(FinanceController.integer(b['installment_index'])),
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
