import 'package:flutter/material.dart';

import '../core/month_utils.dart';
import '../core/user_error.dart';
import '../domain/daily_service_logic.dart';
import '../models/daily_service_attendance.dart';
import '../models/daily_service_settings.dart';
import '../repositories/ledger_repository.dart';
import '../widgets/app_shell.dart';

class DailyAttendanceScreen extends StatefulWidget {
  const DailyAttendanceScreen({
    required this.repository,
    required this.date,
    required this.settings,
    this.initialAttendance,
    this.onCompleted,
    this.onSkipped,
    super.key,
  });

  final LedgerRepository repository;
  final DateTime date;
  final DailyServiceSettings settings;
  final DailyServiceAttendance? initialAttendance;
  final Future<void> Function()? onCompleted;
  final Future<void> Function()? onSkipped;

  @override
  State<DailyAttendanceScreen> createState() => _DailyAttendanceScreenState();
}

class _DailyAttendanceScreenState extends State<DailyAttendanceScreen> {
  late bool _tuitionPresent;
  late bool _milkReceived;
  late final TextEditingController _milkQuantityController;
  late final TextEditingController _remarksController;
  bool _saving = false;
  String? _error;

  double get _tuitionMonthlyFee =>
      widget.initialAttendance?.monthlyTuitionFee ??
      widget.settings.monthlyTuitionFee;

  double get _milkRate =>
      widget.initialAttendance?.milkRatePerKg ?? widget.settings.milkRatePerKg;

  @override
  void initState() {
    super.initState();
    _tuitionPresent =
        widget.initialAttendance?.tuitionPresent ??
        !isTuitionOffDay(widget.date, widget.settings);
    _milkReceived = widget.initialAttendance?.milkReceived ?? true;
    final initialQuantity = widget.initialAttendance?.milkReceived == true
        ? widget.initialAttendance!.milkQuantityKg
        : widget.settings.defaultMilkQuantityKg;
    _milkQuantityController = TextEditingController(
      text: _editableNumber(initialQuantity),
    );
    _remarksController = TextEditingController(
      text: widget.initialAttendance?.remarks ?? '',
    );
  }

  @override
  void dispose() {
    _milkQuantityController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  String _editableNumber(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  Future<void> _save() async {
    if (_saving) return;
    final quantity =
        double.tryParse(
          _milkQuantityController.text
              .trim()
              .replaceAll(',', '')
              .replaceAll(' ', ''),
        ) ??
        0;
    if (_milkReceived && quantity <= 0) {
      setState(() => _error = 'Doodh ki quantity zero se zyada daalo.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    var tuitionExtraConfirmed =
        widget.initialAttendance?.tuitionExtraConfirmed ?? false;
    try {
      final tuitionOffDay = isTuitionOffDay(widget.date, widget.settings);
      final newlyMarkedPresent =
          _tuitionPresent &&
          tuitionOffDay &&
          widget.initialAttendance?.tuitionPresent != true;
      if (newlyMarkedPresent) {
        final monthEntries = await widget.repository.listDailyServiceAttendance(
          widget.date.year,
          widget.date.month,
        );
        final hasPendingAbsence = hasUnpaidTuitionAbsenceBefore(
          monthEntries.where(
            (entry) =>
                dailyAttendanceId(entry.date) != dailyAttendanceId(widget.date),
          ),
          date: widget.date,
          settings: widget.settings,
        );
        if (!hasPendingAbsence) {
          if (mounted) setState(() => _saving = false);
          if (!mounted) return;
          final confirmed = await _confirmExtraTuition();
          if (!confirmed) {
            if (mounted) setState(() => _saving = false);
            return;
          }
          tuitionExtraConfirmed = true;
        }
      }

      if (!_tuitionPresent || !tuitionOffDay) {
        tuitionExtraConfirmed = false;
      }

      final attendance = DailyServiceAttendance(
        date: DateTime(widget.date.year, widget.date.month, widget.date.day),
        tuitionPresent: _tuitionPresent,
        milkReceived: _milkReceived,
        milkQuantityKg: _milkReceived ? quantity : 0,
        monthlyTuitionFee: _tuitionMonthlyFee,
        milkRatePerKg: _milkRate,
        tuitionOffWeekday: widget.settings.tuitionOffWeekday,
        tuitionExtraConfirmed: tuitionExtraConfirmed,
        remarks: _remarksController.text.trim(),
      );
      await widget.repository.saveDailyServiceAttendance(attendance);
      await widget.onCompleted?.call();
      if (mounted) Navigator.of(context).pop(attendance);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = friendlyError(
          error,
          fallback: 'Attendance save nahi hui. Phir koshish karo.',
        );
      });
    }
  }

  Future<bool> _confirmExtraTuition() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey<String>('extra-tuition-confirmation'),
        title: const Text('Extra tuition mark karna hai?'),
        content: const Text(
          'Koi unpaid tuition absence pending nahi hai. Isse ek extra paid '
          'tuition din judega. Aage kisi absence me ye extra din kaam aa '
          'sakta hai aur total nahi badhega.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey<String>('confirm-extra-tuition'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Haan, extra mark karo'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _skipForToday() async {
    if (_saving || widget.onSkipped == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSkipped!.call();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = friendlyError(
          error,
          fallback: 'Skip nahi ho paya. Phir koshish karo.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tuitionOffDay = isTuitionOffDay(widget.date, widget.settings);
    const presentColor = Color(0xff1f8f4d);
    const offColor = Color(0xff9a5b00);
    final absentColor = scheme.error;

    return PopScope(
      canPop: true,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Attendance',
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.98),
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x1a000000),
                blurRadius: 18,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        _saving ? 'Save ho raha hai...' : 'Attendance save karo',
                      ),
                    ),
                  ),
                  if (widget.onSkipped != null) ...<Widget>[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey<String>('skip-button'),
                        onPressed: _saving ? null : _skipForToday,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Aaj ke liye skip'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                scheme.primary.withValues(alpha: 0.12),
                scheme.surface,
                const Color(0xfff5fbf7),
              ],
            ),
          ),
          child: SafeArea(
            child: AppContent(
              maxWidth: 760,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: ListView(
                children: <Widget>[
                  const SizedBox(height: 12),
                  AppSurface(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    color: scheme.primary.withValues(alpha: 0.07),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.fact_check_outlined,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    '${monthName(widget.date.month)} ${widget.date.day}, '
                                    '${widget.date.year}',
                                    style: theme.textTheme.headlineSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Ek baar bharo, phir aage badho.',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _StatusPill(
                              icon: Icons.school_outlined,
                              label: 'Tuition',
                              value: _tuitionPresent
                                  ? 'Aaya'
                                  : tuitionOffDay
                                  ? 'Chhutti'
                                  : 'Gair-hazir',
                              color: _tuitionPresent
                                  ? presentColor
                                  : tuitionOffDay
                                  ? offColor
                                  : absentColor,
                            ),
                            _StatusPill(
                              icon: Icons.local_drink_outlined,
                              label: 'Doodh',
                              value: _milkReceived ? 'Aaya' : 'Nahi aaya',
                              color: _milkReceived ? presentColor : absentColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  AppSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _SectionHeader(
                          icon: Icons.school_outlined,
                          title: 'Tuition',
                          subtitle: tuitionOffDay
                              ? 'Chhutti paid hai. Present mark karne se ek '
                                    'pending absence recover hoti hai.'
                              : 'Hara = aaya, lal = nahi aaya.',
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _BinaryChoiceButton(
                                key: const ValueKey<String>(
                                  'tuition-present-button',
                                ),
                                label: 'Aaya',
                                icon: Icons.check_circle_rounded,
                                selected: _tuitionPresent,
                                accentColor: presentColor,
                                onTap: _saving
                                    ? null
                                    : () => setState(() {
                                        _tuitionPresent = true;
                                        _error = null;
                                      }),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _BinaryChoiceButton(
                                key: ValueKey<String>(
                                  tuitionOffDay
                                      ? 'tuition-off-button'
                                      : 'tuition-absent-button',
                                ),
                                label: tuitionOffDay ? 'Chhutti' : 'Nahi aaya',
                                icon: tuitionOffDay
                                    ? Icons.event_busy_outlined
                                    : Icons.cancel_rounded,
                                selected: !_tuitionPresent,
                                accentColor: tuitionOffDay
                                    ? offColor
                                    : absentColor,
                                onTap: _saving
                                    ? null
                                    : () => setState(() {
                                        _tuitionPresent = false;
                                        _error = null;
                                      }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _SectionHeader(
                          icon: Icons.local_drink_outlined,
                          title: 'Milk',
                          subtitle:
                              'Ek option chuno aur quantity bharo.',
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _BinaryChoiceButton(
                                key: const ValueKey<String>(
                                  'milk-present-button',
                                ),
                                label: 'Aaya',
                                icon: Icons.check_circle_rounded,
                                selected: _milkReceived,
                                accentColor: presentColor,
                                onTap: _saving
                                    ? null
                                    : () => setState(() {
                                        _milkReceived = true;
                                        _error = null;
                                      }),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _BinaryChoiceButton(
                                key: const ValueKey<String>(
                                  'milk-absent-button',
                                ),
                                label: 'Nahi aaya',
                                icon: Icons.cancel_rounded,
                                selected: !_milkReceived,
                                accentColor: absentColor,
                                onTap: _saving
                                    ? null
                                    : () => setState(() {
                                        _milkReceived = false;
                                        _error = null;
                                      }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: _milkReceived
                              ? TextField(
                                  key: const ValueKey<String>(
                                    'milk-quantity-field',
                                  ),
                                  controller: _milkQuantityController,
                                  enabled: !_saving,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  onChanged: (_) =>
                                      setState(() => _error = null),
                                  decoration: const InputDecoration(
                                    labelText: 'Aaj doodh kitna (kg)',
                                    suffixText: 'kg',
                                    prefixIcon: Icon(Icons.scale_outlined),
                                  ),
                                )
                              : DecoratedBox(
                                  key: const ValueKey<String>(
                                    'milk-absent-note',
                                  ),
                                  decoration: BoxDecoration(
                                    color: absentColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: absentColor.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: <Widget>[
                                        Icon(
                                          Icons.info_outline_rounded,
                                          color: absentColor,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Doodh quantity sirf tab chahiye '
                                            'jab doodh aaya ho.',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  AppSurface(
                    child: TextField(
                      key: const ValueKey<String>('daily-attendance-remarks'),
                      controller: _remarksController,
                      enabled: !_saving,
                      minLines: 3,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() => _error = null),
                      decoration: const InputDecoration(
                        labelText: 'Note',
                        hintText: 'Is din ke liye note likho',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: scheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: scheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _BinaryChoiceButton extends StatelessWidget {
  const _BinaryChoiceButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final backgroundColor = selected
        ? accentColor.withValues(alpha: 0.14)
        : scheme.surface;
    final borderColor = selected ? accentColor : scheme.outlineVariant;
    final contentColor = selected ? accentColor : scheme.onSurfaceVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: selected ? 1.6 : 1),
        boxShadow: selected
            ? <BoxShadow>[
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : const <BoxShadow>[],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 20, color: contentColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: contentColor,
                    fontWeight: FontWeight.w800,
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
