import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/ui.dart';
import '../viewmodel/income_view_model.dart';

class IncomePage extends StatefulWidget {
  const IncomePage({required this.vm, super.key});
  final FinanceController vm;
  @override
  State<IncomePage> createState() => _IncomePageState();
}

class _IncomePageState extends State<IncomePage> {
  int tab = 0;
  FinanceController get vm => widget.vm;

  Future<void> _editOrAdd(
    BuildContext context, {
    Map<String, Object?>? existing,
    Map<String, Object?>? savedService,
  }) async {
    final currentMonth = vm.month;
    final initialDate = FinanceController.string(
      existing?['date'] ?? DateTime.now().toIso8601String(),
    ).split('T').first;
    final monthOptionsList = monthOptions(monthsBack: 12, monthsForward: 60);
    final name = FinanceController.string(
      existing?['service'] ?? savedService?['name'],
    );
    final unit = existing?['unit_cents'] ?? savedService?['unit_cents'];
    final defaultInvestmentIds = vm.investments
        .map((investment) => FinanceController.string(investment['id']))
        .join(',');
    final storedInvestmentIds = FinanceController.string(
      existing?['investment_ids'],
    );
    final selectedInvestmentIds = existing == null || storedInvestmentIds == '*'
        ? defaultInvestmentIds
        : storedInvestmentIds;
    final data = await showSmartForm(
      context,
      existing == null ? 'Novo plantão' : 'Editar plantão',
      [
        SmartFieldSpec(
          key: 'service',
          label: 'Local trabalhado',
          initial: name,
        ),
        SmartFieldSpec(
          key: 'date',
          label: 'Data do plantão',
          initial: initialDate,
          kind: SmartFieldKind.date,
        ),
        SmartFieldSpec(
          key: 'unit',
          label: 'Valor de cada plantão',
          initial: unit == null
              ? ''
              : (FinanceController.integer(unit) / 100)
                    .toStringAsFixed(2)
                    .replaceAll('.', ','),
          keyboard: const TextInputType.numberWithOptions(decimal: true),
        ),
        SmartFieldSpec(
          key: 'quantity',
          label: 'Quantidade de plantões',
          initial: '${existing?['quantity'] ?? 1}',
          keyboard: const TextInputType.numberWithOptions(decimal: true),
        ),
        SmartFieldSpec(
          key: 'tax',
          label: 'Aplicar imposto?',
          initial:
              '${FinanceController.integer(existing?['tax_applies']) == 1}',
          kind: SmartFieldKind.toggle,
        ),
        SmartFieldSpec(
          key: 'investment_ids',
          label: 'Regras de investimento aplicadas',
          initial: selectedInvestmentIds,
          kind: SmartFieldKind.multiSelect,
          options: vm.investments.map((investment) {
            final mode = FinanceController.string(investment['mode']);
            final amount = mode == 'percent'
                ? '${investment['value']}%'
                : money(FinanceController.integer(investment['value']));
            return (
              value: FinanceController.string(investment['id']),
              label: '${investment['name']} • $amount',
            );
          }).toList(),
        ),
        SmartFieldSpec(
          key: 'receive_month',
          label: 'Mês de recebimento',
          initial: FinanceController.string(
            existing?['receive_month'] ?? currentMonth,
          ),
          kind: SmartFieldKind.dropdown,
          options: monthOptionsList,
        ),
      ],
      onDelete: existing == null
          ? null
          : (dialogContext) => _deleteIncome(dialogContext, existing),
    );
    if (data == null ||
        data['service'].toString().trim().isEmpty ||
        centsFrom(data['unit'].toString()) <= 0) {
      return;
    }
    if (!context.mounted) return;
    final quantity = double.tryParse(
      data['quantity'].toString().trim().replaceAll(',', '.'),
    );
    if (quantity == null || !quantity.isFinite || quantity <= 0) {
      showFloatingNotice(
        context,
        'Informe uma quantidade de plantões maior que zero.',
      );
      return;
    }
    final payload = {
      'service': data['service'].toString().trim(),
      'unitCents': centsFrom(data['unit'].toString()),
      'quantity': quantity,
      'date': DateTime.tryParse(data['date'].toString()) ?? DateTime.now(),
      'receiveMonth': data['receive_month'].toString(),
      'tax': data['tax'] as bool? ?? false,
      'investmentIds': data['investment_ids']?.toString() ?? '',
    };
    if (existing == null) {
      await vm.addIncome(
        service: payload['service'] as String,
        quantity: payload['quantity'] as double,
        unitCents: payload['unitCents'] as int,
        date: payload['date'] as DateTime,
        receiveMonth: payload['receiveMonth'] as String,
        tax: payload['tax'] as bool,
        investmentIds: payload['investmentIds'] as String,
      );
    } else {
      await vm.updateIncome(
        id: FinanceController.integer(existing['id']),
        service: payload['service'] as String,
        quantity: payload['quantity'] as double,
        unitCents: payload['unitCents'] as int,
        date: payload['date'] as DateTime,
        receiveMonth: payload['receiveMonth'] as String,
        tax: payload['tax'] as bool,
        investmentIds: payload['investmentIds'] as String,
      );
    }
  }

  Future<bool> _deleteIncome(
    BuildContext context,
    Map<String, Object?> income,
  ) async {
    final deleted = await confirmDeleteRecord(
      context,
      title: 'Apagar plantão?',
      message: 'Este plantão será removido permanentemente.',
    );
    if (!deleted || !context.mounted) return false;
    await vm.delete('incomes', FinanceController.integer(income['id']));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final receivedTab = tab == 1;
    final items = vm.incomes.where((entry) {
      if (receivedTab) return entry['receive_month'] == vm.month;
      final workDate = DateTime.tryParse(
        FinanceController.string(entry['date']),
      );
      return workDate != null &&
          FinanceController.monthFromDate(workDate) == vm.month;
    }).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        const PageHeading(
          'Entradas',
          subtitle: 'Acompanhe quando trabalhou e quando vai receber.',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AmountCard(
            label: 'Disponível projetado • ${monthLabel(vm.month)}',
            value: money(vm.incomeTotal),
            highlight: true,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Trabalhados'),
                icon: Icon(Icons.work_outline),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Recebimentos'),
                icon: Icon(Icons.check_circle_outline),
              ),
            ],
            selected: {tab},
            onSelectionChanged: (selection) =>
                setState(() => tab = selection.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _monthPicker(),
        ),
        if (vm.services.isNotEmpty && tab == 0) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 2),
            child: Text(
              'Locais salvos',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6,
              children: vm.services
                  .map(
                    (service) => ActionChip(
                      label: Text(FinanceController.string(service['name'])),
                      onPressed: () =>
                          _editOrAdd(context, savedService: service),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  receivedTab ? 'Recebimentos do mês' : 'Plantões trabalhados',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!receivedTab)
                FilledButton.icon(
                  onPressed: () => _editOrAdd(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar'),
                ),
            ],
          ),
        ),
        ...items.map((entry) {
          final id = FinanceController.integer(entry['id']);
          final received = FinanceController.integer(entry['received']) == 1;
          final value = vm.incomeValue(entry);
          final date = FinanceController.string(entry['date']).split('T').first;
          final quantity = FinanceController.decimal(entry['quantity']);
          final quantityLabel = quantity == quantity.truncateToDouble()
              ? quantity.toInt().toString()
              : quantity.toString().replaceAll('.', ',');
          return Card(
            child: ListTile(
              leading: IconButton(
                tooltip: received
                    ? 'Marcar como trabalhado'
                    : 'Marcar como recebido',
                onPressed: () => vm.setPaid('incomes', id, !received),
                icon: Icon(
                  received ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: received ? AppTheme.lime : AppTheme.muted,
                ),
              ),
              title: Text(
                FinanceController.string(entry['service']),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${dateLabel(date)} • $quantityLabel ${quantity == 1 ? 'plantão' : 'plantões'}${FinanceController.integer(entry['tax_applies']) == 1 ? ' • imposto aplicado' : ''}',
                style: TextStyle(color: AppTheme.muted),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    money(value),
                    style: TextStyle(
                      color: AppTheme.valueGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar entrada',
                    onPressed: () => _editOrAdd(context, existing: entry),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ),
          );
        }),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              receivedTab
                  ? 'Ainda não há recebimentos previstos para este mês.'
                  : 'Ainda não há plantões cadastrados para ${monthLabel(vm.month)}.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Text(
            'O valor exibido é uma estimativa líquida após imposto selecionado e investimentos configurados.',
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
      label: tab == 1 ? 'Mês de recebimento' : 'Mês trabalhado',
    );
  }
}
