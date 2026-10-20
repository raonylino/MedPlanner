import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../notifications/expense_notification_service.dart';
import '../../features/finance_commands.dart';
import 'finance_controller.dart';
import '../models/finance_state.dart';

final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => AppDatabase.instance,
);
final expenseNotificationServiceProvider = Provider<ExpenseNotificationService>(
  (ref) => ExpenseNotificationService(),
);
final financeCommandsProvider = Provider<FinanceCommands>(
  (ref) => FinanceCommands(
    ref.watch(appDatabaseProvider),
    ref.watch(expenseNotificationServiceProvider),
  ),
);
final financeProvider = NotifierProvider<FinanceController, FinanceState>(
  FinanceController.new,
);
