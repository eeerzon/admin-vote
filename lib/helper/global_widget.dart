

import 'dart:io';
import 'dart:ui' as ui;

import 'package:admin_vote_mobile/helper/global_function.dart';
import 'package:admin_vote_mobile/helper/global_var.dart';
import 'package:admin_vote_mobile/services/lang_service.dart';
import 'package:admin_vote_mobile/services/storage_services.dart';
import 'package:flutter/material.dart';

class Skeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const Skeleton({super.key, 
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<Skeleton> createState() => SkeletonState();
}

class SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}

Widget buildHeader(
  BuildContext context,
  String? userName,
  String? token,
  Map<String, dynamic> bahasa,
  Function(int index)? onNavigateToTab,
) {
  return Container(
    color: Colors.red,
    child: Padding(
      padding: EdgeInsetsGeometry.fromLTRB(20, 10, 20, 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.asset(
                "assets/images/avata_logo.png",
                width: 40, height: 40, fit: BoxFit.contain,
              ),

              Row(
                children: [
                  // buildIconCircle(
                  //   icon: Icons.chat_bubble_outline,
                  //   iconColor: const Color(0xFFE04E39),
                  //   bgColor: Colors.white,
                  //   hasBorder: true,
                  // ),
                  // const SizedBox(width: 10),
                  buildIconCircle(
                    child: Text(
                      getInitial(userName!),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE04E39),
                      ),
                    ),
                    bgColor: const Color(0xFFFDEDEA),
                    onTap: () => showLogoutMenu(context, token!, bahasa, onNavigateToTab),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget buildIconCircle({
  IconData? icon,
  Color? iconColor,
  required Color bgColor,
  bool hasBorder = false,
  Widget? child,
  VoidCallback? onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: hasBorder
            ? Border.all(color: const Color(0xFFE0E0E0), width: 1)
            : null,
      ),
      child: Center(
        child: child ??
            Icon(icon, size: 18, color: iconColor),
      ),
    ),
  );
}

class NoOrder extends StatefulWidget {
  const NoOrder({super.key});

  @override
  State<NoOrder> createState() => _NoOrderState();
}

class _NoOrderState extends State<NoOrder> {
  String? langCode;
  Map<String, dynamic> bahasa = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _getBahasa();
    });
  }

  Future<void> _getBahasa() async {
    final code = await StorageService.getLanguage();

    setState(() {
      langCode = code;
    });

    final tempbahasa = await LangService.getJsonData(langCode!, "bahasa");
    setState(() {
      bahasa = tempbahasa;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        width: double.infinity,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: kGlobalPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  child: Image.network(
                    'https://newvote.kreenconnect.com/img/failed.png',
                    height: 170,
                  )
                ),
        
                const SizedBox(height: 8),
                Text(
                  bahasa['no_data'] ?? "Data tidak ditemukan",
                  textAlign: TextAlign.center,
                ),
        
                const SizedBox(height: 8),
                Text(
                  bahasa['no_data_desc'] ?? "Coba gunakan kata kunci lain",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget buildSkeletonDetailHasil() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(width: 1, color: Colors.grey.shade300)
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Skeleton(width: 220, height: 22, borderRadius: 4),
        const SizedBox(height: 20),
        Skeleton(width: 110, height: 22, borderRadius: 12),
        const SizedBox(height: 20),
        Skeleton(width: 130, height: 22, borderRadius: 12),
        const SizedBox(height: 20),
        Skeleton(width: double.infinity, height: 22, borderRadius: 12),
        const SizedBox(height: 20),
        Skeleton(width: double.infinity, height: 22, borderRadius: 12),
      ],
    ),
  );
}


class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const MarqueeText({super.key, required this.text, required this.style});

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textPainter = TextPainter(
            text: TextSpan(text: widget.text, style: widget.style),
            textDirection: ui.TextDirection.ltr,
          )..layout();
          final textWidth = textPainter.width;
          final boxWidth = constraints.maxWidth;
          final totalDistance = textWidth + boxWidth;

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final dx = boxWidth - _controller.value * totalDistance;
              return Stack(
                children: [
                  Positioned(
                    left: dx,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// Bottom sheet Tambah/Edit Finalis - dipakai di new_vote.dart (step finalis
// wizard) dan detail_vote.dart (edit finalis dari vote yang sudah publish).
class TambahFinalisSheet extends StatefulWidget {
  final Map<String, dynamic> bahasa;
  final Future<File?> Function() pickImage;
  final Map<String, dynamic>? initialData;
  final Future<bool> Function(Map<String, dynamic> data) onSave;
  // true = cuma tampilin card pilih foto (dipakai buat "Ganti Foto" di
  // detail_vote.dart, gak perlu buka form finalis lengkap).
  final bool photoOnly;

  const TambahFinalisSheet({
    super.key,
    required this.bahasa,
    required this.pickImage,
    required this.onSave,
    this.initialData,
    this.photoOnly = false,
  });

  @override
  State<TambahFinalisSheet> createState() => _TambahFinalisSheetState();
}

class _TambahFinalisSheetState extends State<TambahFinalisSheet> {
  late final TextEditingController _namaController;
  late final TextEditingController _nomorUrutController;
  late final TextEditingController _namaTambahanController;
  late final TextEditingController _profesiController;
  late final TextEditingController _usiaController;
  late final TextEditingController _deskripsiController;
  late final TextEditingController _videoController;
  late final TextEditingController _igController;
  late final TextEditingController _linkedinController;
  late final TextEditingController _fbController;
  late final TextEditingController _twitterController;
  File? _foto;
  bool _showError = false;
  bool _saving = false;

  Map<String, dynamic> get bahasa => widget.bahasa;
  String? get _existingFotoUrl => widget.initialData?['foto_url'] as String?;

  Widget _fotoPlaceholder() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, color: Colors.grey[400], size: 28),
          const SizedBox(height: 8),
          Text(
            bahasa['klik_unggah_foto'] ?? 'Klik untuk unggah foto (4:5)',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _namaController = TextEditingController(text: d?['nama_finalis'] ?? '');
    _nomorUrutController = TextEditingController(text: d?['nomor_urut'] ?? '');
    _namaTambahanController = TextEditingController(text: d?['nama_tambahan'] ?? '');
    _profesiController = TextEditingController(text: d?['profesi'] ?? '');
    _usiaController = TextEditingController(text: d?['usia'] ?? '');
    _deskripsiController = TextEditingController(text: d?['deskripsi'] ?? '');
    _videoController = TextEditingController(text: d?['video_profile'] ?? '');
    _igController = TextEditingController(text: d?['instagram'] ?? '');
    _linkedinController = TextEditingController(text: d?['linkedin'] ?? '');
    _fbController = TextEditingController(text: d?['facebook'] ?? '');
    _twitterController = TextEditingController(text: d?['twitter'] ?? '');
    _foto = d?['foto'] as File?;
  }

  @override
  void dispose() {
    _namaController.dispose();
    _nomorUrutController.dispose();
    _namaTambahanController.dispose();
    _profesiController.dispose();
    _usiaController.dispose();
    _deskripsiController.dispose();
    _videoController.dispose();
    _igController.dispose();
    _linkedinController.dispose();
    _fbController.dispose();
    _twitterController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!widget.photoOnly &&
        (_namaController.text.trim().isEmpty || _nomorUrutController.text.trim().isEmpty)) {
      setState(() => _showError = true);
      return;
    }

    setState(() => _saving = true);

    final success = await widget.onSave(widget.photoOnly
      ? {'foto': _foto}
      : {
          'nomor_urut': _nomorUrutController.text.trim(),
          'nama_finalis': _namaController.text.trim(),
          'nama_tambahan': _namaTambahanController.text.trim(),
          'profesi': _profesiController.text.trim(),
          'usia': _usiaController.text.trim(),
          'deskripsi': _deskripsiController.text.trim(),
          'video_profile': _videoController.text.trim(),
          'instagram': _igController.text.trim(),
          'linkedin': _linkedinController.text.trim(),
          'facebook': _fbController.text.trim(),
          'twitter': _twitterController.text.trim(),
          'foto': _foto,
        });

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.only(top: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.photoOnly
                            ? (bahasa['ganti_foto'] ?? 'Ganti Foto')
                            : (bahasa['tambah_finalis'] ?? 'Tambah Finalis'),
                          style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: Colors.grey.shade200),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bahasa['foto_finalis_upper'] ?? 'FOTO FINALIS',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600], fontSize: 12, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: () async {
                            final f = await widget.pickImage();
                            if (f != null) setState(() => _foto = f);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 150,
                            child: AspectRatio(
                              aspectRatio: 4 / 5,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                  color: Colors.grey.shade50,
                                ),
                                child: _foto != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(_foto!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                                    )
                                  : (_existingFotoUrl != null && _existingFotoUrl!.isNotEmpty)
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          _existingFotoUrl!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                          errorBuilder: (context, error, stackTrace) => _fotoPlaceholder(),
                                        ),
                                      )
                                    : _fotoPlaceholder(),
                              ),
                            ),
                          ),
                        ),
                      ),

                      if (!widget.photoOnly) ...[
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _field(
                                label: bahasa['nama_finalis'] ?? 'Nama Finalis',
                                required: true,
                                controller: _namaController,
                                hint: bahasa['nama_finalis_hint'] ?? 'Nama finalis',
                                error: _showError && _namaController.text.trim().isEmpty,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(
                                label: bahasa['nomor_urut'] ?? 'Nomor Urut',
                                required: true,
                                controller: _nomorUrutController,
                                hint: bahasa['contoh_1'] ?? 'Contoh: 1',
                                keyboardType: TextInputType.number,
                                error: _showError && _nomorUrutController.text.trim().isEmpty,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        Text(
                          bahasa['opsional_upper'] ?? 'OPSIONAL',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600], fontSize: 12, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 12),
                        _field(
                          label: bahasa['nama_tambahan'] ?? 'Nama Tambahan',
                          controller: _namaTambahanController,
                          hint: bahasa['masukkan_nama_tambahan'] ?? 'Masukkan Nama Tambahan',
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _field(
                                label: bahasa['profesi_aktivitas'] ?? 'Profesi / Aktivitas',
                                controller: _profesiController,
                                hint: bahasa['masukkan_profesi'] ?? 'Masukkan Profesi',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(
                                label: bahasa['usia'] ?? 'Usia',
                                controller: _usiaController,
                                hint: bahasa['masukkan_usia'] ?? 'Masukkan Usia',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        Text(
                          bahasa['deskripsi_biografi'] ?? 'DESKRIPSI / BIOGRAFI',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600], fontSize: 12, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 12),
                        _field(
                          label: bahasa['deskripsi'] ?? 'Deskripsi',
                          controller: _deskripsiController,
                          hint: bahasa['deskripsi_singkat'] ?? 'Deskripsi singkat...',
                          maxLines: 4,
                        ),

                        const SizedBox(height: 16),
                        _field(
                          label: bahasa['video_profile'] ?? 'Video Profile',
                          controller: _videoController,
                          hint: 'URL YouTube / Drive',
                        ),

                        const SizedBox(height: 20),
                        Text(bahasa['social_media_title'] ?? 'Social Media', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _field(label: 'Instagram', controller: _igController, hint: '@ username')),
                            const SizedBox(width: 12),
                            Expanded(child: _field(label: 'LinkedIn', controller: _linkedinController, hint: bahasa['masukkan'] ?? 'Masukkan')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _field(label: 'Facebook', controller: _fbController, hint: bahasa['masukkan'] ?? 'Masukkan')),
                            const SizedBox(width: 12),
                            Expanded(child: _field(label: 'X / Twitter', controller: _twitterController, hint: '@ username')),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100))),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(bahasa['batal'] ?? 'Batal', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check, size: 18),
                        label: Text(
                          _saving ? (bahasa['menyimpan'] ?? 'Menyimpan...') : (bahasa['simpan'] ?? 'Simpan'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool required = false,
    bool showLabel = true,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool error = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Text.rich(
            TextSpan(
              text: label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
              children: [if (required) const TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: error ? Colors.red : Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: error ? Colors.red : const Color(0xFFDC2626)),
            ),
          ),
        ),
      ],
    );
  }
}