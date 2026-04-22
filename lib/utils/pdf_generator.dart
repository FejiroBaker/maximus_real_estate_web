// lib/utils/pdf_generator.dart
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/property_model.dart';

class PDFGenerator {
  static Future<File> generatePropertyReport(
      List<PropertyModel> properties) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('MMMM dd, yyyy');
    final currencyFormat =
        NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    // Calculate statistics
    final totalProperties = properties.length;
    final activeProperties =
        properties.where((p) => p.status == 'active').length;
    final soldProperties =
        properties.where((p) => p.status == 'sold').length;
    final totalValue =
        properties.fold<double>(0, (sum, p) => sum + p.price);
    final avgPrice =
        totalProperties > 0 ? totalValue / totalProperties : 0.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // ── Header ────────────────────────────────────────────────────
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Maximus Real Estate',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue700,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Property Portfolio Report',
                  style: pw.TextStyle(
                      fontSize: 18, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Generated on ${dateFormat.format(DateTime.now())}',
                  style: pw.TextStyle(
                      fontSize: 12, color: PdfColors.grey600),
                ),
                pw.Divider(thickness: 2, color: PdfColors.blue700),
              ],
            ),

            pw.SizedBox(height: 20),

            // ── Summary ───────────────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Portfolio Summary',
                    style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment:
                        pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem(
                          'Total Properties',
                          totalProperties.toString()),
                      _buildStatItem(
                          'Active', activeProperties.toString()),
                      _buildStatItem(
                          'Sold', soldProperties.toString()),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment:
                        pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem('Total Value',
                          currencyFormat.format(totalValue)),
                      _buildStatItem('Average Price',
                          currencyFormat.format(avgPrice)),
                      _buildStatItem('', ''),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // ── Table header ──────────────────────────────────────────────
            pw.Text(
              'Property Listings',
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),

            // ── Table ─────────────────────────────────────────────────────
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300),
                  children: [
                    _buildTableCell('Property', isHeader: true),
                    _buildTableCell('Location', isHeader: true),
                    _buildTableCell('Price', isHeader: true),
                    _buildTableCell('Type', isHeader: true),
                    _buildTableCell('Status', isHeader: true),
                  ],
                ),
                // Data rows
                ...properties.map((p) => pw.TableRow(
                      children: [
                        _buildTableCell(p.title),
                        _buildTableCell(
                            '${p.location.city}, ${p.location.state}'),
                        _buildTableCell(
                            currencyFormat.format(p.price)),
                        _buildTableCell(p.type.toUpperCase()),
                        _buildTableCell(p.status.toUpperCase()),
                      ],
                    )),
              ],
            ),
          ];
        },
      ),
    );

    // ── Save to temp directory ────────────────────────────────────────────
    // Use getTemporaryDirectory() — it's faster than Documents on some
    // devices and avoids permission issues that cause infinite hangs.
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/property_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(path);
    final bytes = await pdf.save();
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<File> generatePropertyDetails(
      PropertyModel property) async {
    final pdf = pw.Document();
    final currencyFormat =
        NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // ── Property header ───────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    property.title,
                    style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    currencyFormat.format(property.price),
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // ── Details ───────────────────────────────────────────────────
            pw.Text(
              'Property Details',
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            _buildDetailRow('Type', property.type.toUpperCase()),
            _buildDetailRow(
                'Listing Type',
                property.listingType == 'sale'
                    ? 'For Sale'
                    : 'For Rent'),
            _buildDetailRow('Status', property.status.toUpperCase()),
            _buildDetailRow(
                'Bedrooms', property.bedrooms.toString()),
            _buildDetailRow(
                'Bathrooms', property.bathrooms.toString()),
            _buildDetailRow(
                'Area', '${property.area.toInt()} sq ft'),

            pw.SizedBox(height: 20),

            // ── Location ──────────────────────────────────────────────────
            pw.Text(
              'Location',
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Text(property.location.fullAddress),

            pw.SizedBox(height: 20),

            // ── Description ───────────────────────────────────────────────
            pw.Text(
              'Description',
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Text(property.description,
                textAlign: pw.TextAlign.justify),

            // ── Amenities ─────────────────────────────────────────────────
            if (property.amenities.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text(
                'Amenities',
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 12),
              pw.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: property.amenities
                    .map((a) => pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey300,
                            borderRadius:
                                const pw.BorderRadius.all(
                                    pw.Radius.circular(16)),
                          ),
                          child: pw.Text(a,
                              style:
                                  const pw.TextStyle(fontSize: 10)),
                        ))
                    .toList(),
              ),
            ],
          ];
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/property_${property.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(path);
    final bytes = await pdf.save();
    await file.writeAsBytes(bytes);
    return file;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static pw.Widget _buildStatItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 14, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text,
      {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style:
                  pw.TextStyle(color: PdfColors.grey700)),
          pw.Text(value,
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}