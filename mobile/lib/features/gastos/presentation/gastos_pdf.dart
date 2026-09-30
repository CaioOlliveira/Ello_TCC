import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/api/api_client.dart';

Future<Uint8List> buildGastosPdf({
  required List<GastoResumo> gastos,
  required double total,
  required String titulo,
  required String periodo,
  required String introducao,
  required String nomeIdoso,
  required DateTime geradoEm,
}) async {
  final pdf = pw.Document(
    title: '$titulo - $nomeIdoso',
    author: 'Ello',
    subject: 'Relatório de gastos da ficha',
  );
  final baseFont = pw.Font.helvetica();
  final boldFont = pw.Font.helveticaBold();
  const teal = PdfColor.fromInt(0xFF087989);
  const darkBlue = PdfColor.fromInt(0xFF17324D);
  const lightTeal = PdfColor.fromInt(0xFFE8F6F8);
  const border = PdfColor.fromInt(0xFFD8E7EA);
  const red = PdfColor.fromInt(0xFFD94D4D);

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 34, 36, 34),
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
      ),
      header: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: border, width: 0.8),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'ello',
              style: pw.TextStyle(
                color: teal,
                fontSize: 23,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'Cuidado que aproxima',
              style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9),
            ),
          ],
        ),
      ),
      footer: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: border, width: 0.8),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Gerado em ${_formatDateTime(geradoEm)}',
              style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
            ),
            pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
            ),
          ],
        ),
      ),
      build: (context) => [
        pw.SizedBox(height: 22),
        pw.Text(
          titulo,
          style: pw.TextStyle(
            color: darkBlue,
            fontSize: 25,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          nomeIdoso,
          style: const pw.TextStyle(color: teal, fontSize: 13),
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          introducao,
          style: const pw.TextStyle(
            color: PdfColors.grey700,
            fontSize: 10.5,
            lineSpacing: 3,
          ),
        ),
        pw.SizedBox(height: 18),
        pw.Container(
          padding: const pw.EdgeInsets.all(15),
          decoration: pw.BoxDecoration(
            color: lightTeal,
            borderRadius: pw.BorderRadius.circular(9),
            border: pw.Border.all(color: border),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: _summaryItem(
                  label: 'PERÍODO',
                  value: periodo,
                  color: darkBlue,
                ),
              ),
              pw.Container(width: 1, height: 36, color: border),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: _summaryItem(
                  label: 'REGISTROS',
                  value: gastos.length.toString(),
                  color: darkBlue,
                ),
              ),
              pw.Container(width: 1, height: 36, color: border),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: _summaryItem(
                  label: 'TOTAL',
                  value: _formatCurrency(total),
                  color: red,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 22),
        pw.Text(
          'Detalhamento dos gastos',
          style: pw.TextStyle(
            color: darkBlue,
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 9),
        pw.TableHelper.fromTextArray(
          headers: const ['Data', 'Descrição', 'Fonte', 'Valor'],
          data: [
            for (final gasto in gastos)
              [
                _formatDate(gasto.dataGasto),
                gasto.descricao,
                gasto.fonte,
                _formatCurrency(gasto.valor),
              ],
          ],
          border: pw.TableBorder.all(color: border, width: 0.7),
          headerDecoration: const pw.BoxDecoration(color: teal),
          headerStyle: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
          cellStyle: const pw.TextStyle(color: darkBlue, fontSize: 8.5),
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 7,
          ),
          cellAlignments: const {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerLeft,
            3: pw.Alignment.centerRight,
          },
          columnWidths: const {
            0: pw.FlexColumnWidth(1.05),
            1: pw.FlexColumnWidth(2.5),
            2: pw.FlexColumnWidth(1.55),
            3: pw.FlexColumnWidth(1.2),
          },
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
        ),
        pw.SizedBox(height: 16),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: teal),
              borderRadius: pw.BorderRadius.circular(7),
            ),
            child: pw.RichText(
              text: pw.TextSpan(
                style: const pw.TextStyle(color: darkBlue, fontSize: 10),
                children: [
                  const pw.TextSpan(text: 'Total do período:  '),
                  pw.TextSpan(
                    text: _formatCurrency(total),
                    style: pw.TextStyle(
                      color: red,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Este documento foi preparado pelo Ello para facilitar o acompanhamento e o compartilhamento das despesas de cuidado.',
          style: const pw.TextStyle(
            color: PdfColors.grey600,
            fontSize: 8.5,
            lineSpacing: 2,
          ),
        ),
      ],
    ),
  );

  return pdf.save();
}

pw.Widget _summaryItem({
  required String label,
  required String value,
  required PdfColor color,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label,
        style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 7.5),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        value,
        maxLines: 2,
        style: pw.TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    ],
  );
}

String _formatCurrency(double value) {
  final fixed = value.toStringAsFixed(2).split('.');
  final chars = fixed.first.split('').reversed.toList();
  final grouped = <String>[];
  for (var i = 0; i < chars.length; i++) {
    if (i > 0 && i % 3 == 0) grouped.add('.');
    grouped.add(chars[i]);
  }
  return 'R\$ ${grouped.reversed.join()},${fixed.last}';
}

String _formatDate(DateTime value) => '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';

String _formatDateTime(DateTime value) => '${_formatDate(value)} às '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
