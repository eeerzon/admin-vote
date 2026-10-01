// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:admin_vote_mobile/helper/global_function.dart';
import 'package:admin_vote_mobile/helper/global_var.dart';
import 'package:admin_vote_mobile/helper/global_widget.dart';
import 'package:admin_vote_mobile/helper/loading_page.dart';
import 'package:admin_vote_mobile/helper/qr_zip_helper.dart';
import 'package:admin_vote_mobile/pages/voteSaya/fitur_vote.dart';
import 'package:admin_vote_mobile/pages/voteSaya/new_vote.dart';
import 'package:admin_vote_mobile/pages/voteSaya/setting_vote.dart';
import 'package:admin_vote_mobile/services/api_services.dart';
import 'package:admin_vote_mobile/services/lang_service.dart';
import 'package:admin_vote_mobile/services/storage_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class DetailVotePage extends StatefulWidget {
  final String idVote;
  const DetailVotePage({super.key, required this.idVote});

  @override
  State<DetailVotePage> createState() => _DetailVotePageState();
}

class _DetailVotePageState extends State<DetailVotePage> {
  String? token;
  String? langCode;
  String? userName;
  String? judulVote;
  Map<String, dynamic> bahasa = {};

  bool isLoading = true;
  Map<String, dynamic>? voteData;
  
  bool isFinalisLoading = true;
  bool isFinalisLoadingMore = false;
  bool hasMoreFinalis = true;
  List<dynamic> finalisList = [];
  int finalisCurrentPage = 1;
  String finalisSearch = '';

  final _searchController = TextEditingController();
  final ScrollController _pageScrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      await _getBahasa();
      await _loadDetailVote();
    });

    _pageScrollController.addListener(_onPageScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _pageScrollController.removeListener(_onPageScroll);
    _pageScrollController.dispose();
    super.dispose();
  }

  void _onPageScroll() {
    if (_pageScrollController.position.pixels >=
        _pageScrollController.position.maxScrollExtent - 200) {
      _loadMoreFinalis();
    }
  }

  Future<void> _getBahasa() async {
    if (!mounted) return;
    final templangCode = await StorageService.getLanguage();
    if (!mounted) return;
    setState(() => langCode = templangCode);

    final tempbahasa = await LangService.getJsonData(langCode!, "bahasa");
    final storedUserData = await StorageService.getUser();
    final storedToken = await StorageService.getToken();

    if (!mounted) return;
    setState(() {
      bahasa = tempbahasa;
      userName = storedUserData['name'] ?? '';
      token = storedToken;
    });
  }

  Future<void> _loadDetailVote() async {
    final valid = await isTokenStillValid(token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }

    final result = await ApiService.get(
      '/api/v1/votes/${widget.idVote}',
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return;
    setState(() {
      voteData = result?['data']?['vote'];
      isLoading = false;
      judulVote = result?['data']?['vote']['judul_vote'];
    });

    await _loadFinalis();
  }

  Future<void> _loadFinalis({bool resetPage = true}) async {
    if (resetPage) {
      finalisCurrentPage = 1;
      hasMoreFinalis = true;
    }

    setState(() => isFinalisLoading = true);

    final valid = await isTokenStillValid(token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }

    final result = await ApiService.get(
      '/api/v1/votes/${widget.idVote}/finalis/list?page=$finalisCurrentPage&search=$finalisSearch',
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return;

    final List<dynamic> newData = result?['data']?['data'] ?? [];
    final int? lastPage = result?['data']?['last_page'];

    setState(() {
      finalisList = newData;
      hasMoreFinalis = lastPage != null ? finalisCurrentPage < lastPage : newData.isNotEmpty;
      isFinalisLoading = false;
    });
  }

  Future<void> _loadMoreFinalis() async {
    if (!hasMoreFinalis || isFinalisLoadingMore || isFinalisLoading) return;

    setState(() => isFinalisLoadingMore = true);
    finalisCurrentPage++;

    final valid = await isTokenStillValid(token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }

    final result = await ApiService.get(
      '/api/v1/votes/${widget.idVote}/finalis/list?page=$finalisCurrentPage&search=$finalisSearch',
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return;

    final List<dynamic> newData = result?['data']?['data'] ?? [];
    final int? lastPage = result?['data']?['last_page'];

    setState(() {
      finalisList.addAll(newData);
      hasMoreFinalis = lastPage != null ? finalisCurrentPage < lastPage : newData.isNotEmpty;
      isFinalisLoadingMore = false;
    });
  }

  String _extractErrorMessage(Map<String, dynamic>? result) {
    final message = result?['message'];
    if (message is String && message.isNotEmpty) return message;

    final errors = result?['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final firstError = errors.values.first;
      if (firstError is List && firstError.isNotEmpty) return firstError.first.toString();
      if (firstError is String) return firstError;
    }

    return bahasa['error'] ?? 'Terjadi kesalahan';
  }

  Future<bool> _confirmDialog({required String message}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade300),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(bahasa['tidak'] ?? 'Tidak'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(bahasa['ya'] ?? 'Ya'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<File?> _pickImageFile() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return null;

    final file = File(picked.path);
    final sizeInMb = await file.length() / (1024 * 1024);
    if (sizeInMb > 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(bahasa['ukuran_file_terlalu_besar'] ?? 'Ukuran file maksimal 10MB')),
        );
      }
      return null;
    }
    return file;
  }

  Map<String, dynamic> _finalisInitialData(Map<String, dynamic> finalis) {
    String s(dynamic v) => v == null ? '' : v.toString();
    return {
      'id_finalis': finalis['id_finalis']?.toString(),
      'nama_finalis': s(finalis['nama_finalis']),
      'nama_tambahan': s(finalis['nama_tambahan']),
      'usia': s(finalis['usia']),
      'profesi': s(finalis['profesi']),
      'nomor_urut': s(finalis['nomor_urut']),
      'deskripsi': s(finalis['deskripsi']),
      'video_profile': s(finalis['video_profile']),
      'facebook': s(finalis['facebook']),
      'instagram': s(finalis['instagram']),
      'linkedin': s(finalis['linkedin']),
      'twitter': s(finalis['twitter']),
      'foto_url': finalis['poster_finalis'],
    };
  }

  void _openTambahFinalisSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TambahFinalisSheet(
        bahasa: bahasa,
        pickImage: _pickImageFile,
        onSave: _createFinalisApi,
      ),
    );
  }

  void _openTambahBanyakFinalisSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TambahBanyakFinalisSheet(
        bahasa: bahasa,
        onSaveMultiple: _createFinalisBulkApi,
      ),
    );
  }

  Future<bool> _createFinalisApi(Map<String, dynamic> data) async {
    final valid = await isTokenStillValid(token);
    if (!mounted) return false;
    if (!valid) {
      await forceLogoutToLogin(context);
      return false;
    }

    String? posterTempId;
    final foto = data['foto'] as File?;
    if (foto != null) {
      final uploadResult = await ApiService.postMultipart(
        '/api/v1/create-vote/${widget.idVote}/step3/finalis/upload-poster',
        fieldName: 'poster',
        file: foto,
        token: token,
        xLanguage: langCode,
      );
      if (!mounted) return false;
      if (uploadResult?['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_extractErrorMessage(uploadResult))),
        );
        return false;
      }
      posterTempId = uploadResult?['data']?['temp_id']?.toString() ?? uploadResult?['data']?['id']?.toString();
    }

    final body = {
      "nama_finalis": data['nama_finalis'],
      "nomor_urut": int.tryParse(data['nomor_urut']?.toString() ?? '') ?? 0,
      "nama_tambahan": data['nama_tambahan'],
      "profesi": data['profesi'],
      "deskripsi": data['deskripsi'],
      "usia": int.tryParse(data['usia']?.toString() ?? '') ?? 0,
      "video_profile": data['video_profile'],
      "instagram": data['instagram'],
      "facebook": data['facebook'],
      "twitter": data['twitter'],
      "linkedin": data['linkedin'],
      if (posterTempId != null) "poster_temp_id": posterTempId,
    };

    final result = await ApiService.post(
      '/api/v1/create-vote/${widget.idVote}/step3/finalis',
      body: body,
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return false;

    if (result?['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_extractErrorMessage(result))),
      );
      return false;
    }

    await _loadFinalis();
    return true;
  }

  Future<bool> _createFinalisBulkApi(List<Map<String, dynamic>> rows) async {
    final valid = await isTokenStillValid(token);
    if (!mounted) return false;
    if (!valid) {
      await forceLogoutToLogin(context);
      return false;
    }

    final body = {
      "finalis": rows.map((r) => {
        "nama_finalis": r['nama_finalis'],
        "nomor_urut": int.tryParse(r['nomor_urut']?.toString() ?? '') ?? 0,
        "nama_tambahan": r['nama_tambahan'],
        "profesi": r['profesi'],
        "usia": int.tryParse(r['usia']?.toString() ?? '') ?? 0,
        "instagram": r['instagram'],
        "facebook": r['facebook'],
        "twitter": r['twitter'],
        "linkedin": r['linkedin'],
        "deskripsi": r['deskripsi'],
        "video_profile": r['video_profile'],
      }).toList(),
    };

    final result = await ApiService.post(
      '/api/v1/create-vote/${widget.idVote}/step3/finalis/bulk',
      body: body,
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return false;

    if (result?['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_extractErrorMessage(result))),
      );
      return false;
    }

    await _loadFinalis();
    return true;
  }

  void _openEditFinalisSheet(Map<String, dynamic> finalis) {
    final idFinalis = finalis['id_finalis']?.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TambahFinalisSheet(
        bahasa: bahasa,
        pickImage: _pickImageFile,
        initialData: _finalisInitialData(finalis),
        onSave: (data) => _updateFinalisApi(idFinalis, data),
      ),
    );
  }

  void _openGantiFotoSheet(Map<String, dynamic> finalis) {
    final idFinalis = finalis['id_finalis']?.toString();
    final initialData = _finalisInitialData(finalis);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TambahFinalisSheet(
        bahasa: bahasa,
        pickImage: _pickImageFile,
        initialData: initialData,
        photoOnly: true,
        onSave: (data) => _updateFinalisApi(idFinalis, {
          ...initialData,
          'foto': data['foto'],
        }),
      ),
    );
  }

  Future<bool> _updateFinalisApi(String? idFinalis, Map<String, dynamic> data, {String? flagAktif}) async {
    if (idFinalis == null || idFinalis.isEmpty) return false;

    final valid = await isTokenStillValid(token);
    if (!mounted) return false;
    if (!valid) {
      await forceLogoutToLogin(context);
      return false;
    }

    String? posterTempId;
    final foto = data['foto'] as File?;
    if (foto != null) {
      final uploadResult = await ApiService.postMultipart(
        '/api/v1/create-vote/${widget.idVote}/step3/finalis/upload-poster',
        fieldName: 'poster',
        file: foto,
        token: token,
        xLanguage: langCode,
      );
      if (!mounted) return false;
      if (uploadResult?['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_extractErrorMessage(uploadResult))),
        );
        return false;
      }
      posterTempId = uploadResult?['data']?['temp_id']?.toString() ?? uploadResult?['data']?['id']?.toString();
    }

    final body = {
      "nama_finalis": data['nama_finalis'],
      "nomor_urut": int.tryParse(data['nomor_urut']?.toString() ?? '') ?? 0,
      "nama_tambahan": data['nama_tambahan'],
      "profesi": data['profesi'],
      "deskripsi": data['deskripsi'],
      "usia": int.tryParse(data['usia']?.toString() ?? '') ?? 0,
      "video_profile": data['video_profile'],
      "instagram": data['instagram'],
      "facebook": data['facebook'],
      "twitter": data['twitter'],
      "linkedin": data['linkedin'],
      if (posterTempId != null) "poster_temp_id": posterTempId,
      if (flagAktif != null) "flag_aktif": flagAktif,
    };

    showLoadingDialog(context, bahasa['memproses'] ?? 'Memproses...');

    final result = await ApiService.put(
      '/api/v1/create-vote/${widget.idVote}/step3/finalis/$idFinalis',
      body: body,
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return false;
    hideLoadingDialog(context);

    if (result?['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_extractErrorMessage(result))),
      );
      return false;
    }

    await _loadFinalis();
    return true;
  }

  Future<void> _handleDeleteFinalis(Map<String, dynamic> finalis) async {
    final idFinalis = finalis['id_finalis']?.toString();
    if (idFinalis == null || idFinalis.isEmpty) return;

    final confirmed = await _confirmDialog(
      message: bahasa['yakin_hapus_finalis'] ?? 'Yakin ingin menghapus finalis ini?',
    );
    if (!confirmed) return;

    final valid = await isTokenStillValid(token);
    if (!mounted) return;
    if (!valid) {
      await forceLogoutToLogin(context);
      return;
    }

    showLoadingDialog(context, bahasa['memproses'] ?? 'Memproses...');

    final result = await ApiService.delete(
      '/api/v1/create-vote/${widget.idVote}/step3/finalis/$idFinalis',
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return;
    hideLoadingDialog(context);

    if (result?['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_extractErrorMessage(result))),
      );
      return;
    }

    await _loadFinalis();
  }

  Future<void> _handleToggleFinalis(Map<String, dynamic> finalis) async {
    final idFinalis = finalis['id_finalis']?.toString();
    if (idFinalis == null || idFinalis.isEmpty) return;

    final isActive = finalis['flag_aktif'] == '1';
    final confirmed = await _confirmDialog(
      message: isActive
        ? (bahasa['yakin_nonaktifkan_finalis'] ?? 'Yakin ingin menonaktifkan finalis ini?')
        : (bahasa['yakin_aktifkan_finalis'] ?? 'Yakin ingin mengaktifkan finalis ini?'),
    );
    if (!confirmed) return;

    await _updateFinalisApi(
      idFinalis,
      _finalisInitialData(finalis),
      flagAktif: isActive ? '0' : '1',
    );
  }

  Future<void> _downloadSemuaQr() async {
    final slug = voteData?['slug']?.toString();
    if (slug == null || slug.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(bahasa['error'] ?? 'Terjadi kesalahan')),
      );
      return;
    }

    final valid = await isTokenStillValid(token);
    if (!mounted) return;
    if (!valid) {
      await forceLogoutToLogin(context);
      return;
    }

    await exportFinalisQrZip(
      context: context,
      idVote: widget.idVote,
      slug: slug,
      token: token,
      langCode: langCode,
    );
  }

  Future<void> _downloadSingleQr(Map<String, dynamic> finalis) async {
    final slug = voteData?['slug']?.toString();
    final idFinalis = finalis['id_finalis']?.toString();
    if (slug == null || slug.isEmpty || idFinalis == null || idFinalis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(bahasa['error'] ?? 'Terjadi kesalahan')),
      );
      return;
    }

    await exportSingleFinalisQr(
      context: context,
      slug: slug,
      idFinalis: idFinalis,
      namaFinalis: (finalis['nama_finalis'] ?? 'finalis').toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            Expanded(
              child: isLoading ? _buildSkeleton() : _buildContent(),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              bahasa['detail_vote'] ?? 'Detail Vote',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),

          buildIconCircle(
            child: Text(
              getInitial(userName ?? 'K'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFE04E39),
              ),
            ),
            bgColor: const Color(0xFFFDEDEA),
            onTap: () => showLogoutMenu(context, token!),
          ),
        ],
      ),
    );
  }

  void showLogoutMenu(BuildContext context, String token) {
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
      if (value == 'logout') {
        confirmLogout(context, token);
      }
    });
  }

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 4 / 5,
                  child: Skeleton(width: double.infinity, height: double.infinity, borderRadius: 0),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(width: 200, height: 20, borderRadius: 8),

                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Skeleton(width: 80, height: 22, borderRadius: 12),
                          const SizedBox(width: 8),
                          Skeleton(width: 100, height: 22, borderRadius: 12),
                        ],
                      ),

                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: Skeleton(width: double.infinity, height: 40, borderRadius: 12)),
                          const SizedBox(width: 8),
                          Expanded(child: Skeleton(width: double.infinity, height: 40, borderRadius: 12)),
                        ],
                      ),

                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Skeleton(width: 30, height: 22, borderRadius: 8),

                          const SizedBox(width: 8,),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Skeleton(width: 150, height: 20, borderRadius: 8),
                              const SizedBox(height: 8),
                              Skeleton(width: 200, height: 20, borderRadius: 8),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Skeleton(width: 30, height: 22, borderRadius: 8),

                          const SizedBox(width: 8,),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Skeleton(width: 150, height: 20, borderRadius: 8),
                              const SizedBox(height: 8),
                              Skeleton(width: 200, height: 20, borderRadius: 8),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Skeleton(width: 30, height: 22, borderRadius: 8),

                          const SizedBox(width: 8,),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Skeleton(width: 150, height: 20, borderRadius: 8),
                              const SizedBox(height: 8),
                              Skeleton(width: 200, height: 20, borderRadius: 8),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final vote = voteData ?? {};

    return SingleChildScrollView(
      controller: _pageScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEventCard(vote),
          const SizedBox(height: 20),
          _buildMenuGrid(),
          const SizedBox(height: 20),
          _buildFinalisSection(),
          const SizedBox(height: 20),

          if (!isFinalisLoading &&
              !isFinalisLoadingMore &&
              !hasMoreFinalis &&
              finalisList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(0),
              child: Center(
                child: Text(
                  bahasa['no_more'] ?? 'Tidak ada data lagi',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> vote) {
    bool isAktif = false;
    String jenisVote = vote['jenis_vote'] ?? '-';
    if (jenisVote == 'free') {
      jenisVote = bahasa['voting_free'] ?? 'Voting Gratis';
    } else if (jenisVote == 'paid') {
      jenisVote = bahasa['voting_paid'] ?? 'Voting Berbayar';
    } else {
      jenisVote = '-';
    }

    String flagAktif = vote['flag_aktif'] ?? '0';
    if (flagAktif == '1') {
      flagAktif = bahasa['aktif'] ?? 'Aktif';
      isAktif = true;
    } else {
      flagAktif = bahasa['nonaktif'] ?? 'Nonaktif';
      isAktif = false;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //banner
          AspectRatio(
            aspectRatio: 4 / 5,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                vote['banner'] ?? '',
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }

                  return Skeleton(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 0,
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: Image.asset('assets/images/img_broken.jpg'),
                  );
                },
              ),
            ),
          ),

          //konten
          SizedBox(height: 12,),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vote['judul_vote'] ?? '-',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                SizedBox(height: 12,),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAktif ? Colors.green.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        flagAktif,
                        style: TextStyle(color: isAktif ? Colors.green : Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ),

                    SizedBox(width: 10,),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        jenisVote
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NewVotePage(editTrayId: widget.idVote),
                              ),
                            );
                          },
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Edit Vote',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () {

                          },
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${bahasa['Lihat'] ?? 'Lihat'} Vote',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 20,
                      color: Colors.grey,
                    ),

                    SizedBox(width: 8,),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bahasa['durasi_vote'] ?? 'Durasi Vote',
                          style: TextStyle(color: Colors.grey),
                        ),
                        
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            buildAdaptiveDateText(
                              langCode,
                              vote['tanggal_buka_vote']?.toString(),
                            ),
                            Text(' - '),
                            buildAdaptiveDateText(
                              langCode,
                              vote['tanggal_tutup_vote']?.toString(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 22,
                      color: Colors.grey,
                    ),

                    SizedBox(width: 8,),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                        'Grand Final',
                          style: TextStyle(color: Colors.grey),
                        ),
                        
                        Text(
                          '${vote['lokasi_nama_tempat'] ?? '-'}, ${vote['lokasi_alamat'] ?? '-'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          formatDateVariants(langCode, vote['tanggal_grandfinal_mulai']?.toString())['long_text']!,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.attach_money_outlined,
                      size: 22,
                      color: Colors.grey,
                    ),

                    SizedBox(width: 8,),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bahasa['harga_per_vote'] ?? 'Harga per Vote',
                          style: TextStyle(color: Colors.grey),
                        ),
                        
                        Text(
                          formatCurrency(vote['harga'] ?? 0, vote['currency']),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildIconCircle(
                      child: Text(
                        getInitial(userName ?? 'K'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE04E39),
                        ),
                      ),
                      bgColor: const Color(0xFFFDEDEA),
                      onTap: () => showLogoutMenu(context, token!),
                    ),

                    SizedBox(width: 8,),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bahasa['penyelenggara'] ?? 'Diselenggarakan Oleh',
                          style: TextStyle(color: Colors.grey),
                        ),
                        
                        Text(
                          userName!,
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Text(
                  bahasa['tautan_vote'] ?? 'Tautan Vote',
                  style: TextStyle(color: Colors.grey),
                ),

                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.link, size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$baseUrl/voting/${vote['slug']}',
                          style: TextStyle(color: Colors.black),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: '$baseUrl/voting/${vote['slug']}'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(bahasa['link_disalin'] ?? 'Link disalin')),
                          );
                        },
                        child: Text(
                          bahasa['salin'] ?? 'Salin',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid() {
    return Column(
      children: [
        _buildMenuItem(
          title: bahasa['bot_nav_4'] ?? 'Pengaturan',
          desc: bahasa['pengaturan_desc'] ??
              'Kelola pengaturan voting, tampilan, dan pembayaran.',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SettingVote(JudulVote: judulVote ?? '-', idVote: widget.idVote, finalisList: finalisList,)),
            );
          },
        ),
        const SizedBox(height: 20),
        _buildMenuItem(
          title: "${bahasa['fitur_vote'] ?? 'Fitur Vote'} 🚀",
          desc: bahasa['fitur_vote_desc'] ??
              'Tingkatkan antusiasme voting dengan promo menarik untuk voter selama periode tertentu.',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => FiturVotePage(idVote: widget.idVote, judulVote: judulVote ?? '-')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required String title,
    required String desc,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalisSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bahasa['daftar_finalis'] ?? 'Daftar Finalis',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            bahasa['daftar_finalis_desc'] ?? 'Lengkapi data finalis yang akan mengikuti voting.',
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: _buildActionChip(
                    icon: Icons.upload_file_outlined,
                    label: bahasa['tambah_banyak'] ?? 'Tambah Banyak',
                    onTap: _openTambahBanyakFinalisSheet,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionChip(
                    icon: Icons.add,
                    label: bahasa['tambah_finalis'] ?? 'Tambah Finalis',
                    filled: true,
                    onTap: _openTambahFinalisSheet,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildActionChip(
            icon: Icons.qr_code_2_outlined,
            label: bahasa['download_semua_qr'] ?? 'Download Semua QR',
            width: double.infinity,
            onTap: _downloadSemuaQr,
          ),

          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            onSubmitted: (value) {
              _searchDebounce?.cancel();
              finalisSearch = value;
              _loadFinalis(resetPage: true);
            },
            onChanged: (value) {
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 500), () {
                if (!mounted) return;
                finalisSearch = value;
                _loadFinalis(resetPage: true);
              });
            },
            decoration: InputDecoration(
              hintText: bahasa['search_finalis'] ?? 'Cari finalis...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey[400]),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDC2626)),
              ),
            ),
          ),

          const SizedBox(height: 20),
          isFinalisLoading
              ? Column(
                  children: [
                    _buildFinalisItemSkeleton(),
                    const SizedBox(height: 20),
                    _buildFinalisItemSkeleton(),
                  ],
                )
              : finalisList.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          bahasa['no_finalis'] ?? 'Belum ada finalis',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        ...finalisList.map((f) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildFinalisItem(f),
                            )),
                        if (isFinalisLoadingMore)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(child: CircularProgressIndicator(color: Color(0xFFDC2626))),
                          ),
                      ],
                    ),
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    double? width,
    bool filled = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? const Color(0xFFDC2626) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: filled ? null : Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: width != null ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: filled ? Colors.white : Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: filled ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalisItemSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(50), child: Skeleton(width: 30, height: 30, borderRadius: 8)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 100, height: 20, borderRadius: 4),
                    const SizedBox(height: 6),
                    Skeleton(width: 70, height: 20, borderRadius: 4),
                    const SizedBox(height: 6),
                    Skeleton(width: 70, height: 20, borderRadius: 4),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Foto finalis
              Expanded(
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 4 / 5,
                      child: Skeleton(width: double.infinity, height: double.infinity, borderRadius: 12)
                    ),
                    const SizedBox(height: 10),
                    Skeleton(width: double.infinity, height: 22, borderRadius: 4),
                    
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // QR Code
              Expanded(
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Skeleton(width: double.infinity, height: double.infinity, borderRadius: 12)
                    ),
                    const SizedBox(height: 10),
                    Skeleton(width: double.infinity, height: 22, borderRadius: 4),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Skeleton(width: 70, height: 20, borderRadius: 4),
              Divider(),
              Skeleton(width: 70, height: 20, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinalisItem(Map<String, dynamic> finalis) {
    final isActive = finalis['flag_aktif'] == '1';
    final hasPoster = finalis['poster_finalis'] != null && finalis['poster_finalis'].toString().isNotEmpty;
    final hasVotes = toInt(finalis['total_voters']) > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: #nomor + nama + nama tambahan + profesi + menu "..."
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    "#${(finalis['nomor_urut'] ?? 0).toString().padLeft(2, '0')}",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        finalis['nama_finalis'] ?? '-',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      if (finalis['nama_tambahan'] != null && finalis['nama_tambahan'].toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          finalis['nama_tambahan'],
                          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                        ),
                      ],
                      if (finalis['profesi'] != null && finalis['profesi'].toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          finalis['profesi'],
                          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz, color: Colors.grey[500]),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _openEditFinalisSheet(finalis);
                    } else if (value == 'delete') {
                      _handleDeleteFinalis(finalis);
                    } else if (value == 'toggle') {
                      _handleToggleFinalis(finalis);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(bahasa['edit'] ?? 'Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(isActive
                              ? (bahasa['nonaktifkan'] ?? 'Nonaktifkan')
                              : (bahasa['aktifkan'] ?? 'Aktifkan')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      enabled: !hasVotes,
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: hasVotes ? Colors.grey.shade300 : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            bahasa['hapus'] ?? 'Hapus',
                            style: TextStyle(color: hasVotes ? Colors.grey.shade400 : Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Foto + QR side by side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Foto finalis
              Expanded(
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 4 / 5,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: hasPoster
                            ? Image.network(
                                finalis['poster_finalis'],
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Skeleton(width: double.infinity, height: double.infinity, borderRadius: 0);
                                },
                                errorBuilder: (context, error, stackTrace) => Center(
                                  child: Text(
                                    bahasa['no_photo'] ?? 'No Photo',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  bahasa['no_photo'] ?? 'No Photo',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _openGantiFotoSheet(finalis),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.red.shade200),
                          foregroundColor: const Color(0xFFDC2626),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          bahasa['ganti_foto'] ?? 'Ganti Foto',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // QR Code
              Expanded(
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 4 / 5,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: _buildQrImage(finalis),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _downloadSingleQr(finalis),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey.shade200),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.grey[700],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          bahasa['unduh_qr'] ?? 'Unduh QR',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Footer: badge Aktif/Nonaktif + Votes count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFECFDF5) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive
                      ? (bahasa['aktif'] ?? 'Aktif')
                      : (bahasa['nonaktif'] ?? 'Nonaktif'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive ? const Color(0xFF059669) : Colors.grey[700],
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    "${bahasa['votes'] ?? 'Votes'} ",
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  Text(
                    thousandSeparator(toInt(finalis['total_voters'])),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQrImage(Map<String, dynamic> finalis) {
    final slug = voteData?['slug'];
    final idFinalis = finalis['id_finalis'];

    if (slug == null || idFinalis == null) {
      return Center(
        child: Icon(Icons.qr_code_2, size: 80, color: Colors.grey[300]),
      );
    }

    final targetUrl = '$baseUrl/voting/$slug/finalis/$idFinalis';
    final encodedUrl = Uri.encodeComponent(targetUrl);
    // ecc=H untuk toleransi kerusakan tinggi, size besar untuk modul QR lebih tebal
    final qrImageUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=400x400&ecc=H&data=$encodedUrl';

    return LayoutBuilder(
      builder: (context, constraints) {
        final qrSize = constraints.maxWidth;
        final logoSize = qrSize * 0.30;

        return Stack(
          alignment: Alignment.center,
          children: [
            Image.network(
              qrImageUrl,
              width: qrSize,
              height: qrSize,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Icon(Icons.qr_code_2, size: 80, color: Colors.grey[300]),
                );
              },
            ),
            Container(
              width: logoSize,
              height: logoSize,
              padding: EdgeInsets.all(logoSize * 0.12),
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/kreenmobileiconrounded.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}