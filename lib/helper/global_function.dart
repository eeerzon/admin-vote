// ignore_for_file: use_build_context_synchronously

import 'package:admin_vote_mobile/helper/excel_export_helper.dart';
import 'package:admin_vote_mobile/helper/global_var.dart';
import 'package:admin_vote_mobile/pages/auth/login_page.dart';
import 'package:admin_vote_mobile/services/storage_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:jwt_decoder/jwt_decoder.dart';

bool isValidEmail(String email) {
  const validTlds = {
    'com', 'net', 'org', 'edu', 'gov', 'mil', 'int',
    'id', 'uk', 'us', 'au', 'de', 'fr', 'jp', 'cn', 'in', 'br',
    'co', 'io', 'ai', 'app', 'dev', 'web', 'info', 'biz', 'name',
    'pro', 'tel', 'mobi', 'asia', 'tv', 'cc', 'me', 'my', 'sg',
    'ph', 'th', 'vn', 'hk', 'tw', 'kr', 'ru', 'nl', 'es', 'it',
    'se', 'no', 'dk', 'fi', 'pl', 'cz', 'hu', 'ro', 'gr', 'pt',
    'ch', 'at', 'be', 'nz', 'za', 'ng', 'ke', 'eg', 'mx', 'ar',
    'cl', 'ca', 'store', 'online', 'site', 'tech', 'media', 'news',
  };

  final regex = RegExp(
    // r'^[a-zA-Z0-9._%+-]+@([a-zA-Z0-9-]+\.)+([a-zA-Z]{3,}|[a-zA-Z]{2}\.[a-zA-Z]{2,})$'
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,}$',
  );
  
  if (!regex.hasMatch(email)) return false;

  final tld = email.split('.').last.toLowerCase();
  return validTlds.contains(tld);
}

bool isValidPhone(String phone) {
  final regex = RegExp(r'^[0-9]{7,15}$');
  return regex.hasMatch(phone);
}

bool isValidPhoneIDR(String phone) {
  final regex = RegExp(r'^08[0-9]{7,15}$');
  return regex.hasMatch(phone);
}

String maskMiddle(String? value, {int prefixLength = 2, int suffixLength = 2}) {
  if (value == null || value.trim().isEmpty) return '-';

  final trimmed = value.trim();
  final length = trimmed.length;

  int prefix = prefixLength;
  int suffix = suffixLength;

  // Adaptif: pastikan tetap ada karakter yang di-mask meski string pendek
  if (length <= prefix + suffix) {
    if (length <= 2) {
      prefix = length > 1 ? 1 : 0;
      suffix = 0;
    } else {
      prefix = 1;
      suffix = 1;
    }
  }

  final maskedLength = length - prefix - suffix;
  if (maskedLength <= 0) return trimmed;

  final masked = '*' * maskedLength;
  return '${trimmed.substring(0, prefix)}$masked${trimmed.substring(length - suffix)}';
}

DateTime parseWib(String value) {
  // Ubah ke ISO +07:00 agar Flutter tahu ini WIB
  return DateTime.parse(
    '${value.replaceAll(' ', 'T')}+07:00',
  );
}

String formatHtmlContent(String? text) {
  if (text == null) return "";
  return text
      .replaceAll('\r\n', '')
      .replaceAll('\n\n', '<br>')
      .replaceAll('\n', '<br>');
}

String parseNewline(String? text) {
  if (text == null || text.isEmpty) return '';
  return text
      .replaceAll('\\n', '\n')
      .replaceAll('\r\n', '\n')
      .trim();
}

bool hasFile(String answer) {
  final uri = Uri.tryParse(answer);
  if (uri == null) return false;
  final path = uri.path;
  return path.contains('.');
}

String translateError(String message, String? langCode) {
  final normalized = message.toLowerCase().trim().replaceAll(RegExp(r'\.+$'), '');

  if (langCode == 'id') {
    
    for (final entry in idNormalizationMap.entries) {
      final key = entry.key.toLowerCase().trim().replaceAll(RegExp(r'\.+$'), '');
      if (normalized == key) {
        return entry.value;
      }
    }
    
    for (final entry in idNormalizationMap.entries) {
      final key = entry.key.toLowerCase().trim().replaceAll(RegExp(r'\.+$'), '');
      if (normalized.contains(key)) {
        return entry.value;
      }
    }
    return message;
  }


  for (final entry in errorTranslationMap.entries) {
    final key = entry.key.toLowerCase().trim().replaceAll(RegExp(r'\.+$'), '');
    if (normalized == key) {
      return entry.value;
    }
  }
  
  for (final entry in errorTranslationMap.entries) {
    final key = entry.key.toLowerCase().trim().replaceAll(RegExp(r'\.+$'), '');
    if (normalized.contains(key)) {
      return entry.value;
    }
  }

  return message;
}

class EmailInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    
    final text = newValue.text.replaceAll(RegExp(r'\s'), '');
    
    final spacesBeforeCursor = newValue.text
        .substring(0, newValue.selection.baseOffset)
        .replaceAll(RegExp(r'\s'), '')
        .length;

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: spacesBeforeCursor.clamp(0, text.length),
      ),
    );
  }
}

extension StringExtension on String {
  String get capitalize {
    if (isEmpty) return this;
    return split(' ')
      .map((word) => word.isEmpty 
        ? word 
        : word[0].toUpperCase() + word.substring(1))
      .join(' ');
  }
}

bool isHtmlEmpty(String? html) {
  if (html == null || html.isEmpty) return true;
  
  final text = html
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', '')
      .trim();

  return text.isEmpty;
}

String normalizePartnerUrl(String url) {
  url = url.trim();
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }
  return 'https://$url';
}

String simplifyKontenHtml(String rawHtml) {
  final document = html_parser.parse(rawHtml);
  final buffer = StringBuffer();

  void processNode(dom.Node node) {
    if (node is dom.Text) {
      final text = node.text.trim();
      if (text.isNotEmpty) {
        buffer.writeln('<p>${_escapeButKeepEntities(text)}</p>');
      }
      return;
    }

    if (node is! dom.Element) return;
    final el = node;
    final classes = el.classes;
    final tag = el.localName;

    // Pola utama: <div class="row ..."> berisi col-auto (nomor) + col (judul & isi)
    if (tag == 'div' && classes.contains('row')) {
      final directDivCols = el.children.where((c) => c.localName == 'div').toList();

      if (directDivCols.length >= 2 && directDivCols[0].classes.contains('col-auto')) {
        final nomorEl = directDivCols[0];
        final contentCol = directDivCols[1];

        final nomor = nomorEl.text.trim();
        final headingEl = contentCol.children.firstWhere(
          (c) => c.localName == 'h5' || c.localName == 'h6',
          orElse: () => dom.Element.tag('_none'),
        );

        if (headingEl.localName != '_none') {
          final headingTag = headingEl.localName;
          final judul = headingEl.text.trim();
          // GABUNG nomor + judul jadi SATU baris teks di dalam SATU tag heading
          buffer.writeln('<$headingTag><b>$nomor</b> $judul</$headingTag>');

          for (final child in contentCol.children) {
            if (child != headingEl) processNode(child);
          }
        } else {
          // gak ada heading: nomor + isi jadi satu paragraf, isi diproses sbg TEXT saja (bukan innerHtml mentah)
          buffer.writeln('<p><b>$nomor</b> ${contentCol.text.trim()}</p>');
          for (final child in contentCol.children) {
            // tetap proses nested list/div lain di dalamnya kalau ada
            if (child.localName == 'ul' || child.localName == 'ol') {
              processNode(child);
            }
          }
        }
        return;
      }

      // row tanpa pola col-auto+col (misal cuma <div class="row"><div class="col">isi</div></div>)
      for (final child in el.children) {
        processNode(child);
      }
      return;
    }

    if (tag == 'ol' || tag == 'ul') {
      buffer.writeln(el.outerHtml);
      return;
    }

    if (tag == 'h5' || tag == 'h6') {
      buffer.writeln(el.outerHtml);
      return;
    }

    if (tag == 'p' || tag == 'br') {
      buffer.writeln(el.outerHtml);
      return;
    }

    // div generik (container, col tanpa row, dll): proses isinya aja
    if (tag == 'div') {
      for (final child in el.nodes) {
        processNode(child);
      }
      return;
    }

    // fallback
    for (final child in el.nodes) {
      processNode(child);
    }
  }

  for (final child in document.body?.nodes ?? []) {
    processNode(child);
  }

  return buffer.toString();
}

String _escapeButKeepEntities(String text) => text;

void confirmLogout(BuildContext context ,String token) async {
  //jika memerlukan api logout

  // Map<String, dynamic>? result;

  // try {
  //   result = await ApiService.post("/api/v1/auth/logout", token: token);
  // } catch (e) {
  //   result = null;
  // }

  // final bool isSuccess = result?['success'] == true;

  // if (isSuccess) {
  //   await StorageService.removeToken();
  //   await StorageService.removeRefreshToken();
  //   await StorageService.clearUser();

  //   Navigator.pushAndRemoveUntil(
  //     context,
  //     MaterialPageRoute(builder: (_) => LoginPage()),
  //     (route) => false,
  //   );
  // } else {

  //   final String errorMessage = result?['message']?.toString() ??
  //       bahasa['logout_gagal_desc'] ??
  //       'Gagal melakukan logout. Silakan coba lagi.';

  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: Text(bahasa['logout_gagal'] ?? 'Logout Gagal'),
  //       content: Text(errorMessage),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: Text(bahasa['ok'] ?? 'OK'),
  //         ),
  //       ],
  //     ),
  //   );
  // }


  await StorageService.removeToken();
  await StorageService.removeRefreshToken();
  await StorageService.clearUser();

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => LoginPage()),
    (route) => false,
  );
}

String getInitial(String userName) {
  final name = userName.trim();
  if (name.isNotEmpty) {
    return name[0].toUpperCase();
  }
  return "K";
}

Map<String, String> formatDateVariants(String? langCode, String? rawDate, {bool includeTime = false}) {
  if (rawDate == null || rawDate.isEmpty) {
    return {'long': '-', 'short': '-', 'long_text': '-'};
  }

  try {
    final date = DateTime.parse(rawDate).toLocal();
    final isEnglish = langCode?.toLowerCase().startsWith('en') ?? false;

    final longMonths = isEnglish
        ? const [
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December',
          ]
        : const [
            'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
            'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
          ];

    final shortMonths = isEnglish
        ? const [
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
          ]
        : const [
            'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
            'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
          ];

    final dayNames = isEnglish
        ? const [
            'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
          ]
        : const [
            'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
          ];

    final day = date.day.toString().padLeft(2, '0');
    final year = date.year;
    final dayName = dayNames[date.weekday - 1];

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final timeSuffix = includeTime ? ', $hour.$minute' : '';

    return {
      'long': "$day ${longMonths[date.month - 1]} $year$timeSuffix",
      'short': "$day ${shortMonths[date.month - 1]} $year$timeSuffix",
      'long_text': "$dayName, ${date.day} ${longMonths[date.month - 1]} $year$timeSuffix",
    };
  } catch (e) {
    return {'long': rawDate, 'short': rawDate, 'long_text': rawDate};
  }
}

Widget buildAdaptiveDateText(
  String? langCode,
  String? rawDate, {
  TextStyle? style,
  bool includeTime = false,
}) {
  final variants = formatDateVariants(langCode, rawDate, includeTime: includeTime);
  final textStyle = style ?? const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

  return LayoutBuilder(
    builder: (context, constraints) {
      final longPainter = TextPainter(
        text: TextSpan(text: variants['long'], style: textStyle),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();

      final fitsLong = longPainter.width <= constraints.maxWidth;

      return Text(
        fitsLong ? variants['long']! : variants['short']!,
        style: textStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    },
  );
}

String formatCurrency(dynamic rawValue, String currency) {
  final double value = (rawValue is num) ? rawValue.toDouble() : 0.0;

  if (currency.toUpperCase() == 'IDR') {
    final rounded = value.round(); // ceil ke satuan rupiah terdekat
    final formatted = thousandSeparator(rounded);
    return "IDR $formatted";
  } else {
    final formatted = value.toStringAsFixed(2);
    return "${currency.toUpperCase()} $formatted";
  }
}

String thousandSeparator(int number) {
  final str = number.abs().toString();
  final buffer = StringBuffer();
  final sign = number < 0 ? '-' : '';

  for (int i = 0; i < str.length; i++) {
    if (i != 0 && (str.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(str[i]);
  }

  return '$sign${buffer.toString()}';
}

int toIntInline(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

Future<bool> isTokenStillValid(String? token) async {
  if (token == null || token.isEmpty) return false;

  try {
    return !JwtDecoder.isExpired(token);
  } catch (e) {
    return false;
  }
}

Future<void> forceLogoutToLogin(BuildContext context) async {
  await StorageService.removeToken();
  await StorageService.removeRefreshToken();
  await StorageService.clearUser();

  if (!context.mounted) return;

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => LoginPage()),
    (route) => false,
  );
}

bool isUnauthenticatedResponse(Map<String, dynamic>? result) {
  if (result == null) return false;

  final message = result['message']?.toString().toLowerCase() ?? '';

  return message.contains('unauthenticated') ||
      message.contains('unauthorized');
}

class StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  StickyTabBarDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: height,
      child: Container(
        color: const Color(0xFFF5F5F7),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant StickyTabBarDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}

void showLogoutMenu(
  BuildContext context, 
  String token, 
  Map<String, dynamic> bahasa, 
  Function(int index)? onNavigateToTab
) {
  final RenderBox renderBox = context.findRenderObject() as RenderBox;
  final Offset offset = renderBox.localToGlobal(Offset.zero);

  showMenu(
    context: context,
    position: RelativeRect.fromLTRB(
      offset.dx + renderBox.size.width,
      offset.dy + 60,
      offset.dx,
      0,
    ),
    items: [
      PopupMenuItem(
        value: 'profile',
        child: Row(
          children: [
            const Icon(Icons.person_outline, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            Text(bahasa['profile'] ?? 'Profil'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'logout',
        child: Row(
          children: [
            const Icon(Icons.logout, size: 18, color: Colors.red),
            const SizedBox(width: 8),
            Text(bahasa['logout'] ?? 'Logout'),
          ],
        ),
      ),
    ],
  ).then((value) {
    if (value == 'profile') {
      onNavigateToTab?.call(3);
    } else if (value == 'logout') {
      confirmLogout(context, token);
    }
  });
}

String formatPercent(dynamic percent) {
  final value = (percent as num?)?.toDouble() ?? 0;
  return '${value.toStringAsFixed(2)}%';
}

Future<void> downloadExcel(BuildContext context, String idVote, List<dynamic> activeList) async {
  await exportToExcel(
    context: context,
    fileName: 'Leaderboard_$idVote',
    headers: ['Rank', 'Nama Finalis', 'Nama Tambahan', 'Total Voters', 'Persentase'],
    rows: activeList.asMap().entries.map((entry) {
      final item = entry.value as Map<String, dynamic>;
      return [
        entry.key + 1,
        item['nama_finalis'] ?? '-',
        item['nama_tambahan'] ?? '-',
        toIntInline(item['total_voters']),
        formatPercent(item['percent']),
      ];
    }).toList(),
  );
}