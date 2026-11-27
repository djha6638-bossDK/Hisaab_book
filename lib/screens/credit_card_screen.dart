import 'package:flutter/material.dart';

import '../core/currency.dart';
import '../core/month_utils.dart';
import '../core/user_error.dart';
import '../domain/credit_card_logic.dart';
import '../models/credit_card_entry.dart';
import '../repositories/ledger_repository.dart';
import '../widgets/app_shell.dart';

class CreditCardScreen extends StatefulWidget {
  const CreditCardScreen({required this.repository, super.key});

  final LedgerRepository repository;

  @override
  State<CreditCardScreen> createState() => _CreditCardScreenState();
}

class _CreditCardScreenState extends State<CreditCardScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<CreditCardEntry> _entries = <CreditCardEntry>[];
  late int _selectedMonth;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _load();
  }

  List<CreditCardEntry> get _monthEntries => _entries
      .where(
        (entry) =>
            entry.date.year == _selectedYear &&
            entry.date.month == _selectedMonth,
      )
      .toList(growable: false);

  void _shiftMonth(int delta) {
    final target = DateTime(_selectedYear, _selectedMonth + delta);
    setState(() {
      _selectedYear = target.year;
      _selectedMonth = target.month;
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showModalBottomSheet<({int year, int month})>(
      context: context,
      showDragHandle: true,
      builder: (_) =>
          _MonthPickerSheet(month: _selectedMonth, year: _selectedYear),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedYear = picked.year;
      _selectedMonth = picked.month;
    });
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final entries = await widget.repository.listCreditCardEntries();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = friendlyError(
          error,
          fallback: 'Credit card ka hisaab load nahi hua. Phir koshish karo.',
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit({
    CreditCardEntry? existing,
    CreditCardEntryType type = CreditCardEntryType.spend,
  }) async {
    if (_busy) return;
    final now = DateTime.now();
    final lastDayOfMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final defaultDate = DateTime(
      _selectedYear,
      _selectedMonth,
      now.day > lastDayOfMonth ? lastDayOfMonth : now.day,
    );
    final result = await showDialog<CreditCardEntry>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreditCardEntryDialog(
        existing: existing,
        type: existing?.type ?? type,
        defaultDate: defaultDate,
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.saveCreditCardEntry(result);
      await _load(showLoader: false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(
              error,
              fallback: 'Entry save nahi hui. Phir koshish karo.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(CreditCardEntry entry) async {
    if (_busy) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Entry delete karni hai?'),
            content: Text(
              '${entry.displayDescription} '
              '(${formatIndianCurrency(entry.amount)}) hata di jayegi.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete karo'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.deleteCreditCardEntry(entry.id);
      await _load(showLoader: false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(error, fallback: 'Entry delete nahi hui.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = CreditCardSummary.fromEntries(_entries);
    final monthEntries = _monthEntries;
    final monthLabel = '${monthName(_selectedMonth)} $_selectedYear';
    return Scaffold(
      appBar: AppBar(title: const Text('Credit Card')),
      body: _loading
          ? const AppLoadingView(
              label: 'Credit card ka hisaab load ho raha hai...',
            )
          : _error != null
          ? AppStatusView(
              icon: Icons.cloud_off_outlined,
              title: 'Hisaab load nahi hua',
              message: _error,
              action: FilledButton(
                onPressed: _load,
                child: const Text('Phir koshish karo'),
              ),
            )
          : SafeArea(
              child: AppContent(
                maxWidth: 760,
                child: RefreshIndicator(
                  onRefresh: () => _load(showLoader: false),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: <Widget>[
                      _SummaryCard(summary: summary),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: FilledButton.icon(
                              key: const ValueKey<String>(
                                'credit-card-add-spend',
                              ),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 44),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                              onPressed: _busy ? null : _edit,
                              icon: const Icon(Icons.add, size: 20),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Naya kharch'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const ValueKey<String>(
                                'credit-card-add-payment',
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 44),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                              onPressed: _busy
                                  ? null
                                  : () => _edit(
                                      type: CreditCardEntryType.payment,
                                    ),
                              icon: const Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 20,
                              ),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Payment jama'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _MonthSwitcher(
                        month: _selectedMonth,
                        year: _selectedYear,
                        onPrevious: () => _shiftMonth(-1),
                        onNext: () => _shiftMonth(1),
                        onTap: _pickMonth,
                      ),
                      const SizedBox(height: 18),
                      AppSectionHeader(
                        title: 'Kharch aur payment',
                        subtitle: monthEntries.isEmpty
                            ? '$monthLabel me koi entry nahi.'
                            : '$monthLabel ki entries — latest sabse upar.',
                        trailing: monthEntries.isEmpty
                            ? null
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${monthEntries.length}',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 14),
                      if (monthEntries.isEmpty)
                        AppSurface(
                          color: const Color(0xfff8faf9),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Column(
                              children: <Widget>[
                                Icon(
                                  Icons.credit_card_off_outlined,
                                  size: 34,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _entries.isEmpty
                                      ? 'Abhi koi entry nahi'
                                      : 'Is mahine koi entry nahi',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _entries.isEmpty
                                      ? 'Pehla kharch ya card payment add karo.'
                                      : 'Doosra mahina chuno ya nayi entry add karo.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        for (final entry in monthEntries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _EntryTile(
                              entry: entry,
                              enabled: !_busy,
                              onEdit: () => _edit(existing: entry),
                              onDelete: () => _delete(entry),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final CreditCardSummary summary;

  @override
  Widget build(BuildContext context) {
    final outstanding = summary.outstanding;
    final due = outstanding > 0 ? outstanding : 0.0;
    final advance = outstanding < -0.005 ? outstanding.abs() : 0.0;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xff10241b), Color(0xff1f6a45)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xff10241b).withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: <Widget>[
            Positioned(
              right: -46,
              top: -52,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              right: 74,
              bottom: -66,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.credit_card,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'CREDIT CARD',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.6,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Baki due',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      if (summary.isSettled && summary.hasEntries)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.check_circle_outline,
                                color: Colors.white,
                                size: 15,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Sab clear',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    formatIndianCurrency(due),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  if (advance > 0) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      'Extra jama ${formatIndianCurrency(advance)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Divider(
                    color: Colors.white.withValues(alpha: 0.18),
                    height: 1,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _SummaryStat(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Payment jama',
                          value: formatIndianCurrency(summary.totalPaid),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      Expanded(
                        child: _SummaryStat(
                          icon: Icons.receipt_long_outlined,
                          label: 'Total spend',
                          value: formatIndianCurrency(summary.totalSpend),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.66)),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({
    required this.month,
    required this.year,
    required this.onPrevious,
    required this.onNext,
    required this.onTap,
  });

  final int month;
  final int year;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppSurface(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: <Widget>[
          IconButton(
            key: const ValueKey<String>('credit-card-prev-month'),
            tooltip: 'Pichla mahina',
            visualDensity: VisualDensity.compact,
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: InkWell(
              key: const ValueKey<String>('credit-card-month-picker'),
              borderRadius: BorderRadius.circular(999),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.event_outlined, size: 16, color: scheme.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${monthName(month)} $year',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.expand_more,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            key: const ValueKey<String>('credit-card-next-month'),
            tooltip: 'Agla mahina',
            visualDensity: VisualDensity.compact,
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({required this.month, required this.year});

  final int month;
  final int year;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int _year = widget.year;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Pichla saal',
                  onPressed: () => setState(() => _year--),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '$_year',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Agla saal',
                  onPressed: () => setState(() => _year++),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.6,
              children: <Widget>[
                for (var month = 1; month <= 12; month++)
                  _MonthChip(
                    month: month,
                    selected: month == widget.month && _year == widget.year,
                    onTap: () =>
                        Navigator.pop(context, (year: _year, month: month)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({
    required this.month,
    required this.selected,
    required this.onTap,
  });

  final int month;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? Colors.transparent : scheme.outline,
            ),
          ),
          child: Text(
            monthName(month),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? scheme.onPrimary : scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

enum _EntryAction { edit, delete }

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  final CreditCardEntry entry;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = entry.isPayment
        ? const Color(0xff176b3a)
        : const Color(0xffb3261e);
    final amount =
        '${entry.isPayment ? '-' : ''}'
        '${formatIndianCurrency(entry.amount)}';
    final theme = Theme.of(context);
    return AppSurface(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 7, 2, 7),
        child: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                entry.isPayment
                    ? Icons.check_circle_outline
                    : Icons.shopping_bag_outlined,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    entry.displayDescription,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${entry.date.day} ${monthName(entry.date.month)} '
                    '${entry.date.year} · '
                    '${entry.isPayment ? 'Payment' : 'Kharch'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              amount,
              style: theme.textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(
              width: 34,
              height: 34,
              child: PopupMenuButton<_EntryAction>(
                enabled: enabled,
                tooltip: 'Entry options',
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (action) {
                  switch (action) {
                    case _EntryAction.edit:
                      onEdit();
                    case _EntryAction.delete:
                      onDelete();
                  }
                },
                itemBuilder: (context) => const <PopupMenuEntry<_EntryAction>>[
                  PopupMenuItem<_EntryAction>(
                    value: _EntryAction.edit,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit karo'),
                    ),
                  ),
                  PopupMenuItem<_EntryAction>(
                    value: _EntryAction.delete,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete karo'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditCardEntryDialog extends StatefulWidget {
  const _CreditCardEntryDialog({
    required this.existing,
    required this.type,
    required this.defaultDate,
  });

  final CreditCardEntry? existing;
  final CreditCardEntryType type;
  final DateTime defaultDate;

  @override
  State<_CreditCardEntryDialog> createState() => _CreditCardEntryDialogState();
}

class _CreditCardEntryDialogState extends State<_CreditCardEntryDialog> {
  late final TextEditingController _amount;
  late final TextEditingController _description;
  late DateTime _date;
  String? _error;

  bool get _isPayment => widget.type == CreditCardEntryType.payment;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _amount = TextEditingController(
      text: existing == null ? '' : existing.amount.toStringAsFixed(2),
    );
    _description = TextEditingController(text: existing?.description ?? '');
    _date = existing?.date ?? widget.defaultDate;
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Date chuno',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _submit() {
    final amount = parseIndianAmount(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Sahi rakam bharo (zero se zyada).');
      return;
    }
    final description = _description.text.trim();
    if (!_isPayment && description.isEmpty) {
      setState(() => _error = 'Kis liye kharch kiya, wo likho.');
      return;
    }
    Navigator.pop(
      context,
      CreditCardEntry(
        id: widget.existing?.id ?? '',
        type: widget.type,
        amount: amount,
        description: description,
        date: _date,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing
        ? 'Entry badlo'
        : _isPayment
        ? 'Payment jama karo'
        : 'Naya kharch';
    return AlertDialog(
      title: Row(
        children: <Widget>[
          Icon(
            _isPayment
                ? Icons.account_balance_wallet_outlined
                : Icons.shopping_bag_outlined,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title)),
        ],
      ),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                key: const ValueKey<String>('credit-card-amount'),
                controller: _amount,
                autofocus: !_isEditing,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _isPayment ? 'Payment rakam' : 'Kharch ki rakam',
                  prefixText: '\u20b9 ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey<String>('credit-card-description'),
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: _isPayment
                      ? 'Payment note (optional)'
                      : 'Kis liye kharch kiya?',
                  hintText: _isPayment
                      ? 'Jaise: Card bill payment'
                      : 'Jaise: Mobile kharida',
                  prefixIcon: const Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                key: const ValueKey<String>('credit-card-date'),
                borderRadius: BorderRadius.circular(4),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    prefixIcon: Icon(Icons.event_outlined),
                  ),
                  child: Text(
                    '${_date.day} ${monthName(_date.month)} ${_date.year}',
                  ),
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('credit-card-save'),
          onPressed: _submit,
          child: const Text('Save karo'),
        ),
      ],
    );
  }
}
