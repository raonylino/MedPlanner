abstract final class FinanceValues {
  static String monthFromDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';
  static int integer(Object? value) => (value as num?)?.toInt() ?? 0;
  static double decimal(Object? value) => (value as num?)?.toDouble() ?? 0;
  static String string(Object? value) => value?.toString() ?? '';
}
