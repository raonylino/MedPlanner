import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/ui.dart';
import '../viewmodel/planning_view_model.dart';

class PlanningPage extends StatelessWidget {
  const PlanningPage({required this.vm, super.key});
  final FinanceController vm;

  Future<void> _editOrAdd(
    BuildContext context, {
    Map<String, Object?>? existing,
  }) async {
    final targetMonth = FinanceController.string(
      existing?['month'] ?? vm.month,
    );
    final firstDay = DateTime.tryParse('$targetMonth-01') ?? DateTime.now();
    final lastDay = DateTime(firstDay.year, firstDay.month + 1, 0);
    final today = DateTime.now();
    final defaultDay =
        existing == null &&
            today.year == firstDay.year &&
            today.month == firstDay.month
        ? today.day
        : 1;
    final initialDueDate = existing == null
        ? '${firstDay.year}-${firstDay.month.toString().padLeft(2, '0')}-${defaultDay.toString().padLeft(2, '0')}'
        : FinanceController.string(existing['due_date']);
    final options = vm
        .categoriesFor('planning')
        .map(
          (c) => (
            value: FinanceController.string(c['name']),
            label: FinanceController.string(c['name']),
          ),
        )
        .toList();
    final selectedCategory = FinanceController.string(existing?['category']);
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
          initial: FinanceController.string(existing?['title']),
        ),
        SmartFieldSpec(
          key: 'amount',
          label: 'Valor',
          initial: existing == null
              ? ''
              : (FinanceController.integer(existing['amount_cents']) / 100)
                    .toStringAsFixed(2)
                    .replaceAll('.', ','),
          keyboard: const TextInputType.numberWithOptions(decimal: true),
        ),

        if (existing == null)
          const SmartFieldSpec(
            key: 'repeat_count',
            label: 'Repetir por quantos meses? (total, incluindo este mês)',
            initial: '1',
            keyboard: TextInputType.number,
          ),
        SmartFieldSpec(
          key: 'due_date',
          label: 'Vencimento',
          initial: initialDueDate,
          kind: SmartFieldKind.optionalDate,
          firstDate: firstDay,
          lastDate: lastDay,
          spacingAfter: 12,
          helperText:
              'Com o vencimento definido, você receberá uma notificação no dia e outra um dia antes, se as notificações do aparelho estiverem ativadas.',
        ),
      ],
    );
    if (data == null ||
        data['category'] == null ||
        data['title'].toString().trim().isEmpty ||
        centsFrom(data['amount'].toString()) <= 0) {
      return;
    }
    if (!context.mounted) return;
    final repeatCount = int.tryParse(data['repeat_count']?.toString() ?? '1');
    if (existing == null &&
        (repeatCount == null || repeatCount < 1 || repeatCount > 120)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe uma quantidade entre 1 e 120 meses.'),
        ),
      );
      return;
    }
    final dueDate = DateTime.tryParse(data['due_date']?.toString() ?? '');
    final title = data['title'].toString().trim();
    final category = data['category']?.toString() ?? 'Outros';
    final cents = centsFrom(data['amount'].toString());
    if (existing == null) {
      final remindersEnabled = await vm.addExpense(
        title: title,
        category: category,
        cents: cents,
        month: vm.month,
        dueDate: dueDate,
        repeatCount: repeatCount!,
      );
      if (dueDate != null && !remindersEnabled && context.mounted) {
        _showNotificationUnavailable(context);
      }
    } else {
      final remindersEnabled = await vm.updateExpense(
        id: FinanceController.integer(existing['id']),
        title: title,
        category: category,
        cents: cents,
        dueDate: dueDate,
      );
      if (dueDate != null && !remindersEnabled && context.mounted) {
        _showNotificationUnavailable(context);
      }
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
    await vm.delete('expenses', FinanceController.integer(expense['id']));
  }

  @override
  Widget build(BuildContext context) {
    final items = vm.expenses.where((e) => e['month'] == vm.month).toList();
    final grouped = <String, List<Map<String, Object?>>>{};
    for (final item in items) {
      grouped
          .putIfAbsent(FinanceController.string(item['category']), () => [])
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
          Padding(
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
            (sum, e) => sum + FinanceController.integer(e['amount_cents']),
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
                        style: TextStyle(color: AppTheme.muted),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        money(subtotal),
                        style: TextStyle(
                          color: AppTheme.valueGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ...group.value.map((e) {
                  final id = FinanceController.integer(e['id']);
                  final paid = FinanceController.integer(e['paid']) == 1;
                  final dueDate = FinanceController.string(e['due_date']);
                  return Card(
                    child: CheckboxListTile(
                      value: paid,
                      onChanged: (v) async {
                        final remindersEnabled = await vm.setPaid(
                          'expenses',
                          id,
                          v ?? false,
                        );
                        if (!remindersEnabled && context.mounted) {
                          _showNotificationUnavailable(context);
                        }
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(FinanceController.string(e['title'])),
                      subtitle: Text(
                        [
                          paid ? 'Pago' : 'Previsto',
                          if (dueDate.isNotEmpty)
                            'Vence em ${dateLabel(dueDate)}',
                        ].join(' • '),
                        style: TextStyle(color: AppTheme.muted),
                      ),
                      secondary: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            money(FinanceController.integer(e['amount_cents'])),
                            style: TextStyle(
                              color: AppTheme.valueGreen,
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

  void _showNotificationUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Despesa atualizada, mas os lembretes estão desativados. Ative as notificações nas configurações do aparelho.',
        ),
      ),
    );
  }
}
