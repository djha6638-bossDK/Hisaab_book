import 'package:flutter/material.dart';

import '../core/assignee.dart';
import '../models/payment_person.dart';

class PaymentPersonChoice {
  const PaymentPersonChoice.self() : person = null, addPerson = false;
  const PaymentPersonChoice.person(this.person) : addPerson = false;
  const PaymentPersonChoice.add() : person = null, addPerson = true;

  final PaymentPerson? person;
  final bool addPerson;
}

Future<PaymentPersonChoice?> showPaymentPersonPicker({
  required BuildContext context,
  required List<PaymentPerson> people,
  required String assignedPersonId,
  required String assignedPersonName,
}) {
  return showModalBottomSheet<PaymentPersonChoice>(
    context: context,
    showDragHandle: true,
    builder: (context) => _PaymentPersonPickerSheet(
      people: people,
      assignedPersonId: assignedPersonId,
      assignedPersonName: assignedPersonName,
    ),
  );
}

Future<String?> showAddPaymentPersonDialog({
  required BuildContext context,
  required Set<String> existingNames,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _AddPaymentPersonDialog(existingNames: existingNames),
  );
}

class _PaymentPersonPickerSheet extends StatelessWidget {
  const _PaymentPersonPickerSheet({
    required this.people,
    required this.assignedPersonId,
    required this.assignedPersonName,
  });

  final List<PaymentPerson> people;
  final String assignedPersonId;
  final String assignedPersonName;

  bool _isSelected(PaymentPerson person) {
    if (assignedPersonId.isNotEmpty) return person.id == assignedPersonId;
    return assignedPersonName.isNotEmpty &&
        person.normalizedName == assignedPersonName.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final selfSelected = assignedPersonId.isEmpty && assignedPersonName.isEmpty;
    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 480),
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.person_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Kisko payment assign karna hai?',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: const Text(defaultAssigneeLabel),
              trailing: selfSelected
                  ? Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              selected: selfSelected,
              selectedTileColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.06),
              onTap: () =>
                  Navigator.pop(context, const PaymentPersonChoice.self()),
            ),
            for (final person in people)
              ListTile(
                leading: CircleAvatar(
                  child: Text(person.name.characters.first.toUpperCase()),
                ),
                title: Text(person.name),
                trailing: _isSelected(person)
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                selected: _isSelected(person),
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.06),
                onTap: () =>
                    Navigator.pop(context, PaymentPersonChoice.person(person)),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1),
              title: const Text('Naya person jodo'),
              onTap: () =>
                  Navigator.pop(context, const PaymentPersonChoice.add()),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPaymentPersonDialog extends StatefulWidget {
  const _AddPaymentPersonDialog({required this.existingNames});

  final Set<String> existingNames;

  @override
  State<_AddPaymentPersonDialog> createState() =>
      _AddPaymentPersonDialogState();
}

class _AddPaymentPersonDialogState extends State<_AddPaymentPersonDialog> {
  final TextEditingController _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Person ka naam zaroori hai.');
      return;
    }
    if (widget.existingNames.contains(name.toLowerCase())) {
      setState(() => _error = 'Ye person pehle se list me hai.');
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Naya payment person'),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Person ka naam',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Add karo'),
        ),
      ],
    );
  }
}
