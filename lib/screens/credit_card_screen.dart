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

  @override
  void initState() {
    super.initState();
    _load();
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
    final result = await showDialog<CreditCardEntry>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreditCardEntryDialog(
        existing: existing,
        type: existing?.type ?? type,
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
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final addSpend = FilledButton.icon(
                            key: const ValueKey<String>(
                              'credit-card-add-spend',
                            ),
                            onPressed: _busy ? null : _edit,
                            icon: const Icon(Icons.add),
                            label: const Text('Naya kharch'),
                          );
                          final addPayment = OutlinedButton.icon(
                            key: const ValueKey<String>(
                              'credit-card-add-payment',
                            ),
                            onPressed: _busy
                                ? null
                                : () =>
                                      _edit(type: CreditCardEntryType.payment),
                            icon: const Icon(
                              Icons.account_balance_wallet_outlined,
                            ),
                            label: const Text('Payment jama'),
                          );
                          if (constraints.maxWidth < 430) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                addSpend,
                                const SizedBox(height: 10),
                                addPayment,
                              ],
                            );
                          }
                          return Row(
                            children: <Widget>[
                              Expanded(child: addSpend),
                              const SizedBox(width: 10),
                              Expanded(child: addPayment),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      AppSectionHeader(
                        title: 'Kharch aur payment',
                        subtitle: _entries.isEmpty
                            ? 'Har entry date ke saath yahan dikhegi.'
                            : 'Latest entry sabse upar hai.',
                        trailing: _entries.isEmpty
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
                                  '${_entries.length}',
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
                      if (_entries.isEmpty)
                        AppSurface(
                          color: const Color(0xfff8faf9),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 22),
                            child: Column(
                              children: <Widget>[
                                Icon(
                                  Icons.credit_card_off_outlined,
                                  size: 38,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Abhi koi entry nahi',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Pehla kharch ya card payment add karo.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        for (final entry in _entries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
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
    return AppSurface(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            entry.isPayment
                ? Icons.check_circle_outline
                : Icons.shopping_bag_outlined,
            color: color,
            size: 22,
          ),
        ),
        title: Text(
          entry.displayDescription,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${entry.date.day} ${monthName(entry.date.month)} '
          '${entry.date.year} · ${entry.isPayment ? 'Payment' : 'Kharch'}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              amount,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
            PopupMenuButton<_EntryAction>(
              enabled: enabled,
              tooltip: 'Entry options',
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
          ],
        ),
      ),
    );
  }
}

class _CreditCardEntryDialog extends StatefulWidget {
  const _CreditCardEntryDialog({required this.existing, required this.type});

  final CreditCardEntry? existing;
  final CreditCardEntryType type;

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
    final now = DateTime.now();
    _date = existing?.date ?? DateTime(now.year, now.month, now.day);
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
