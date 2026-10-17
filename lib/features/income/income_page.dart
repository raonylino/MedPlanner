import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/ui.dart';
import '../finance_view_model.dart';

class IncomePage extends StatefulWidget {
  const IncomePage({required this.vm, super.key});
  final FinanceViewModel vm;
  @override
  State<IncomePage> createState() => _IncomePageState();
}

class _IncomePageState extends State<IncomePage> {
  int tab = 0;
  FinanceViewModel get vm => widget.vm;

  Future<void> _editOrAdd(
    BuildContext context, {
    Map<String, Object?>? existing,
    Map<String, Object?>? savedService,
  }) async {
    final currentMonth = vm.month;
    final initialDate = FinanceViewModel.string(
      existing?['date'] ?? DateTime.now().toIso8601String(),
    ).split('T').first;
    final monthOptionsList = monthOptions(monthsBack: 12, monthsForward: 60);
    final name = FinanceViewModel.string(
      existing?['service'] ?? savedService?['name'],
    );
    final unit = existing?['unit_cents'] ?? savedService?['unit_cents'];
    final defaultInvestmentIds = vm.investments
        .map((investment) => FinanceViewModel.string(investment['id']))
        .join(',');
    final storedInvestmentIds = FinanceViewModel.string(
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
              : (FinanceViewModel.integer(unit) / 100)
                    .toStringAsFixed(2)
                    .replaceAll('.', ','),
          keyboard: TextInputType.number,
        ),
        SmartFieldSpec(
          key: 'quantity',
          label: 'Quantidade de plantões',
          initial: '${existing?['quantity'] ?? 1}',
          keyboard: TextInputType.number,
        ),
        SmartFieldSpec(
          key: 'tax',
          label: 'Aplicar imposto?',
          initial: '${FinanceViewModel.integer(existing?['tax_applies']) == 1}',
          kind: SmartFieldKind.toggle,
        ),
        SmartFieldSpec(
          key: 'investment_ids',
          label: 'Regras de investimento aplicadas',
          initial: selectedInvestmentIds,
          kind: SmartFieldKind.multiSelect,
          options: vm.investments.map((investment) {
            final mode = FinanceViewModel.string(investment['mode']);
            final amount = mode == 'percent'
                ? '${investment['value']}%'
                : money(FinanceViewModel.integer(investment['value']));
            return (
              value: FinanceViewModel.string(investment['id']),
              label: '${investment['name']} • $amount',
            );
          }).toList(),
        ),
        SmartFieldSpec(
          key: 'receive_month',
          label: 'Mês de recebimento',
          initial: FinanceViewModel.string(
            existing?['receive_month'] ?? currentMonth,
          ),
          kind: SmartFieldKind.dropdown,
          options: monthOptionsList,
        ),
      ],
    );
    if (data == null ||
        data['service'].toString().trim().isEmpty ||
        centsFrom(data['unit'].toString()) <= 0) {
      return;
    }
    final payload = {
      'service': data['service'].toString().trim(),
      'unitCents': centsFrom(data['unit'].toString()),
      'quantity': (int.tryParse(data['quantity'].toString()) ?? 1).clamp(
        1,
        10000,
      ),
      'date': DateTime.tryParse(data['date'].toString()) ?? DateTime.now(),
      'receiveMonth': data['receive_month'].toString(),
      'tax': data['tax'] as bool? ?? false,
      'investmentIds': data['investment_ids']?.toString() ?? '',
    };
    if (existing == null) {
      await vm.addIncome(
        service: payload['service'] as String,
        quantity: payload['quantity'] as int,
        unitCents: payload['unitCents'] as int,
        date: payload['date'] as DateTime,
        receiveMonth: payload['receiveMonth'] as String,
        tax: payload['tax'] as bool,
        investmentIds: payload['investmentIds'] as String,
      );
    } else {
      await vm.updateIncome(
        id: FinanceViewModel.integer(existing['id']),
        service: payload['service'] as String,
        quantity: payload['quantity'] as int,
        unitCents: payload['unitCents'] as int,
        date: payload['date'] as DateTime,
        receiveMonth: payload['receiveMonth'] as String,
        tax: payload['tax'] as bool,
        investmentIds: payload['investmentIds'] as String,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final receivedTab = tab == 1;
    final items = vm.incomes.where((entry) {
      if (receivedTab) return entry['receive_month'] == vm.month;
      final workDate = DateTime.tryParse(
        FinanceViewModel.string(entry['date']),
      );
      return workDate != null &&
          FinanceViewModel.monthFromDate(workDate) == vm.month;
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
          const Padding(
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
                      label: Text(FinanceViewModel.string(service['name'])),
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
                  style: const TextStyle(
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
          final id = FinanceViewModel.integer(entry['id']);
          final received = FinanceViewModel.integer(entry['received']) == 1;
          final value = vm.incomeValue(entry);
          final date = FinanceViewModel.string(entry['date']).split('T').first;
          final qty = FinanceViewModel.integer(entry['quantity']);
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
                FinanceViewModel.string(entry['service']),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${dateLabel(date)} • $qty ${qty == 1 ? 'plantão' : 'plantões'}${FinanceViewModel.integer(entry['tax_applies']) == 1 ? ' • imposto aplicado' : ''}',
                style: const TextStyle(color: AppTheme.muted),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    money(value),
                    style: const TextStyle(
                      color: AppTheme.lime,
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
              style: const TextStyle(color: AppTheme.muted),
            ),
          ),
        const Padding(
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
