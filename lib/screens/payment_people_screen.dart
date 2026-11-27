import 'package:flutter/material.dart';

import '../core/user_error.dart';
import '../models/payment_person.dart';
import '../repositories/ledger_repository.dart';
import '../widgets/app_shell.dart';

class PaymentPeopleScreen extends StatefulWidget {
  const PaymentPeopleScreen({required this.repository, super.key});

  final LedgerRepository repository;

  @override
  State<PaymentPeopleScreen> createState() => _PaymentPeopleScreenState();
}

class _PaymentPeopleScreenState extends State<PaymentPeopleScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<PaymentPerson> _people = <PaymentPerson>[];

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
      final people = await widget.repository.listPaymentPeople();
      if (!mounted) return;
      setState(() => _people = people);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(
          error,
          fallback: 'Payment log load nahi hue. Phir koshish karo.',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addPerson() async {
    final name = await _askName();
    if (name == null || !mounted) return;
    await _savePerson(PaymentPerson(id: '', name: name));
  }

  Future<void> _renamePerson(PaymentPerson person) async {
    final name = await _askName(initialName: person.name);
    if (name == null || name == person.name || !mounted) return;
    await _savePerson(PaymentPerson(id: person.id, name: name));
  }

  Future<void> _savePerson(PaymentPerson person) async {
    setState(() => _busy = true);
    try {
      await widget.repository.savePaymentPerson(person);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            person.id.isEmpty ? 'Naya payment person jud gaya.' : 'Naam badal gaya.',
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(
              error,
              fallback: 'Payment person save nahi hua. Phir koshish karo.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deletePerson(PaymentPerson person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Payment person hatao?'),
        content: Text(
          '${person.name} list se hat jayega. Purane saved record me uska '
          'naam waisa hi rahega.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hata do'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.deletePaymentPerson(person.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment person list se hat gaya.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(
              error,
              fallback: 'Payment person delete nahi hua. Phir koshish karo.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askName({String initialName = ''}) {
    return showDialog<String>(
      context: context,
      builder: (_) => _PersonNameDialog(
        initialName: initialName,
        existingNames: <String>{
          for (final person in _people)
            if (person.name != initialName) person.normalizedName,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment log'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Naya person jodo',
            onPressed: _busy ? null : _addPerson,
            icon: const Icon(Icons.person_add_alt_1),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading || _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: AppContent(
          maxWidth: 720,
          child: _loading
              ? const AppLoadingView(label: 'Payment log load ho rahe hain...')
              : _error != null
              ? AppStatusView(
                  icon: Icons.cloud_off_outlined,
                  title: 'Payment log load nahi hue',
                  message: _error,
                  action: FilledButton(
                    onPressed: _load,
                    child: const Text('Phir koshish karo'),
                  ),
                )
              : _people.isEmpty
              ? AppStatusView(
                  icon: Icons.people_outline,
                  title: 'Abhi koi payment person nahi',
                  message:
                      'Expense kisi aur ke naam par lagana ho to yahan se '
                      'person jodo.',
                  action: FilledButton.icon(
                    onPressed: _busy ? null : _addPerson,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Person jodo'),
                  ),
                )
              : ListView(
                  children: <Widget>[
                    const AppSectionHeader(
                      title: 'Payment log',
                      subtitle:
                          'Expense kisi ke naam par lagao. Naam badlo ya '
                          'hatao, purane record waise hi rahenge.',
                    ),
                    const SizedBox(height: 12),
                    AppSurface(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: <Widget>[
                          for (final entry in _people.asMap().entries) ...[
                            if (entry.key > 0) const Divider(height: 1),
                            ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  entry.value.name.characters.first
                                      .toUpperCase(),
                                ),
                              ),
                              title: Text(entry.value.name),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  IconButton(
                                    tooltip: 'Naam badlo',
                                    onPressed: _busy
                                        ? null
                                        : () =>
                                              _renamePerson(entry.value),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Person hatao',
                                    onPressed: _busy
                                        ? null
                                        : () =>
                                              _deletePerson(entry.value),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PersonNameDialog extends StatefulWidget {
  const _PersonNameDialog({
    required this.initialName,
    required this.existingNames,
  });

  final String initialName;
  final Set<String> existingNames;

  @override
  State<_PersonNameDialog> createState() => _PersonNameDialogState();
}

class _PersonNameDialogState extends State<_PersonNameDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Naam zaroori hai.');
      return;
    }
    if (widget.existingNames.contains(name.toLowerCase())) {
      setState(() => _error = 'Ye naam pehle se list me hai.');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final renaming = widget.initialName.isNotEmpty;
    return AlertDialog(
      title: Text(renaming ? 'Naam badlo' : 'Naya payment person'),
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(renaming ? 'Save karo' : 'Add karo'),
        ),
      ],
    );
  }
}
