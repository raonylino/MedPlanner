import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

String money(int cents) =>
    'R\$ ${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')}';

class PageHeading extends StatelessWidget {
  const PageHeading(this.title, {this.subtitle, super.key});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: const TextStyle(color: AppTheme.muted)),
        ],
      ],
    ),
  );
}

class AmountCard extends StatelessWidget {
  const AmountCard({
    required this.label,
    required this.value,
    this.highlight = false,
    super.key,
  });
  final String label, value;
  final bool highlight;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: highlight ? AppTheme.lime : AppTheme.surface,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: highlight ? AppTheme.bg : AppTheme.muted,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            color: highlight ? AppTheme.bg : AppTheme.text,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class RecordTile extends StatelessWidget {
  const RecordTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
    this.onEdit,
    this.onDelete,
    super.key,
  });
  final String title, subtitle, trailing;
  final VoidCallback? onTap, onEdit, onDelete;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.muted)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            trailing,
            style: const TextStyle(
              color: AppTheme.lime,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (onEdit != null && onDelete != null)
            PopupMenuButton<String>(
              tooltip: 'Ações',
              onSelected: (action) {
                if (action == 'edit') onEdit!();
                if (action == 'delete') onDelete!();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'delete', child: Text('Apagar')),
              ],
            )
          else if (onEdit != null)
            IconButton(
              tooltip: 'Editar',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, color: AppTheme.muted),
            )
          else if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: AppTheme.muted),
            ),
        ],
      ),
    ),
  );
}

typedef FieldSpec = ({
  String key,
  String label,
  String initial,
  TextInputType keyboard,
});

enum SmartFieldKind { text, dropdown, multiSelect, toggle, date, optionalDate }

typedef SelectOption = ({String value, String label});

class SmartFieldSpec {
  const SmartFieldSpec({
    required this.key,
    required this.label,
    this.initial = '',
    this.keyboard = TextInputType.text,
    this.kind = SmartFieldKind.text,
    this.options = const [],
    this.firstDate,
    this.lastDate,
    this.onCreateOption,
    this.onDeleteOption,
  });
  final String key;
  final String label;
  final String initial;
  final TextInputType keyboard;
  final SmartFieldKind kind;
  final List<SelectOption> options;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final Future<String?> Function(BuildContext context)? onCreateOption;
  final Future<bool> Function(BuildContext context, String value)?
  onDeleteOption;
}

const _createOptionValue = '__create_category__';
const _emptyOptionValue = '__empty_category__';

Future<bool> confirmDeleteRecord(
  BuildContext context, {
  required String title,
  required String message,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(dialogContext).width * 0.01,
        ),
        constraints: BoxConstraints(
          minWidth: MediaQuery.sizeOf(dialogContext).width * 0.98,
          maxWidth: MediaQuery.sizeOf(dialogContext).width * 0.98,
        ),
        backgroundColor: AppTheme.surface,
        title: Text(title),
        content: Text(message),
        actionsAlignment: MainAxisAlignment.start,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    ) ??
    false;

Future<String?> createCategoryOption(
  BuildContext context,
  Future<void> Function(String name) save,
) async {
  final result = await showDataForm(context, 'Criar categoria', [
    (
      key: 'name',
      label: 'Nome da categoria',
      initial: '',
      keyboard: TextInputType.text,
    ),
  ]);
  final name = result?['name']?.trim() ?? '';
  if (name.isEmpty) return null;
  await save(name);
  return name;
}

Future<bool> deleteCategoryOption(
  BuildContext context,
  String name,
  List<Map<String, Object?>> categories,
  Future<void> Function(int id) delete,
) async {
  final matches = categories.where((category) => category['name'] == name);
  if (matches.isEmpty) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(dialogContext).width * 0.01,
      ),
      constraints: BoxConstraints(
        minWidth: MediaQuery.sizeOf(dialogContext).width * 0.98,
        maxWidth: MediaQuery.sizeOf(dialogContext).width * 0.98,
      ),
      backgroundColor: AppTheme.surface,
      title: const Text('Apagar categoria?'),
      actionsAlignment: MainAxisAlignment.start,
      content: Text(
        '“$name” será removida das opções. Os lançamentos já cadastrados serão mantidos.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Apagar'),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  final id = (matches.first['id'] as num?)?.toInt();
  if (id == null) return false;
  await delete(id);
  return true;
}

const _monthNames = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

List<SelectOption> monthOptions({int monthsBack = 12, int monthsForward = 60}) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month - monthsBack, 1);
  final count = monthsBack + monthsForward + 1;
  return List.generate(count, (i) {
    final date = DateTime(start.year, start.month + i, 1);
    final value = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    return (
      value: value,
      label: '${_monthNames[date.month - 1]} de ${date.year}',
    );
  });
}

String monthLabel(String value) {
  final parts = value.split('-');
  if (parts.length != 2) return value;
  final month = int.tryParse(parts[1]);
  if (month == null || month < 1 || month > 12) return value;
  return '${_monthNames[month - 1]} de ${parts[0]}';
}

class MonthCarousel extends StatefulWidget {
  const MonthCarousel({
    required this.selectedMonth,
    required this.onChanged,
    required this.label,
    super.key,
  });
  final String selectedMonth;
  final ValueChanged<String> onChanged;
  final String label;

  @override
  State<MonthCarousel> createState() => _MonthCarouselState();
}

class _MonthCarouselState extends State<MonthCarousel> {
  static const _itemExtent = 112.0;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerSelected());
  }

  @override
  void didUpdateWidget(covariant MonthCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMonth != widget.selectedMonth) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerSelected());
    }
  }

  void _centerSelected() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      5 * _itemExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _value(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  Future<void> _showAllMonths(BuildContext context) async {
    final selected =
        DateTime.tryParse('${widget.selectedMonth}-01') ?? DateTime.now();
    final now = DateTime.now();
    final start = DateTime(now.year - 10, 1, 1);
    final end = DateTime(now.year + 10, 12, 1);
    final count = (end.year - start.year) * 12 + end.month - start.month + 1;
    final months = List.generate(
      count,
      (i) => DateTime(start.year, start.month + i, 1),
    );
    if (!months.any((date) => _value(date) == widget.selectedMonth)) {
      months.add(DateTime(selected.year, selected.month, 1));
    }
    months.sort((a, b) => b.compareTo(a));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.98,
      ),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Todos os meses',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: months.length,
                  itemBuilder: (context, index) {
                    final date = months[index];
                    final value = _value(date);
                    return ListTile(
                      title: Text(monthLabel(value)),
                      trailing: value == widget.selectedMonth
                          ? const Icon(Icons.check, color: AppTheme.lime)
                          : null,
                      onTap: () {
                        widget.onChanged(value);
                        Navigator.pop(sheetContext);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected =
        DateTime.tryParse('${widget.selectedMonth}-01') ?? DateTime.now();
    final months = List.generate(
      11,
      (i) => DateTime(selected.year, selected.month + i - 5, 1),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(color: AppTheme.muted),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showAllMonths(context),
                icon: const Icon(Icons.calendar_month, size: 16),
                label: const Text('Todos os meses'),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            height: 42,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: months.length,
              itemExtent: _itemExtent,
              padding: EdgeInsets.symmetric(
                horizontal: ((constraints.maxWidth - _itemExtent) / 2).clamp(
                  0,
                  double.infinity,
                ),
              ),
              itemBuilder: (context, index) {
                final date = months[index];
                final value = _value(date);
                final active = value == widget.selectedMonth;
                return Center(
                  child: ChoiceChip(
                    showCheckmark: false,
                    label: Text(
                      '${_monthNames[date.month - 1].substring(0, 3)} ${date.year}',
                    ),
                    selected: active,
                    onSelected: (_) => widget.onChanged(value),
                    selectedColor: AppTheme.lime,
                    labelStyle: TextStyle(
                      color: active ? AppTheme.bg : AppTheme.text,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: AppTheme.surface,
                    side: BorderSide(
                      color: active ? AppTheme.lime : AppTheme.surface2,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

String dateLabel(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

Future<String?> _showCategorySelector(
  BuildContext context,
  SmartFieldSpec field,
  String? selectedValue,
) async {
  var currentValue = selectedValue;
  return showDialog<String>(
    context: context,
    builder: (pickerContext) => StatefulBuilder(
      builder: (pickerContext, setPickerState) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(pickerContext).width * 0.01,
        ),
        constraints: BoxConstraints(
          minWidth: MediaQuery.sizeOf(pickerContext).width * 0.98,
          maxWidth: MediaQuery.sizeOf(pickerContext).width * 0.98,
        ),
        backgroundColor: AppTheme.surface,
        title: Text(field.label),
        actionsAlignment: MainAxisAlignment.start,
        content: SizedBox(
          height: MediaQuery.sizeOf(pickerContext).height * 0.55,
          child: ListView(
            children: [
              for (final option in List<SelectOption>.of(field.options))
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () async {
                    final deleted = await field.onDeleteOption!(
                      pickerContext,
                      option.value,
                    );
                    if (!deleted || !pickerContext.mounted) return;
                    field.options.removeWhere(
                      (item) => item.value == option.value,
                    );
                    if (currentValue == option.value) {
                      currentValue =
                          field.options.firstOrNull?.value ?? _emptyOptionValue;
                    }
                    setPickerState(() {});
                    if (currentValue == _emptyOptionValue) {
                      Navigator.pop(pickerContext, _emptyOptionValue);
                    }
                  },
                  child: ListTile(
                    title: Text(option.label),
                    leading: Icon(
                      currentValue == option.value
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: currentValue == option.value
                          ? AppTheme.lime
                          : AppTheme.muted,
                    ),
                    onTap: () => Navigator.pop(pickerContext, option.value),
                  ),
                ),
              if (field.onCreateOption != null)
                ListTile(
                  leading: const Icon(Icons.add, color: AppTheme.lime),
                  title: const Text('Criar categoria'),
                  onTap: () async {
                    final created = await field.onCreateOption!(pickerContext);
                    if (!pickerContext.mounted || created == null) return;
                    final category = created.trim();
                    if (category.isEmpty) return;
                    if (!field.options.any((item) => item.value == category)) {
                      field.options.add((value: category, label: category));
                    }
                    Navigator.pop(pickerContext, category);
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(pickerContext),
            child: const Text('Fechar'),
          ),
        ],
      ),
    ),
  );
}

Future<Map<String, Object?>?> showSmartForm(
  BuildContext context,
  String title,
  List<SmartFieldSpec> fields,
) async {
  final values = <String, Object?>{
    for (final field in fields)
      field.key: switch (field.kind) {
        SmartFieldKind.toggle => field.initial == 'true',
        SmartFieldKind.multiSelect =>
          field.initial.split(',').where((value) => value.isNotEmpty).toSet(),
        _ => field.initial,
      },
  };
  final result = await showDialog<Map<String, Object?>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(dialogContext).width * 0.01,
        ),
        constraints: BoxConstraints(
          minWidth: MediaQuery.sizeOf(dialogContext).width * 0.98,
          maxWidth: MediaQuery.sizeOf(dialogContext).width * 0.98,
        ),
        backgroundColor: AppTheme.surface,
        title: Text(title),
        actionsAlignment: MainAxisAlignment.start,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: fields.map((field) {
              switch (field.kind) {
                case SmartFieldKind.text:
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      initialValue: field.initial,
                      keyboardType: field.keyboard,
                      decoration: InputDecoration(labelText: field.label),
                      onChanged: (value) => values[field.key] = value,
                    ),
                  );
                case SmartFieldKind.dropdown:
                  final options = field.options;
                  if (options.isEmpty && field.onCreateOption == null) {
                    return const SizedBox.shrink();
                  }
                  final selected =
                      options.any((e) => e.value == values[field.key])
                      ? values[field.key] as String
                      : options.isEmpty
                      ? null
                      : options.first.value;
                  values[field.key] = selected;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: field.onDeleteOption != null
                        ? InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final choice = await _showCategorySelector(
                                dialogContext,
                                field,
                                values[field.key] as String?,
                              );
                              if (choice == null || !dialogContext.mounted) {
                                return;
                              }
                              setDialogState(() {
                                values[field.key] = choice == _emptyOptionValue
                                    ? null
                                    : choice;
                              });
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: field.label,
                                helperText:
                                    'Toque para selecionar; segure para apagar',
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      options
                                              .where(
                                                (option) =>
                                                    option.value == selected,
                                              )
                                              .firstOrNull
                                              ?.label ??
                                          'Selecione uma categoria',
                                      textAlign: TextAlign.left,
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down),
                                ],
                              ),
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            initialValue: selected,
                            decoration: InputDecoration(labelText: field.label),
                            items:
                                options
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e.value,
                                        child: Text(e.label),
                                      ),
                                    )
                                    .toList()
                                  ..addAll(
                                    field.onCreateOption == null
                                        ? const []
                                        : [
                                            const DropdownMenuItem(
                                              value: _createOptionValue,
                                              child: Text('+ Criar categoria'),
                                            ),
                                          ],
                                  ),
                            onChanged: (value) async {
                              if (value == _createOptionValue) {
                                final created = await field.onCreateOption!(
                                  dialogContext,
                                );
                                if (created != null &&
                                    created.trim().isNotEmpty) {
                                  final category = created.trim();
                                  if (!options.any(
                                    (item) => item.value == category,
                                  )) {
                                    options.add((
                                      value: category,
                                      label: category,
                                    ));
                                  }
                                  setDialogState(
                                    () => values[field.key] = category,
                                  );
                                }
                                return;
                              }
                              setDialogState(() => values[field.key] = value);
                            },
                          ),
                  );
                case SmartFieldKind.multiSelect:
                  final selectedValues =
                      values[field.key] as Set<String>? ?? <String>{};
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            field.label,
                            style: const TextStyle(color: AppTheme.muted),
                          ),
                        ),
                        if (field.options.isEmpty)
                          const Text(
                            'Nenhuma regra de investimento cadastrada.',
                            style: TextStyle(color: AppTheme.muted),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 2,
                            children: field.options.map((option) {
                              final isSelected = selectedValues.contains(
                                option.value,
                              );
                              return FilterChip(
                                label: Text(option.label),
                                selected: isSelected,
                                showCheckmark: false,
                                onSelected: (selected) => setDialogState(() {
                                  if (selected) {
                                    selectedValues.add(option.value);
                                  } else {
                                    selectedValues.remove(option.value);
                                  }
                                }),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  );
                case SmartFieldKind.toggle:
                  return SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(field.label),
                    value: values[field.key] as bool? ?? false,
                    activeThumbColor: AppTheme.lime,
                    onChanged: (value) =>
                        setDialogState(() => values[field.key] = value),
                  );
                case SmartFieldKind.date:
                  final requestedDate =
                      DateTime.tryParse(values[field.key]?.toString() ?? '') ??
                      DateTime.now();
                  final firstDate = field.firstDate ?? DateTime(2000);
                  final lastDate = field.lastDate ?? DateTime(2100);
                  final date = requestedDate.isBefore(firstDate)
                      ? firstDate
                      : requestedDate.isAfter(lastDate)
                      ? lastDate
                      : requestedDate;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(field.label),
                    subtitle: Text(
                      dateLabel(date.toIso8601String()),
                      style: const TextStyle(color: AppTheme.lime),
                    ),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: date,
                        firstDate: firstDate,
                        lastDate: lastDate,
                      );
                      if (picked != null) {
                        setDialogState(
                          () => values[field.key] =
                              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
                        );
                      }
                    },
                  );
                case SmartFieldKind.optionalDate:
                  final value = values[field.key]?.toString() ?? '';
                  final requestedDate =
                      DateTime.tryParse(value) ?? DateTime.now();
                  final firstDate = field.firstDate ?? DateTime(2000);
                  final lastDate = field.lastDate ?? DateTime(2100);
                  final date = requestedDate.isBefore(firstDate)
                      ? firstDate
                      : requestedDate.isAfter(lastDate)
                      ? lastDate
                      : requestedDate;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(field.label),
                    subtitle: Text(
                      value.isEmpty ? 'Sem vencimento' : dateLabel(value),
                      style: const TextStyle(color: AppTheme.lime),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (value.isNotEmpty)
                          IconButton(
                            tooltip: 'Limpar vencimento',
                            onPressed: () =>
                                setDialogState(() => values[field.key] = ''),
                            icon: const Icon(Icons.close),
                          ),
                        const Icon(Icons.calendar_month),
                      ],
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: date,
                        firstDate: firstDate,
                        lastDate: lastDate,
                      );
                      if (picked != null) {
                        setDialogState(
                          () => values[field.key] =
                              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
                        );
                      }
                    },
                  );
              }
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              for (final field in fields.where(
                (field) => field.kind == SmartFieldKind.text,
              )) {
                values[field.key] = values[field.key]?.toString().trim() ?? '';
              }
              for (final field in fields.where(
                (field) => field.kind == SmartFieldKind.multiSelect,
              )) {
                values[field.key] =
                    (values[field.key] as Set<String>? ?? <String>{}).join(',');
              }
              Navigator.pop(dialogContext, Map<String, Object?>.from(values));
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
  return result;
}

Future<Map<String, String>?> showDataForm(
  BuildContext context,
  String title,
  List<FieldSpec> fields,
) async {
  final values = <String, String>{
    for (final field in fields) field.key: field.initial,
  };
  final result = await showDialog<Map<String, String>>(
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
      title: Text(title),
      actionsAlignment: MainAxisAlignment.start,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final f in fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  initialValue: f.initial,
                  keyboardType: f.keyboard,
                  decoration: InputDecoration(labelText: f.label),
                  onChanged: (value) => values[f.key] = value,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, {
            for (final entry in values.entries) entry.key: entry.value.trim(),
          }),
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
  return result;
}

int centsFrom(String value) {
  var normalized = value
      .trim()
      .replaceAll('R\$', '')
      .replaceAll(' ', '')
      .replaceAll(RegExp(r'[^0-9,.]'), '');
  final comma = normalized.lastIndexOf(',');
  final dot = normalized.lastIndexOf('.');
  if (comma >= 0 && dot >= 0) {
    final decimal = comma > dot ? ',' : '.';
    normalized = normalized
        .replaceAll(decimal == ',' ? '.' : ',', '')
        .replaceAll(decimal, '.');
  } else if (comma >= 0) {
    normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
  } else if (dot >= 0) {
    final decimalDigits = normalized.length - dot - 1;
    if (decimalDigits > 2) normalized = normalized.replaceAll('.', '');
  }
  return ((double.tryParse(normalized) ?? 0) * 100).round();
}
