import 'dart:collection';

/// Immutable map-compatible base for rows used by the existing views.
abstract class FinanceRecord extends MapBase<String, Object?> {
  FinanceRecord(Map<String, Object?> data) : _data = Map.unmodifiable(data);

  final Map<String, Object?> _data;

  @override
  Iterable<String> get keys => _data.keys;
  @override
  Object? operator [](Object? key) => _data[key];
  @override
  void operator []=(String key, Object? value) =>
      throw UnsupportedError('Finance records are immutable');
  @override
  void clear() => throw UnsupportedError('Finance records are immutable');
  @override
  Object? remove(Object? key) =>
      throw UnsupportedError('Finance records are immutable');

  int intValue(String key) => (_data[key] as num?)?.toInt() ?? 0;
  double doubleValue(String key) => (_data[key] as num?)?.toDouble() ?? 0;
  String stringValue(String key) => _data[key]?.toString() ?? '';
}
