import 'dart:io';

import 'package:admin_vote_mobile/helper/loading_page.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

CellValue _toCellValue(dynamic value) {
  if (value == null) return TextCellValue('-');
  if (value is int) return IntCellValue(value);
  if (value is double) return DoubleCellValue(value);
  if (value is bool) return TextCellValue(value ? 'Ya' : 'Tidak');
  return TextCellValue(value.toString());
}

bool _isExportingExcel = false;

// share_plus butuh sharePositionOrigin non-zero (dipakai buat anchor
// popover di iPad, tapi divalidasi juga di iPhone) - ambil dari RenderBox
// context yang dikasih, fallback ke ukuran layar kalau belum ke-layout.
Rect? _sharePositionOrigin(BuildContext context) {
  final box = context.findRenderObject();
  if (box is RenderBox && box.hasSize && box.size != Size.zero) {
    return box.localToGlobal(Offset.zero) & box.size;
  }
  final mediaQuery = MediaQuery.maybeOf(context);
  if (mediaQuery != null) {
    return Offset.zero & mediaQuery.size;
  }
  return null;
}

/// Bikin file .xlsx dari [headers] + [rows], lalu buka share sheet
/// biar user bisa simpan/kirim filenya.
///
/// Dipanggil dari tombol "Download Excel" di halaman hasil vote
/// (dukungan, transaksi, leaderboard, transaksi per finalis, dst).
Future<void> exportToExcel({
  required BuildContext context,
  required String fileName,
  required List<String> headers,
  required List<List<dynamic>> rows,
  String sheetName = 'Sheet1',
  String? loadingText,
  String? emptyText,
  String? errorText,
}) async {
  if (rows.isEmpty) {
    Fluttertoast.showToast(msg: emptyText ?? 'Tidak ada data untuk diunduh');
    return;
  }

  // Cegah export nyala dobel (mis. tombolnya kepencet 2x) - share sheet
  // iOS bisa error kalau dipanggil dua kali beruntun selagi masih aktif.
  if (_isExportingExcel) return;
  _isExportingExcel = true;

  showLoadingDialog(context, loadingText ?? 'Menyiapkan file excel...');
  var loadingShown = true;

  try {
    final excel = Excel.createExcel();

    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != sheetName) {
      excel.rename(defaultSheet, sheetName);
    }
    final sheet = excel[sheetName];

    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (final cell
        in sheet.row(0)) {
      cell?.cellStyle = CellStyle(bold: true);
    }

    for (final row in rows) {
      sheet.appendRow(row.map(_toCellValue).toList());
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Gagal encode file excel');
    }

    final dir = await getTemporaryDirectory();
    final safeName =
        '${fileName}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File('${dir.path}/$safeName');
    await file.writeAsBytes(bytes, flush: true);

    if (!context.mounted) return;
    hideLoadingDialog(context);
    loadingShown = false;

    final shareOrigin = _sharePositionOrigin(context);

    // Jeda dikit biar animasi dismiss dialog loading kelar dulu - kalau
    // share sheet iOS langsung dipanggil pas dialog masih nutup, dua-duanya
    // rebutan presentasi dan shareXFiles bisa throw.
    await Future.delayed(const Duration(milliseconds: 300));

    await Share.shareXFiles(
      [XFile(file.path)],
      text: fileName,
      sharePositionOrigin: shareOrigin,
    );
  } catch (e, st) {
    debugPrint('exportToExcel error: $e\n$st');
    if (loadingShown && context.mounted) hideLoadingDialog(context);
    Fluttertoast.showToast(msg: errorText ?? 'Gagal mengunduh excel');
  } finally {
    _isExportingExcel = false;
  }
}
