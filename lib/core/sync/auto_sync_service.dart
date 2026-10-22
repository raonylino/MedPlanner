import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';

/// Keeps SQLite usable offline and syncs complete finance snapshots whenever
/// the authenticated user is online. The local copy is merged by record key.
class AutoSyncService {
  AutoSyncService(
    this._client,
    this._database, {
    this.onLocalDataChanged,
    Connectivity? connectivity,
  }) : _connectivity = connectivity ?? Connectivity();

  final SupabaseClient _client;
  final AppDatabase _database;
  final Future<void> Function()? onLocalDataChanged;
  final Connectivity _connectivity;
  bool _running = false;
  bool _runAgain = false;
  bool _runAgainForceRemoteCheck = false;
  String? _watchingUserId;
  RealtimeChannel? _channel;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  String? lastError;

  Future<void> watchCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      await stopWatching();
      return;
    }
    if (_watchingUserId == user.id) return;
    await stopWatching();
    _watchingUserId = user.id;
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        unawaited(synchronize());
      }
    });
    _channel = _client
        .channel('finance-backups-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'finance_backups',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (_) => unawaited(synchronize(forceRemoteCheck: true)),
        )
        .subscribe((status, _) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            unawaited(synchronize(forceRemoteCheck: true));
          }
        });
  }

  Future<void> stopWatching() async {
    final channel = _channel;
    _channel = null;
    _watchingUserId = null;
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    if (channel != null) await channel.unsubscribe();
  }

  Future<bool> synchronize({bool forceRemoteCheck = false}) async {
    if (_running) {
      _runAgain = true;
      _runAgainForceRemoteCheck = _runAgainForceRemoteCheck || forceRemoteCheck;
      return false;
    }
    final user = _client.auth.currentUser;
    if (user == null) return false;
    _running = true;
    lastError = null;
    try {
      final connectivity = await _connectivity.checkConnectivity();
      if (connectivity.every((result) => result == ConnectivityResult.none)) {
        lastError =
            'Sem conexão com a internet. Os dados continuam salvos neste aparelho.';
        return false;
      }
      final state = await _database.syncState();
      final previousUser = state?['user_id']?.toString();
      if (previousUser != null && previousUser != user.id) {
        lastError =
            'Este aparelho tem dados sincronizados em outra conta. Entre na conta original para continuar a sincronização.';
        return false;
      }
      final localData = await _database.exportAll();
      final local = _normalizeSnapshot(localData, markSynced: false);
      final baselineText = previousUser == user.id && state != null
          ? state['baseline_json']?.toString()
          : null;
      final lastSyncAt =
          state?['last_sync_at']?.toString() ??
          state?['last_synced_at']?.toString();
      final baseline = _normalizeSnapshot(
        _decodeSnapshot(baselineText),
        fallbackUpdatedAt: lastSyncAt,
      );
      final dirtyRows = await _database.unsyncedRows();
      final hasDirtyRows = dirtyRows.values.any((rows) => rows.isNotEmpty);
      final hasLocalChanges =
          hasDirtyRows ||
          baselineText == null ||
          !_sameSnapshot(local, baseline);
      final Map<String, dynamic>? remoteMetadata = await _client
          .from('finance_backups')
          .select('updated_at')
          .eq('user_id', user.id)
          .maybeSingle();
      final remoteUpdatedAt = remoteMetadata?['updated_at']?.toString();
      final remoteChanged =
          remoteMetadata == null ||
          lastSyncAt == null ||
          _isAfter(remoteUpdatedAt, lastSyncAt);
      if (!forceRemoteCheck && !hasLocalChanges && !remoteChanged) {
        return true;
      }

      Map<String, dynamic>? remote;
      String? syncedAt = remoteUpdatedAt;
      var remoteVersion = remoteUpdatedAt;
      var remoteExists = remoteMetadata != null;
      if (forceRemoteCheck || remoteChanged || baselineText == null) {
        final Map<String, dynamic>? row = await _client
            .from('finance_backups')
            .select('data, updated_at')
            .eq('user_id', user.id)
            .maybeSingle();
        if (row != null && row['data'] is! Map) {
          throw const FormatException(
            'O backup remoto tem um formato inválido e não será substituído.',
          );
        }
        remote = row == null
            ? null
            : _normalizeSnapshot(
                Map<String, dynamic>.from(row['data'] as Map),
                fallbackUpdatedAt: row['updated_at']?.toString(),
              );
        syncedAt = row?['updated_at']?.toString() ?? syncedAt;
        remoteVersion = syncedAt;
        remoteExists = row != null;
      } else {
        remote = baseline;
      }

      final mergeLocal =
          baselineText == null && remote != null && _isDefaultOnly(local)
          ? <String, dynamic>{}
          : local;
      final merged = _mergeSnapshots(
        baseline: baseline,
        local: mergeLocal,
        remote: remote,
      );
      final serverSnapshot = _markSnapshotSynced(merged);
      if (remote == null || !_sameSnapshot(serverSnapshot, remote)) {
        final updatedAt = DateTime.now().toUtc().toIso8601String();
        final payload = {
          'user_id': user.id,
          'data': serverSnapshot,
          'schema_version': 1,
          'updated_at': updatedAt,
        };
        final response = !remoteExists
            ? await _insertSnapshot(payload)
            : await _updateSnapshot(
                userId: user.id,
                expectedUpdatedAt: remoteVersion,
                data: serverSnapshot,
                updatedAt: updatedAt,
              );
        if (response == null) {
          lastError =
              'A nuvem mudou durante a sincronização. Os dados serão reconciliados novamente.';
          _runAgain = true;
          return false;
        }
        syncedAt = response['updated_at']?.toString() ?? syncedAt;
      }
      if (!_sameSnapshot(_normalizeSnapshot(local), serverSnapshot)) {
        final applied = await _database.restoreAll(
          serverSnapshot,
          markSynced: true,
          expectedLocal: localData,
        );
        if (!applied) {
          lastError =
              'Uma alteração local ocorreu durante a sincronização. Ela será enviada novamente.';
          _runAgain = true;
          return false;
        }
        await onLocalDataChanged?.call();
      } else {
        await _database.markSynced(dirtyRows);
      }
      await _database.saveSyncState(
        userId: user.id,
        baselineJson: jsonEncode(_canonicalize(serverSnapshot)),
        syncedAt: syncedAt ?? DateTime.now().toUtc().toIso8601String(),
      );
      if (!_sameSnapshot(
        serverSnapshot,
        _normalizeSnapshot(await _database.exportAll()),
      )) {
        await _database.markSyncPending();
        _runAgain = true;
      }
      return true;
    } catch (error) {
      lastError =
          'Não foi possível sincronizar agora. Seus dados continuam salvos neste aparelho. ($error)';
      return false;
    } finally {
      _running = false;
      if (_runAgain) {
        final forceRemoteCheck = _runAgainForceRemoteCheck;
        _runAgain = false;
        _runAgainForceRemoteCheck = false;
        unawaited(
          Future<void>.delayed(Duration.zero).then((_) async {
            await synchronize(forceRemoteCheck: forceRemoteCheck);
          }),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _insertSnapshot(
    Map<String, Object?> payload,
  ) async {
    try {
      return await _client
          .from('finance_backups')
          .insert(payload)
          .select('updated_at')
          .single();
    } on PostgrestException catch (error) {
      if (error.code == '23505') return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _updateSnapshot({
    required String userId,
    required String? expectedUpdatedAt,
    required Map<String, dynamic> data,
    required String updatedAt,
  }) async {
    if (expectedUpdatedAt == null) {
      throw StateError('O backup remoto não possui versão para comparação.');
    }
    return _client
        .from('finance_backups')
        .update({'data': data, 'schema_version': 1, 'updated_at': updatedAt})
        .eq('user_id', userId)
        .eq('updated_at', expectedUpdatedAt)
        .select('updated_at')
        .maybeSingle();
  }

  Map<String, dynamic> _decodeSnapshot(String? encoded) {
    if (encoded == null || encoded.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      throw const FormatException(
        'O estado local de sincronização é inválido.',
      );
    }
    return Map<String, dynamic>.from(decoded);
  }

  Map<String, dynamic> _normalizeSnapshot(
    Map<String, dynamic> snapshot, {
    String? fallbackUpdatedAt,
    bool markSynced = true,
  }) {
    final fallback =
        fallbackUpdatedAt ?? DateTime.now().toUtc().toIso8601String();
    final normalized = {
      for (final entry in snapshot.entries)
        entry.key: _normalizeRows(
          entry.key,
          entry.value,
          fallbackUpdatedAt: fallback,
          markSynced: markSynced,
        ),
    };
    final cardIdsByLegacyId = {
      for (final card in _rows(normalized['cards']))
        card['id']?.toString(): card['sync_id']?.toString(),
    };
    for (final expense in _rows(normalized['card_expenses'])) {
      expense.putIfAbsent(
        'card_sync_id',
        () => cardIdsByLegacyId[expense['card_id']?.toString()],
      );
    }
    return normalized;
  }

  List<Map<String, dynamic>> _normalizeRows(
    String table,
    Object? value, {
    required String fallbackUpdatedAt,
    required bool markSynced,
  }) {
    if (value is! List) {
      throw FormatException('A tabela $table tem um formato inválido.');
    }
    final rows = <Map<String, dynamic>>[];
    for (final row in value) {
      if (row is! Map) {
        throw FormatException('Há um registro inválido na tabela $table.');
      }
      final normalized = Map<String, dynamic>.from(row);
      normalized.putIfAbsent('updated_at', () => fallbackUpdatedAt);
      final identity = switch (table) {
        'settings' => normalized['key'],
        'categories' =>
          '${normalized['name'] ?? ''}|${normalized['scope'] ?? ''}',
        'services' => normalized['name'],
        _ => normalized['id'],
      };
      normalized.putIfAbsent(
        'sync_id',
        () => 'legacy-$table-${identity ?? rows.length}',
      );
      if (markSynced) normalized['is_synced'] = 1;
      normalized.putIfAbsent('is_synced', () => 0);
      normalized.putIfAbsent('deleted_at', () => null);
      rows.add(normalized);
    }
    rows.sort(
      (a, b) => _normalizedRecordKey(
        table,
        a,
      ).compareTo(_normalizedRecordKey(table, b)),
    );
    return rows;
  }

  String _normalizedRecordKey(String table, Map<String, dynamic> row) {
    if (table == 'settings') return row['key']?.toString() ?? '';
    if (table == 'categories') {
      return '${row['name'] ?? ''}|${row['scope'] ?? ''}';
    }
    if (table == 'services') return row['name']?.toString() ?? '';
    return row['id']?.toString() ?? '';
  }

  Map<String, dynamic> _markSnapshotSynced(Map<String, dynamic> snapshot) => {
    for (final entry in snapshot.entries)
      entry.key: entry.value is List
          ? (entry.value as List).map((row) {
              if (row is! Map) return row;
              return {...Map<String, dynamic>.from(row), 'is_synced': 1};
            }).toList()
          : entry.value,
  };

  bool _isAfter(String? value, String previous) {
    final current = DateTime.tryParse(value ?? '');
    final last = DateTime.tryParse(previous);
    return current != null && last != null && current.isAfter(last);
  }

  bool _isDefaultOnly(Map<String, dynamic> snapshot) {
    for (final table in [
      'expenses',
      'incomes',
      'services',
      'cards',
      'card_expenses',
      'goals',
    ]) {
      if (_rows(snapshot[table]).isNotEmpty) return false;
    }
    final settings = _rows(snapshot['settings']);
    if (settings.any(
      (row) =>
          row['key'] != 'tax_percent' ||
          row['value'] != '0' ||
          row['deleted_at'] != null,
    )) {
      return false;
    }
    final investments = _rows(snapshot['investments']);
    if (investments.any(
      (row) =>
          row['name'] != 'Reserva' ||
          row['mode'] != 'percent' ||
          row['value'] != 10 ||
          row['deleted_at'] != null,
    )) {
      return false;
    }
    const defaults = {
      'Vida',
      'Mensal',
      'Investimento',
      'Mercado',
      'Transporte',
      'Moradia',
      'Saúde',
      'Lazer',
      'Outros',
    };
    return _rows(snapshot['categories']).every(
      (row) =>
          defaults.contains(row['name']) &&
          const {'planning', 'cards', 'goals'}.contains(row['scope']) &&
          row['deleted_at'] == null,
    );
  }

  Map<String, dynamic> _mergeSnapshots({
    required Map<String, dynamic> baseline,
    required Map<String, dynamic> local,
    required Map<String, dynamic>? remote,
  }) {
    final cloud = remote ?? <String, dynamic>{};
    final result = <String, dynamic>{};
    const recordKeys = <String, String>{
      'settings': 'key',
      'categories': 'name_scope',
      'services': 'name',
    };
    final knownTables = {...baseline.keys, ...local.keys, ...cloud.keys};
    for (final table in knownTables) {
      final baseRows = _rows(baseline[table]);
      final localRows = _rows(local[table]);
      final remoteRows = _rows(cloud[table]);
      if (baseRows.isEmpty && localRows.isEmpty && remoteRows.isEmpty) {
        result[table] = local[table] ?? cloud[table] ?? baseline[table] ?? [];
        continue;
      }
      final keyField = recordKeys[table] ?? 'sync_id';
      final baseByKey = _indexRows(table, keyField, baseRows);
      final localByKey = _indexRows(table, keyField, localRows);
      final remoteByKey = _indexRows(table, keyField, remoteRows);
      final keys = <String>{
        ...baseByKey.keys,
        ...localByKey.keys,
        ...remoteByKey.keys,
      };
      final mergedRows = <Map<String, dynamic>>[];
      for (final key in keys) {
        final base = baseByKey[key];
        final localRecord = localByKey[key];
        final remoteRecord = remoteByKey[key];
        final localChanged = !_sameRecord(localRecord, base);
        final remoteChanged = !_sameRecord(remoteRecord, base);
        final selected = localChanged
            ? localRecord
            : remoteChanged
            ? remoteRecord
            : (localRecord ?? remoteRecord ?? base);
        if (selected != null) mergedRows.add(selected);
      }
      mergedRows.sort(
        (a, b) => _recordKey(
          table,
          keyField,
          a,
        ).compareTo(_recordKey(table, keyField, b)),
      );
      result[table] = mergedRows;
    }
    return result;
  }

  List<Map<String, dynamic>> _rows(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Map<String, Map<String, dynamic>> _indexRows(
    String table,
    String keyField,
    List<Map<String, dynamic>> rows,
  ) => {for (final row in rows) _recordKey(table, keyField, row): row};

  String _recordKey(String table, String keyField, Map<String, dynamic> row) {
    final value = keyField == 'name_scope'
        ? '${row['name'] ?? ''}|${row['scope'] ?? ''}'
        : row[keyField];
    return value?.toString() ?? jsonEncode(_canonicalize(row));
  }

  bool _sameRecord(Object? a, Object? b) =>
      jsonEncode(_canonicalize(a)) == jsonEncode(_canonicalize(b));

  bool _sameSnapshot(Map<String, dynamic> a, Map<String, dynamic> b) =>
      jsonEncode(_canonicalize(a)) == jsonEncode(_canonicalize(b));

  Object? _canonicalize(Object? value) {
    if (value is Map) {
      final sortedKeys =
          value.keys
              .map((key) => key.toString())
              .where((key) => key != 'id' && key != 'card_id')
              .toList()
            ..sort();
      return {for (final key in sortedKeys) key: _canonicalize(value[key])};
    }
    if (value is List) return value.map(_canonicalize).toList();
    return value;
  }
}
