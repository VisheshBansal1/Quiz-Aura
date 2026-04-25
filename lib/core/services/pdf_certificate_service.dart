import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

/// Generates and shares a PDF certificate for quiz/tournament completion.
/// Uses the `pdf` + `printing` packages — no server needed.
class PdfCertificateService {
  /// Generate and share a certificate PDF.
  static Future<void> generateAndShare({
    required String userName,
    required String achievement,  // e.g., "Completed DSA Quiz with 92%"
    required String quizTitle,
    required DateTime date,
    required double score,
  }) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd MMMM yyyy').format(date);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // ── Outer border ──────────────────────────────────────────────
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.teal,
                    width: 8,
                  ),
                  borderRadius: pw.BorderRadius.circular(12),
                ),
              ),

              // ── Inner border ──────────────────────────────────────────────
              pw.Positioned(
                left: 12,
                right: 12,
                top: 12,
                bottom: 12,
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: PdfColors.teal300,
                      width: 2,
                    ),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                ),
              ),

              // ── Content ───────────────────────────────────────────────────
              pw.Center(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      'CERTIFICATE OF ACHIEVEMENT',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal,
                        letterSpacing: 3,
                      ),
                    ),

                    pw.SizedBox(height: 8),

                    pw.Container(
                      width: 200,
                      height: 2,
                      color: PdfColors.teal300,
                    ),

                    pw.SizedBox(height: 24),

                    pw.Text(
                      'This is to certify that',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey700,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),

                    pw.SizedBox(height: 16),

                    pw.Text(
                      userName,
                      style: pw.TextStyle(
                        fontSize: 36,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey900,
                      ),
                    ),

                    pw.SizedBox(height: 16),

                    pw.Text(
                      'has successfully completed',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey700,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),

                    pw.SizedBox(height: 12),

                    pw.Text(
                      quizTitle,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal800,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),

                    pw.SizedBox(height: 8),

                    pw.Text(
                      'with a score of ${score.toStringAsFixed(1)}%',
                      style: pw.TextStyle(
                        fontSize: 18,
                        color: PdfColors.grey800,
                      ),
                    ),

                    pw.SizedBox(height: 32),

                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        pw.Column(
                          children: [
                            pw.Text(
                              dateStr,
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Container(
                              width: 120,
                              height: 1,
                              color: PdfColors.grey400,
                              margin: const pw.EdgeInsets.only(top: 4),
                            ),
                            pw.Text(
                              'Date',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey600,
                              ),
                            ),
                          ],
                        ),
                        pw.Column(
                          children: [
                            pw.Text(
                              'QuizAura',
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.teal,
                              ),
                            ),
                            pw.Container(
                              width: 120,
                              height: 1,
                              color: PdfColors.grey400,
                              margin: const pw.EdgeInsets.only(top: 4),
                            ),
                            pw.Text(
                              'Platform',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 24),

                    pw.Text(
                      'College Competitive Quiz Platform',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey500,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'QuizAura_Certificate_$userName.pdf',
    );
  }
}
