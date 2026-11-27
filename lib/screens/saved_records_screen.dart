import 'package:flutter/material.dart';

import '../core/user_error.dart';
import '../domain/daily_service_logic.dart';
import '../models/monthly_record.dart';
import '../repositories/ledger_repository.dart';
import '../services/daily_service_settings_resolver.dart';
import '../services/pdf_report_service.dart';
import '../widgets/app_shell.dart';
import 'monthly_record_screen.dart';

class SavedRecordsScreen extends StatefulWidget {
  const SavedRecordsScreen({
    required this.repository,
    required this.pdfReportService,
    super.key,
  });

  final LedgerRepository repository;
  final PdfReportService pdfReportService;

  @override
  State<SavedRecordsScreen> createState() => _SavedRecordsScreenState();
}

class _SavedRecordsScreenState extends State<SavedRecordsScreen> {
  bool _loading = true;
  bool _pdfBusy = false;
  bool _deleting = false;
  String? _error;
  String? _selectedId;
  List<MonthlyRecord> _records = <MonthlyRecord>[];

  MonthlyRecord? get _selectedRecord {
    final id = _selectedId;
    if (id == null) return null;
    for (final record in _records) {
      if (record.id == id) return record;
    }
    return null;
  }

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
      final records = await widget.repository.listMonthlyRecords();
      if (!mounted) return;
      setState(() {
        _records = records;
        if (!_records.any((record) => record.id == _selectedId)) {
          _selectedId = _records.isEmpty ? null : _records.last.id;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(
          error,
          fallback: 'Saved records load nahi hue. Phir koshish karo.',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openSelected() async {
    final record = _selectedRecord;
    if (record == null) {
      _showMessage('Pehle koi saved record chuno.');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MonthlyRecordScreen(
          repository: widget.repository,
          initialRecord: record,
          viewOnly: true,
        ),
      ),
    );
    await _load();
  }

  Future<DailyServiceReportTotals?> _loadDailyTotals(
    MonthlyRecord record,
  ) async {
    final settings = await resolveDailyServiceMonthSettings(
      repository: widget.repository,
      year: record.year,
      month: record.month,
    );
    if (settings == null) return null;
    final entries = await widget.repository.listDailyServiceAttendance(
      record.year,
      record.month,
    );
    final summary = summarizeDailyServices(
      entries,
      year: record.year,
      month: record.month,
      settings: settings,
    );
    return DailyServiceReportTotals(
      tuitionAmount: summary.tuitionAmount,
      milkAmount: summary.milkAmount,
      pendingDays: summary.pendingDays,
    );
  }

  Future<void> _runPdf(
    Future<void> Function(
      MonthlyRecord record,
      DailyServiceReportTotals? totals,
    )
    action,
  ) async {
    if (_pdfBusy) return;
    final record = _selectedRecord;
    if (record == null) {
      _showMessage('Pehle koi saved record chuno.');
      return;
    }
    setState(() => _pdfBusy = true);
    try {
      final totals = await _loadDailyTotals(record);
      await action(record, totals);
    } catch (error) {
      _showMessage(
        friendlyError(
          error,
          fallback: 'PDF banane me dikkat aayi. Phir koshish karo.',
        ),
      );
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  Future<void> _deleteSelected() async {
    if (_deleting || _pdfBusy) return;
    final record = _selectedRecord;
    if (record == null) {
      _showMessage('Pehle koi saved record chuno.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ye record delete karna hai?'),
        content: Text(
          '${record.label} ka poora record hat jayega. Ye wapas nahi aayega.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete karo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await widget.repository.deleteMonthlyRecord(record.id);
      if (!mounted) return;
      _showMessage('${record.label} ka record delete ho gaya.');
      setState(() => _selectedId = null);
      await _load();
    } catch (error) {
      _showMessage(
        friendlyError(
          error,
          fallback: 'Record delete nahi hua. Phir koshish karo.',
        ),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purane record'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Naya load karo',
            onPressed: _loading || _pdfBusy || _deleting ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const AppLoadingView(label: 'Purane record load ho rahe hain...')
          : _error != null
          ? AppStatusView(
              icon: Icons.cloud_off_outlined,
              title: 'Record load nahi hue',
              message: _error,
              action: OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Phir koshish karo'),
              ),
            )
          : _records.isEmpty
          ? const AppStatusView(
              icon: Icons.folder_open_outlined,
              title: 'Koi saved record nahi',
              message: 'Jo mahina save karoge wahan yahan dikhega.',
            )
          : SafeArea(
              child: AppContent(
                maxWidth: 720,
                child: ListView(
                  children: <Widget>[
                    const AppSectionHeader(
                      title: 'Record chuno',
                      subtitle:
                          'Purana mahina dekho, delete karo ya PDF banao.',
                    ),
                    const SizedBox(height: 14),
                    AppSurface(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          DropdownButtonFormField<String>(
                            initialValue: _selectedId,
                            decoration: const InputDecoration(
                              labelText: 'Purana mahina',
                              prefixIcon: Icon(Icons.event_note_outlined),
                            ),
                            items: _records
                                .map(
                                  (record) => DropdownMenuItem<String>(
                                    value: record.id,
                                    child: Text(record.label),
                                  ),
                                )
                                .toList(),
                            onChanged: _pdfBusy || _deleting
                                ? null
                                : (value) =>
                                      setState(() => _selectedId = value),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _openSelected,
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('Record dekho'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _deleting ? null : _deleteSelected,
                            icon: _deleting
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.delete_outline),
                            label: const Text('Record delete karo'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppSurface(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const AppSectionHeader(
                            title: 'PDF report',
                            subtitle:
                                'Dekho, print karo, share karo ya Downloads '
                                'me save karo.',
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _pdfBusy
                                ? null
                                : () => _runPdf(
                                    (record, totals) =>
                                        widget.pdfReportService.previewAndPrint(
                                          record,
                                          dailyServices: totals,
                                        ),
                                  ),
                            icon: const Icon(Icons.print_outlined),
                            label: const Text('PDF dekho ya print karo'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _pdfBusy
                                ? null
                                : () => _runPdf(
                                    (record, totals) =>
                                        widget.pdfReportService.share(
                                          record,
                                          dailyServices: totals,
                                        ),
                                  ),
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('PDF share karo'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _pdfBusy
                                ? null
                                : () => _runPdf((record, totals) async {
                                    final name = await widget.pdfReportService
                                        .download(
                                          record,
                                          dailyServices: totals,
                                        );
                                    _showMessage(
                                      'PDF ready hai ($name). Share sheet me '
                                      'Downloads ya Files chuno.',
                                    );
                                  }),
                            icon: _pdfBusy
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.download_outlined),
                            label: Text(
                              _pdfBusy
                                  ? 'PDF taiyar ho raha hai...'
                                  : 'PDF save karo',
                            ),
                          ),
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
