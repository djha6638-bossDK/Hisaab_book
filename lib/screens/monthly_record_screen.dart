import 'package:flutter/material.dart';

import '../core/assignee.dart';
import '../core/currency.dart';
import '../core/user_error.dart';
import '../domain/monthly_record_logic.dart';
import '../models/expense_entry.dart';
import '../models/income_entry.dart';
import '../models/monthly_record.dart';
import '../models/payment_person.dart';
import '../repositories/ledger_repository.dart';
import '../widgets/app_shell.dart';
import 'income_setup_dialog.dart';
import 'payment_person_picker.dart';

class MonthlyRecordScreen extends StatefulWidget {
  const MonthlyRecordScreen({
    required this.repository,
    required this.initialRecord,
    required this.viewOnly,
    this.isNewRecord = false,
    super.key,
  });

  final LedgerRepository repository;
  final MonthlyRecord initialRecord;
  final bool viewOnly;
  final bool isNewRecord;

  @override
  State<MonthlyRecordScreen> createState() => _MonthlyRecordScreenState();
}

class _ExpenseRowController {
  _ExpenseRowController(ExpenseEntry entry)
    : name = TextEditingController(text: entry.name),
      amount = TextEditingController(
        text: entry.name.isEmpty && entry.amount == 0
            ? ''
            : entry.amount.toStringAsFixed(2),
      ),
      fromRecurring = entry.fromRecurringTemplate,
      assignedPersonId = entry.assignedPersonId,
      assignedPersonName = entry.assignedPersonName;

  final TextEditingController name;
  final TextEditingController amount;
  final bool fromRecurring;
  String? assignedPersonId;
  String? assignedPersonName;

  String get assigneeLabel {
    final name = assignedPersonName?.trim() ?? '';
    return name.isEmpty ? defaultAssigneeLabel : name;
  }

  void assignTo(PaymentPerson? person) {
    assignedPersonId = person?.id;
    assignedPersonName = person?.name;
  }

  ExpenseEntry? toEntry() {
    final value = parseIndianAmount(amount.text);
    if (name.text.trim().isEmpty || value == null) return null;
    return ExpenseEntry(
      name: name.text.trim(),
      amount: value,
      fromRecurringTemplate: fromRecurring,
      assignedPersonId: assignedPersonId,
      assignedPersonName: assignedPersonName,
    );
  }

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

class _MonthlyRecordScreenState extends State<MonthlyRecordScreen> {
  late final List<_ExpenseRowController> _expenseRows;
  late List<IncomeEntry> _incomes;
  List<PaymentPerson> _paymentPeople = <PaymentPerson>[];
  late bool _viewOnly;
  bool _dirty = false;
  bool _saving = false;
  bool _deleting = false;
  bool _paymentPeopleLoaded = false;
  Future<void>? _paymentPeopleLoad;

  @override
  void initState() {
    super.initState();
    _viewOnly = widget.viewOnly;
    _incomes = List<IncomeEntry>.from(widget.initialRecord.incomes);
    _expenseRows = widget.initialRecord.expenses
        .map(_ExpenseRowController.new)
        .toList();
    if (_expenseRows.isEmpty) {
      _expenseRows.add(
        _ExpenseRowController(const ExpenseEntry(name: '', amount: 0)),
      );
    }
  }

  @override
  void dispose() {
    for (final row in _expenseRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  MonthlyRecord? _buildRecord({bool showError = true}) {
    final expenseValidation = validateExpenseRows(
      _expenseRows.map(
        (row) => (
          name: row.name.text,
          amount: row.amount.text,
          fromRecurring: row.fromRecurring,
          assignedPersonId: row.assignedPersonId,
          assignedPersonName: row.assignedPersonName,
        ),
      ),
    );
    if (!expenseValidation.isValid) {
      if (showError) _showMessage(expenseValidation.errors.first);
      return null;
    }
    return widget.initialRecord.copyWith(
      incomes: _incomes,
      expenses: expenseValidation.value,
    );
  }

  double get _incomeValue => incomeTotal(_incomes);
  double get _expenseValue => _expenseRows.fold(
    0,
    (total, row) => total + (parseIndianAmount(row.amount.text) ?? 0),
  );

  List<ExpenseEntry> get _currentExpenses => <ExpenseEntry>[
    for (final row in _expenseRows) ?row.toEntry(),
  ];

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
      _showMessage(
        friendlyError(
          error,
          fallback: 'Payment log load nahi hue. Phir koshish karo.',
        ),
      );
    } finally {
      _paymentPeopleLoad = null;
    }
  }

  Future<void> _chooseAssignee(_ExpenseRowController row) async {
    if (!_paymentPeopleLoaded) {
      await _ensurePaymentPeopleLoaded();
      if (!mounted || !_paymentPeopleLoaded) return;
    }

    final people = List<PaymentPerson>.from(_paymentPeople);
    final assignedId = row.assignedPersonId?.trim() ?? '';
    final assignedName = row.assignedPersonName?.trim() ?? '';
    final hasAssignedPerson = assignedName.isNotEmpty;
    if (hasAssignedPerson &&
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
      row.assignTo(person);
      _dirty = true;
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
      _showMessage(
        friendlyError(
          error,
          fallback: 'Payment person add nahi hua. Phir koshish karo.',
        ),
      );
      return null;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm(
    String title,
    String message, {
    String confirmLabel = 'Haan',
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _editIncome() async {
    final result = await showDialog<IncomeSetupResult>(
      context: context,
      builder: (_) => IncomeSetupDialog(initialIncomes: _incomes),
    );
    if (result == null || !mounted) return;
    setState(() {
      _incomes = result.incomes;
      _dirty = true;
    });
  }

  Future<void> _deleteRecord() async {
    if (_deleting) return;
    final confirmed = await _confirm(
      'Ye mahina delete karna hai?',
      '${widget.initialRecord.label} ka poora saved record hat jayega. '
          'Ye wapas nahi aayega.',
      confirmLabel: 'Delete karo',
    );
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
    try {
      await widget.repository.deleteMonthlyRecord(widget.initialRecord.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      _showMessage(
        friendlyError(
          error,
          fallback: 'Record delete nahi hua. Phir koshish karo.',
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final record = _buildRecord();
    if (record == null) return;

    final creating = widget.isNewRecord;
    setState(() => _saving = true);
    try {
      try {
        await widget.repository.saveMonthlyRecord(
          record,
          overwrite: !creating,
        );
      } on MonthlyRecordAlreadyExistsException {
        if (!mounted) return;
        final confirmed = await _confirm(
          'Ye mahina pehle se saved hai',
          '${record.label} ka record pehle se hai. Usko update karna hai?',
          confirmLabel: 'Update karo',
        );
        if (!confirmed) {
          if (mounted) setState(() => _saving = false);
          return;
        }
        await widget.repository.saveMonthlyRecord(record, overwrite: true);
      }
      if (!mounted) return;
      _dirty = false;
      _showMessage(
        creating ? 'Mahine ka record save ho gaya.' : 'Record update ho gaya.',
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      _showMessage(
        friendlyError(
          error,
          fallback: 'Record save nahi hua. Phir koshish karo.',
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addExpense() {
    setState(() {
      _expenseRows.add(
        _ExpenseRowController(const ExpenseEntry(name: '', amount: 0)),
      );
      _dirty = true;
    });
  }

  Future<void> _requestPop() async {
    if (!_dirty || _viewOnly) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final discard = await _confirm(
      'Bina save kiye bahar nikle?',
      'Is mahine ke badle hue changes chale jayenge.',
      confirmLabel: 'Bahar niklo',
    );
    if (!discard || !mounted) return;
    setState(() => _dirty = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final allocations = expenseAllocations(_currentExpenses);
    final balance = _incomeValue - _expenseValue;
    var runningBalance = _incomeValue;
    final rowBalances = <double>[
      for (final row in _expenseRows)
        runningBalance -= parseIndianAmount(row.amount.text) ?? 0,
    ];
    return PopScope(
      canPop: !_dirty || _viewOnly,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.initialRecord.label),
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _requestPop,
            icon: const Icon(Icons.arrow_back),
          ),
          actions: <Widget>[
            if (!widget.isNewRecord)
              IconButton(
                tooltip: 'Record delete karo',
                onPressed: _deleting ? null : _deleteRecord,
                icon: _deleting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
              ),
            if (_viewOnly)
              IconButton(
                tooltip: 'Record badlo',
                onPressed: () => setState(() => _viewOnly = false),
                icon: const Icon(Icons.edit),
              ),
          ],
        ),
        bottomNavigationBar: _viewOnly
            ? null
            : Material(
                color: Theme.of(context).colorScheme.surface,
                elevation: 12,
                shadowColor: const Color(0x330d2116),
                child: SafeArea(
                  child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              _saving ? 'Save ho raha hai...' : 'Mahina save karo',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        floatingActionButton: _viewOnly
            ? null
            : FloatingActionButton(
                tooltip: 'Kharcha jodo',
                onPressed: _addExpense,
                shape: const CircleBorder(),
                child: const Icon(Icons.add),
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: SafeArea(
          child: AppContent(
            maxWidth: 920,
            child: ListView(
              children: <Widget>[
                AppSurface(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _SummaryValue(
                          icon: Icons.arrow_downward,
                          label: 'Income',
                          value: formatIndianCurrency(_incomeValue),
                          color: const Color(0xff176b3a),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 52,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      Expanded(
                        child: _SummaryValue(
                          icon: Icons.arrow_upward,
                          label: 'Kharch',
                          value: formatIndianCurrency(_expenseValue),
                          color: const Color(0xffb75c12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppSectionHeader(
                  title: 'Income',
                  subtitle: _viewOnly
                      ? 'Is mahine ki saved income.'
                      : 'Salary, pension ya koi bhi income source badlo.',
                ),
                const SizedBox(height: 12),
                AppSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (_incomes.isEmpty)
                        Text(
                          'Koi income source nahi hai.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else
                        for (final entry in _incomes.asMap().entries) ...<Widget>[
                          if (entry.key > 0) const Divider(height: 18),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  entry.value.name,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              Text(
                                formatIndianCurrency(entry.value.amount),
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ],
                      if (!_viewOnly) ...<Widget>[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            key: const ValueKey<String>('edit-income-button'),
                            onPressed: _saving ? null : _editIncome,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Income badlo'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppSectionHeader(
                  title: 'Kharch',
                  subtitle: _viewOnly
                      ? 'Is mahine ke saved kharch.'
                      : 'Rakam bharo aur chuno kaun payment karega.',
                ),
                const SizedBox(height: 12),
                for (final entry in _expenseRows.asMap().entries)
                  _EditableMoneyRow(
                    nameController: entry.value.name,
                    amountController: entry.value.amount,
                    nameLabel: entry.value.fromRecurring
                        ? 'Recurring kharch'
                        : 'Kharcha',
                    balance: formatIndianCurrency(rowBalances[entry.key]),
                    assigneeLabel: entry.value.assigneeLabel,
                    enabled: !_viewOnly,
                    onAssign: _viewOnly
                        ? null
                        : () => _chooseAssignee(entry.value),
                    onChanged: () {
                      _markDirty();
                      setState(() {});
                    },
                    onRemove: _viewOnly
                        ? null
                        : () {
                            final removed = _expenseRows.removeAt(entry.key);
                            removed.dispose();
                            setState(() => _dirty = true);
                          },
                  ),
                AppSurface(
                  color: balance < 0
                      ? Theme.of(
                          context,
                        ).colorScheme.error.withValues(alpha: 0.06)
                      : const Color(0xffedf5f1),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        balance < 0
                            ? Icons.warning_amber_outlined
                            : Icons.check_circle_outline,
                        color: balance < 0
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Bachat = ${formatIndianCurrency(balance)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                if (allocations.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 24),
                  const AppSectionHeader(
                    title: 'Payment ka hisaab',
                    subtitle: 'Har person ka total kharch.',
                  ),
                  const SizedBox(height: 12),
                  AppSurface(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: <Widget>[
                        for (final entry in allocations.asMap().entries) ...[
                          if (entry.key > 0) const Divider(),
                          _AllocationRow(allocation: entry.value),
                        ],
                      ],
                    ),
                  ),
                ],
                if (!_viewOnly) const SizedBox(height: 72),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditableMoneyRow extends StatelessWidget {
  const _EditableMoneyRow({
    required this.nameController,
    required this.amountController,
    required this.nameLabel,
    required this.balance,
    required this.assigneeLabel,
    required this.enabled,
    required this.onAssign,
    required this.onChanged,
    required this.onRemove,
  });

  final TextEditingController nameController;
  final TextEditingController amountController;
  final String nameLabel;
  final String balance;
  final String assigneeLabel;
  final bool enabled;
  final VoidCallback? onAssign;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppSurface(
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 600;
            final nameField = TextField(
              controller: nameController,
              enabled: enabled,
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(
                labelText: nameLabel,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 11,
                ),
              ),
            );
            final amountField = TextField(
              controller: amountController,
              enabled: enabled,
              onChanged: (_) => onChanged(),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Rakam',
                prefixText: '\u20b9 ',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 11,
                ),
              ),
            );
            final balanceField = InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Baki',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 11,
                ),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(balance),
                ),
              ),
            );
            final assignee = ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: onAssign == null
                  ? Chip(
                      avatar: const Icon(Icons.person_outline, size: 16),
                      label: Text(
                        assigneeLabel,
                        overflow: TextOverflow.ellipsis,
                      ),
                      visualDensity: VisualDensity.compact,
                    )
                  : ActionChip(
                      avatar: const Icon(Icons.person_outline, size: 16),
                      label: Text(
                        assigneeLabel,
                        overflow: TextOverflow.ellipsis,
                      ),
                      tooltip: 'Payment person chuno',
                      visualDensity: VisualDensity.compact,
                      onPressed: onAssign,
                    ),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: nameField),
                      if (onRemove != null) ...<Widget>[
                        const SizedBox(width: 4),
                        assignee,
                        const SizedBox(width: 2),
                        IconButton(
                          tooltip: 'Row hatao',
                          onPressed: onRemove,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ] else ...<Widget>[const SizedBox(width: 4), assignee],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Expanded(child: amountField),
                      const SizedBox(width: 6),
                      Expanded(child: balanceField),
                    ],
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 3, child: nameField),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: amountField),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: balanceField),
                    const SizedBox(width: 6),
                    assignee,
                    if (onRemove != null) ...<Widget>[
                      const SizedBox(width: 2),
                      IconButton(
                        tooltip: 'Row hatao',
                        onPressed: onRemove,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AllocationRow extends StatelessWidget {
  const _AllocationRow({required this.allocation});

  final ExpenseAllocation allocation;

  @override
  Widget build(BuildContext context) {
    final expenseLabel = allocation.expenseCount == 1
        ? '1 kharcha'
        : '${allocation.expenseCount} kharch';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        child: Text(allocation.label.characters.first.toUpperCase()),
      ),
      title: Text(allocation.label),
      subtitle: Text(expenseLabel),
      trailing: Text(
        formatIndianCurrency(allocation.amount),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
