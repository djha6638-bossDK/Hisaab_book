import 'package:flutter/material.dart';

import '../core/assignee.dart';
import '../core/currency.dart';
import '../core/user_error.dart';
import '../models/payment_person.dart';
import '../models/recurring_expense.dart';
import '../repositories/ledger_repository.dart';
import '../widgets/app_shell.dart';
import 'payment_person_picker.dart';

class RecurringExpensesScreen extends StatefulWidget {
  const RecurringExpensesScreen({required this.repository, super.key});

  final LedgerRepository repository;

  @override
  State<RecurringExpensesScreen> createState() =>
      _RecurringExpensesScreenState();
}

class _RecurringExpensesScreenState extends State<RecurringExpensesScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<RecurringExpense> _expenses = <RecurringExpense>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final expenses = await widget.repository.listRecurringExpenses();
      if (!mounted) return;
      setState(() => _expenses = expenses);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = friendlyError(
          error,
          fallback: 'Recurring kharch load nahi hue. Phir koshish karo.',
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([RecurringExpense? existing]) async {
    if (_busy) return;
    final result = await showDialog<RecurringExpense>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RecurringExpenseDialog(
        repository: widget.repository,
        existing: existing,
        nextOrder: _expenses.length,
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.saveRecurringExpense(result);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(
              error,
              fallback: 'Recurring kharch save nahi hua. Phir koshish karo.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(RecurringExpense expense) async {
    if (_busy) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Recurring kharch delete karna hai?'),
            content: Text('${expense.name} aage naye mahine me nahi aayega.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete karo'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.deleteRecurringExpense(expense.id);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(
              error,
              fallback: 'Recurring kharch delete nahi hua.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring kharch')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Recurring kharch jodo',
        onPressed: _busy ? null : _edit,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const AppLoadingView(label: 'Recurring kharch load ho rahe hain...')
          : _error != null
          ? AppStatusView(
              icon: Icons.cloud_off_outlined,
              title: 'Recurring kharch load nahi hue',
              message: _error,
              action: OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Phir koshish karo'),
              ),
            )
          : _expenses.isEmpty
          ? const AppStatusView(
              icon: Icons.repeat,
              title: 'Koi recurring kharch nahi',
              message:
                  'Roz-mahine wale kharch yahan jodo. Naya mahina banate waqt '
                  'ye apne aap jud jayenge.',
            )
          : SafeArea(
              child: AppContent(
                maxWidth: 760,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                child: ListView(
                  children: <Widget>[
                    const AppSectionHeader(
                      title: 'Har mahine ke default',
                      subtitle:
                          'Jo active hain wahi naye mahine me apne aap judenge.',
                    ),
                    const SizedBox(height: 14),
                    for (final expense in _expenses)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppSurface(
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            contentPadding: const EdgeInsets.fromLTRB(
                              14,
                              8,
                              6,
                              8,
                            ),
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color:
                                    (expense.isActive
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant)
                                        .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                expense.isActive
                                    ? Icons.check_circle_outline
                                    : Icons.pause_circle_outline,
                                color: expense.isActive
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            title: Text(
                              expense.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${formatIndianCurrency(expense.defaultAmount)}'
                                ' \u2022 ${expense.assigneeLabel}',
                              ),
                            ),
                            trailing: Wrap(
                              spacing: 2,
                              children: <Widget>[
                                IconButton(
                                  tooltip: 'Badlo',
                                  onPressed: _busy
                                      ? null
                                      : () => _edit(expense),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Delete karo',
                                  onPressed: _busy
                                      ? null
                                      : () => _delete(expense),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _RecurringExpenseDialog extends StatefulWidget {
  const _RecurringExpenseDialog({
    required this.repository,
    required this.existing,
    required this.nextOrder,
  });

  final LedgerRepository repository;
  final RecurringExpense? existing;
  final int nextOrder;

  @override
  State<_RecurringExpenseDialog> createState() =>
      _RecurringExpenseDialogState();
}

class _RecurringExpenseDialogState extends State<_RecurringExpenseDialog> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _order;
  late bool _active;
  String? _assignedPersonId;
  String? _assignedPersonName;
  List<PaymentPerson> _paymentPeople = <PaymentPerson>[];
  bool _paymentPeopleLoaded = false;
  Future<void>? _paymentPeopleLoad;
  String? _error;

  String get _assigneeLabel {
    final name = _assignedPersonName?.trim() ?? '';
    return name.isEmpty ? defaultAssigneeLabel : name;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _amount = TextEditingController(
      text: existing == null ? '' : existing.defaultAmount.toStringAsFixed(2),
    );
    _order = TextEditingController(
      text: '${existing?.displayOrder ?? widget.nextOrder}',
    );
    _active = existing?.isActive ?? true;
    _assignedPersonId = existing?.assignedPersonId;
    _assignedPersonName = existing?.assignedPersonName;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _ensurePaymentPeopleLoaded() {
    if (_paymentPeopleLoaded) return Future<void>.value();
    return _paymentPeopleLoad ??= _loadPaymentPeople();
  }

  Future<void> _loadPaymentPeople() async {
    try {
      final people = await widget.repository.listPaymentPeople();
      if (!mounted) return;
      setState(() {
        _paymentPeople = people;
        _paymentPeopleLoaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = friendlyError(
          error,
          fallback: 'Payment log load nahi hue. Phir koshish karo.',
        ),
      );
    } finally {
      _paymentPeopleLoad = null;
    }
  }

  Future<void> _chooseAssignee() async {
    if (!_paymentPeopleLoaded) {
      await _ensurePaymentPeopleLoaded();
      if (!mounted || !_paymentPeopleLoaded) return;
    }

    final people = List<PaymentPerson>.from(_paymentPeople);
    final assignedId = _assignedPersonId?.trim() ?? '';
    final assignedName = _assignedPersonName?.trim() ?? '';
    if (assignedName.isNotEmpty &&
        !people.any(
          (person) =>
              (assignedId.isNotEmpty && person.id == assignedId) ||
              person.normalizedName == assignedName.toLowerCase(),
        )) {
      people.add(PaymentPerson(id: assignedId, name: assignedName));
      people.sort((a, b) => a.name.compareTo(b.name));
    }

    final choice = await showPaymentPersonPicker(
      context: context,
      people: people,
      assignedPersonId: assignedId,
      assignedPersonName: assignedName,
    );
    if (choice == null || !mounted) return;

    PaymentPerson? person = choice.person;
    if (choice.addPerson) {
      person = await _addPaymentPerson();
      if (person == null || !mounted) return;
    }

    setState(() {
      _assignedPersonId = person?.id;
      _assignedPersonName = person?.name;
      _error = null;
    });
  }

  Future<PaymentPerson?> _addPaymentPerson() async {
    final name = await showAddPaymentPersonDialog(
      context: context,
      existingNames: <String>{
        defaultAssigneeLabel.toLowerCase(),
        for (final person in _paymentPeople) person.normalizedName,
      },
    );
    if (name == null || !mounted) return null;

    try {
      final saved = await widget.repository.savePaymentPerson(
        PaymentPerson(id: '', name: name),
      );
      if (!mounted) return null;
      setState(() {
        _paymentPeople = <PaymentPerson>[
          ..._paymentPeople.where((person) => person.id != saved.id),
          saved,
        ]..sort((a, b) => a.name.compareTo(b.name));
        _paymentPeopleLoaded = true;
      });
      return saved;
    } catch (error) {
      if (!mounted) return null;
      setState(
        () => _error = friendlyError(
          error,
          fallback: 'Payment person add nahi hua. Phir koshish karo.',
        ),
      );
      return null;
    }
  }

  void _submit() {
    final name = _name.text.trim();
    final amount = parseIndianAmount(_amount.text);
    final order = int.tryParse(_order.text.trim());
    if (name.isEmpty) {
      setState(() => _error = 'Kharch ka naam bharo.');
      return;
    }
    if (amount == null || amount < 0) {
      setState(() => _error = 'Sahi rakam bharo (zero ya usse zyada).');
      return;
    }
    if (order == null || order < 0) {
      setState(() => _error = 'Order zero ya usse zyada daalo.');
      return;
    }
    Navigator.pop(
      context,
      RecurringExpense(
        id: widget.existing?.id ?? '',
        name: name,
        defaultAmount: amount,
        isActive: _active,
        displayOrder: order,
        assignedPersonId: _assignedPersonId,
        assignedPersonName: _assignedPersonName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Recurring kharch jodo'
            : 'Recurring kharch badlo',
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Kharch ka naam',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Har mahine ki default rakam',
                  prefixText: '\u20b9 ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _order,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Order (chhota number pehle)',
                  prefixIcon: Icon(Icons.format_list_numbered),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: const Icon(Icons.person_outline, size: 18),
                  label: Text(_assigneeLabel),
                  tooltip: 'Payment person chuno',
                  onPressed: _chooseAssignee,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active rakho'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save karo')),
      ],
    );
  }
}
