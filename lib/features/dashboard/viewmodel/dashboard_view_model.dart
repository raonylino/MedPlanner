export '../../../core/providers/finance_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/finance_controller.dart';

/// Viewmodel entry point for the dashboard feature. Shared persistence and refresh
/// coordination remain in FinanceController; the feature UI depends on this
/// scoped provider so its state management can evolve independently.
final dashboardViewModelProvider = Provider<FinanceController>(
  (ref) => ref.watch(financeProvider.notifier),
);
