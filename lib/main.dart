import 'dart:async';

import 'package:circle_nav_bar/circle_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/providers/app_providers.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/view/login_page.dart';
import 'features/auth/view/password_recovery_page.dart';
import 'features/cards/view/cards_page.dart';
import 'features/cards/viewmodel/cards_view_model.dart';
import 'features/dashboard/view/dashboard_page.dart';
import 'features/dashboard/viewmodel/dashboard_view_model.dart';
import 'features/goals/view/goals_page.dart';
import 'features/goals/viewmodel/goals_view_model.dart';
import 'features/income/view/income_page.dart';
import 'features/income/viewmodel/income_view_model.dart';
import 'features/planning/view/planning_page.dart';
import 'features/planning/viewmodel/planning_view_model.dart';
import 'features/settings/view/settings_page.dart';
import 'features/settings/viewmodel/settings_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  runApp(const ProviderScope(child: FinanceApp()));
}

class FinanceApp extends ConsumerWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financeProvider);
    AppTheme.lightMode = state.lightTheme;
    return MaterialApp(
      title: 'MedPlanner',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('pt', 'BR')],
      theme: AppTheme.current,
      home: state.loading ? const MedPlannerSplash() : const AppEntryGate(),
    );
  }
}

class AppEntryGate extends ConsumerStatefulWidget {
  const AppEntryGate({super.key});

  @override
  ConsumerState<AppEntryGate> createState() => _AppEntryGateState();
}

class _AppEntryGateState extends ConsumerState<AppEntryGate> {
  bool _passwordRecoveryFlow = false;
  String? _bindingUserId;
  Future<Map<String, Object?>?>? _bindingFuture;

  @override
  Widget build(BuildContext context) {
    ref.listen(supabaseAuthStateProvider, (previous, next) {
      if (next.asData?.value.session != null) {
        unawaited(ref.read(autoSyncServiceProvider).watchCurrentUser());
      } else if (next.asData != null) {
        unawaited(ref.read(autoSyncServiceProvider).stopWatching());
      }
      final event = next.asData?.value.event;
      if (event == AuthChangeEvent.passwordRecovery && !_passwordRecoveryFlow) {
        setState(() => _passwordRecoveryFlow = true);
      } else if (event == AuthChangeEvent.signedOut && _passwordRecoveryFlow) {
        setState(() => _passwordRecoveryFlow = false);
      }
    });

    final authState = ref.watch(supabaseAuthStateProvider);
    final event = authState.asData?.value.event;
    if (event == AuthChangeEvent.passwordRecovery) {
      _passwordRecoveryFlow = true;
    }
    if (_passwordRecoveryFlow) return const PasswordRecoveryPage();

    final session =
        authState.asData?.value.session ??
        ref.read(supabaseClientProvider).auth.currentSession;
    if (session != null) {
      if (_bindingUserId != session.user.id) {
        _bindingUserId = session.user.id;
        _bindingFuture = ref.read(appDatabaseProvider).syncState();
      }
      return FutureBuilder<Map<String, Object?>?>(
        future: _bindingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const MedPlannerSplash();
          }
          final boundUser = snapshot.data?['user_id']?.toString();
          if (snapshot.hasError) {
            return _LocalAccountMismatch(
              email: session.user.email ?? '',
              reason:
                  'Não foi possível verificar a conta associada a este aparelho. Saia e tente novamente.',
              onSignOut: () => ref.read(authViewModelProvider).signOut(),
            );
          }
          if (boundUser != null && boundUser != session.user.id) {
            return _LocalAccountMismatch(
              email: session.user.email ?? '',
              reason:
                  'Os dados locais pertencem à conta sincronizada anteriormente. Entre na conta original para continuar.',
              onSignOut: () => ref.read(authViewModelProvider).signOut(),
            );
          }
          return const FinanceShell();
        },
      );
    }
    if (authState.isLoading) return const MedPlannerSplash();
    return const LoginPage();
  }
}

class _LocalAccountMismatch extends StatelessWidget {
  const _LocalAccountMismatch({
    required this.email,
    required this.reason,
    required this.onSignOut,
  });
  final String email;
  final String reason;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.bg,
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 42, color: AppTheme.lime),
                const SizedBox(height: 18),
                const Text(
                  'Este aparelho não pode usar esta conta',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  '$reason\n\nConta atual: $email',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.muted, height: 1.5),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sair desta conta'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class MedPlannerSplash extends StatelessWidget {
  const MedPlannerSplash({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
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

class FinanceShell extends ConsumerStatefulWidget {
  const FinanceShell({super.key});
  @override
  ConsumerState<FinanceShell> createState() => _FinanceShellState();
}

class _FinanceShellState extends ConsumerState<FinanceShell>
    with WidgetsBindingObserver {
  int selected = 2;
  bool _tourCheckStarted = false;
  static const titles = [
    'Planejamento',
    'Recebimentos',
    'Início',
    'Cartões',
    'Metas',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTour());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(autoSyncServiceProvider).synchronize());
    }
  }

  Future<void> _maybeShowTour() async {
    if (_tourCheckStarted) return;
    _tourCheckStarted = true;
    final controller = ref.read(financeProvider.notifier);
    final shouldShow = await controller.shouldShowTaxInvestmentTour();
    if (!mounted || !shouldShow) return;
    await _showTaxInvestmentTour(context);
    if (mounted) await controller.markTaxInvestmentTourSeen();
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
                    style: TextStyle(color: AppTheme.muted, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${step + 1} de ${pages.length}',
                    style: TextStyle(color: AppTheme.muted, fontSize: 12),
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
    ref.watch(financeProvider);
    ref.watch(supabaseAuthStateProvider);
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final fullName = user?.userMetadata?['full_name']?.toString().trim() ?? '';
    final firstName = fullName.isEmpty
        ? ''
        : fullName.split(RegExp(r'\s+')).first;
    final greetingName = firstName.isEmpty
        ? ''
        : '${firstName[0].toUpperCase()}${firstName.substring(1)}';
    final hour = DateTime.now().hour;
    final String greeting;
    if (hour >= 5 && hour < 12) {
      greeting = 'Bom dia';
    } else if (hour >= 12 && hour < 18) {
      greeting = 'Boa tarde';
    } else {
      greeting = 'Boa noite';
    }
    final String title;
    if (selected == 2) {
      title = greetingName.isEmpty ? '$greeting!' : '$greeting, $greetingName';
    } else {
      title = titles[selected];
    }
    final incomeVm = ref.read(incomeViewModelProvider);
    final planningVm = ref.read(planningViewModelProvider);
    final dashboardVm = ref.read(dashboardViewModelProvider);
    final cardsVm = ref.read(cardsViewModelProvider);
    final goalsVm = ref.read(goalsViewModelProvider);
    final settingsVm = ref.read(settingsViewModelProvider);
    final pages = [
      IncomePage(vm: incomeVm),
      PlanningPage(vm: planningVm),
      DashboardPage(vm: dashboardVm),
      CardsPage(vm: cardsVm),
      GoalsPage(vm: goalsVm),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Configurações e backup',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SettingsPage(vm: settingsVm)),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(child: pages[selected]),
      bottomNavigationBar: CircleNavBar(
        activeIndex: selected,
        onTap: (index) => setState(() => selected = index),
        activeIcons: [
          Icon(Icons.south_west, color: AppTheme.onLime),
          Icon(Icons.event_note, color: AppTheme.onLime),
          Icon(Icons.space_dashboard, color: AppTheme.onLime),
          Icon(Icons.credit_card, color: AppTheme.onLime),
          Icon(Icons.flag, color: AppTheme.onLime),
        ],
        inactiveIcons: [
          Icon(Icons.south_west, color: AppTheme.muted),
          Icon(Icons.event_note_outlined, color: AppTheme.muted),
          Icon(Icons.space_dashboard_outlined, color: AppTheme.muted),
          Icon(Icons.credit_card_outlined, color: AppTheme.muted),
          Icon(Icons.flag_outlined, color: AppTheme.muted),
        ],
        levels: const ['Entradas', 'Planejar', 'Início', 'Cartões', 'Metas'],
        activeLevelsStyle: TextStyle(
          color: AppTheme.valueGreen,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
        inactiveLevelsStyle: TextStyle(color: AppTheme.muted, fontSize: 10),
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
