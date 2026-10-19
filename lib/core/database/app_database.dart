import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// SQLite is the single source of truth. No network client is used by the app.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final root = await getDatabasesPath();
    return openDatabase(
      p.join(root, 'controle_financeiro.db'),
      version: 7,
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
      },
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

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
    where: where,
    whereArgs: args,
    orderBy: orderBy,
  );
  Future<int> add(String table, Map<String, Object?> values) async =>
      (await database).insert(table, values);
  Future<int> update(String table, Map<String, Object?> values, int id) async =>
      (await database).update(table, values, where: 'id = ?', whereArgs: [id]);
  Future<int> remove(String table, int id) async =>
      (await database).delete(table, where: 'id = ?', whereArgs: [id]);
  Future<void> setting(String key, String value) async =>
      (await database).insert('settings', {
        'key': key,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
  Future<String> getSetting(String key, [String fallback = '0']) async {
    final result = await (await database).query(
      'settings',
      where: 'key = ?',
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
      data[table] = await db.query(table);
    }
    return data;
  }

  Future<void> restoreAll(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
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
          if (table == 'card_expenses') row.putIfAbsent('paid', () => 0);
          if (table == 'card_expenses') {
            if (row['purchase_id'] == null) {
              row['purchase_id'] = 'legacy-single-${row['id'] ?? ''}';
            }
          }
          if (table == 'expenses') row.putIfAbsent('due_date', () => null);
          if (table == 'categories') row.putIfAbsent('scope', () => 'planning');
          if (table == 'incomes') row.putIfAbsent('investment_ids', () => '*');
          await txn.insert(table, row);
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
    });
  }
}
