import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/app_database.dart';
import '../notifications/expense_notification_service.dart';
import '../../features/finance_commands.dart';
import '../../features/settings/viewmodel/cloud_backup_view_model.dart';
import '../sync/auto_sync_service.dart';
import '../../features/auth/viewmodel/auth_view_model.dart';
import 'finance_controller.dart';
import '../models/finance_state.dart';

final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => AppDatabase.instance,
);
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
final supabaseAuthStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseClientProvider).auth.onAuthStateChange,
);
final cloudBackupViewModelProvider = Provider<CloudBackupViewModel>(
  (ref) => CloudBackupViewModel(ref.watch(supabaseClientProvider)),
);
final autoSyncServiceProvider = Provider<AutoSyncService>(
  (ref) {
    final service = AutoSyncService(
      ref.watch(supabaseClientProvider),
      ref.watch(appDatabaseProvider),
      onLocalDataChanged: () async {
        final finance = ref.read(financeProvider.notifier);
        await finance.load(showLoading: false);
        await finance.refreshExpenseNotifications();
      },
    );
    ref.onDispose(() => unawaited(service.stopWatching()));
    return service;
  },
);
final authViewModelProvider = Provider<AuthViewModel>(
  (ref) => AuthViewModel(ref.watch(supabaseClientProvider)),
);
final expenseNotificationServiceProvider = Provider<ExpenseNotificationService>(
  (ref) => ExpenseNotificationService(),
);
final financeCommandsProvider = Provider<FinanceCommands>(
  (ref) => FinanceCommands(
    ref.watch(appDatabaseProvider),
    ref.watch(expenseNotificationServiceProvider),
    afterLocalWrite: () async {
      await ref.read(autoSyncServiceProvider).synchronize();
    },
  ),
);
final financeProvider = NotifierProvider<FinanceController, FinanceState>(
  FinanceController.new,
);
