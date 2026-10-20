import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/ui.dart';
import '../viewmodel/goals_view_model.dart';

class GoalsPage extends StatelessWidget {
  const GoalsPage({required this.vm, super.key});
  final FinanceController vm;

  Future<void> _editOrAdd(
    BuildContext context, {
    Map<String, Object?>? existing,
  }) async {
    final selectedCategory = FinanceController.string(existing?['category']);
    final categories = vm
        .categoriesFor('goals')
        .map(
          (c) => (
            value: FinanceController.string(c['name']),
            label: FinanceController.string(c['name']),
          ),
        )
        .toList();
    if (selectedCategory.isNotEmpty &&
        !categories.any((option) => option.value == selectedCategory)) {
      categories.add((value: selectedCategory, label: selectedCategory));
    }
    final data = await showSmartForm(
      context,
      existing == null ? 'Nova meta de compra' : 'Editar meta',
      [
        SmartFieldSpec(
          key: 'title',
          label: 'O que você quer comprar?',
          initial: FinanceController.string(existing?['title']),
        ),
        SmartFieldSpec(
          key: 'category',
          label: 'Categoria',
          initial: selectedCategory,
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
        SmartFieldSpec(
          key: 'description',
          label: 'Descrição',
          initial: FinanceController.string(existing?['description']),
        ),
        SmartFieldSpec(
          key: 'unit',
          label: 'Valor unitário',
          initial: existing == null
              ? ''
              : (FinanceController.integer(existing['unit_cents']) / 100)
                    .toStringAsFixed(2)
                    .replaceAll('.', ','),
          keyboard: TextInputType.number,
        ),
        SmartFieldSpec(
          key: 'quantity',
          label: 'Quantidade',
          initial: '${existing?['quantity'] ?? 1}',
          keyboard: TextInputType.number,
        ),
      ],
    );
    if (data == null ||
        data['category'] == null ||
        data['title'].toString().trim().isEmpty ||
        centsFrom(data['unit'].toString()) <= 0) {
      return;
    }
    final payload = {
      'title': data['title'].toString().trim(),
      'category': data['category']?.toString() ?? 'Outros',
      'description': data['description']?.toString() ?? '',
      'unitCents': centsFrom(data['unit'].toString()),
      'quantity': (int.tryParse(data['quantity'].toString()) ?? 1).clamp(
        1,
        10000,
      ),
    };
    if (existing == null) {
      await vm.addGoal(
        title: payload['title'] as String,
        category: payload['category'] as String,
        description: payload['description'] as String,
        unitCents: payload['unitCents'] as int,
        quantity: payload['quantity'] as int,
      );
    } else {
      await vm.updateGoal(
        id: FinanceController.integer(existing['id']),
        title: payload['title'] as String,
        category: payload['category'] as String,
        description: payload['description'] as String,
        unitCents: payload['unitCents'] as int,
        quantity: payload['quantity'] as int,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Map<String, Object?>>>{};
    for (final goal in vm.goals) {
      grouped
          .putIfAbsent(FinanceController.string(goal['category']), () => [])
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
                onPressed: () => _editOrAdd(context),
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
                FinanceController.integer(item['unit_cents']) *
                    FinanceController.integer(item['quantity']),
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
                      FinanceController.integer(goal['unit_cents']) *
                      FinanceController.integer(goal['quantity']);
                  final details = FinanceController.string(goal['description']);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: RecordTile(
                      title: FinanceController.string(goal['title']),
                      subtitle:
                          '${goal['quantity']} × ${money(FinanceController.integer(goal['unit_cents']))}${details.isEmpty ? '' : '\n$details'}',
                      trailing: money(amount),
                      onEdit: () => _editOrAdd(context, existing: goal),
                      onDelete: () => vm.delete(
                        'goals',
                        FinanceController.integer(goal['id']),
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
