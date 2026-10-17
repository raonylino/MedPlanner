import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/ui.dart';
import '../finance_view_model.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({required this.vm, super.key});
  final FinanceViewModel vm;
  @override
  Widget build(BuildContext context) {
    final net = vm.incomeTotal - vm.plannedTotal - vm.cardTotal;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        const Text(
          'Seu resumo mensal',
          style: TextStyle(color: AppTheme.muted),
        ),
        const SizedBox(height: 8),
        MonthCarousel(
          selectedMonth: vm.month,
          onChanged: vm.setMonthValue,
          label: 'Mês',
        ),
        const SizedBox(height: 10),
        AmountCard(
          label: 'Saldo projetado',
          value: money(net),
          highlight: true,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AmountCard(
                label: 'Entradas líquidas',
                value: money(vm.incomeTotal),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AmountCard(
                label: 'Despesas previstas',
                value: money(vm.plannedTotal + vm.cardTotal),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _taxAndInvestmentsCard(),
        const SizedBox(height: 22),
        const Text(
          'Acompanhe o mês',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _progress(
          context,
          'Despesas planejadas pagas',
          vm.paidTotal,
          vm.plannedTotal,
        ),
        const SizedBox(height: 12),
        _progress(
          context,
          'Parcelas e compras no cartão',
          vm.cardTotal,
          vm.cards.fold(
            0,
            (a, c) => a + FinanceViewModel.integer(c['limit_cents']),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Próximos compromissos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '${vm.expenses.where((e) => e['month'] == vm.month && FinanceViewModel.integer(e['paid']) == 0).length} pendentes',
              style: const TextStyle(color: AppTheme.muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...vm.expenses
            .where((e) => e['month'] == vm.month)
            .take(5)
            .map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RecordTile(
                  title: FinanceViewModel.string(e['title']),
                  subtitle:
                      '${e['category']} • ${FinanceViewModel.integer(e['paid']) == 1 ? 'Pago' : 'Previsto'}',
                  trailing: money(FinanceViewModel.integer(e['amount_cents'])),
                ),
              ),
            ),
        if (vm.expenses.isEmpty && vm.cardExpenses.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Adicione suas primeiras despesas para ver o planejamento aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted),
            ),
          ),
        const SizedBox(height: 20),
        Text(
          'Total de metas: ${money(vm.goalTotal)}',
          style: const TextStyle(color: AppTheme.muted),
        ),
      ],
    );
  }

  Widget _taxAndInvestmentsCard() {
    final selectedYear =
        int.tryParse(vm.month.split('-').first) ?? DateTime.now().year;
    final tax = vm.taxPercent
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'\.?0+$'), '')
        .replaceAll('.', ',');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Impostos e investimentos',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Imposto estimado anual • $selectedYear',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  money(vm.taxAmountForYear(selectedYear)),
                  style: const TextStyle(
                    color: AppTheme.lime,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Soma dos impostos previstos para o ano selecionado.',
            style: TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Text(
            'Valores de ${monthLabel(vm.month)}',
            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.percent, size: 18, color: AppTheme.lime),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Imposto estimado • $tax%',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                money(vm.taxAmountForMonth(vm.month)),
                style: const TextStyle(
                  color: AppTheme.lime,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (vm.investments.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Nenhuma regra de investimento cadastrada.',
                style: TextStyle(color: AppTheme.muted),
              ),
            )
          else
            ...vm.investments.map((investment) {
              final isPercent = investment['mode'] == 'percent';
              final ruleValue = isPercent
                  ? '${investment['value']}%'
                  : '${money(FinanceViewModel.integer(investment['value']))} fixos';
              final monthlyValue = vm.monthlyInvestmentAmount(
                FinanceViewModel.integer(investment['id']),
                forMonth: vm.month,
              );
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    const Icon(
                      Icons.savings_outlined,
                      size: 18,
                      color: AppTheme.lime,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            FinanceViewModel.string(investment['name']),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            ruleValue,
                            style: const TextStyle(
                              color: AppTheme.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      money(monthlyValue),
                      style: const TextStyle(
                        color: AppTheme.lime,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
          const Text(
            'O imposto e os investimentos acima consideram apenas os recebimentos previstos para o mês selecionado.',
            style: TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _progress(BuildContext context, String label, int value, int total) {
    final fraction = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Container(
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
              Expanded(child: Text(label)),
              Text(
                money(value),
                style: const TextStyle(
                  color: AppTheme.lime,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: fraction,
            minHeight: 7,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: AppTheme.surface2,
            color: AppTheme.lime,
          ),
          const SizedBox(height: 8),
          Text(
            'de ${money(total)}',
            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
