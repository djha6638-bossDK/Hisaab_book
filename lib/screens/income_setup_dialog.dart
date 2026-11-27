import 'package:flutter/material.dart';

import '../domain/monthly_record_logic.dart';
import '../models/income_entry.dart';

class IncomeSetupResult {
  const IncomeSetupResult({required this.incomes});

  final List<IncomeEntry> incomes;
}

class IncomeSetupDialog extends StatefulWidget {
  const IncomeSetupDialog({
    this.initialIncomes = const <IncomeEntry>[],
    super.key,
  });

  final List<IncomeEntry> initialIncomes;

  @override
  State<IncomeSetupDialog> createState() => _IncomeSetupDialogState();
}

class _IncomeRow {
  _IncomeRow({
    required String name,
    this.nameReadOnly = false,
    double? initialAmount,
  }) : nameController = TextEditingController(text: name),
       amountController = TextEditingController(
         text: initialAmount == null || initialAmount == 0
             ? ''
             : initialAmount == initialAmount.roundToDouble()
             ? initialAmount.toStringAsFixed(0)
             : initialAmount.toString(),
       );

  final TextEditingController nameController;
  final TextEditingController amountController;
  final bool nameReadOnly;

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }
}

class _IncomeSetupDialogState extends State<IncomeSetupDialog> {
  late final List<_IncomeRow> _rows = widget.initialIncomes.isEmpty
      ? <_IncomeRow>[
          _IncomeRow(name: 'Salary', nameReadOnly: true),
          _IncomeRow(name: 'Pension', nameReadOnly: true),
        ]
      : <_IncomeRow>[
          for (final income in widget.initialIncomes)
            _IncomeRow(name: income.name, initialAmount: income.amount),
        ];
  String? _error;

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() => _rows.add(_IncomeRow(name: '')));
  }

  void _removeRow(int index) {
    final row = _rows.removeAt(index);
    row.dispose();
    setState(() {});
  }

  void _submit() {
    final validation = validateIncomeRows(
      _rows.map(
        (row) =>
            (name: row.nameController.text, amount: row.amountController.text),
      ),
    );
    if (!validation.isValid) {
      setState(() => _error = validation.errors.first);
      return;
    }
    Navigator.of(context).pop(IncomeSetupResult(incomes: validation.value));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialIncomes.isNotEmpty;
    return AlertDialog(
      title: Text(editing ? 'Income badlo' : 'Mahine ki income'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final entry in _rows.asMap().entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        flex: 5,
                        child: TextField(
                          controller: entry.value.nameController,
                          readOnly: entry.value.nameReadOnly,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Income source',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: entry.value.amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            prefixText: '\u20b9 ',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      IconButton(
                        tooltip: 'Income hatao',
                        onPressed: () => _removeRow(entry.key),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Income jodo'),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(editing ? 'Save karo' : 'Aage badho'),
        ),
      ],
    );
  }
}
