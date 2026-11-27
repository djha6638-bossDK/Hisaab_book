import 'package:flutter/material.dart';

import '../core/currency.dart';
import '../core/month_utils.dart';
import '../core/user_error.dart';
import '../core/year_utils.dart';
import '../domain/daily_service_logic.dart';
import '../models/daily_service_attendance.dart';
import '../models/daily_service_settings.dart';
import '../repositories/ledger_repository.dart';
import '../services/daily_service_settings_resolver.dart';
import '../widgets/app_shell.dart';
import 'daily_attendance_screen.dart';
import 'daily_service_settings_screen.dart';

class DailyServicesScreen extends StatefulWidget {
  const DailyServicesScreen({required this.repository, super.key});

  final LedgerRepository repository;

  @override
  State<DailyServicesScreen> createState() => _DailyServicesScreenState();
}

class _DailyServicesScreenState extends State<DailyServicesScreen> {
  late int _selectedMonth;
  late int _selectedYear;
  DailyServiceSettings? _settings;
  List<DailyServiceAttendance> _entries = <DailyServiceAttendance>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object?>(<Future<Object?>>[
        widget.repository.getDailyServiceSettings(),
        widget.repository.listDailyServiceAttendance(
          _selectedYear,
          _selectedMonth,
        ),
      ]);
      final globalSettings = results[0] as DailyServiceSettings?;
      final entries = results[1] as List<DailyServiceAttendance>;
      final settings = globalSettings == null
          ? null
          : await resolveDailyServiceMonthSettings(
              repository: widget.repository,
              year: _selectedYear,
              month: _selectedMonth,
              entries: entries,
            );
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _entries = entries;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(
          error,
          fallback: 'Tuition aur doodh ka data load nahi ho paya.',
        );
      });
    }
  }

  Future<void> _editSettings() async {
    final now = DateTime.now();
    if (_selectedYear != now.year || _selectedMonth != now.month) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Purane mahine ka rate lock hai. Settings sirf current mahine '
            'ke liye badal sakte ho.',
          ),
        ),
      );
      return;
    }
    final saved = await Navigator.of(context).push<DailyServiceSettings>(
      MaterialPageRoute<DailyServiceSettings>(
        builder: (_) => DailyServiceSettingsScreen(
          repository: widget.repository,
          initialSettings: _settings,
        ),
      ),
    );
    if (saved == null || !mounted) return;
    setState(() => _settings = saved);
  }

  Future<void> _editAttendance(DateTime date) async {
    final settings = _settings;
    if (settings == null) {
      await _editSettings();
      return;
    }
    final existing = _entries
        .where((entry) => _sameDate(entry.date, date))
        .firstOrNull;
    final saved = await Navigator.of(context).push<DailyServiceAttendance>(
      MaterialPageRoute<DailyServiceAttendance>(
        builder: (_) => DailyAttendanceScreen(
          repository: widget.repository,
          date: date,
          settings: settings,
          initialAttendance: existing,
        ),
      ),
    );
    if (saved != null && mounted) await _load();
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tuition aur doodh'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Tuition aur doodh settings',
            onPressed: _editSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: AppContent(
          maxWidth: 820,
          child: _loading
              ? const AppLoadingView(label: 'Tuition aur doodh load ho raha hai...')
              : _error != null
              ? AppStatusView(
                  icon: Icons.cloud_off_outlined,
                  title: 'Report load nahi hui',
                  message: _error,
                  action: FilledButton(
                    onPressed: _load,
                    child: const Text('Phir koshish karo'),
                  ),
                )
              : ListView(
                  children: <Widget>[
                    if (_settings == null) ...<Widget>[
                      AppSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const AppSectionHeader(
                              title: 'Tuition aur doodh set karo',
                              subtitle:
                                  'Pehle tuition fee, doodh ka rate aur roz ki '
                                  'default quantity bharo.',
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _editSettings,
                              icon: const Icon(Icons.settings_outlined),
                              label: const Text('Settings kholo'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    _MonthSelector(
                      selectedMonth: _selectedMonth,
                      selectedYear: _selectedYear,
                      onMonthChanged: (value) {
                        _selectedMonth = value;
                        _load();
                      },
                      onYearChanged: (value) {
                        _selectedYear = value;
                        _load();
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_settings != null) ...<Widget>[
                      _AbsentDatesSummary(
                        year: _selectedYear,
                        month: _selectedMonth,
                        settings: _settings!,
                        entries: _entries,
                      ),
                      const SizedBox(height: 16),
                      _MonthSummary(
                        year: _selectedYear,
                        month: _selectedMonth,
                        settings: _settings!,
                        entries: _entries,
                      ),
                      const SizedBox(height: 20),
                      const AppSectionHeader(
                        title: 'Roz ka report',
                        subtitle:
                            'Kisi bhi date par tap karke attendance bharo ya '
                            'sudharo. Orange date par long press karke note '
                            'dekho.',
                      ),
                      const SizedBox(height: 12),
                      _DailyReport(
                        year: _selectedYear,
                        month: _selectedMonth,
                        settings: _settings!,
                        entries: _entries,
                        onEdit: _editAttendance,
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.selectedMonth,
    required this.selectedYear,
    required this.onMonthChanged,
    required this.onYearChanged,
  });

  final int selectedMonth;
  final int selectedYear;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onYearChanged;

  @override
  Widget build(BuildContext context) {
    final years = availableYears();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: selectedMonth,
              decoration: const InputDecoration(labelText: 'Mahina'),
              items: List<DropdownMenuItem<int>>.generate(
                12,
                (index) => DropdownMenuItem<int>(
                  value: index + 1,
                  child: Text(monthNames[index]),
                ),
              ),
              onChanged: (value) {
                if (value != null) onMonthChanged(value);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: selectedYear,
              decoration: const InputDecoration(labelText: 'Saal'),
              items: <DropdownMenuItem<int>>[
                for (final year in years)
                  DropdownMenuItem<int>(value: year, child: Text('$year')),
              ],
              onChanged: (value) {
                if (value != null) onYearChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AbsentDatesSummary extends StatelessWidget {
  const _AbsentDatesSummary({
    required this.year,
    required this.month,
    required this.settings,
    required this.entries,
  });

  final int year;
  final int month;
  final DailyServiceSettings settings;
  final List<DailyServiceAttendance> entries;

  @override
  Widget build(BuildContext context) {
    final summary = summarizeDailyServices(
      entries,
      year: year,
      month: month,
      settings: settings,
    );
    final milkAbsent = entries
        .where((entry) => !entry.milkReceived)
        .map((entry) => _AbsenceDate(_shortDate(entry.date)))
        .toList();

    return AppSurface(
      color: const Color(0xfffff7ed),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Gair-hazir dates',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _AbsentDateLine(
            icon: Icons.school_outlined,
            label: 'Tuition',
            keyLabel: 'Tuition',
            dates: <_AbsenceDate>[
              for (final absence in summary.tuitionAbsences)
                _AbsenceDate(
                  _shortDate(absence.date),
                  status: absence.compensation,
                ),
            ],
          ),
          const SizedBox(height: 10),
          _AbsentDateLine(
            icon: Icons.local_drink_outlined,
            label: 'Doodh',
            keyLabel: 'Milk',
            dates: milkAbsent,
          ),
        ],
      ),
    );
  }

  String _shortDate(DateTime date) =>
      '${date.day} ${monthName(date.month).substring(0, 3)}';
}

class _AbsentDateLine extends StatelessWidget {
  const _AbsentDateLine({
    required this.icon,
    required this.label,
    required this.dates,
    this.keyLabel,
  });

  final IconData icon;
  final String label;
  final String? keyLabel;
  final List<_AbsenceDate> dates;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    const compensatedColor = Color(0xff176b3a);
    const extraColor = Color(0xffa66a00);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 19, color: errorColor),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 7),
        if (dates.isEmpty)
          Text('Koi nahi', style: Theme.of(context).textTheme.bodyMedium)
        else
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              for (final date in dates)
                Builder(
                  builder: (context) {
                    final dateColor = switch (date.status) {
                      TuitionAbsenceCompensation.none => errorColor,
                      TuitionAbsenceCompensation.laterOffDay =>
                        compensatedColor,
                      TuitionAbsenceCompensation.prepaidExtra => extraColor,
                    };
                    final statusKey = switch (date.status) {
                      TuitionAbsenceCompensation.none => 'absent',
                      TuitionAbsenceCompensation.laterOffDay => 'compensated',
                      TuitionAbsenceCompensation.prepaidExtra =>
                        'extra-compensated',
                    };
                    return Container(
                      key: ValueKey<String>(
                        '$statusKey-${keyLabel ?? label}-${date.label}',
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: dateColor.withValues(alpha: 0.1),
                        border: Border.all(
                          color: dateColor.withValues(alpha: 0.4),
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        date.label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: dateColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }
}

class _AbsenceDate {
  const _AbsenceDate(
    this.label, {
    this.status = TuitionAbsenceCompensation.none,
  });

  final String label;
  final TuitionAbsenceCompensation status;
}

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({
    required this.year,
    required this.month,
    required this.settings,
    required this.entries,
  });

  final int year;
  final int month;
  final DailyServiceSettings settings;
  final List<DailyServiceAttendance> entries;

  @override
  Widget build(BuildContext context) {
    final summary = summarizeDailyServices(
      entries,
      year: year,
      month: month,
      settings: settings,
    );
    return Column(
      children: <Widget>[
        AppSurface(
          color: const Color(0xffedf5f1),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _SummaryMetric(
                  label: 'Tuition din',
                  value: '${summary.tuitionDays}',
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: 'Doodh din',
                  value: '${summary.milkDays}',
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: 'Doodh total',
                  value: '${_formatQuantity(summary.totalMilkQuantityKg)} kg',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: _ServiceAmountPanel(
                icon: Icons.school_outlined,
                label: 'Tuition ka amount',
                keyName: 'Tuition amount',
                value: summary.tuitionAmount,
                monthlyTotal: settings.monthlyTuitionFee,
                color: const Color(0xff176b3a),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ServiceAmountPanel(
                icon: Icons.local_drink_outlined,
                label: 'Doodh amount',
                keyName: 'Milk amount',
                value: summary.milkAmount,
                color: const Color(0xff9a5b00),
              ),
            ),
          ],
        ),
        if (summary.pendingDays > 0) ...<Widget>[
          const SizedBox(height: 10),
          AppSurface(
            color: const Color(0xfffff7ed),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.pending_actions_outlined, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${summary.pendingDays} din pending hain. Inka amount '
                    'total me nahi joda gaya. Attendance bharne par hi judega.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ServiceAmountPanel extends StatelessWidget {
  const _ServiceAmountPanel({
    required this.icon,
    required this.label,
    required this.value,
    this.keyName,
    this.monthlyTotal,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String? keyName;
  final double value;
  final double? monthlyTotal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(
                  key: ValueKey<String>('${keyName ?? label}-current'),
                  formatIndianCurrency(value),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (monthlyTotal != null) ...<Widget>[
                  const SizedBox(width: 5),
                  Text(
                    key: ValueKey<String>(
                      '${keyName ?? label}-monthly-total',
                    ),
                    '/ ${formatIndianCurrency(monthlyTotal!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _DailyReport extends StatelessWidget {
  const _DailyReport({
    required this.year,
    required this.month,
    required this.settings,
    required this.entries,
    required this.onEdit,
  });

  final int year;
  final int month;
  final DailyServiceSettings settings;
  final List<DailyServiceAttendance> entries;
  final ValueChanged<DateTime> onEdit;

  @override
  Widget build(BuildContext context) {
    final extraTuitionDates = <int>{
      for (final entry in entries)
        if (entry.date.year == year &&
            entry.date.month == month &&
            entry.tuitionPresent &&
            entry.tuitionExtraConfirmed)
          entry.date.day,
    };
    final byDay = <int, DailyServiceAttendance>{
      for (final entry in entries.where(
        (entry) => entry.date.year == year && entry.date.month == month,
      ))
        entry.date.day: entry,
    };
    final days = DateTime(year, month + 1, 0).day;
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    return AppSurface(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: <Widget>[
            for (var day = 1; day <= days; day++) ...<Widget>[
              if (day > 1) const Divider(),
              Builder(
                builder: (context) {
                  final date = DateTime(year, month, day);
                  final entry = byDay[day];
                  final isFuture = date.isAfter(normalizedToday);
                  final tuitionOffDay = isTuitionOffDay(date, settings);
                  return ListTile(
                    key: ValueKey<String>(
                      'daily-service-${dailyAttendanceId(date)}',
                    ),
                    enabled: !isFuture,
                    onTap: isFuture ? null : () => onEdit(date),
                    onLongPress: entry?.hasRemarks == true
                        ? () => _showRemarks(context, entry!)
                        : null,
                    leading: SizedBox(
                      width: 38,
                      child: _ReportDate(
                        day: day,
                        hasRemarks: entry?.hasRemarks == true,
                        isExtraTuition: extraTuitionDates.contains(day),
                      ),
                    ),
                    title: Text(_weekdayName(date.weekday)),
                    subtitle: isFuture
                        ? const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text('Aage aane wala'),
                          )
                        : entry == null
                        ? _MissingAttendanceIndicators(
                            tuitionOffDay: tuitionOffDay,
                          )
                        : _AttendanceIndicators(
                            entry: entry,
                            tuitionOffDay: tuitionOffDay,
                            extraTuition: extraTuitionDates.contains(day),
                          ),
                    trailing: entry == null
                        ? Icon(
                            isFuture
                                ? Icons.schedule_outlined
                                : Icons.add_circle_outline,
                          )
                        : const Icon(Icons.edit_outlined),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _weekdayName(int weekday) => const <String>[
    'Somvar',
    'Mangalvar',
    'Budhvar',
    'Guruvar',
    'Shukravar',
    'Shanivar',
    'Ravivar',
  ][weekday - 1];

  Future<void> _showRemarks(
    BuildContext context,
    DailyServiceAttendance entry,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: <Widget>[
            const Icon(Icons.notes_outlined, color: Color(0xffc65d00)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Note - ${entry.date.day} ${monthName(entry.date.month)} '
                '${entry.date.year}',
              ),
            ),
          ],
        ),
        content: SelectableText(
          entry.remarks.trim(),
          key: const ValueKey<String>('remarks-read-only-text'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Band karo'),
          ),
        ],
      ),
    );
  }
}

class _ReportDate extends StatelessWidget {
  const _ReportDate({
    required this.day,
    required this.hasRemarks,
    required this.isExtraTuition,
  });

  final int day;
  final bool hasRemarks;
  final bool isExtraTuition;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      '$day',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: hasRemarks || isExtraTuition ? Colors.white : null,
        fontWeight: hasRemarks || isExtraTuition ? FontWeight.w800 : null,
      ),
    );
    if (!hasRemarks && !isExtraTuition) return text;

    return Tooltip(
      message: isExtraTuition
          ? 'Extra paid tuition din'
          : 'Note dekhne ke liye long press karo',
      child: Container(
        key: ValueKey<String>(
          isExtraTuition ? 'extra-tuition-date-$day' : 'remarks-date-$day',
        ),
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isExtraTuition
              ? const Color(0xffa66a00)
              : const Color(0xffc65d00),
          shape: BoxShape.circle,
        ),
        child: text,
      ),
    );
  }
}

class _AttendanceIndicators extends StatelessWidget {
  const _AttendanceIndicators({
    required this.entry,
    required this.tuitionOffDay,
    required this.extraTuition,
  });

  final DailyServiceAttendance? entry;
  final bool tuitionOffDay;
  final bool extraTuition;

  @override
  Widget build(BuildContext context) {
    final attendance = entry;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 5,
        children: <Widget>[
          _AttendanceStatus(
            icon: tuitionOffDay
                ? Icons.event_busy_outlined
                : Icons.school_outlined,
            label: extraTuition
                ? 'Extra tuition'
                : attendance?.tuitionPresent == true
                ? 'Tuition aaya'
                : tuitionOffDay
                ? 'Tuition chhutti'
                : 'Tuition nahi aaya',
            status: extraTuition
                ? _AttendanceStatusType.extra
                : attendance?.tuitionPresent == true
                ? _AttendanceStatusType.present
                : tuitionOffDay
                ? _AttendanceStatusType.off
                : _AttendanceStatusType.absent,
          ),
          if (attendance != null)
            _AttendanceStatus(
              icon: Icons.local_drink_outlined,
              label: attendance.milkReceived
                  ? 'Doodh ${_formatQuantity(attendance.milkQuantityKg)} kg'
                  : 'Doodh nahi aaya',
              status: attendance.milkReceived
                  ? _AttendanceStatusType.present
                  : _AttendanceStatusType.absent,
            ),
        ],
      ),
    );
  }
}

class _MissingAttendanceIndicators extends StatelessWidget {
  const _MissingAttendanceIndicators({required this.tuitionOffDay});

  final bool tuitionOffDay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 5,
        children: <Widget>[
          _AttendanceStatus(
            icon: tuitionOffDay
                ? Icons.event_busy_outlined
                : Icons.pending_actions_outlined,
            label: tuitionOffDay
                ? 'Tuition chhutti - pending'
                : 'Attendance pending',
            status: _AttendanceStatusType.off,
          ),
          const _AttendanceStatus(
            icon: Icons.local_drink_outlined,
            label: 'Doodh pending',
            status: _AttendanceStatusType.off,
          ),
        ],
      ),
    );
  }
}

class _AttendanceStatus extends StatelessWidget {
  const _AttendanceStatus({
    required this.icon,
    required this.label,
    required this.status,
  });

  final IconData icon;
  final String label;
  final _AttendanceStatusType status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      _AttendanceStatusType.present => const Color(0xff176b3a),
      _AttendanceStatusType.absent => Theme.of(context).colorScheme.error,
      _AttendanceStatusType.off => const Color(0xff9a5b00),
      _AttendanceStatusType.extra => const Color(0xffa66a00),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

enum _AttendanceStatusType { present, absent, off, extra }

String _formatQuantity(double value) {
  final text = value.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}
