import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Helper generik untuk export data ke file Excel (.xlsx) lalu
/// membuka share sheet supaya pengguna bisa menyimpan/mengirim filenya.
///
/// Dipakai bersama oleh NilaiScreen (export semua data) dan
/// NilaiSiswaDetailScreen (export nilai 1 siswa) supaya tidak
/// ada duplikasi logic pembuatan file Excel.
class ExportExcelHelper {
  static Future<void> exportToExcel({
    required String sheetName,
    required List<String> headers,
    required List<List<CellValue>> rows,
    required String fileNamePrefix,
    String shareText = 'Data Nilai Organku',
  }) async {
    final excelFile = Excel.createExcel();
    final sheet = excelFile[sheetName];

    // Hapus sheet default kosong "Sheet1" bila ada
    if (excelFile.sheets.containsKey('Sheet1')) {
      excelFile.delete('Sheet1');
    }

    // ── Header kolom ──
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (var col = 0; col < headers.length; col++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.cellStyle = CellStyle(bold: true);
    }

    // ── Isi baris data ──
    for (final row in rows) {
      sheet.appendRow(row);
    }

    final bytes = excelFile.encode();
    if (bytes == null) throw Exception("Gagal membuat file Excel");

    // ── Simpan ke file sementara ──
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final namaFile = '${fileNamePrefix}_'
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}'
        '.xlsx';
    final filePath = '${dir.path}/$namaFile';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    // ── Buka share sheet ──
    await Share.shareXFiles(
      [XFile(filePath)],
      text: shareText,
      subject: namaFile,
    );
  }
}