import 'dart:io';

import 'package:admin_vote_mobile/helper/global_var.dart';
import 'package:admin_vote_mobile/helper/loading_page.dart';
import 'package:admin_vote_mobile/services/api_services.dart';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

bool _isExportingQrZip = false;
bool _isExportingSingleQr = false;

// Sama kayak _sharePositionOrigin di excel_export_helper.dart - share_plus
// butuh sharePositionOrigin non-zero buat anchor popover di iPad.
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

String _sanitizeFileName(String input) {
  final cleaned = input.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
  return cleaned.isEmpty ? '-' : cleaned;
}

/// Download QR semua finalis (semua halaman, bukan cuma yang udah ke-load di
/// UI), lalu digabung jadi 1 file .zip dan dibuka lewat share sheet.
///
/// Nama tiap file: "{urutan 4 digit}-{nama finalis}-{nomor urut}.png"
/// Nama zip: "qr-finalis-{idVote}.zip"
///
/// Dipanggil dari tombol "Download Semua QR" di detail_vote.dart.
Future<void> exportFinalisQrZip({
  required BuildContext context,
  required String idVote,
  required String slug,
  required String? token,
  required String? langCode,
  String? loadingText,
  String? emptyText,
  String? errorText,
}) async {
  if (_isExportingQrZip) return;
  _isExportingQrZip = true;

  showLoadingDialog(context, loadingText ?? 'Menyiapkan file QR...');
  var loadingShown = true;

  try {
    // Ambil semua finalis lewat semua halaman - tombol ini "download SEMUA",
    // jadi gak boleh cuma ngandelin finalisList yang udah ke-load di layar.
    final List<dynamic> allFinalis = [];
    var page = 1;
    while (true) {
      final result = await ApiService.get(
        '/api/v1/votes/$idVote/finalis/list?page=$page&search=',
        xLanguage: langCode,
        token: token,
      );
      final data = result?['data']?['data'];
      if (data is List) allFinalis.addAll(data);

      final lastPage = result?['data']?['last_page'];
      if (lastPage == null || page >= lastPage || data is! List || data.isEmpty) break;
      page++;
    }

    if (allFinalis.isEmpty) {
      if (context.mounted) {
        hideLoadingDialog(context);
        loadingShown = false;
      }
      Fluttertoast.showToast(msg: emptyText ?? 'Belum ada finalis untuk diunduh');
      return;
    }

    final archive = Archive();

    for (var i = 0; i < allFinalis.length; i++) {
      final f = allFinalis[i];
      if (f is! Map) continue;

      final idFinalis = f['id_finalis'];
      if (idFinalis == null) continue;

      final targetUrl = '$baseUrl/voting/$slug/finalis/$idFinalis';
      final encodedUrl = Uri.encodeComponent(targetUrl);
      final qrImageUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=400x400&ecc=H&data=$encodedUrl';

      final response = await http.get(Uri.parse(qrImageUrl));
      if (response.statusCode != 200) continue;

      final namaFinalis = _sanitizeFileName((f['nama_finalis'] ?? 'finalis').toString());
      final nomorUrut = _sanitizeFileName((f['nomor_urut'] ?? '').toString());
      final seq = (i + 1).toString().padLeft(4, '0');
      final fileName = '$seq-$namaFinalis-$nomorUrut.png';

      archive.addFile(ArchiveFile(fileName, response.bodyBytes.length, response.bodyBytes));
    }

    if (archive.isEmpty) {
      throw Exception('Tidak ada QR yang berhasil diunduh');
    }

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw Exception('Gagal membuat file zip');
    }

    final dir = await getTemporaryDirectory();
    final zipFile = File('${dir.path}/qr-finalis-$idVote.zip');
    await zipFile.writeAsBytes(zipBytes, flush: true);

    if (!context.mounted) return;
    hideLoadingDialog(context);
    loadingShown = false;

    final shareOrigin = _sharePositionOrigin(context);

    // Jeda dikit biar animasi dismiss dialog loading kelar dulu, sama kayak
    // exportToExcel - share sheet iOS bisa throw kalau dipanggil pas dialog
    // masih nutup.
    await Future.delayed(const Duration(milliseconds: 300));

    await Share.shareXFiles(
      [XFile(zipFile.path)],
      text: 'QR Finalis',
      sharePositionOrigin: shareOrigin,
    );
  } catch (e, st) {
    debugPrint('exportFinalisQrZip error: $e\n$st');
    if (loadingShown && context.mounted) hideLoadingDialog(context);
    Fluttertoast.showToast(msg: errorText ?? 'Gagal mengunduh QR');
  } finally {
    _isExportingQrZip = false;
  }
}

/// Download QR 1 finalis aja (bukan bulk/zip) - file PNG langsung dibuka
/// lewat share sheet.
///
/// Nama file: "qr-{nama finalis}-{id_finalis}.png"
///
/// Dipanggil dari tombol "Unduh QR" di tiap card finalis di detail_vote.dart.
Future<void> exportSingleFinalisQr({
  required BuildContext context,
  required String slug,
  required String idFinalis,
  required String namaFinalis,
  String? loadingText,
  String? errorText,
}) async {
  if (_isExportingSingleQr) return;
  _isExportingSingleQr = true;

  showLoadingDialog(context, loadingText ?? 'Menyiapkan QR...');
  var loadingShown = true;

  try {
    final targetUrl = '$baseUrl/voting/$slug/finalis/$idFinalis';
    final encodedUrl = Uri.encodeComponent(targetUrl);
    final qrImageUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=400x400&ecc=H&data=$encodedUrl';

    final response = await http.get(Uri.parse(qrImageUrl));
    if (response.statusCode != 200) {
      throw Exception('Gagal mengunduh QR (${response.statusCode})');
    }

    final fileName = 'qr-${_sanitizeFileName(namaFinalis)}-${_sanitizeFileName(idFinalis)}.png';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(response.bodyBytes, flush: true);

    if (!context.mounted) return;
    hideLoadingDialog(context);
    loadingShown = false;

    final shareOrigin = _sharePositionOrigin(context);

    await Future.delayed(const Duration(milliseconds: 300));

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'QR $namaFinalis',
      sharePositionOrigin: shareOrigin,
    );
  } catch (e, st) {
    debugPrint('exportSingleFinalisQr error: $e\n$st');
    if (loadingShown && context.mounted) hideLoadingDialog(context);
    Fluttertoast.showToast(msg: errorText ?? 'Gagal mengunduh QR');
  } finally {
    _isExportingSingleQr = false;
  }
}
