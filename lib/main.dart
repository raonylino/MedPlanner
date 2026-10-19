import 'package:circle_nav_bar/circle_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/database/app_database.dart';
import 'core/theme/app_theme.dart';
import 'features/cards/cards_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/finance_view_model.dart';
import 'features/goals/goals_page.dart';
import 'features/income/income_page.dart';
import 'features/planning/planning_page.dart';
import 'features/settings/settings_page.dart';

void main() => runApp(const FinanceApp());

class FinanceApp extends StatefulWidget {
  const FinanceApp({super.key});
  @override
  State<FinanceApp> createState() => _FinanceAppState();
}

class _FinanceAppState extends State<FinanceApp> {
  late final FinanceViewModel vm = FinanceViewModel(AppDatabase.instance)
    ..load();
  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MedPlanner',
    debugShowCheckedModeBanner: false,
    locale: const Locale('pt', 'BR'),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('pt', 'BR')],
    theme: AppTheme.dark,
    home: AnimatedBuilder(
      animation: vm,
      builder: (context, _) =>
          vm.loading ? const MedPlannerSplash() : FinanceShell(vm: vm),
    ),
  );
}

class MedPlannerSplash extends StatelessWidget {
  const MedPlannerSplash({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: AppTheme.bg,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image(
            image: AssetImage('assets/image/icon.png'),
            width: 176,
            height: 176,
            fit: BoxFit.contain,
          ),
          SizedBox(height: 16),
          Text(
            'MedPlanner',
            style: TextStyle(
              color: AppTheme.text,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class FinanceShell extends StatefulWidget {
  const FinanceShell({required this.vm, super.key});
  final FinanceViewModel vm;
  @override
  State<FinanceShell> createState() => _FinanceShellState();
}

class _FinanceShellState extends State<FinanceShell> {
  int selected = 2;
  bool _tourCheckStarted = false;
  static const titles = [
    'Planejamento',
    'Recebimentos',
    'Visão geral',
    'Cartões',
    'Metas',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTour());
  }

  Future<void> _maybeShowTour() async {
    if (_tourCheckStarted) return;
    _tourCheckStarted = true;
    final shouldShow = await widget.vm.shouldShowTaxInvestmentTour();
    if (!mounted || !shouldShow) return;
    await _showTaxInvestmentTour(context);
    if (mounted) await widget.vm.markTaxInvestmentTourSeen();
  }

  Future<void> _showTaxInvestmentTour(BuildContext context) async {
    var step = 0;
    const pages = [
      (
        icon: Icons.percent,
        title: 'Imposto estimado',
        description:
            'Defina a porcentagem em Configurações. Ao cadastrar um recebimento, marque “Aplicar imposto?” para estimar o desconto. O cálculo aparece no mês em que o valor será recebido.',
      ),
      (
        icon: Icons.savings_outlined,
        title: 'Regras de investimento',
        description:
            'Crie regras percentuais ou de valor fixo em Configurações e escolha quais se aplicam a cada recebimento. As porcentagens são calculadas sobre o valor que sobra depois do imposto.',
      ),
      (
        icon: Icons.space_dashboard_outlined,
        title: 'Acompanhe no início',
        description:
            'O início mostra a soma anual estimada dos impostos e, abaixo, os valores de imposto e investimento do mês selecionado. Troque o mês para consultar outros recebimentos.',
      ),
    ];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final page = pages[step];
          return AlertDialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(dialogContext).width * 0.01,
            ),
            constraints: BoxConstraints(
              minWidth: MediaQuery.sizeOf(dialogContext).width * 0.98,
              maxWidth: MediaQuery.sizeOf(dialogContext).width * 0.98,
            ),
            backgroundColor: AppTheme.surface,
            title: const Text('Conheça o MedPlanner'),
            actionsAlignment: MainAxisAlignment.start,
            content: SizedBox(
              width: MediaQuery.sizeOf(dialogContext).width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(page.icon, color: AppTheme.lime, size: 34),
                  const SizedBox(height: 12),
                  Text(
                    page.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    page.description,
                    style: const TextStyle(color: AppTheme.muted, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${step + 1} de ${pages.length}',
                    style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            actions: [
              if (step > 0)
                TextButton(
                  onPressed: () => setDialogState(() => step--),
                  child: const Text('Voltar'),
                ),
              FilledButton(
                onPressed: () {
                  if (step == pages.length - 1) {
                    Navigator.pop(dialogContext);
                  } else {
                    setDialogState(() => step++);
                  }
                },
                child: Text(step == pages.length - 1 ? 'Concluir' : 'Próximo'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      IncomePage(vm: widget.vm),
      PlanningPage(vm: widget.vm),
      DashboardPage(vm: widget.vm),
      CardsPage(vm: widget.vm),
      GoalsPage(vm: widget.vm),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[selected],
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Configurações e backup',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SettingsPage(vm: widget.vm)),
            ),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: SafeArea(child: pages[selected]),
      bottomNavigationBar: CircleNavBar(
        activeIndex: selected,
        onTap: (index) => setState(() => selected = index),
        activeIcons: const [
          Icon(Icons.south_west, color: AppTheme.bg),
          Icon(Icons.event_note, color: AppTheme.bg),
          Icon(Icons.space_dashboard, color: AppTheme.bg),
          Icon(Icons.credit_card, color: AppTheme.bg),
          Icon(Icons.flag, color: AppTheme.bg),
        ],
        inactiveIcons: const [
          Icon(Icons.south_west, color: AppTheme.muted),
          Icon(Icons.event_note_outlined, color: AppTheme.muted),
          Icon(Icons.space_dashboard_outlined, color: AppTheme.muted),
          Icon(Icons.credit_card_outlined, color: AppTheme.muted),
          Icon(Icons.flag_outlined, color: AppTheme.muted),
        ],
        levels: const ['Entradas', 'Planejar', 'Início', 'Cartões', 'Metas'],
        activeLevelsStyle: const TextStyle(
          color: AppTheme.lime,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
        inactiveLevelsStyle: const TextStyle(
          color: AppTheme.muted,
          fontSize: 10,
        ),
        color: AppTheme.surface,
        circleColor: AppTheme.lime,
        height: 66,
        circleWidth: 56,
        padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
        cornerRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
        shadowColor: Colors.black26,
        elevation: 8,
      ),
    );
  }
}
