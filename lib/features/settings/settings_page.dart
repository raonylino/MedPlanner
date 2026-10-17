import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/ui.dart';
import '../finance_view_model.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.vm, super.key});
  final FinanceViewModel vm;

  Future<void> _tax(BuildContext context) async {
    final data = await showDataForm(context, 'Imposto estimado', [
      (
        key: 'percent',
        label: 'Alíquota estimada em %',
        initial: '${vm.taxPercent}',
        keyboard: const TextInputType.numberWithOptions(decimal: true),
      ),
    ]);
    final value = double.tryParse(
      (data?['percent'] ?? '').replaceAll(',', '.'),
    );
    if (value != null && value >= 0 && value <= 100) {
      await vm.saveTax(value);
    } else if (data != null && context.mounted) {
      _notice(context, 'Informe um percentual entre 0 e 100.');
    }
  }

  Future<void> _investment(BuildContext context) async {
    final data = await showSmartForm(context, 'Nova regra de investimento', [
      const SmartFieldSpec(key: 'name', label: 'Nome (ex.: Reserva, Viagem)'),
      SmartFieldSpec(
        key: 'mode',
        label: 'Tipo de regra',
        initial: 'percent',
        kind: SmartFieldKind.dropdown,
        options: [
          (value: 'percent', label: 'Porcentagem'),
          (value: 'fixed', label: 'Valor fixo'),
        ],
      ),
      const SmartFieldSpec(
        key: 'value',
        label: 'Valor da regra',
        keyboard: TextInputType.number,
      ),
    ]);
    final name = data?['name']?.toString().trim() ?? '';
    if (data == null || name.isEmpty) return;
    final mode = data['mode'] == 'fixed' ? 'fixed' : 'percent';
    final value = mode == 'fixed'
        ? centsFrom(data['value']?.toString() ?? '')
        : (int.tryParse(data['value']?.toString() ?? '') ?? 0);
    final percentTotal =
        vm.investments
            .where((i) => i['mode'] == 'percent')
            .fold(0, (a, i) => a + FinanceViewModel.integer(i['value'])) +
        (mode == 'percent' ? value : 0);
    if (value <= 0 || percentTotal > 100) {
      if (context.mounted) {
        _notice(
          context,
          'Valor inválido. A soma dos investimentos percentuais não pode passar de 100%.',
        );
      }
      return;
    }
    await vm.addInvestment(name, mode, value);
  }

  static void _notice(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<File> _writeFile(String name, List<int> bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _shareFile(BuildContext context, File file) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Arquivo exportado do Meu Financeiro',
      ),
    );
  }

  Future<void> _backup(BuildContext context) async {
    final data = await AppDatabase.instance.exportAll();
    final file = await _writeFile(
      'backup_financeiro_${DateTime.now().millisecondsSinceEpoch}.json',
      utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
    );
    if (context.mounted) await _shareFile(context, file);
  }

  Future<void> _restore(BuildContext context) async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null) return;
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(ctx).width * 0.01,
        ),
        constraints: BoxConstraints(
          minWidth: MediaQuery.sizeOf(ctx).width * 0.98,
          maxWidth: MediaQuery.sizeOf(ctx).width * 0.98,
        ),
        backgroundColor: AppTheme.surface,
        title: const Text('Substituir os dados atuais?'),
        actionsAlignment: MainAxisAlignment.start,
        content: const Text(
          'O conteúdo do backup vai substituir todos os dados que estão neste aparelho.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final bytes = await File(result.path!).readAsBytes();
      final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      await AppDatabase.instance.restoreAll(decoded);
      await vm.load();
      if (context.mounted) _notice(context, 'Backup restaurado.');
    } catch (_) {
      if (context.mounted) {
        _notice(
          context,
          'Não foi possível restaurar. Escolha um backup JSON válido.',
        );
      }
    }
  }

  Future<void> _xlsx(BuildContext context) async {
    final data = await AppDatabase.instance.exportAll();
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    for (final entry in data.entries) {
      final sheet = excel[entry.key];
      final columns = entry.value.isEmpty
          ? <String>[]
          : entry.value.first.keys.toList();
      if (columns.isEmpty) {
        sheet.appendRow([TextCellValue('Sem dados')]);
        continue;
      }
      sheet.appendRow(columns.map((c) => TextCellValue(c)).toList());
      for (final row in entry.value) {
        sheet.appendRow(
          columns.map((c) => TextCellValue('${row[c] ?? ''}')).toList(),
        );
      }
    }
    final bytes = excel.save();
    if (bytes == null) {
      if (context.mounted) {
        _notice(context, 'Não foi possível gerar a planilha.');
      }
      return;
    }
    final file = await _writeFile(
      'controle_financeiro_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      bytes,
    );
    if (context.mounted) await _shareFile(context, file);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: vm,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Cálculos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.percent, color: AppTheme.lime),
              title: const Text('Imposto estimado'),
              subtitle: Text(
                'Usado somente em recebimentos marcados • ${vm.taxPercent}%',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _tax(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.savings_outlined, color: AppTheme.lime),
              title: const Text('Regras de investimento'),
              subtitle: const Text(
                'Percentual calculado sobre o recebimento após imposto',
              ),
              trailing: const Icon(Icons.add),
              onTap: () => _investment(context),
            ),
          ),
          ...vm.investments.map(
            (i) => Card(
              child: ListTile(
                title: Text(FinanceViewModel.string(i['name'])),
                subtitle: Text(
                  i['mode'] == 'percent'
                      ? '${i['value']}% do líquido'
                      : 'Valor fixo • ${money(FinanceViewModel.integer(i['value']))}',
                ),
                trailing: IconButton(
                  onPressed: () =>
                      vm.deleteInvestment(FinanceViewModel.integer(i['id'])),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Backup e exportação',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.file_download_outlined,
                color: AppTheme.lime,
              ),
              title: const Text('Exportar planilha Excel'),
              subtitle: const Text('Gera .xlsx com os dados do aplicativo'),
              onTap: () => _xlsx(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.backup_outlined, color: AppTheme.lime),
              title: const Text('Criar backup dos dados'),
              subtitle: const Text(
                'Gera arquivo JSON para guardar ou compartilhar',
              ),
              onTap: () => _backup(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.settings_backup_restore,
                color: AppTheme.lime,
              ),
              title: const Text('Restaurar backup JSON'),
              subtitle: const Text(
                'Substitui os dados locais pelo arquivo escolhido',
              ),
              onTap: () => _restore(context),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Os dados ficam neste aparelho. Guarde uma cópia do backup em local seguro; a restauração substitui os dados atuais.',
            style: TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
