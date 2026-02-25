import 'dart:convert';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../../domain/entities/meeting.dart';

class PdfExportService {
  List<String> _parseList(String text) {
    if (text.isEmpty) return [];

    final trimmed = text.trim();

    // Handle JSON array format: ["item1", "item2"]
    if (trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (e) {
        // Try to clean and retry
        try {
          final cleaned = trimmed.replaceAll(RegExp(r'[\[\]"]'), '');
          if (cleaned.contains(',')) {
            return cleaned
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
          }
          return cleaned
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        } catch (_) {}
      }
    }

    // Try comma-separated
    if (trimmed.contains(',')) {
      return trimmed
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  Future<pw.Document> generateMeetingPdf(Meeting meeting) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          _buildHeader(meeting),
          if (meeting.summary != null && meeting.summary!.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            _buildSection('Summary', meeting.summary!),
          ],
          if (meeting.keyTakeaways != null &&
              meeting.keyTakeaways!.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _buildListSection(
              'Key Takeaways',
              _parseList(meeting.keyTakeaways!),
            ),
          ],
          if (meeting.actionItems.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _buildActionItems(meeting.actionItems),
          ],
          if (meeting.decisions != null && meeting.decisions!.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _buildListSection('Decisions Made', _parseList(meeting.decisions!)),
          ],
          if (meeting.suggestions != null &&
              meeting.suggestions!.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _buildListSection('Suggestions', _parseList(meeting.suggestions!)),
          ],
          if (meeting.dates.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _buildDates(meeting.dates),
          ],
          if (meeting.participants != null &&
              meeting.participants!.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _buildListSection(
              'Participants',
              _parseList(meeting.participants!),
            ),
          ],
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _buildHeader(Meeting meeting) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          meeting.title ?? 'Meeting Notes',
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey900,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          _formatDate(meeting.createdAt) +
              (meeting.durationSeconds != null && meeting.durationSeconds! > 0
                  ? ' | Duration: ${_formatDuration(meeting.durationSeconds!)}'
                  : ''),
          style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
        ),
        if (meeting.tagline != null && meeting.tagline!.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text(
            meeting.tagline!,
            style: pw.TextStyle(
              fontSize: 12,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey700,
            ),
          ),
        ],
        pw.SizedBox(height: 12),
        pw.Divider(color: PdfColors.grey300, thickness: 1),
      ],
    );
  }

  pw.Widget _buildSection(String title, String content) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          content,
          style: pw.TextStyle(
            fontSize: 11,
            color: PdfColors.grey800,
            lineSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildListSection(String title, List<String> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.SizedBox(height: 8),
        ...items.map(
          (item) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 4,
                  height: 4,
                  margin: const pw.EdgeInsets.only(top: 5, right: 8),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey600,
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    item,
                    style: pw.TextStyle(fontSize: 11, color: PdfColors.grey800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildActionItems(List<ActionItem> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Action Items',
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.SizedBox(height: 8),
        ...items.map(
          (item) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 14,
                  height: 14,
                  margin: const pw.EdgeInsets.only(right: 8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: item.isCompleted
                          ? PdfColors.green600
                          : PdfColors.grey400,
                      width: 1.5,
                    ),
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: item.isCompleted
                      ? pw.Center(
                          child: pw.Text(
                            'x',
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.green600,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                ),
                pw.Expanded(
                  child: pw.Text(
                    item.text,
                    style: pw.TextStyle(
                      fontSize: 11,
                      color: item.isCompleted
                          ? PdfColors.grey500
                          : PdfColors.grey800,
                      decoration: item.isCompleted
                          ? pw.TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildDates(List<MeetingDate> dates) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Important Dates',
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.SizedBox(height: 8),
        ...dates.map(
          (date) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    '${date.dateTime.day}/${date.dateTime.month}/${date.dateTime.year}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        date.title,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                      if (date.description != null &&
                          date.description!.isNotEmpty)
                        pw.Text(
                          date.description!,
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (mins > 0) {
      return '${mins}m ${secs}s';
    }
    return '${secs}s';
  }

  Future<void> sharePdf(Meeting meeting) async {
    final pdf = await generateMeetingPdf(meeting);
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${(meeting.title ?? 'meeting').replaceAll(' ', '_')}.pdf',
    );
  }

  Future<void> printPdf(Meeting meeting) async {
    final pdf = await generateMeetingPdf(meeting);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<String> savePdf(Meeting meeting) async {
    final pdf = await generateMeetingPdf(meeting);
    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        '${(meeting.title ?? 'meeting').replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }
}
