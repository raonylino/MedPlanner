import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// SQLite keeps the app available offline; an authenticated user is synced to
/// the private Supabase JSON snapshot when the network is available.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final root = await getDatabasesPath();
    return openDatabase(
      p.join(root, 'controle_financeiro.db'),
      version: 9,
      onCreate: (db, _) async {
        await db.execute('''CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
        category TEXT NOT NULL, amount_cents INTEGER NOT NULL,
        month TEXT NOT NULL, paid INTEGER NOT NULL DEFAULT 0,
        due_date TEXT)''');
        await db.execute('''CREATE TABLE incomes (
        id INTEGER PRIMARY KEY AUTOINCREMENT, service TEXT NOT NULL,
        quantity REAL NOT NULL, unit_cents INTEGER NOT NULL, date TEXT NOT NULL,
        receive_month TEXT NOT NULL, tax_applies INTEGER NOT NULL DEFAULT 0,
        received INTEGER NOT NULL DEFAULT 0,
        investment_ids TEXT NOT NULL DEFAULT '*')''');
        await db.execute('''CREATE TABLE categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
          scope TEXT NOT NULL, UNIQUE(name, scope))''');
        await _seedCategories(db);
        await db.execute('''CREATE TABLE services (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE,
        unit_cents INTEGER NOT NULL)''');
        await db.execute(
          '''CREATE TABLE cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, limit_cents INTEGER NOT NULL)''',
        );
        await db.execute('''CREATE TABLE card_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT, card_id INTEGER NOT NULL,
        title TEXT NOT NULL, category TEXT NOT NULL, amount_cents INTEGER NOT NULL,
        installment_count INTEGER NOT NULL, installment_index INTEGER NOT NULL,
        month TEXT NOT NULL, recurring INTEGER NOT NULL DEFAULT 0,
        paid INTEGER NOT NULL DEFAULT 0, purchase_id TEXT,
        FOREIGN KEY(card_id) REFERENCES cards(id) ON DELETE CASCADE)''');
        await db.execute('''CREATE TABLE goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
        category TEXT NOT NULL, description TEXT NOT NULL DEFAULT '',
        unit_cents INTEGER NOT NULL, quantity INTEGER NOT NULL)''');
        await db.execute(
          'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await db.execute('''CREATE TABLE investments (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
        mode TEXT NOT NULL, value INTEGER NOT NULL)''');
        await _createSyncState(db);
        await _addSyncMetadata(db);
        await _installSyncTriggers(db);
        await db.insert('settings', {'key': 'tax_percent', 'value': '0'});
        await db.insert('investments', {
          'name': 'Reserva',
          'mode': 'percent',
          'value': 10,
        });
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''CREATE TABLE services (
          id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE,
          unit_cents INTEGER NOT NULL)''');
        }
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE incomes ADD COLUMN receive_month TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            "UPDATE incomes SET receive_month = substr(date, 1, 7) WHERE receive_month = ''",
          );
          await db.execute(
            'CREATE TABLE categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE)',
          );
          await _seedCategories(db);
          await db.execute(
            'INSERT OR IGNORE INTO categories(name) SELECT category FROM expenses WHERE category IS NOT NULL AND category <> ""',
          );
          await db.execute(
            'INSERT OR IGNORE INTO categories(name) SELECT category FROM card_expenses WHERE category IS NOT NULL AND category <> ""',
          );
          await db.execute(
            'INSERT OR IGNORE INTO categories(name) SELECT category FROM goals WHERE category IS NOT NULL AND category <> ""',
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE card_expenses ADD COLUMN paid INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE categories RENAME TO categories_old');
          await db.execute('''CREATE TABLE categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            scope TEXT NOT NULL,
            UNIQUE(name, scope))''');
          final oldCategories = await db.query('categories_old');
          for (final category in oldCategories) {
            final name = category['name']?.toString() ?? '';
            if (name.isEmpty) continue;
            for (final scope in ['planning', 'cards', 'goals']) {
              await db.insert('categories', {
                'name': name,
                'scope': scope,
              }, conflictAlgorithm: ConflictAlgorithm.ignore);
            }
          }
          await db.execute('DROP TABLE categories_old');
        }
        if (oldVersion < 6) {
          await db.execute(
            "ALTER TABLE incomes ADD COLUMN investment_ids TEXT NOT NULL DEFAULT '*'",
          );
        }
        if (oldVersion < 7) {
          await db.execute('ALTER TABLE expenses ADD COLUMN due_date TEXT');
          await db.execute(
            'ALTER TABLE card_expenses ADD COLUMN purchase_id TEXT',
          );
          await db.execute(
            "UPDATE card_expenses SET purchase_id = 'legacy-single-' || id",
          );
          await _groupLegacyPurchases(db);

          await db.execute('ALTER TABLE incomes RENAME TO incomes_old');
          await db.execute('''CREATE TABLE incomes (
            id INTEGER PRIMARY KEY AUTOINCREMENT, service TEXT NOT NULL,
            quantity REAL NOT NULL, unit_cents INTEGER NOT NULL, date TEXT NOT NULL,
            receive_month TEXT NOT NULL, tax_applies INTEGER NOT NULL DEFAULT 0,
            received INTEGER NOT NULL DEFAULT 0,
            investment_ids TEXT NOT NULL DEFAULT '*')''');
          await db.execute('''INSERT INTO incomes (
            id, service, quantity, unit_cents, date, receive_month,
            tax_applies, received, investment_ids)
            SELECT id, service, quantity, unit_cents, date, receive_month,
              tax_applies, received, investment_ids
            FROM incomes_old''');
          await db.execute('DROP TABLE incomes_old');
        }
        if (oldVersion < 8) {
          await _createSyncState(db);
        }
        if (oldVersion < 9) {
          await _createSyncState(db);
          await _addSyncMetadata(db);
          await _installSyncTriggers(db);
        }
      },
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _createSyncState(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS sync_state (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      user_id TEXT,
      last_synced_at TEXT,
      last_sync_at TEXT,
      baseline_json TEXT,
      pending INTEGER NOT NULL DEFAULT 1 CHECK (pending IN (0, 1)),
      syncing INTEGER NOT NULL DEFAULT 0 CHECK (syncing IN (0, 1)))''');
    final columns = await db.rawQuery('PRAGMA table_info(sync_state)');
    final existingColumns = columns.map((row) => row['name']).toSet();
    if (!existingColumns.contains('last_sync_at')) {
      await db.execute('ALTER TABLE sync_state ADD COLUMN last_sync_at TEXT');
    }
    if (!existingColumns.contains('syncing')) {
      await db.execute(
        'ALTER TABLE sync_state ADD COLUMN syncing INTEGER NOT NULL DEFAULT 0',
      );
    }
    await db.insert('sync_state', {
      'id': 1,
      'pending': 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _addSyncMetadata(DatabaseExecutor db) async {
    for (final table in _financeTables) {
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      final existingColumns = columns.map((row) => row['name']).toSet();
      if (!existingColumns.contains('updated_at')) {
        await db.execute(
          "ALTER TABLE $table ADD COLUMN updated_at TEXT NOT NULL DEFAULT ''",
        );
      }
      if (!existingColumns.contains('sync_id')) {
        await db.execute('ALTER TABLE $table ADD COLUMN sync_id TEXT');
      }
      if (!existingColumns.contains('is_synced')) {
        await db.execute(
          'ALTER TABLE $table ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (!existingColumns.contains('deleted_at')) {
        await db.execute('ALTER TABLE $table ADD COLUMN deleted_at TEXT');
      }
      await db.execute(
        "UPDATE $table SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE updated_at = ''",
      );
      final identityField = switch (table) {
        'settings' => 'key',
        'categories' => "name || '|' || scope",
        'services' => 'name',
        _ => 'id',
      };
      await db.execute(
        "UPDATE $table SET sync_id = 'legacy-$table-' || $identityField WHERE sync_id IS NULL OR sync_id = ''",
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS sync_${table}_sync_id_idx ON $table(sync_id)',
      );
      if (table == 'card_expenses') {
        if (!existingColumns.contains('card_sync_id')) {
          await db.execute(
            'ALTER TABLE card_expenses ADD COLUMN card_sync_id TEXT',
          );
        }
        await db.execute('''UPDATE card_expenses
          SET card_sync_id = (
            SELECT sync_id FROM cards WHERE cards.id = card_expenses.card_id
          )
          WHERE card_sync_id IS NULL OR length(card_sync_id) = 0''');
      }
    }
  }

  static const _financeTables = [
    'expenses',
    'incomes',
    'services',
    'categories',
    'cards',
    'card_expenses',
    'goals',
    'settings',
    'investments',
  ];

  Future<void> _installSyncTriggers(DatabaseExecutor db) async {
    for (final table in _financeTables) {
      final keyField = table == 'settings' ? 'key' : 'id';
      final cardSyncAssignment = table == 'card_expenses'
          ? ', card_sync_id = (SELECT sync_id FROM cards WHERE cards.id = NEW.card_id)'
          : '';
      await db.execute('DROP TRIGGER IF EXISTS sync_${table}_insert');
      await db.execute('DROP TRIGGER IF EXISTS sync_${table}_update');
      await db.execute('DROP TRIGGER IF EXISTS sync_${table}_delete');
      await db.execute('''CREATE TRIGGER sync_${table}_insert
        AFTER INSERT ON $table
        WHEN (SELECT syncing FROM sync_state WHERE id = 1) = 0
        BEGIN
          UPDATE $table
            SET sync_id = COALESCE(NULLIF(sync_id, ''), lower(hex(randomblob(16)))),
                updated_at = strftime('%Y-%m-%dT%H:%M:%fZ','now'),
                is_synced = 0$cardSyncAssignment
            WHERE $keyField = NEW.$keyField;
          UPDATE sync_state SET pending = 1 WHERE id = 1;
        END''');
      await db.execute('''CREATE TRIGGER sync_${table}_update
        AFTER UPDATE ON $table
        WHEN (SELECT syncing FROM sync_state WHERE id = 1) = 0
          AND NEW.updated_at = OLD.updated_at
          AND NEW.is_synced = OLD.is_synced
        BEGIN
          UPDATE $table
            SET sync_id = COALESCE(NULLIF(sync_id, ''), lower(hex(randomblob(16)))),
                updated_at = strftime('%Y-%m-%dT%H:%M:%fZ','now'),
                is_synced = 0$cardSyncAssignment
            WHERE $keyField = NEW.$keyField;
          UPDATE sync_state SET pending = 1 WHERE id = 1;
        END''');
    }
  }

  Future<Map<String, Object?>?> syncState() async {
    final rows = await (await database).query('sync_state', where: 'id = 1');
    return rows.isEmpty ? null : rows.single;
  }

  Future<void> saveSyncState({
    required String userId,
    required String baselineJson,
    required String syncedAt,
  }) async {
    await (await database).update('sync_state', {
      'user_id': userId,
      'baseline_json': baselineJson,
      'last_synced_at': syncedAt,
      'last_sync_at': syncedAt,
      'pending': 0,
    }, where: 'id = 1');
  }

  Future<Map<String, List<Map<String, Object?>>>> unsyncedRows() async {
    final db = await database;
    return {
      for (final table in _financeTables)
        table: await db.query(table, where: 'is_synced = 0'),
    };
  }

  Future<void> markSynced(Map<String, List<Map<String, Object?>>> rows) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final entry in rows.entries) {
        final keyField = entry.key == 'settings' ? 'key' : 'id';
        for (final row in entry.value) {
          final key = row[keyField];
          final updatedAt = row['updated_at'];
          if (key == null || updatedAt == null) continue;
          final current = await txn.query(
            entry.key,
            where: '$keyField = ? AND is_synced = 0',
            whereArgs: [key],
          );
          if (current.isEmpty ||
              _encodeRows(current, keyField) != _encodeRows([row], keyField)) {
            continue;
          }
          await txn.update(
            entry.key,
            {'is_synced': 1},
            where: '$keyField = ? AND updated_at = ? AND is_synced = 0',
            whereArgs: [key, updatedAt],
          );
        }
      }
    });
  }

  Future<void> markSyncPending() async =>
      (await database).update('sync_state', {'pending': 1}, where: 'id = 1');

  Future<void> _seedCategories(DatabaseExecutor db) async {
    for (final name in [
      'Vida',
      'Mensal',
      'Investimento',
      'Mercado',
      'Transporte',
      'Moradia',
      'Saúde',
      'Lazer',
      'Outros',
    ]) {
      for (final scope in ['planning', 'cards', 'goals']) {
        await db.insert('categories', {
          'name': name,
          'scope': scope,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  Future<void> _groupLegacyPurchases(DatabaseExecutor db) async {
    final expenses = await db.query(
      'card_expenses',
      where: "purchase_id LIKE 'legacy-single-%'",
      orderBy:
          'card_id, title, category, installment_count, recurring, month, installment_index, id',
    );
    final groups =
        <
          ({
            int cardId,
            String title,
            String category,
            int count,
            int recurring,
            String startMonth,
          }),
          List<Map<String, Object?>>
        >{};

    for (final expense in expenses) {
      final count = (expense['installment_count'] as num?)?.toInt() ?? 1;
      final recurring = (expense['recurring'] as num?)?.toInt() ?? 0;
      final index = (expense['installment_index'] as num?)?.toInt() ?? 1;
      final monthParts = expense['month']?.toString().split('-') ?? [];
      if (monthParts.length != 2 || (count < 2 && recurring == 0)) continue;
      final year = int.tryParse(monthParts[0]);
      final month = int.tryParse(monthParts[1]);
      if (year == null || month == null) continue;
      final start = recurring == 1
          ? DateTime(year, month, 1)
          : DateTime(year, month - index + 1, 1);
      final startMonth =
          '${start.year}-${start.month.toString().padLeft(2, '0')}';
      final key = (
        cardId: (expense['card_id'] as num?)?.toInt() ?? 0,
        title: expense['title']?.toString() ?? '',
        category: expense['category']?.toString() ?? '',
        count: count,
        recurring: recurring,
        startMonth: recurring == 1 ? 'recurring' : startMonth,
      );
      groups.putIfAbsent(key, () => []).add(expense);
    }

    for (final group in groups.entries) {
      final rows = group.value;
      final recurring = group.key.recurring == 1;
      final expectedCount = recurring ? 12 : group.key.count;
      if (rows.length != expectedCount) continue;
      final months = <String>{};
      final indices = <int>{};
      var complete = true;
      for (final row in rows) {
        final monthValue = row['month']?.toString() ?? '';
        final monthParts = monthValue.split('-');
        final year = monthParts.length == 2
            ? int.tryParse(monthParts[0])
            : null;
        final monthNumber = monthParts.length == 2
            ? int.tryParse(monthParts[1])
            : null;
        if (year == null || monthNumber == null) {
          complete = false;
          break;
        }
        months.add(monthValue);
        indices.add((row['installment_index'] as num?)?.toInt() ?? 1);
        final start = recurring
            ? DateTime(year, monthNumber, 1)
            : DateTime(
                year,
                monthNumber -
                    ((row['installment_index'] as num?)?.toInt() ?? 1) +
                    1,
                1,
              );
        final startMonth =
            '${start.year}-${start.month.toString().padLeft(2, '0')}';
        if (!recurring && startMonth != group.key.startMonth) {
          complete = false;
          break;
        }
      }
      if (!complete || months.length != expectedCount) continue;
      if (!recurring &&
          (indices.length != expectedCount ||
              !List.generate(
                expectedCount,
                (index) => index + 1,
              ).every(indices.contains))) {
        continue;
      }
      if (recurring && indices.length != 1) continue;
      if (recurring) {
        final sortedMonths = months.toList()..sort();
        final firstParts = sortedMonths.first.split('-');
        final firstYear = int.parse(firstParts[0]);
        final firstMonth = int.parse(firstParts[1]);
        final contiguous = List.generate(expectedCount, (index) {
          final month = DateTime(firstYear, firstMonth + index, 1);
          return '${month.year}-${month.month.toString().padLeft(2, '0')}';
        }).every(months.contains);
        if (!contiguous) continue;
      }

      final purchaseId = 'legacy-${rows.first['id']}';
      for (final row in rows) {
        await db.update(
          'card_expenses',
          {'purchase_id': purchaseId},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
  }

  Future<List<Map<String, Object?>>> rows(
    String table, {
    String? where,
    List<Object?>? args,
    String? orderBy,
  }) async => (await database).query(
    table,
    where: where == null
        ? 'deleted_at IS NULL'
        : '($where) AND deleted_at IS NULL',
    whereArgs: args,
    orderBy: orderBy,
  );
  Future<int> add(String table, Map<String, Object?> values) async =>
      (await database).insert(table, values);
  Future<int> update(String table, Map<String, Object?> values, int id) async =>
      (await database).update(table, values, where: 'id = ?', whereArgs: [id]);
  Future<void> saveService(String name, int unitCents) async {
    final db = await database;
    final updated = await db.update(
      'services',
      {'unit_cents': unitCents, 'deleted_at': null},
      where: 'name = ?',
      whereArgs: [name],
    );
    if (updated == 0) {
      await db.insert('services', {'name': name, 'unit_cents': unitCents});
    }
  }

  Future<int> remove(String table, int id) async {
    final db = await database;
    return db.transaction((txn) async {
      final deletedAt = DateTime.now().toUtc().toIso8601String();
      if (table == 'cards') {
        await txn.update(
          'card_expenses',
          {'deleted_at': deletedAt},
          where: 'card_id = ? AND deleted_at IS NULL',
          whereArgs: [id],
        );
      }
      return txn.update(
        table,
        {'deleted_at': deletedAt},
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [id],
      );
    });
  }

  Future<void> setting(String key, String value) async {
    final db = await database;
    final updated = await db.update(
      'settings',
      {'value': value, 'deleted_at': null},
      where: 'key = ?',
      whereArgs: [key],
    );
    if (updated == 0) {
      await db.insert('settings', {'key': key, 'value': value});
    }
  }

  Future<String> getSetting(String key, [String fallback = '0']) async {
    final result = await (await database).query(
      'settings',
      where: 'key = ? AND deleted_at IS NULL',
      whereArgs: [key],
    );
    return result.isEmpty ? fallback : result.first['value'] as String;
  }

  Future<Map<String, List<Map<String, Object?>>>> exportAll() async {
    final db = await database;
    final data = <String, List<Map<String, Object?>>>{};
    for (final table in [
      'expenses',
      'incomes',
      'services',
      'categories',
      'cards',
      'card_expenses',
      'goals',
      'settings',
      'investments',
    ]) {
      data[table] = await db.query(
        table,
        orderBy: table == 'settings' ? 'key' : 'id',
      );
    }
    return data;
  }

  Future<bool> restoreAll(
    Map<String, dynamic> data, {
    bool markSynced = false,
    Map<String, List<Map<String, Object?>>>? expectedLocal,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      if (expectedLocal != null) {
        for (final table in _financeTables) {
          final keyField = table == 'settings' ? 'key' : 'id';
          final current = await txn.query(table, orderBy: keyField);
          final expected =
              <Map<String, Object?>>[
                ...(expectedLocal[table] ?? const <Map<String, Object?>>[]),
              ]..sort(
                (a, b) => (a[keyField] ?? '').toString().compareTo(
                  (b[keyField] ?? '').toString(),
                ),
              );
          if (_encodeRows(current, keyField) !=
              _encodeRows(expected, keyField)) {
            return false;
          }
        }
      }
      await txn.update('sync_state', {'syncing': 1}, where: 'id = 1');
      const tables = [
        'card_expenses',
        'expenses',
        'incomes',
        'cards',
        'goals',
        'settings',
        'investments',
        'services',
        'categories',
      ];
      for (final table in tables) {
        await txn.delete(table);
      }
      final cardIdBySyncId = <String, int>{};
      final cardIdByOldId = <String, int>{};
      for (final table in [
        'expenses',
        'incomes',
        'services',
        'categories',
        'cards',
        'card_expenses',
        'goals',
        'settings',
        'investments',
      ]) {
        final items = (data[table] as List<dynamic>?) ?? [];
        for (final item in items) {
          final row = Map<String, Object?>.from(item as Map);
          if (table == 'incomes' && !row.containsKey('receive_month')) {
            row['receive_month'] = (row['date']?.toString() ?? '').substring(
              0,
              7,
            );
          }
          if (table == 'categories') row.putIfAbsent('scope', () => 'planning');
          if (table == 'card_expenses') row.putIfAbsent('paid', () => 0);
          if (table == 'card_expenses') {
            if (row['purchase_id'] == null) {
              row['purchase_id'] = 'legacy-single-${row['id'] ?? ''}';
            }
          }
          if (table == 'expenses') row.putIfAbsent('due_date', () => null);
          if (table == 'incomes') row.putIfAbsent('investment_ids', () => '*');
          final oldId = row['id'];
          final syncId = row['sync_id']?.toString();
          final identity = switch (table) {
            'settings' => row['key'],
            'categories' => '${row['name'] ?? ''}|${row['scope'] ?? ''}',
            'services' => row['name'],
            _ => oldId,
          };
          row['sync_id'] =
              syncId ??
              'legacy-$table-${identity ?? DateTime.now().microsecondsSinceEpoch}';
          if (table == 'card_expenses') {
            final cardSyncId = row['card_sync_id']?.toString();
            final remappedCardId =
                cardIdBySyncId[cardSyncId] ??
                cardIdByOldId[row['card_id']?.toString()];
            if (remappedCardId == null) {
              throw StateError(
                'Não foi possível associar uma parcela ao cartão durante a restauração.',
              );
            }
            row['card_id'] = remappedCardId;
            row['card_sync_id'] =
                cardSyncId ??
                cardIdBySyncId.entries
                    .where((entry) => entry.value == remappedCardId)
                    .map((entry) => entry.key)
                    .first;
          }
          row.putIfAbsent(
            'updated_at',
            () => DateTime.now().toUtc().toIso8601String(),
          );
          row['is_synced'] = markSynced
              ? 1
              : (row['is_synced'] == true ? 1 : row['is_synced'] ?? 0);
          row.putIfAbsent('deleted_at', () => null);
          if (table != 'settings') row.remove('id');
          final restoredId = await txn.insert(table, row);
          if (table == 'cards') {
            cardIdBySyncId[row['sync_id'].toString()] = restoredId;
            if (oldId != null) {
              cardIdByOldId.putIfAbsent(oldId.toString(), () => restoredId);
            }
          }
        }
      }
      await _groupLegacyPurchases(txn);
      final categoryCount =
          Sqflite.firstIntValue(
            await txn.rawQuery('SELECT COUNT(*) FROM categories'),
          ) ??
          0;
      if (categoryCount == 0) {
        await _seedCategories(txn);
      }
      await txn.update('sync_state', {'syncing': 0}, where: 'id = 1');
      return true;
    });
  }

  String _encodeRows(List<Map<String, Object?>> rows, String keyField) {
    final sortedRows =
        rows.map((row) {
          final keys = row.keys.toList()..sort();
          return {for (final key in keys) key: row[key]};
        }).toList()..sort(
          (a, b) => (a[keyField] ?? '').toString().compareTo(
            (b[keyField] ?? '').toString(),
          ),
        );
    return sortedRows.toString();
  }
}
