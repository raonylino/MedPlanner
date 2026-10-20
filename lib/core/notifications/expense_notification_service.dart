import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class ExpenseNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool? _permissionGranted;

  Future<void> _initialize() async {
    if (_initialized) return;
    timezone_data.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      final identifier = switch (localTimezone.identifier) {
        'GMT' || 'UTC' || 'Etc/UTC' => 'Etc/UTC',
        final value => value,
      };
      timezone.setLocalLocation(timezone.getLocation(identifier));
    } on timezone.LocationNotFoundException {
      // Some Android devices report aliases such as GMT that are absent from
      // the bundled IANA database. Keep timezone's initialized UTC fallback.
      timezone.setLocalLocation(timezone.getLocation('Etc/UTC'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  Future<bool> syncExpense(Map<String, Object?> expense) async {
    await _initialize();
    final id = (expense['id'] as num).toInt();
    await cancelExpense(id);
    final dueDate = DateTime.tryParse(expense['due_date']?.toString() ?? '');
    if (dueDate == null || (expense['paid'] as num?)?.toInt() == 1) {
      return true;
    }
    if (!await _hasNotificationPermission()) return false;

    await _schedule(
      _notificationId(id, 0),
      expense,
      DateTime(dueDate.year, dueDate.month, dueDate.day - 1, 9),
      'vence amanhã',
    );
    await _schedule(
      _notificationId(id, 1),
      expense,
      DateTime(dueDate.year, dueDate.month, dueDate.day, 9),
      'vence hoje',
    );
    return true;
  }

  Future<void> cancelExpense(int expenseId) async {
    await _initialize();
    await _plugin.cancel(id: _notificationId(expenseId, 0));
    await _plugin.cancel(id: _notificationId(expenseId, 1));
  }

  Future<bool> replaceAllExpenseReminders(
    List<Map<String, Object?>> expenses,
  ) async {
    await _initialize();
    await _plugin.cancelAll();
    var remindersEnabled = true;
    for (final expense in expenses) {
      final dueDate = expense['due_date']?.toString() ?? '';
      if (dueDate.isEmpty || (expense['paid'] as num?)?.toInt() == 1) {
        continue;
      }
      remindersEnabled = await syncExpense(expense) && remindersEnabled;
    }
    return remindersEnabled;
  }

  Future<bool> _hasNotificationPermission() async {
    if (_permissionGranted != null) return _permissionGranted!;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      _permissionGranted =
          await android.requestNotificationsPermission() ?? false;
      return _permissionGranted!;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      _permissionGranted =
          await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
      return _permissionGranted!;
    }

    _permissionGranted = false;
    return false;
  }

  Future<void> _schedule(
    int notificationId,
    Map<String, Object?> expense,
    DateTime date,
    String dueLabel,
  ) async {
    final now = DateTime.now();
    if (!date.isAfter(now)) {
      final isToday =
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
      if (!isToday || dueLabel != 'vence hoje') return;
      date = now.add(const Duration(minutes: 1));
    }
    final scheduledDate = timezone.TZDateTime.from(date, timezone.local);
    final title = expense['title']?.toString() ?? 'Despesa';
    final amountCents = (expense['amount_cents'] as num?)?.toInt() ?? 0;
    final amount =
        'R\$ ${(amountCents / 100).toStringAsFixed(2).replaceAll('.', ',')}';

    await _plugin.zonedSchedule(
      id: notificationId,
      title: '$title $dueLabel',
      body: 'Valor: $amount',
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'expense_due_dates',
          'Vencimentos de despesas',
          channelDescription: 'Avisos de despesas planejadas não pagas',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'expense:${expense['id']}',
    );
  }

  int _notificationId(int expenseId, int reminder) => expenseId * 2 + reminder;
}
