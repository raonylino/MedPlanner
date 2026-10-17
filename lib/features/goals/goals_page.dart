import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/ui.dart';
import '../finance_view_model.dart';

class GoalsPage extends StatelessWidget {
  const GoalsPage({required this.vm, super.key});
  final FinanceViewModel vm;

  Future<void> _add(BuildContext context) async {
    final categories = vm
        .categoriesFor('goals')
        .map(
          (c) => (
            value: FinanceViewModel.string(c['name']),
            label: FinanceViewModel.string(c['name']),
          ),
        )
        .toList();
    final data = await showSmartForm(context, 'Nova meta de compra', [
      const SmartFieldSpec(key: 'title', label: 'O que você quer comprar?'),
      SmartFieldSpec(
        key: 'category',
        label: 'Categoria',
        kind: SmartFieldKind.dropdown,
        options: categories,
        onCreateOption: (dialogContext) => createCategoryOption(
          dialogContext,
          (name) => vm.addCategory(name, 'goals'),
        ),
        onDeleteOption: (dialogContext, name) => deleteCategoryOption(
          dialogContext,
          name,
          vm.categoriesFor('goals'),
          vm.deleteCategory,
        ),
      ),
      const SmartFieldSpec(key: 'description', label: 'Descrição'),
      const SmartFieldSpec(
        key: 'unit',
        label: 'Valor unitário',
        keyboard: TextInputType.number,
      ),
      const SmartFieldSpec(
        key: 'quantity',
        label: 'Quantidade',
        initial: '1',
        keyboard: TextInputType.number,
      ),
    ]);
    if (data == null ||
        data['category'] == null ||
        data['title'].toString().trim().isEmpty ||
        centsFrom(data['unit'].toString()) <= 0) {
      return;
    }
    await vm.addGoal(
      title: data['title'].toString().trim(),
      category: data['category']?.toString() ?? 'Outros',
      description: data['description']?.toString() ?? '',
      unitCents: centsFrom(data['unit'].toString()),
      quantity: (int.tryParse(data['quantity'].toString()) ?? 1).clamp(
        1,
        10000,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Map<String, Object?>>>{};
    for (final goal in vm.goals) {
      grouped
          .putIfAbsent(FinanceViewModel.string(goal['category']), () => [])
          .add(goal);
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        const PageHeading(
          'Metas de compra',
          subtitle: 'Planeje objetivos sem misturá-los às despesas do mês.',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AmountCard(
            label: 'Valor total das metas',
            value: money(vm.goalTotal),
            highlight: true,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Seus objetivos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _add(context),
                icon: const Icon(Icons.add),
                label: const Text('Nova meta'),
              ),
            ],
          ),
        ),
        if (grouped.isEmpty)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Text(
              'Suas metas aparecem aqui. Elas não entram nos gastos até você decidir comprá-las.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted),
            ),
          ),
        ...grouped.entries.map((group) {
          final subtotal = group.value.fold(
            0,
            (sum, item) =>
                sum +
                FinanceViewModel.integer(item['unit_cents']) *
                    FinanceViewModel.integer(item['quantity']),
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
                ...group.value.map((goal) {
                  final amount =
                      FinanceViewModel.integer(goal['unit_cents']) *
                      FinanceViewModel.integer(goal['quantity']);
                  final details = FinanceViewModel.string(goal['description']);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: RecordTile(
                      title: FinanceViewModel.string(goal['title']),
                      subtitle:
                          '${goal['quantity']} × ${money(FinanceViewModel.integer(goal['unit_cents']))}${details.isEmpty ? '' : '\n$details'}',
                      trailing: money(amount),
                      onDelete: () => vm.delete(
                        'goals',
                        FinanceViewModel.integer(goal['id']),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }
}
