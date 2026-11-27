import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/assignee.dart';
import '../core/currency.dart';
import '../models/expense_entry.dart';
import '../models/monthly_record.dart';

class DailyServiceReportTotals {
  const DailyServiceReportTotals({
    required this.tuitionAmount,
    required this.milkAmount,
    this.pendingDays = 0,
  });

  final double tuitionAmount;
  final double milkAmount;
  final int pendingDays;

  double get totalAmount => tuitionAmount + milkAmount;
}

class PdfReportService {
  static const String _regularFontAsset = 'assets/fonts/Roboto-Regular.ttf';
  static const String _boldFontAsset = 'assets/fonts/Roboto-Bold.ttf';
  static const PdfColor _primary = PdfColor.fromInt(0xff166534);
  static const PdfColor _primarySoft = PdfColor.fromInt(0xffecfdf3);
  static const PdfColor _ink = PdfColor.fromInt(0xff17211b);
  static const PdfColor _muted = PdfColor.fromInt(0xff5f6b64);
  static const PdfColor _line = PdfColor.fromInt(0xffd6ddd8);
  static const PdfColor _surface = PdfColor.fromInt(0xfff6f8f7);
  static const int _sideBySideRowLimit = 16;

  Future<Uint8List> buildReport(
    MonthlyRecord record, {
    DailyServiceReportTotals? dailyServices,
  }) async {
    final regularFont = pw.Font.ttf(await rootBundle.load(_regularFontAsset));
    final boldFont = pw.Font.ttf(await rootBundle.load(_boldFontAsset));
    final addedPersonExpenses = record.expenses
        .where((expense) => expense.assigneeLabel != defaultAssigneeLabel)
        .toList();
    final addedPersonGroups = _groupByPerson(addedPersonExpenses);
    final addedPersonRowCount =
        addedPersonExpenses.length + addedPersonGroups.length + 2;
    final useSideBySideLayout =
        record.expenses.length <= _sideBySideRowLimit &&
        addedPersonRowCount <= _sideBySideRowLimit;

    final document = pw.Document(
      title: 'Hisaab Book - ${record.label}',
      author: 'Hisaab Book',
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 26, 30, 30),
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        footer: _buildFooter,
        build: (context) => <pw.Widget>[
          _buildHeader(record),
          pw.SizedBox(height: 14),
          _buildSummary(record),
          if (dailyServices != null) ...<pw.Widget>[
            pw.SizedBox(height: 10),
            _buildDailyServicesSummary(dailyServices),
          ],
          pw.SizedBox(height: 18),
          if (useSideBySideLayout)
            _buildSideBySideTables(
              record.expenses,
              addedPersonExpenses,
              addedPersonGroups,
            )
          else ...<pw.Widget>[
            _buildSectionHeading(
              title: 'All expenses',
              meta: '${record.expenses.length} entries',
            ),
            _buildAllExpensesTable(record.expenses),
            pw.SizedBox(height: 18),
            _buildSectionHeading(
              title: 'Added persons',
              meta: '${addedPersonGroups.length} people',
            ),
            _buildAddedPersonsTable(addedPersonExpenses, addedPersonGroups),
          ],
        ],
      ),
    );
    return document.save();
  }

  pw.Widget _buildHeader(MonthlyRecord record) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: <pw.Widget>[
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  'MONTHLY EXPENSE STATEMENT',
                  style: pw.TextStyle(
                    color: _muted,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  record.label.toUpperCase(),
                  style: pw.TextStyle(
                    color: _ink,
                    fontSize: 21,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.Text(
              'HISAAB BOOK',
              style: pw.TextStyle(
                color: _primary,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 9),
        pw.Container(height: 2, color: _primary),
      ],
    );
  }

  pw.Widget _buildSummary(MonthlyRecord record) {
    final balance = record.totalIncome - record.totalExpenses;
    final incomeDetails = record.incomes
        .map(
          (income) =>
              '${income.name}: ${formatIndianCurrencyForPdf(income.amount)}',
        )
        .join('  |  ');

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: pw.BoxDecoration(
        color: _surface,
        border: pw.Border.all(color: _line, width: 0.7),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Expanded(
            flex: 2,
            child: _buildSummaryValue(
              label: 'TOTAL INCOME',
              value: formatIndianCurrencyForPdf(record.totalIncome),
              detail: incomeDetails.isEmpty
                  ? 'No income sources'
                  : incomeDetails,
            ),
          ),
          _buildSummaryDivider(),
          pw.Expanded(
            child: _buildSummaryValue(
              label: 'TOTAL EXPENSES',
              value: formatIndianCurrencyForPdf(record.totalExpenses),
            ),
          ),
          _buildSummaryDivider(),
          pw.Expanded(
            child: _buildSummaryValue(
              label: 'BALANCE',
              value: formatIndianCurrencyForPdf(balance),
              valueColor: balance < 0 ? PdfColors.red700 : _primary,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryValue({
    required String label,
    required String value,
    String? detail,
    PdfColor valueColor = _ink,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(
          label,
          style: pw.TextStyle(
            color: _muted,
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: valueColor,
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        if (detail != null) ...<pw.Widget>[
          pw.SizedBox(height: 4),
          pw.Text(
            detail,
            style: const pw.TextStyle(color: _muted, fontSize: 7.5),
          ),
        ],
      ],
    );
  }

  pw.Widget _buildSummaryDivider() {
    return pw.Container(
      width: 1,
      height: 42,
      margin: const pw.EdgeInsets.symmetric(horizontal: 12),
      color: _line,
    );
  }

  pw.Widget _buildDailyServicesSummary(DailyServiceReportTotals totals) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _line, width: 0.7),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Row(
            children: <pw.Widget>[
              pw.Text(
                'TUITION & MILK',
                style: pw.TextStyle(
                  color: _muted,
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(width: 12),
              if (totals.pendingDays > 0)
                pw.Text(
                  '${totals.pendingDays} din pending - total me nahi joda',
                  style: const pw.TextStyle(color: _muted, fontSize: 7),
                ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: <pw.Widget>[
              pw.Expanded(
                child: _buildSummaryValue(
                  label: 'TUITION',
                  value: formatIndianCurrencyForPdf(totals.tuitionAmount),
                ),
              ),
              _buildSummaryDivider(),
              pw.Expanded(
                child: _buildSummaryValue(
                  label: 'MILK',
                  value: formatIndianCurrencyForPdf(totals.milkAmount),
                ),
              ),
              _buildSummaryDivider(),
              pw.Expanded(
                child: _buildSummaryValue(
                  label: 'NET TOTAL',
                  value: formatIndianCurrencyForPdf(totals.totalAmount),
                  valueColor: _primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSideBySideTables(
    List<ExpenseEntry> expenses,
    List<ExpenseEntry> addedPersonExpenses,
    Map<String, List<ExpenseEntry>> groups,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Expanded(
          child: pw.Column(
            children: <pw.Widget>[
              _buildSectionHeading(
                title: 'All expenses',
                meta: '${expenses.length} entries',
              ),
              _buildAllExpensesTable(expenses),
            ],
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: pw.Column(
            children: <pw.Widget>[
              _buildSectionHeading(
                title: 'Added persons',
                meta: '${groups.length} people',
              ),
              _buildAddedPersonsTable(addedPersonExpenses, groups),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSectionHeading({
    required String title,
    required String meta,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(9, 7, 9, 7),
      decoration: const pw.BoxDecoration(
        color: _surface,
        border: pw.Border(
          left: pw.BorderSide(color: _primary, width: 3),
          top: pw.BorderSide(color: _line, width: 0.6),
          right: pw.BorderSide(color: _line, width: 0.6),
          bottom: pw.BorderSide(color: _line, width: 0.6),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(
            title,
            style: pw.TextStyle(
              color: _ink,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            meta,
            style: const pw.TextStyle(color: _muted, fontSize: 7.5),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildAllExpensesTable(List<ExpenseEntry> expenses) {
    final rows = <pw.TableRow>[
      _tableHeader(const <String>['Expense', 'Amount']),
      if (expenses.isEmpty)
        _tableRow(const <String>['No expenses recorded', ''], muted: true)
      else
        for (final entry in expenses.asMap().entries)
          _tableRow(<String>[
            entry.value.name,
            formatIndianCurrencyForPdf(entry.value.amount),
          ], shaded: entry.key.isOdd),
      _totalRow(
        label: 'Total expenses',
        amount: expenses.fold<double>(
          0,
          (total, expense) => total + expense.amount,
        ),
      ),
    ];
    return _buildTable(
      rows: rows,
      widths: const <int, pw.TableColumnWidth>{
        0: pw.FlexColumnWidth(2.8),
        1: pw.FlexColumnWidth(1.4),
      },
    );
  }

  pw.Widget _buildAddedPersonsTable(
    List<ExpenseEntry> expenses,
    Map<String, List<ExpenseEntry>> groups,
  ) {
    final multiplePeople = groups.length > 1;
    var rowIndex = 0;
    final rows = <pw.TableRow>[
      _tableHeader(const <String>['Person', 'Expense', 'Amount']),
      if (expenses.isEmpty)
        _tableRow(const <String>['', 'No assigned expenses', ''], muted: true)
      else
        for (final group in groups.entries) ...<pw.TableRow>[
          for (final expense in group.value)
            _tableRow(<String>[
              expense == group.value.first ? group.key : '',
              expense.name,
              formatIndianCurrencyForPdf(expense.amount),
            ], shaded: (rowIndex++).isOdd),
          _subtotalRow(
            label: '${group.key} total',
            amount: group.value.fold<double>(
              0,
              (total, expense) => total + expense.amount,
            ),
          ),
        ],
      if (multiplePeople)
        _totalRow(
          label: 'Assigned total',
          amount: expenses.fold<double>(
            0,
            (total, expense) => total + expense.amount,
          ),
          columnCount: 3,
        ),
    ];
    return _buildTable(
      rows: rows,
      widths: const <int, pw.TableColumnWidth>{
        0: pw.FlexColumnWidth(1.35),
        1: pw.FlexColumnWidth(1.9),
        2: pw.FlexColumnWidth(1.35),
      },
    );
  }

  pw.Widget _buildTable({
    required List<pw.TableRow> rows,
    required Map<int, pw.TableColumnWidth> widths,
  }) {
    return pw.Table(
      border: const pw.TableBorder(
        left: pw.BorderSide(color: _line, width: 0.6),
        right: pw.BorderSide(color: _line, width: 0.6),
        bottom: pw.BorderSide(color: _line, width: 0.6),
        horizontalInside: pw.BorderSide(color: _line, width: 0.45),
        verticalInside: pw.BorderSide(color: _line, width: 0.45),
      ),
      columnWidths: widths,
      children: rows,
    );
  }

  pw.TableRow _tableHeader(List<String> values) {
    return pw.TableRow(
      repeat: true,
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: values
          .asMap()
          .entries
          .map(
            (entry) => _tableCell(
              entry.value,
              bold: true,
              color: _ink,
              alignRight: entry.key == values.length - 1,
            ),
          )
          .toList(),
    );
  }

  pw.TableRow _tableRow(
    List<String> values, {
    bool shaded = false,
    bool muted = false,
  }) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: shaded ? _surface : PdfColors.white),
      children: values
          .asMap()
          .entries
          .map(
            (entry) => _tableCell(
              entry.value,
              color: muted ? _muted : _ink,
              alignRight: entry.key == values.length - 1,
            ),
          )
          .toList(),
    );
  }

  pw.TableRow _subtotalRow({required String label, required double amount}) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: _surface),
      children: <pw.Widget>[
        _tableCell(''),
        _tableCell(label, bold: true),
        _tableCell(
          formatIndianCurrencyForPdf(amount),
          bold: true,
          alignRight: true,
        ),
      ],
    );
  }

  pw.TableRow _totalRow({
    required String label,
    required double amount,
    int columnCount = 2,
  }) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: _primarySoft),
      children: <pw.Widget>[
        if (columnCount == 3) _tableCell(''),
        _tableCell(label, bold: true, color: _primary),
        _tableCell(
          formatIndianCurrencyForPdf(amount),
          bold: true,
          color: _primary,
          alignRight: true,
        ),
      ],
    );
  }

  pw.Widget _tableCell(
    String text, {
    bool bold = false,
    bool alignRight = false,
    PdfColor color = _ink,
  }) {
    return pw.Container(
      alignment: alignRight
          ? pw.Alignment.centerRight
          : pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5.5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  Map<String, List<ExpenseEntry>> _groupByPerson(List<ExpenseEntry> expenses) {
    final groups = <String, List<ExpenseEntry>>{};
    for (final expense in expenses) {
      groups
          .putIfAbsent(expense.assigneeLabel, () => <ExpenseEntry>[])
          .add(expense);
    }
    final sortedGroups = groups.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    return <String, List<ExpenseEntry>>{
      for (final group in sortedGroups) group.key: group.value,
    };
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 7),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _line, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(
            'Hisaab Book monthly statement',
            style: const pw.TextStyle(color: _muted, fontSize: 7),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(color: _muted, fontSize: 7),
          ),
        ],
      ),
    );
  }

  Future<void> previewAndPrint(
    MonthlyRecord record, {
    DailyServiceReportTotals? dailyServices,
  }) async {
    final bytes = await buildReport(record, dailyServices: dailyServices);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> share(
    MonthlyRecord record, {
    DailyServiceReportTotals? dailyServices,
  }) async {
    final bytes = await buildReport(record, dailyServices: dailyServices);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${record.id}-hisaab-book.pdf',
    );
  }

  /// Opens the Android share/save sheet so the PDF can be saved to Downloads
  /// or any other public location instead of a private app folder.
  Future<String> download(
    MonthlyRecord record, {
    DailyServiceReportTotals? dailyServices,
  }) async {
    final filename = '${record.id}-hisaab-book.pdf';
    final bytes = await buildReport(record, dailyServices: dailyServices);
    await Printing.sharePdf(bytes: bytes, filename: filename);
    return filename;
  }
}
