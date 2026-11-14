import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:convert';
import '../../utils/pdf_check.dart';

class ReportPdfService {
  static final _blue = PdfColor.fromHex('005CAB');
  static final _lightBlue = PdfColor.fromHex('EAF2FA');
  static const _border = PdfColors.grey400;

  /// [report] keys used: category, customerName, technicianName, address,
  /// createdAt, submittedAt, issueSummary, stepsTaken, resolutionSummary,
  /// technicianNotes, supervisorComments, proofUrl, technicianSignature,
  /// technicianSignedAt, supervisorSignature, supervisorName, signedAt
  static Future<void> export({
    required String ticketId,
    required Map<String, dynamic> report,
  }) async {
    String field(String key) {
      final v = (report[key] ?? '').toString().trim();
      return v.isEmpty ? '-' : v;
    }

    final proofUrl = (report['proofUrl'] ?? '').toString();
    pw.ImageProvider? proofImage;
    if (proofUrl.isNotEmpty && !proofUrl.toLowerCase().endsWith('.pdf')) {
      try {
        // A slow or broken link must not hold the export up for long.
        proofImage = await networkImage(
          proofUrl,
        ).timeout(const Duration(seconds: 15));
      } catch (_) {
        proofImage = null;
      }
    }

    pw.ImageProvider? sigImage;
    final sigB64 = (report['supervisorSignature'] ?? '').toString();
    if (sigB64.isNotEmpty) {
      try {
        sigImage = pw.MemoryImage(base64Decode(sigB64));
      } catch (_) {
        sigImage = null;
      }
    }

    pw.ImageProvider? techSigImage;
    final techSigB64 = (report['technicianSignature'] ?? '').toString();
    if (techSigB64.isNotEmpty) {
      try {
        techSigImage = pw.MemoryImage(base64Decode(techSigB64));
      } catch (_) {
        techSigImage = null;
      }
    }

    final steps = (report['stepsTaken'] ?? '')
        .toString()
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .map((l) {
          final line = l.trim();
          final done = line.startsWith('✓');
          final title = (line.startsWith('✓') || line.startsWith('✗'))
              ? line.substring(1).trim()
              : line;
          return MapEntry(title, done);
        })
        .toList();

    final notes = (report['technicianNotes'] ?? '').toString().trim();
    final supervisorComments = (report['supervisorComments'] ?? '')
        .toString()
        .trim();

    final shortId = ticketId.length >= 8
        ? ticketId.substring(0, 8).toUpperCase()
        : ticketId.toUpperCase();
    final reportNo = 'SR-$shortId';
    final reportDate = _date(
      report['submittedAt'] is Timestamp
          ? report['submittedAt'] as Timestamp
          : Timestamp.now(),
    );

    int n = 0;
    String num(String t) => '${++n}. $t';

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        // A long report may need many pages; the default limit is 20.
        maxPages: 200,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 40),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _border, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'TM Assist - Service Report $reportNo',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
        build: (ctx) => [
          // Letterhead
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'TM ASSIST',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: _blue,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Technical Service Report',
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Report No: $reportNo',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Date: $reportDate',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(height: 2, color: _blue),
          pw.SizedBox(height: 18),

          // Ticket details
          _heading(num('TICKET DETAILS')),
          pw.Table(
            border: pw.TableBorder.all(color: _border, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.2),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(1.2),
              3: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                children: [
                  _labelCell('Ticket ID'),
                  _valueCell(ticketId),
                  _labelCell('Category'),
                  _valueCell(field('category')),
                ],
              ),
              pw.TableRow(
                children: [
                  _labelCell('Customer'),
                  _valueCell(field('customerName')),
                  _labelCell('Technician'),
                  _valueCell(field('technicianName')),
                ],
              ),
              pw.TableRow(
                children: [
                  _labelCell('Address'),
                  _valueCell(field('address')),
                  _labelCell('Ticket Created'),
                  _valueCell(
                    report['createdAt'] is Timestamp
                        ? _date(report['createdAt'] as Timestamp)
                        : '-',
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 18),

          _heading(num('ISSUE SUMMARY')),
          _body(field('issueSummary')),
          pw.SizedBox(height: 18),

          _heading(num('TROUBLESHOOTING STEPS')),
          if (steps.isEmpty)
            _body('No steps recorded.')
          else
            pw.Table(
              border: pw.TableBorder.all(color: _border, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(28),
                1: pw.FlexColumnWidth(4),
                2: pw.FixedColumnWidth(62),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: _lightBlue),
                  children: [
                    _valueCell('#', bold: true),
                    _valueCell('Step', bold: true),
                    _valueCell('Status', bold: true),
                  ],
                ),
                ...steps.asMap().entries.map((e) {
                  final done = e.value.value;
                  return pw.TableRow(
                    children: [
                      _valueCell('${e.key + 1}'),
                      _valueCell(e.value.key),
                      _valueCell(
                        done ? 'Done' : 'Not done',
                        bold: true,
                        color: done
                            ? PdfColor.fromHex('2E7D32')
                            : PdfColor.fromHex('C62828'),
                      ),
                    ],
                  );
                }),
              ],
            ),
          pw.SizedBox(height: 18),

          _heading(num('RESOLUTION SUMMARY')),
          _body(field('resolutionSummary')),
          pw.SizedBox(height: 18),

          _heading(num('TECHNICIAN NOTES')),
          _body(notes.isEmpty ? 'No additional notes.' : notes),
          pw.SizedBox(height: 18),

          if (proofUrl.isNotEmpty) ...[
            _heading(num('PROOF OF COMPLETION')),
            proofImage != null
                ? pw.Container(
                    height: 240,
                    alignment: pw.Alignment.centerLeft,
                    padding: const pw.EdgeInsets.all(4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _border, width: 0.5),
                    ),
                    child: pw.Image(proofImage, fit: pw.BoxFit.contain),
                  )
                : _body('Proof file attached (could not be embedded).'),
            pw.SizedBox(height: 18),
          ],

          if (supervisorComments.isNotEmpty) ...[
            _heading(num('SUPERVISOR COMMENTS')),
            _body(supervisorComments),
            pw.SizedBox(height: 18),
          ],

          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _signBox(
                  'Prepared by (Technician)',
                  field('technicianName') == '-' ? '' : field('technicianName'),
                  report['technicianSignedAt'] is Timestamp
                      ? _date(report['technicianSignedAt'] as Timestamp)
                      : reportDate,
                  signature: techSigImage,
                ),
              ),
              pw.SizedBox(width: 24),
              pw.Expanded(
                child: _signBox(
                  'Reviewed by (Supervisor)',
                  (report['supervisorName'] ?? '').toString(),
                  report['signedAt'] is Timestamp
                      ? _date(report['signedAt'] as Timestamp)
                      : '',
                  signature: sigImage,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // Share a real .pdf file (a normal share sheet) instead of the phone's own
    // print service, which saved broken files on some Xiaomi phones.
    final bytes = await pdf.save();
    if (!isValidPdfBytes(bytes)) {
      // The callers' catch shows "Could not export the PDF. Please try again."
      throw StateError('The PDF was not created correctly.');
    }
    await Printing.sharePdf(bytes: bytes, filename: _fileName(reportNo));
  }

  /// A file name made only of letters, digits, dot, dash and underscore.
  static String _fileName(String reportNo) {
    final safe = reportNo.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return 'Service-Report-$safe.pdf';
  }

  /// Text that the PDF's built-in font can draw. That font covers Latin-1
  /// only, so common punctuation is replaced by its plain form, control
  /// characters are dropped and any other character becomes "?" instead of
  /// breaking the page. Very long unbroken words are split so they wrap, and
  /// [maxLength] cuts text that sits in a table cell (a row cannot be split
  /// across pages).
  static String _safe(String text, {int? maxLength}) {
    var out = text
        .replaceAll(RegExp('[\u2018\u2019\u201A]'), "'")
        .replaceAll(RegExp('[\u201C\u201D\u201E]'), '"')
        .replaceAll(RegExp('[\u2013\u2014]'), '-')
        .replaceAll('\u2026', '...')
        .replaceAll('\u2022', '-')
        .replaceAll('\t', ' ')
        .replaceAll(RegExp('[\u200B-\u200D\uFEFF]'), '');

    final buffer = StringBuffer();
    for (final unit in out.runes) {
      if (unit == 10) {
        buffer.writeCharCode(unit);
      } else if (unit < 32 || unit == 127) {
        continue;
      } else if (unit > 255) {
        buffer.write('?');
      } else {
        buffer.writeCharCode(unit);
      }
    }
    out = buffer.toString();

    out = out.replaceAllMapped(RegExp(r'\S{40,}'), (m) {
      final word = m.group(0)!;
      return [
        for (var i = 0; i < word.length; i += 40)
          word.substring(i, i + 40 > word.length ? word.length : i + 40),
      ].join(' ');
    });

    if (maxLength != null && out.length > maxLength) {
      out = '${out.substring(0, maxLength)}...';
    }
    return out;
  }

  static String _date(Timestamp t) {
    final d = t.toDate();
    return '${d.day}/${d.month}/${d.year}';
  }

  static pw.Widget _heading(String text) => pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(bottom: 8),
    padding: const pw.EdgeInsets.only(bottom: 3),
    decoration: pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _blue, width: 1)),
    ),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: _blue,
      ),
    ),
  );

  static pw.Widget _body(String text) => pw.Text(
    _safe(text),
    style: const pw.TextStyle(
      fontSize: 10.5,
      lineSpacing: 3,
      color: PdfColors.grey900,
    ),
  );

  static pw.Widget _labelCell(String text) => pw.Container(
    color: _lightBlue,
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(
      _safe(text, maxLength: 400),
      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
    ),
  );

  static pw.Widget _valueCell(
    String text, {
    bool bold = false,
    PdfColor? color,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(
      _safe(text, maxLength: 400),
      style: pw.TextStyle(
        fontSize: 9.5,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color ?? PdfColors.grey900,
      ),
    ),
  );

  static pw.Widget _signBox(
    String role,
    String name,
    String date, {
    pw.ImageProvider? signature,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        role,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 6),
      pw.Container(
        height: 40,
        alignment: pw.Alignment.bottomLeft,
        child: signature != null
            ? pw.Image(signature, fit: pw.BoxFit.contain)
            : pw.SizedBox(),
      ),
      pw.Container(height: 0.8, color: PdfColors.grey700),
      pw.SizedBox(height: 4),
      pw.Text(
        name.isEmpty ? 'Name:' : 'Name: ${_safe(name, maxLength: 80)}',
        style: const pw.TextStyle(fontSize: 9),
      ),
      pw.Text(
        date.isEmpty ? 'Date:' : 'Date: $date',
        style: const pw.TextStyle(fontSize: 9),
      ),
    ],
  );
}
