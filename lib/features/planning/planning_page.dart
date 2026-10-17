import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/ui.dart';
import '../finance_view_model.dart';

class PlanningPage extends StatelessWidget {
  const PlanningPage({required this.vm, super.key});
  final FinanceViewModel vm;

  Future<void> _editOrAdd(
    BuildContext context, {
    Map<String, Object?>? existing,
  }) async {
    final options = vm
        .categoriesFor('planning')
        .map(
          (c) => (
            value: FinanceViewModel.string(c['name']),
            label: FinanceViewModel.string(c['name']),
          ),
        )
        .toList();
    final selectedCategory = FinanceViewModel.string(existing?['category']);
    if (selectedCategory.isNotEmpty &&
        !options.any((option) => option.value == selectedCategory)) {
      options.add((value: selectedCategory, label: selectedCategory));
    }
    final data = await showSmartForm(
      context,
      existing == null ? 'Nova despesa planejada' : 'Editar despesa planejada',
      [
        SmartFieldSpec(
          key: 'category',
          label: 'Categoria',
          initial: selectedCategory,
          kind: SmartFieldKind.dropdown,
          options: options,
          onCreateOption: (dialogContext) => createCategoryOption(
            dialogContext,
            (name) => vm.addCategory(name, 'planning'),
          ),
          onDeleteOption: (dialogContext, name) => deleteCategoryOption(
            dialogContext,
            name,
            vm.categoriesFor('planning'),
            vm.deleteCategory,
          ),
        ),
        SmartFieldSpec(
          key: 'title',
          label: 'Nome da despesa',
          initial: FinanceViewModel.string(existing?['title']),
        ),
        SmartFieldSpec(
          key: 'amount',
          label: 'Valor',
          initial: existing == null
              ? ''
              : (FinanceViewModel.integer(existing['amount_cents']) / 100)
                    .toStringAsFixed(2)
                    .replaceAll('.', ','),
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
    final title = data['title'].toString().trim();
    final category = data['category']?.toString() ?? 'Outros';
    final cents = centsFrom(data['amount'].toString());
    if (existing == null) {
      await vm.addExpense(
        title: title,
        category: category,
        cents: cents,
        month: vm.month,
      );
    } else {
      await vm.updateExpense(
        id: FinanceViewModel.integer(existing['id']),
        title: title,
        category: category,
        cents: cents,
      );
    }
  }

  Future<void> _deleteExpense(
    BuildContext context,
    Map<String, Object?> expense,
  ) async {
    final deleted = await confirmDeleteRecord(
      context,
      title: 'Apagar despesa?',
      message: 'Esta despesa planejada será removida permanentemente.',
    );
    if (!deleted || !context.mounted) return;
    await vm.delete('expenses', FinanceViewModel.integer(expense['id']));
  }

  @override
  Widget build(BuildContext context) {
    final items = vm.expenses.where((e) => e['month'] == vm.month).toList();
    final grouped = <String, List<Map<String, Object?>>>{};
    for (final item in items) {
      grouped
          .putIfAbsent(FinanceViewModel.string(item['category']), () => [])
          .add(item);
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        const PageHeading(
          'Planejamento mensal',
          subtitle: 'Organize despesas por mês e categoria.',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _monthPicker(),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: AmountCard(
                  label: 'Prevista',
                  value: money(vm.plannedTotal),
                  highlight: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AmountCard(label: 'Já pago', value: money(vm.paidTotal)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Despesas do mês',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _editOrAdd(context),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar'),
              ),
            ],
          ),
        ),
        if (grouped.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Nenhuma despesa planejada para este mês.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted),
            ),
          ),
        ...grouped.entries.map((group) {
          final subtotal = group.value.fold(
            0,
            (sum, e) => sum + FinanceViewModel.integer(e['amount_cents']),
          );
          final percent = vm.plannedTotal == 0
              ? 0
              : (subtotal * 100 / vm.plannedTotal).round();
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surface2,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.key,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                      const SizedBox(width: 12),
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
                ...group.value.map((e) {
                  final id = FinanceViewModel.integer(e['id']);
                  final paid = FinanceViewModel.integer(e['paid']) == 1;
                  return Card(
                    child: CheckboxListTile(
                      value: paid,
                      onChanged: (v) => vm.setPaid('expenses', id, v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(FinanceViewModel.string(e['title'])),
                      subtitle: Text(
                        paid ? 'Pago' : 'Previsto',
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                      secondary: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            money(FinanceViewModel.integer(e['amount_cents'])),
                            style: const TextStyle(
                              color: AppTheme.lime,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Ações da despesa',
                            onSelected: (action) {
                              if (action == 'edit') {
                                _editOrAdd(context, existing: e);
                              } else if (action == 'delete') {
                                _deleteExpense(context, e);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Apagar'),
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
      ],
    );
  }

  Widget _monthPicker() {
    return MonthCarousel(
      selectedMonth: vm.month,
      onChanged: vm.setMonthValue,
      label: 'Mês do planejamento',
    );
  }
}
