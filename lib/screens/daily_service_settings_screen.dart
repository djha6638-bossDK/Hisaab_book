import 'package:flutter/material.dart';

import '../core/currency.dart';
import '../core/user_error.dart';
import '../models/daily_service_settings.dart';
import '../repositories/ledger_repository.dart';
import '../widgets/app_shell.dart';

class DailyServiceSettingsScreen extends StatefulWidget {
  const DailyServiceSettingsScreen({
    required this.repository,
    this.initialSettings,
    super.key,
  });

  final LedgerRepository repository;
  final DailyServiceSettings? initialSettings;

  @override
  State<DailyServiceSettingsScreen> createState() =>
      _DailyServiceSettingsScreenState();
}

class _DailyServiceSettingsScreenState
    extends State<DailyServiceSettingsScreen> {
  static const List<DropdownMenuItem<int>>
  _weekdayItems = <DropdownMenuItem<int>>[
    DropdownMenuItem<int>(value: DateTime.monday, child: Text('Somvar')),
    DropdownMenuItem<int>(value: DateTime.tuesday, child: Text('Mangalvar')),
    DropdownMenuItem<int>(value: DateTime.wednesday, child: Text('Budhvar')),
    DropdownMenuItem<int>(value: DateTime.thursday, child: Text('Guruvar')),
    DropdownMenuItem<int>(value: DateTime.friday, child: Text('Shukravar')),
    DropdownMenuItem<int>(value: DateTime.saturday, child: Text('Shanivar')),
    DropdownMenuItem<int>(value: DateTime.sunday, child: Text('Ravivar')),
  ];

  late final TextEditingController _tuitionFeeController;
  late final TextEditingController _milkRateController;
  late final TextEditingController _milkQuantityController;
  late int _tuitionOffWeekday;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tuitionFeeController = TextEditingController(
      text: _editableNumber(widget.initialSettings?.monthlyTuitionFee),
    );
    _milkRateController = TextEditingController(
      text: _editableNumber(widget.initialSettings?.milkRatePerKg),
    );
    _milkQuantityController = TextEditingController(
      text: _editableNumber(widget.initialSettings?.defaultMilkQuantityKg),
    );
    _tuitionOffWeekday =
        widget.initialSettings?.tuitionOffWeekday ?? DateTime.sunday;
  }

  @override
  void dispose() {
    _tuitionFeeController.dispose();
    _milkRateController.dispose();
    _milkQuantityController.dispose();
    super.dispose();
  }

  String _editableNumber(double? value) {
    if (value == null || value == 0) return '';
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  double? _positiveValue(TextEditingController controller) {
    final value = parseIndianAmount(controller.text);
    return value != null && value > 0 ? value : null;
  }

  Future<void> _save() async {
    if (_saving) return;
    final tuitionFee = _positiveValue(_tuitionFeeController);
    final milkRate = _positiveValue(_milkRateController);
    final milkQuantity = _positiveValue(_milkQuantityController);
    if (tuitionFee == null || milkRate == null || milkQuantity == null) {
      setState(() => _error = 'Teeno rakam zero se zyada daalo.');
      return;
    }

    final settings = DailyServiceSettings(
      monthlyTuitionFee: tuitionFee,
      milkRatePerKg: milkRate,
      defaultMilkQuantityKg: milkQuantity,
      tuitionOffWeekday: _tuitionOffWeekday,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.saveDailyServiceSettings(settings);
      final now = DateTime.now();
      await widget.repository.saveDailyServiceMonthSettings(
        now.year,
        now.month,
        settings,
      );
      if (mounted) Navigator.of(context).pop(settings);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = friendlyError(
          error,
          fallback: 'Settings save nahi hui. Phir koshish karo.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final tuitionFee = parseIndianAmount(_tuitionFeeController.text) ?? 0;
    final milkRate = parseIndianAmount(_milkRateController.text) ?? 0;
    final milkQuantity = parseIndianAmount(_milkQuantityController.text) ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Tuition aur doodh settings')),
      bottomNavigationBar: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 12,
        child: SafeArea(
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _saving ? 'Save ho rahi hai...' : 'Settings save karo',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: AppContent(
          child: ListView(
            children: <Widget>[
              const AppSectionHeader(
                title: 'Tuition',
                subtitle:
                    'Har hafte ki chhutti ka din chuno aur mahine ki fee '
                    'daalo. Purane mahine apne rate par lock rahenge.',
              ),
              const SizedBox(height: 12),
              AppSurface(
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: _tuitionFeeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() => _error = null),
                      decoration: const InputDecoration(
                        labelText: 'Mahine ki tuition fee',
                        prefixText: '\u20b9 ',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _CalculatedValue(
                      label: '$daysInMonth din ka rate',
                      value: formatIndianCurrency(tuitionFee / daysInMonth),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _tuitionOffWeekday,
                      decoration: const InputDecoration(
                        labelText: 'Har hafte tuition ki chhutti',
                        prefixIcon: Icon(Icons.event_busy_outlined),
                      ),
                      items: _weekdayItems,
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                _tuitionOffWeekday = value;
                                _error = null;
                              });
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const AppSectionHeader(
                title: 'Doodh',
                subtitle:
                    'Roz ki default quantity apne aap aayegi. Kisi din ke '
                    'liye alag quantity bhi daal sakte ho.',
              ),
              const SizedBox(height: 12),
              AppSurface(
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: _milkRateController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() => _error = null),
                      decoration: const InputDecoration(
                        labelText: 'Doodh ka rate (per kg)',
                        prefixText: '\u20b9 ',
                        prefixIcon: Icon(Icons.local_drink_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _milkQuantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() => _error = null),
                      decoration: const InputDecoration(
                        labelText: 'Roz ki default quantity',
                        suffixText: 'kg',
                        prefixIcon: Icon(Icons.scale_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _CalculatedValue(
                      label: 'Roz ka default doodh kharch',
                      value: formatIndianCurrency(milkRate * milkQuantity),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 88),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalculatedValue extends StatelessWidget {
  const _CalculatedValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(
          Icons.calculate_outlined,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
