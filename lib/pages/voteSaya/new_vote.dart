// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:admin_vote_mobile/helper/global_function.dart';
import 'package:admin_vote_mobile/helper/global_var.dart';
import 'package:admin_vote_mobile/helper/global_widget.dart';
import 'package:admin_vote_mobile/helper/loading_page.dart';
import 'package:admin_vote_mobile/pages/voteSaya/detail_vote.dart';
import 'package:admin_vote_mobile/services/api_services.dart';
import 'package:admin_vote_mobile/services/lang_service.dart';
import 'package:admin_vote_mobile/services/storage_services.dart';
import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class NewVotePage extends StatefulWidget {
  final void Function(int index)? onNavigateToTab;
  // Diisi kalau buka wizard ini untuk EDIT vote yang sudah ada (draft).
  // trayId create-vote ternyata sama dengan id_vote yang sudah ada, jadi
  // tidak perlu hit /init lagi - langsung dipakai sebagai trayId.
  final String? editTrayId;
  const NewVotePage({
    super.key,
    this.onNavigateToTab,
    this.editTrayId,
  });

  @override
  State<NewVotePage> createState() => NewVotePageState();
}

class NewVotePageState extends State<NewVotePage> {
  String? token;
  String? langCode;
  String? userName;
  Map<String, dynamic> bahasa = {};

  bool isLoading = true;

  int currentStep = 1;
  int? _lastScrolledStep;
  // Mode edit - snapshot per step buat deteksi ada perubahan atau tidak,
  // supaya "Lanjut" gak hit API simpan kalau gak ada yang diubah.
  final Map<int, String> _stepSnapshots = {};
  final ScrollController _stepScrollController = ScrollController();
  bool _showError = false;

  // Step 1
  String? trayId;
  String? resultIdVote;
  String? jenisVote; // 'free' | 'paid'
  String? kategoriVote;
  List<dynamic> kategoriList = [];
  String? webCategory; // '0' | '1'
  bool errCodejenisVote = true;
  bool errCodekategoriVote = true;
  bool errCodeWebCategory = true;
  String? textErrJenisVote, textErrKategoriVote, textErrPlatform;

  // Step 2
  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _syaratKetentuanController = TextEditingController();
  final _tanggalBukaController = TextEditingController();
  final _tanggalTutupController = TextEditingController();
  final _tanggalGrandFinalController = TextEditingController();
  final _namaTempatController = TextEditingController();
  final _waktuMulaiController = TextEditingController();
  final _waktuSelesaiController = TextEditingController();
  final _alamatController = TextEditingController();
  final _hargaController = TextEditingController();
  // final _minimalPembelianController = TextEditingController();
  final _namaPenyelenggaraController = TextEditingController();
  String zonaWaktu = 'WIB';
  String mataUang = 'IDR';
  DateTime? tanggalBukaVote;
  DateTime? tanggalTutupVote;
  DateTime? tanggalGrandFinal;
  TimeOfDay? waktuMulaiGf;
  TimeOfDay? waktuSelesaiGf;
  bool aktifkanPaket = false;
  String jenisPaket = 'diskon'; // 'diskon' | 'fix'
  String tipeDiskon = 'persen'; // 'persen' | 'flat'
  List<Map<String, TextEditingController>> paketList = [];
  File? posterVoteImage;
  File? logoPenyelenggaraImage;
  final ImagePicker _imagePicker = ImagePicker();
  List<Map<String, dynamic>> categoryList = [];

  // URL gambar yang sudah tersimpan di server (mode edit) - dipakai sebagai
  // preview selama user belum pilih file baru untuk menggantinya.
  String? existingBannerUrl;
  String? existingLogoPenyelenggaraUrl;
  String? existingMascotUrl;
  String? existingHeroBannerUrl;
  String? existingSponsor1Url;
  String? existingSponsor2Url;
  String? existingSponsor3Url;

  // Step 3 - Finalis
  List<Map<String, dynamic>> finalisList = [];
  String finalisSearch = '';

  // Step 3 (khusus webCategory == '1') - Setup Custom Web
  final _linkVotingController = TextEditingController();
  String bahasaVote = 'id'; // 'id' | 'en' | 'th' | 'ms'
  File? mascotImage;
  File? heroBannerImage;
  final _deskripsiFooterController = TextEditingController();
  int themeId = 0;
  List<Map<String, dynamic>> voteThemes = [];
  List<Map<String, dynamic>> voteTemplates = [];
  bool _stepWebInitLoading = false;
  bool _stepWebInitLoaded = false;
  bool _stepWebInitError = false;
  final _judulVideoTutorialController = TextEditingController();
  final _urlVideoTutorialController = TextEditingController();
  bool faqAktif = false;
  bool teksBerjalanAktif = false;
  final _instagramController = TextEditingController();
  final _twitterController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _tiktokController = TextEditingController();
  bool sponsorAktif = false;
  List<Map<String, TextEditingController>> faqList = [];
  Color teksBerjalanColor = const Color(0xFF14B8A6);
  final _teksBerjalanController = TextEditingController();
  File? sponsorBaris1;
  File? sponsorBaris2;
  File? sponsorBaris3;

  // Step 4 - Pengaturan
  String visibilitas = 'publik'; // 'publik' | 'privat'

  // Step 4 (khusus webCategory == '0') - Pengaturan Tampilan
  String? versiTampilan = '3'; // vote_template_id, statis - API belum ready

  // Step 5 - Pengaturan Lanjutan
  bool privateVotingAktif = false;
  bool voteLiveAktif = false;
  bool fiturCountdownAktif = false;
  bool tutupHalamanVotingAktif = false;
  bool sembunyikanNomorFinalisAktif = false;
  bool notifikasiAktif = true;
  bool sembunyikanLeaderboardAktif = false;
  String urutanFinalis = 'nomor_urut'; // 'nomor_urut' | 'abjad' | 'jumlah_vote'
  bool loginRequiredAktif = false;
  bool verifikasiEmailAktif = false;
  Set<String> dataWajibPemilih = {};
  String _artikelSearch = '';
  List<Map<String, dynamic>> artikelList = [];
  String? selectedArtikelId;
  String? selectedArtikelTitle;
  bool batasanJumlahVoteAktif = false;
  final _batasQtyPerTransaksiController = TextEditingController();
  final _batasTransaksiPerVoterController = TextEditingController();
  String? indikatorBatasVote;

  static const List<Map<String, String>> _dataPemilihFields = [
    {'key': 'no_hp', 'label': 'No. HP'},
    {'key': 'nim', 'label': 'NIM'},
    {'key': 'nip', 'label': 'NIP'},
    {'key': 'nisn', 'label': 'NISN'},
    {'key': 'npwp', 'label': 'NPWP'},
    {'key': 'nik', 'label': 'NIK'},
    {'key': 'visa', 'label': 'Visa'},
    {'key': 'email', 'label': 'Email'},
    {'key': 'asal_daerah', 'label': 'Asal Daerah'},
  ];

  // Step 6 (khusus paid) - Metode Pembayaran
  String? metodePembayaran;
  bool _paymentMethodsLoading = false;
  bool _paymentMethodsLoaded = false;
  bool _paymentMethodsError = false;
  List<Map<String, dynamic>> _paymentMethods = [];
  final Set<String> _activeRegions = {'ID', 'SG', 'EU'};
  final Set<String> _selectedPaymentMethodIds = {};
  final Set<String> _customFeePaymentMethodIds = {};
  final Map<String, TextEditingController> _feeRpControllers = {};
  final Map<String, TextEditingController> _feePercentControllers = {};

  // id_category_payget -> label tampilan (dari analisa payment.json,
  // gak ada field nama kategori eksplisit di response).
  static const Map<String, String> _paymentCategoryLabels = {
    '29664654747546567': 'E-Wallet',
    '53496745345654675': 'QR Codes',
    '47384573458345763': 'Credit Card',
    '97459744754874746': 'Payment Bank',
    '63443667445675751': 'Direct Debit',
    '74736547833537363': 'Retail',
    '37438734842674574': 'Counter',
    '15345667365654345': 'Virtual Account',
    '8': 'E-Wallet',
  };

  static const List<Map<String, String>> _paymentGlobalRegions = [
    {'key': 'US', 'name': 'United States'},
  ];
  static const List<Map<String, String>> _paymentAsiaRegions = [
    {'key': 'ID', 'name': 'Indonesia'},
    {'key': 'SG', 'name': 'Singapore'},
    {'key': 'PH', 'name': 'Philippines'},
    {'key': 'MY', 'name': 'Malaysia'},
    {'key': 'TH', 'name': 'Thailand'},
  ];
  static const List<Map<String, String>> _paymentEuropeRegions = [
    {'key': 'EU', 'name': 'Eropa'},
  ];

  // Step Boost
  bool boostAktif = false;
  final _boostMulaiController = TextEditingController();
  final _boostSelesaiController = TextEditingController();
  DateTime? boostMulai;
  DateTime? boostSelesai;
  int boostMultiplier = 2;
  bool boostMengertiChecked = false;
  bool voteGratisHarianAktif = false;
  final _batasVoteGratisController = TextEditingController(text: '0');

  // Halaman sukses setelah publish (full replace, bukan bagian wizard step)
  bool _publishSuccess = false;
  int _redirectCountdown = 8;
  Timer? _redirectTimer;

  int get totalSteps => jenisVote == 'paid' ? 7 : 6;

  // Mapping step index -> label (tergantung jenis vote)
  String get stepLabel {
    if (jenisVote == 'paid') {
      switch (currentStep) {
        case 1: return bahasa['jenis_vote'] ?? 'Jenis Vote';
        case 2: return bahasa['informasi_vote'] ?? 'Informasi Vote';
        case 3: return webCategory == '1' ? (bahasa['setup_custom_web'] ?? 'Setup Custom Web') : (bahasa['finalis'] ?? 'Finalis');
        case 4: return bahasa['pengaturan'] ?? 'Pengaturan';
        case 5: return bahasa['pengaturan_lanjutan'] ?? 'Pengaturan Lanjutan';
        case 6: return bahasa['metode_pembayaran'] ?? 'Metode Pembayaran';
        case 7: return bahasa['promo_boost'] ?? 'Promo / Boost';
      }
    } else {
      switch (currentStep) {
        case 1: return bahasa['jenis_vote'] ?? 'Jenis Vote';
        case 2: return bahasa['informasi_vote'] ?? 'Informasi Vote';
        case 3: return webCategory == '1' ? (bahasa['setup_custom_web'] ?? 'Setup Custom Web') : (bahasa['finalis'] ?? 'Finalis');
        case 4: return bahasa['pengaturan'] ?? 'Pengaturan';
        case 5: return bahasa['pengaturan_lanjutan'] ?? 'Pengaturan Lanjutan';
        case 6: return bahasa['promo_boost'] ?? 'Promo / Boost';
      }
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      await _getBahasa();
      await voteInit();
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _stepScrollController.dispose();
    _judulController.dispose();
    _deskripsiController.dispose();
    _syaratKetentuanController.dispose();
    _tanggalBukaController.dispose();
    _tanggalTutupController.dispose();
    _tanggalGrandFinalController.dispose();
    _namaTempatController.dispose();
    _waktuMulaiController.dispose();
    _waktuSelesaiController.dispose();
    _alamatController.dispose();
    _hargaController.dispose();
    // _minimalPembelianController.dispose();
    _namaPenyelenggaraController.dispose();
    for (final row in paketList) {
      row['qty']?.dispose();
      row['diskon']?.dispose();
    }
    _linkVotingController.dispose();
    _deskripsiFooterController.dispose();
    _judulVideoTutorialController.dispose();
    _urlVideoTutorialController.dispose();
    _instagramController.dispose();
    _twitterController.dispose();
    _youtubeController.dispose();
    _tiktokController.dispose();
    _teksBerjalanController.dispose();
    for (final faq in faqList) {
      faq['pertanyaan']?.dispose();
      faq['jawaban']?.dispose();
    }
    _batasQtyPerTransaksiController.dispose();
    _batasTransaksiPerVoterController.dispose();
    for (final c in _feeRpControllers.values) {
      c.dispose();
    }
    for (final c in _feePercentControllers.values) {
      c.dispose();
    }
    _boostMulaiController.dispose();
    _boostSelesaiController.dispose();
    _batasVoteGratisController.dispose();
    super.dispose();
  }

  Future<void> _getBahasa() async {
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
      _namaPenyelenggaraController.text = userName!;
      token = storedToken;
    });
  }

  bool get isEditMode => widget.editTrayId != null;

  Future<void> voteInit() async {
    final valid = await isTokenStillValid(token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }

    if (isEditMode) {
      trayId = widget.editTrayId;
      await StorageService.setTrayId(trayId!);

      final categoriesResult = await ApiService.get(
        '/api/v1/create-vote/categories',
        xLanguage: langCode,
        token: token,
      );

      await _loadExistingVoteData();

      if (!mounted) return;
      setState(() {
        kategoriList = categoriesResult?['data']['kategori'];
        textErrJenisVote = bahasa['err_step_1'].replaceAll('{varible}', bahasa['jenis_vote'] ?? 'Jenis Vote');
        textErrKategoriVote = bahasa['err_step_1'].replaceAll('{varible}', bahasa['kategori_vote'] ?? 'Kategori Vote');
        textErrPlatform = bahasa['err_step_1'].replaceAll('{varible}', 'Platform');
        isLoading = false;
      });
      return;
    }

    final result = await Future.wait([
      ApiService.post('/api/v1/create-vote/init', xLanguage: langCode, token: token,),
      ApiService.get('/api/v1/create-vote/categories', xLanguage: langCode, token: token)
    ]);

    trayId = result[0]?['data']['tray_id'];
    await StorageService.setTrayId(trayId!);

    if (!mounted) return;
    setState(() {
      kategoriList = result[1]?['data']['kategori'];
      textErrJenisVote = bahasa['err_step_1'].replaceAll('{varible}', bahasa['jenis_vote'] ?? 'Jenis Vote');
      textErrKategoriVote = bahasa['err_step_1'].replaceAll('{varible}', bahasa['kategori_vote'] ?? 'Kategori Vote');
      textErrPlatform = bahasa['err_step_1'].replaceAll('{varible}', 'Platform');
      isLoading = false;
    });
  }

  Map<String, dynamic>? _dataOf(Map<String, dynamic>? result) {
    final data = result?['data'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  Map<String, dynamic>? _voteOf(Map<String, dynamic>? result) {
    final vote = _dataOf(result)?['vote'];
    return vote is Map ? Map<String, dynamic>.from(vote) : null;
  }

  String? _str(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  TimeOfDay? _parseTimeOfDay(dynamic raw) {
    final s = _str(raw);
    if (s == null) return null;
    final parts = s.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatJam(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // Mode edit - ambil semua data yang sudah tersimpan dari tiap step GET,
  // supaya wizard ini kebuka dalam kondisi terisi lengkap (bukan kosong).
  Future<void> _loadExistingVoteData() async {
    final results = await Future.wait([
      ApiService.get('/api/v1/create-vote/$trayId/step1', xLanguage: langCode, token: token),
      ApiService.get('/api/v1/create-vote/$trayId/step2', xLanguage: langCode, token: token),
      ApiService.get('/api/v1/create-vote/$trayId/step-web', xLanguage: langCode, token: token),
      ApiService.get('/api/v1/create-vote/$trayId/step3', xLanguage: langCode, token: token),
      ApiService.get('/api/v1/create-vote/$trayId/step4', xLanguage: langCode, token: token),
      ApiService.get('/api/v1/create-vote/$trayId/step5', xLanguage: langCode, token: token),
      ApiService.get('/api/v1/create-vote/$trayId/step6', xLanguage: langCode, token: token),
      ApiService.get('/api/v1/create-vote/$trayId/step-promo', xLanguage: langCode, token: token),
    ]);

    final step1 = results[0];
    final step2 = results[1];
    final stepWeb = results[2];
    final step3 = results[3];
    final step4 = results[4];
    final step5 = results[5];
    final step6 = results[6];
    final stepPromo = results[7];

    // Step 1
    final draft = _dataOf(step1)?['draft'];
    if (draft is Map) {
      jenisVote = _str(draft['jenis_vote']);
      kategoriVote = _str(draft['choose_category']);
      webCategory = _str(draft['web_category']);
    }

    // Step 2
    final vote2 = _voteOf(step2);
    if (vote2 != null) {
      _judulController.text = _str(vote2['judul_vote']) ?? '';
      _deskripsiController.text = _str(vote2['deskripsi']) ?? '';
      _syaratKetentuanController.text = _str(vote2['snk']) ?? '';
      zonaWaktu = _str(vote2['code_timezone']) ?? zonaWaktu;
      mataUang = _str(vote2['currency']) ?? mataUang;
      _namaPenyelenggaraController.text = _str(vote2['nama_penyelenggara']) ?? '';
      _namaTempatController.text = _str(vote2['lokasi_nama_tempat']) ?? '';
      _alamatController.text = _str(vote2['lokasi_alamat']) ?? '';
      if (_str(vote2['harga']) != null) _hargaController.text = vote2['harga'].toString();

      final buka = DateTime.tryParse(_str(vote2['tanggal_buka_vote']) ?? '');
      if (buka != null) {
        tanggalBukaVote = buka;
        _tanggalBukaController.text = DateFormat('dd/MM/yyyy, HH:mm').format(buka);
      }
      final tutup = DateTime.tryParse(_str(vote2['tanggal_tutup_vote']) ?? '');
      if (tutup != null) {
        tanggalTutupVote = tutup;
        _tanggalTutupController.text = DateFormat('dd/MM/yyyy, HH:mm').format(tutup);
      }
      final grandFinal = DateTime.tryParse(_str(vote2['tanggal_grandfinal_mulai']) ?? '');
      if (grandFinal != null) {
        tanggalGrandFinal = grandFinal;
        _tanggalGrandFinalController.text = DateFormat('dd/MM/yyyy').format(grandFinal);
      }
      final waktuMulai = _parseTimeOfDay(vote2['waktu_mulai']);
      if (waktuMulai != null) {
        waktuMulaiGf = waktuMulai;
        _waktuMulaiController.text = _formatJam(waktuMulai);
      }
      final waktuSelesai = _parseTimeOfDay(vote2['waktu_selesai']);
      if (waktuSelesai != null) {
        waktuSelesaiGf = waktuSelesai;
        _waktuSelesaiController.text = _formatJam(waktuSelesai);
      }

      existingBannerUrl = _resolveImageUrl(vote2['banner']);
      existingLogoPenyelenggaraUrl = _resolveImageUrl(vote2['icon_penyelenggara']);
    }

    // Step-web (khusus webCategory == '1') - schema-nya cuma expose
    // id_vote/judul_vote/web_category, jadi field custom web lainnya
    // (link, footer, faq, dst) belum bisa dihidrasi dari sini.
    final voteWeb = _voteOf(stepWeb);
    if (voteWeb != null && webCategory == null) {
      webCategory = _str(voteWeb['web_category']) ?? webCategory;
    }

    // Step 3 - Finalis
    final finalisServer = _dataOf(step3)?['finalis'];
    if (finalisServer is List && finalisServer.isNotEmpty) {
      finalisList = finalisServer.map<Map<String, dynamic>>((f) {
        final m = f is Map ? Map<String, dynamic>.from(f) : <String, dynamic>{};
        return {
          'id_finalis': _str(m['id_finalis']),
          'nama_finalis': _str(m['nama_finalis']) ?? '',
          'nama_tambahan': _str(m['nama_tambahan']) ?? '',
          'usia': _str(m['usia']) ?? '',
          'profesi': _str(m['profesi']) ?? '',
          'nomor_urut': _str(m['nomor_urut']) ?? '',
          'deskripsi': _str(m['deskripsi']) ?? '',
          'video_profile': _str(m['video_profile']) ?? '',
          'facebook': _str(m['facebook']) ?? '',
          'instagram': _str(m['instagram']) ?? '',
          'linkedin': _str(m['linkedin']) ?? '',
          'twitter': _str(m['twitter']) ?? '',
          'foto': null,
          'foto_url': _resolveImageUrl(m['poster_finalis']),
        };
      }).toList();
    }

    // Step 4 - Pengaturan Tampilan (id_theme/teks berjalan/sponsor dipakai
    // bareng sama Custom Web karena state-nya memang shared).
    final vote4 = _voteOf(step4);
    if (vote4 != null) {
      versiTampilan = _str(vote4['vote_template_id']) ?? versiTampilan;
      final serverThemeId = int.tryParse(_str(vote4['id_theme']) ?? '');
      if (serverThemeId != null) themeId = serverThemeId;
      teksBerjalanAktif = _str(vote4['flag_running_text']) == '1';
      if (_str(vote4['running_text']) != null) _teksBerjalanController.text = vote4['running_text'];
      sponsorAktif = _str(vote4['flag_sponsor']) == '1';
    }

    // Step 5 - Pengaturan Lanjutan
    final vote5 = _voteOf(step5);
    if (vote5 != null) {
      privateVotingAktif = _str(vote5['private_voting']) == '1';
      voteLiveAktif = _str(vote5['flag_live']) == '1';
      fiturCountdownAktif = _str(vote5['flag_countdown']) == '1';
      tutupHalamanVotingAktif = _str(vote5['flag_tutup_view']) == '1';
      sembunyikanNomorFinalisAktif = _str(vote5['flag_hide_nomor_urut']) == '1';
      sembunyikanLeaderboardAktif = _str(vote5['flag_hide_leaderboard']) == '1';
      notifikasiAktif = _str(vote5['flag_notif']) == '1';
      urutanFinalis = _str(vote5['urutan_total_voting']) ?? urutanFinalis;
      loginRequiredAktif = _str(vote5['flag_login']) == '1';
      verifikasiEmailAktif = _str(vote5['flag_verify_email']) == '1';
      batasanJumlahVoteAktif = _str(vote5['flag_batasi_voting']) == '1';
      if (_str(vote5['batas_qty']) != null) _batasQtyPerTransaksiController.text = vote5['batas_qty'].toString();
      if (_str(vote5['qty_batas']) != null) _batasTransaksiPerVoterController.text = vote5['qty_batas'].toString();
      selectedArtikelId = _str(vote5['article']);
      selectedArtikelTitle = _str(vote5['article_title']);
      // indikator_vote (Data Wajib Pemilih) yang dipilih tidak diexpose di
      // GET step5 (cuma flag_indikator_vote), jadi belum bisa dihidrasi.
    }

    // Step 6 - Metode Pembayaran (khusus paid)
    if (jenisVote == 'paid') {
      final payment = _dataOf(step6)?['payment'];
      final selected = payment is Map ? payment['selected_payment'] : null;
      if (selected is List) {
        _selectedPaymentMethodIds
          ..clear()
          ..addAll(selected.where((e) => e != null).map((e) => e.toString()));
      }
    }

    // Step promo - asumsi struktur `booster` mengikuti field yang sama
    // dengan body submit (dokumentasinya cuma nulis `{}`, jadi ini
    // best-effort, bukan kepastian dari kontrak).
    final booster = _dataOf(stepPromo)?['booster'];
    if (booster is Map) {
      final b = Map<String, dynamic>.from(booster);
      boostAktif = _str(b['boost_active']) == '1';
      final boostStart = DateTime.tryParse(_str(b['boost_start_date']) ?? '');
      if (boostStart != null) {
        boostMulai = boostStart;
        _boostMulaiController.text = DateFormat('dd/MM/yyyy, HH:mm').format(boostStart);
      }
      final boostEnd = DateTime.tryParse(_str(b['boost_end_date']) ?? '');
      if (boostEnd != null) {
        boostSelesai = boostEnd;
        _boostSelesaiController.text = DateFormat('dd/MM/yyyy, HH:mm').format(boostEnd);
      }
      final multiplier = int.tryParse(_str(b['boost_multiplier']) ?? '');
      if (multiplier != null) boostMultiplier = multiplier;
      final freeQuota = int.tryParse(_str(b['free_quota']) ?? '');
      if (freeQuota != null && freeQuota > 0) {
        voteGratisHarianAktif = true;
        _batasVoteGratisController.text = freeQuota.toString();
      }
    }

    _snapshotAllSteps();
  }

  // Kunci sederhana buat deteksi "ada perubahan atau tidak" per step, dengan
  // encode field-field relevan step itu jadi satu string. Bukan representasi
  // body submit yang persis, cuma buat dibandingkan (equal = gak ada perubahan).
  String _stepSnapshotKey(int step) {
    if (step == 1) {
      return jsonEncode([jenisVote, kategoriVote, webCategory]);
    }

    if (step == 2) {
      return jsonEncode([
        _judulController.text, _deskripsiController.text, _syaratKetentuanController.text,
        zonaWaktu, mataUang, _namaPenyelenggaraController.text, _namaTempatController.text,
        _alamatController.text, _hargaController.text,
        _tanggalBukaController.text, _tanggalTutupController.text, _tanggalGrandFinalController.text,
        _waktuMulaiController.text, _waktuSelesaiController.text,
        posterVoteImage?.path, logoPenyelenggaraImage?.path,
        aktifkanPaket, jenisPaket, tipeDiskon,
        paketList.map((r) => '${r['qty']?.text}:${r['diskon']?.text}').join(','),
      ]);
    }

    if (step == 3) {
      if (webCategory == '1') {
        return jsonEncode([
          _linkVotingController.text, bahasaVote, mascotImage?.path, heroBannerImage?.path,
          _deskripsiFooterController.text, themeId, _judulVideoTutorialController.text,
          _urlVideoTutorialController.text, faqAktif,
          faqList.map((f) => '${f['pertanyaan']?.text}:${f['jawaban']?.text}').join(','),
          teksBerjalanAktif, _teksBerjalanController.text, teksBerjalanColor.toARGB32(),
          _instagramController.text, _twitterController.text, _youtubeController.text, _tiktokController.text,
          sponsorAktif, sponsorBaris1?.path, sponsorBaris2?.path, sponsorBaris3?.path,
        ]);
      }
      return jsonEncode(finalisList.map((f) => [
        f['id_finalis'], f['nama_finalis'], f['nomor_urut'], f['nama_tambahan'], f['profesi'], f['usia'],
        f['deskripsi'], f['instagram'], f['facebook'], f['linkedin'], f['twitter'], f['video_profile'],
        f['foto'] is File ? (f['foto'] as File).path : null,
      ]).toList());
    }

    if (step == 4) {
      if (webCategory == '0') {
        return jsonEncode([
          versiTampilan, themeId, teksBerjalanAktif, _teksBerjalanController.text,
          teksBerjalanColor.toARGB32(), sponsorAktif,
          sponsorBaris1?.path, sponsorBaris2?.path, sponsorBaris3?.path,
        ]);
      }
      return '';
    }

    if (step == 5) {
      return jsonEncode([
        privateVotingAktif, voteLiveAktif, fiturCountdownAktif, tutupHalamanVotingAktif,
        sembunyikanNomorFinalisAktif, sembunyikanLeaderboardAktif, notifikasiAktif,
        urutanFinalis, loginRequiredAktif, verifikasiEmailAktif,
        (dataWajibPemilih.toList()..sort()).join(','),
        batasanJumlahVoteAktif, _batasQtyPerTransaksiController.text, _batasTransaksiPerVoterController.text,
        selectedArtikelId, selectedArtikelTitle,
      ]);
    }

    if (jenisVote == 'paid' && step == 6) {
      return jsonEncode([
        (_activeRegions.toList()..sort()).join(','),
        (_selectedPaymentMethodIds.toList()..sort()).join(','),
      ]);
    }

    if (step == totalSteps) {
      return jsonEncode([
        boostAktif, _boostMulaiController.text, _boostSelesaiController.text, boostMultiplier,
        voteGratisHarianAktif, _batasVoteGratisController.text,
      ]);
    }

    return '';
  }

  void _snapshotAllSteps() {
    for (var s = 1; s <= totalSteps; s++) {
      _stepSnapshots[s] = _stepSnapshotKey(s);
    }
  }

  bool _stepChanged(int step) {
    if (!isEditMode) return true; // vote baru - selalu submit seperti biasa
    return _stepSnapshotKey(step) != _stepSnapshots[step];
  }

  void _markStepSaved(int step) {
    _stepSnapshots[step] = _stepSnapshotKey(step);
  }

  bool _canGoNext() {
    switch (currentStep) {
      case 1:
        return jenisVote != null && kategoriVote != null && webCategory != null;
      case 2:
        if (_judulController.text.trim().isEmpty) return false;
        if (_deskripsiController.text.trim().isEmpty) return false;
        if (_tanggalBukaController.text.trim().isEmpty) return false;
        if (_tanggalTutupController.text.trim().isEmpty) return false;
        if (jenisVote == 'paid') {
          if (_hargaController.text.trim().isEmpty) return false;
          // if (_minimalPembelianController.text.trim().isEmpty) return false;
          if (aktifkanPaket) {
            for (final row in paketList) {
              if (row['qty']!.text.trim().isEmpty) return false;
              if (row['diskon']!.text.trim().isEmpty) return false;
            }
          }
        }
        if (_tanggalGrandFinalController.text.trim().isEmpty) return false;
        if (_namaTempatController.text.trim().isEmpty) return false;
        if (_waktuMulaiController.text.trim().isEmpty) return false;
        if (_waktuSelesaiController.text.trim().isEmpty) return false;
        if (_alamatController.text.trim().isEmpty) return false;
        if (_namaPenyelenggaraController.text.trim().isEmpty) return false;
        if (logoPenyelenggaraImage == null && existingLogoPenyelenggaraUrl == null) return false;
        return true;
      case 3:
        if (webCategory == '1') {
          if (_linkVotingController.text.trim().isEmpty) return false;
          if (_urlVideoTutorialController.text.trim().isEmpty) return false;
          if (heroBannerImage == null && existingHeroBannerUrl == null) return false;
        } else {
          if (finalisList.isEmpty) return false;
        }
        return true;
      case 4:
        if (webCategory == '0') {
          if (versiTampilan == null || versiTampilan!.trim().isEmpty) return false;
          if (themeId < 0) return false; // Warna Template selalu punya default saat step ini muncul
        }
        return true;
      case 6:
        if (jenisVote == 'paid') {
          if (_selectedPaymentMethodIds.isEmpty) return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _onNext() async {
    if (!_canGoNext()) {
      setState(() {
        _showError = true;
      });
      return;
    }

    if (isEditMode && !_stepChanged(currentStep)) {
      setState(() => currentStep++);
      return;
    }

    if (currentStep == 1) {
      await _submitStep1();
      return;
    }

    if (currentStep == 2) {
      await _submitStep2();
      return;
    }

    if (currentStep == 3) {
      if (webCategory == '1') {
        await _submitStepWeb();
      } else {
        setState(() => currentStep++);
      }
      return;
    }

    if (currentStep == 4) {
      if (webCategory == '0') {
        await _submitStep4();
      } else {
        setState(() => currentStep++);
      }
      return;
    }

    if (currentStep == 5) {
      await _submitStep5();
      return;
    }

    if (currentStep == totalSteps) {
      await _submitStepPromoBoost();
      return;
    }

    setState(() => currentStep++);
  }

  Future<void> _submitStep1() async {
    final valid = await isTokenStillValid(token);
    if (!mounted) return;
    if (!valid) {
      await forceLogoutToLogin(context);
      return;
    }

    showLoadingDialog(context, bahasa['memproses'] ?? 'Memproses...');

    final body = {
      "jenis_vote": jenisVote,
      "choose_category": kategoriVote,
      "web_category": webCategory,
    };

    final result = await ApiService.post(
      '/api/v1/create-vote/$trayId/step1',
      body: body,
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return;
    hideLoadingDialog(context);

    if (result != null && result['success'] == true && result['data']['id_vote'] != 'null') {
      _markStepSaved(currentStep);
      setState(() {
        currentStep++;
        resultIdVote = result['data']['id_vote'];
      });
    } else if (result != null && result['success'] == true && result['data']['id_vote'] == 'null') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('id_vote = null')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result?['message']?.toString() ?? (bahasa['error'] ?? 'Terjadi kesalahan'))),
      );
    }
  }

  // Backend kadang balikin "data" sebagai array kosong ([]) kalau gagal
  // (bukan object) - jadi jangan langsung index ['temp_id'], cek dulu tipenya.
  String? _extractTempId(Map<String, dynamic>? result) {
    final data = result?['data'];
    if (data is Map) {
      return data['temp_id']?.toString() ?? data['id']?.toString();
    }
    return null;
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

  Future<void> _submitStep2() async {
    final valid = await isTokenStillValid(token);
    if (!mounted) return;
    if (!valid) {
      await forceLogoutToLogin(context);
      return;
    }

    showLoadingDialog(context, bahasa['memproses'] ?? 'Memproses...');

    String? bannerTempId;
    String? bannerUrl;
    String? logoTempId;
    String? logoUrl;

    if (posterVoteImage != null) {
      final bannerResult = await ApiService.postMultipart(
        '/api/v1/create-vote/$trayId/step2/upload-banner',
        fieldName: 'file_banner',
        file: posterVoteImage!,
        token: token,
        xLanguage: langCode,
      );
      if (bannerResult?['success'] != true) {
        if (!mounted) return;
        hideLoadingDialog(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_extractErrorMessage(bannerResult))),
        );
        return;
      }
      bannerTempId = _extractTempId(bannerResult);
      bannerUrl = bannerResult?['data']?['url'];
    }

    if (logoPenyelenggaraImage != null) {
      final logoResult = await ApiService.postMultipart(
        '/api/v1/create-vote/$trayId/step2/upload-logo',
        fieldName: 'file_logo',
        file: logoPenyelenggaraImage!,
        token: token,
        xLanguage: langCode,
      );
      if (logoResult?['success'] != true) {
        if (!mounted) return;
        hideLoadingDialog(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_extractErrorMessage(logoResult))),
        );
        return;
      }
      logoTempId = _extractTempId(logoResult);
      logoUrl = logoResult?['data']?['url'];
    }

    final qtyList = <int>[];
    final diskonList = <double>[];
    final qtyFixList = <int>[];
    final diskonFlatFixList = <double>[];

    final typeDiscount = jenisPaket == 'fix' ? 'flat' : (tipeDiskon == 'persen' ? 'percent' : 'flat');

    if (jenisVote == 'paid' && aktifkanPaket) {
      for (final row in paketList) {
        final qty = int.tryParse(row['qty']!.text) ?? 0;
        final diskon = double.tryParse(row['diskon']!.text) ?? 0;
        if (jenisPaket == 'fix') {
          qtyFixList.add(qty);
          diskonFlatFixList.add(diskon);
        } else {
          qtyList.add(qty);
          diskonList.add(diskon);
        }
      }
      
      final previewResult = await ApiService.post(
        '/api/v1/create-vote/$trayId/step2/package-preview',
        body: {
          "harga": num.tryParse(_hargaController.text) ?? 0,
          "mode_paket": jenisPaket,
          "type_discount": typeDiscount,
          "qty": qtyList.map((e) => e.toString()).toList(),
          "diskon": diskonList.map((e) => e.toString()).toList(),
          "qty_fix": qtyFixList.map((e) => e.toString()).toList(),
          "diskon_flat_fix": diskonFlatFixList.map((e) => e.toString()).toList(),
        },
        xLanguage: langCode,
        token: token,
      );

      if (previewResult?['success'] != true) {
        if (!mounted) return;
        hideLoadingDialog(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_extractErrorMessage(previewResult))),
        );
        return;
      }
    }

    String? formatJam(TimeOfDay? t) {
      if (t == null) return null;
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    
    String? formatTanggalApi(DateTime? dt) {
      if (dt == null) return null;
      return DateFormat("yyyy-MM-dd").format(dt);
    }

    final body = {
      "judul_vote": _judulController.text.trim(),
      "deskripsi": _deskripsiController.text.trim(),
      "snk": _syaratKetentuanController.text.trim(),
      "zona_waktu": zonaWaktu,
      "tanggal_buka_vote": formatTanggalApi(tanggalBukaVote),
      "tanggal_tutup_vote": formatTanggalApi(tanggalTutupVote),
      "matauang": jenisVote == 'paid' ? mataUang : null,
      "nama_penyelenggara": _namaPenyelenggaraController.text.trim(),
      "tanggal_grandfinal_mulai": formatTanggalApi(tanggalGrandFinal),
      "waktu_mulai_gf": formatJam(waktuMulaiGf),
      "tanggal_grandfinal_selesai": formatTanggalApi(tanggalGrandFinal),
      "waktu_selesai_gf": formatJam(waktuSelesaiGf),
      "lokasi_nama_tempat": _namaTempatController.text.trim(),
      "lokasi_alamat": _alamatController.text.trim(),
      "file_banner": bannerUrl,
      "banner_temp_id": bannerTempId,
      "file_logo": logoUrl,
      "logo_temp_id": logoTempId,
      if (jenisVote == 'paid') "mode_paket": jenisPaket,
      "harga": num.tryParse(_hargaController.text) ?? 0,
      // if (jenisVote == 'paid') "minimal_pembelian": int.tryParse(_minimalPembelianController.text) ?? 0,
      if (jenisVote == 'paid') "minimal_pembelian": 1,
      if (jenisVote == 'paid') "aktikan_paket": aktifkanPaket ? "on" : "off",
      if (jenisVote == 'paid') "type_discount": typeDiscount,
      if (jenisVote == 'paid' && aktifkanPaket) "qty": qtyList.map((e) => e.toString()).toList(),
      if (jenisVote == 'paid' && aktifkanPaket) "diskon": diskonList.map((e) => e.toString()).toList(),
      if (jenisVote == 'paid' && aktifkanPaket) "qty_fix": qtyFixList.map((e) => e.toString()).toList(),
      if (jenisVote == 'paid' && aktifkanPaket) "diskon_flat_fix": diskonFlatFixList.map((e) => e.toString()).toList()
    };

    final result = await ApiService.post(
      '/api/v1/create-vote/$trayId/step2',
      body: body,
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return;
    hideLoadingDialog(context);

    if (result != null && result['success'] == true) {
      _markStepSaved(currentStep);
      setState(() => currentStep++);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result?['message']?.toString() ?? (bahasa['error'] ?? 'Terjadi kesalahan'))),
      );
    }
  }

  Future<String?> _fileToBase64(File? file) async {
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).padLeft(6, '0')}';
  }

  Future<void> _submitStepWeb() async {
    final valid = await isTokenStillValid(token);
    if (!mounted) return;
    if (!valid) {
      await forceLogoutToLogin(context);
      return;
    }

    showLoadingDialog(context, bahasa['memproses'] ?? 'Memproses...');

    final mascotBase64 = await _fileToBase64(mascotImage);
    final heroBannerBase64 = await _fileToBase64(heroBannerImage);
    final sponsor1Base64 = await _fileToBase64(sponsorBaris1);
    final sponsor2Base64 = await _fileToBase64(sponsorBaris2);
    final sponsor3Base64 = await _fileToBase64(sponsorBaris3);
    final linkWeb = '${_linkVotingController.text.trim()}.$baseCustomWeb';

    final body = {
      "type_save": "save",
      "url_web": linkWeb,
      "link_web": linkWeb,
      "default_lang": bahasaVote,
      "id_theme": themeId,
      if (mascotBase64 != null) "banner_base64": mascotBase64,
      "banner_finalis_base64": heroBannerBase64,
      if (_deskripsiFooterController.text.trim().isNotEmpty)
        "deskripsi_footer": _deskripsiFooterController.text.trim(),
      if (_judulVideoTutorialController.text.trim().isNotEmpty)
        "tutorial_vote": _judulVideoTutorialController.text.trim(),
      "url_video_tutorial": _urlVideoTutorialController.text.trim(),
      "flag_faq": faqAktif ? "1" : "0",
      if (faqAktif) "faq_pertanyaan": faqList.map((f) => f['pertanyaan']!.text.trim()).toList(),
      if (faqAktif) "faq_jawaban": faqList.map((f) => f['jawaban']!.text.trim()).toList(),
      "flag_running_text": teksBerjalanAktif ? "1" : "0",
      if (teksBerjalanAktif) "running_text": _teksBerjalanController.text.trim(),
      if (teksBerjalanAktif) "running_text_color": _colorToHex(teksBerjalanColor),
      if (_instagramController.text.trim().isNotEmpty) "link_ig": _instagramController.text.trim(),
      if (_twitterController.text.trim().isNotEmpty) "link_twitter": _twitterController.text.trim(),
      if (_youtubeController.text.trim().isNotEmpty) "link_youtube": _youtubeController.text.trim(),
      if (_tiktokController.text.trim().isNotEmpty) "link_tiktok": _tiktokController.text.trim(),
      "flag_sponsor": sponsorAktif ? "1" : "0",
      if (sponsorAktif && sponsor1Base64 != null) "images_line_1": {"image": sponsor1Base64},
      if (sponsorAktif && sponsor2Base64 != null) "images_line_2": {"image": sponsor2Base64},
      if (sponsorAktif && sponsor3Base64 != null) "images_line_3": {"image": sponsor3Base64},
    };

    final result = await ApiService.post(
      '/api/v1/create-vote/$trayId/step-web',
      body: body,
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return;
    hideLoadingDialog(context);

    if (result != null && result['success'] == true) {
      _markStepSaved(currentStep);
      setState(() => currentStep++);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result?['message']?.toString() ?? (bahasa['error'] ?? 'Terjadi kesalahan'))),
      );
    }
  }

  // Step 4 (khusus webCategory == '0') - Pengaturan Tampilan
  Future<void> _submitStep4() async {
    final valid = await isTokenStillValid(token);
    if (!mounted) return;
    if (!valid) {
      await forceLogoutToLogin(context);
      return;
    }

    showLoadingDialog(context, bahasa['memproses'] ?? 'Memproses...');

    final body = {
      "type_save": "save",
      "vote_template_id": int.tryParse(versiTampilan ?? '') ?? 0,
      "id_theme": themeId,
      "flag_running_text": teksBerjalanAktif ? "1" : "0",
      "running_text": _teksBerjalanController.text.trim(),
      "running_text_color": _colorToHex(teksBerjalanColor),
      "flag_sponsor": sponsorAktif ? "1" : "0",
    };

    final result = await ApiService.post(
      '/api/v1/create-vote/$trayId/step4',
      body: body,
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return;
    hideLoadingDialog(context);

    if (result != null && result['success'] == true) {
      _markStepSaved(currentStep);
      setState(() => currentStep++);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_extractErrorMessage(result))),
      );
    }
  }

  // Step 5 - Pengaturan Lanjutan
  Future<void> _submitStep5() async {
    final valid = await isTokenStillValid(token);
    if (!mounted) return;
    if (!valid) {
      await forceLogoutToLogin(context);
      return;
    }

    showLoadingDialog(context, bahasa['memproses'] ?? 'Memproses...');

    final body = {
      "type_save": "save",
      "private_voting": privateVotingAktif ? "1" : null,
      "flag_live": voteLiveAktif ? "1" : null,
      "flag_countdown": fiturCountdownAktif ? "1" : null,
      "flag_tutup_view": tutupHalamanVotingAktif ? "1" : null,
      "flag_hide_nomor_urut": sembunyikanNomorFinalisAktif ? "1" : null,
      "flag_hide_leaderboard": sembunyikanLeaderboardAktif ? "1" : null,
      "flag_notif": notifikasiAktif ? "1" : null,
      "urutan_total_voting": urutanFinalis,
      "flag_login": loginRequiredAktif ? "1" : null,
      "flag_verify_email": verifikasiEmailAktif ? "1" : null,
      "indikator_vote": dataWajibPemilih.toList(),
      "flag_indikator_vote": dataWajibPemilih.isNotEmpty ? "1" : null,
      "flag_batasi_voting": batasanJumlahVoteAktif ? "1" : null,
      "batas_qty": int.tryParse(_batasQtyPerTransaksiController.text.trim()) ?? 0,
      "qty_batas": int.tryParse(_batasTransaksiPerVoterController.text.trim()) ?? 0,
      "batasi_voting": 0,
      "article": selectedArtikelId ?? "",
      "article_title": selectedArtikelTitle ?? "",
    };

    final result = await ApiService.post(
      '/api/v1/create-vote/$trayId/step5',
      body: body,
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return;
    hideLoadingDialog(context);

    if (result != null && result['success'] == true) {
      _markStepSaved(currentStep);
      setState(() => currentStep++);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_extractErrorMessage(result))),
      );
    }
  }

  // Step terakhir - Promo dan Booster
  Future<void> _submitStepPromoBoost() async {
    final valid = await isTokenStillValid(token);
    if (!mounted) return;
    if (!valid) {
      await forceLogoutToLogin(context);
      return;
    }

    showLoadingDialog(context, bahasa['memproses'] ?? 'Memproses...');

    String? formatBoostDate(DateTime? dt) {
      if (dt == null) return null;
      return '${DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(dt)}Z';
    }

    final body = {
      "type_save": "save",
      "boost_active": boostAktif ? "1" : "0",
      "boost_start_date": boostAktif ? formatBoostDate(boostMulai) : null,
      "boost_end_date": boostAktif ? formatBoostDate(boostSelesai) : null,
      "boost_multiplier": boostAktif ? boostMultiplier : null,
      "free_quota": voteGratisHarianAktif ? (int.tryParse(_batasVoteGratisController.text.trim()) ?? 0) : 0,
    };

    final result = await ApiService.post(
      '/api/v1/create-vote/$trayId/step-promo',
      body: body,
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return;
    hideLoadingDialog(context);

    if (result != null && result['success'] == true) {
      _onPublish();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_extractErrorMessage(result))),
      );
    }
  }

  void _onBack() {
    if (currentStep > 1) {
      setState(() => currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  // Dialog konfirmasi generik di tengah layar (Ya/Tidak) - dipakai buat
  // Simpan Draft dan Hapus Finalis.
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

  void _onSaveDraft() async {
    final confirmed = await _confirmDialog(
      message: bahasa['yakin_simpan_draft'] ?? 'Yakin ingin menyimpan sebagai draft?',
    );
    if (!confirmed || !mounted) return;

    pendingSwitchToDraftTab = true;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _onPublish() {
    _redirectTimer?.cancel();
    setState(() {
      _publishSuccess = true;
      _redirectCountdown = 8;
    });
    _redirectTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_redirectCountdown <= 1) {
        timer.cancel();
        _goToDaftarVote();
        return;
      }
      setState(() => _redirectCountdown--);
    });
  }

  void _goToDaftarVote() {
    _redirectTimer?.cancel();
    Navigator.pop(context);
  }

  void _goToLihatVote() {
    _redirectTimer?.cancel();
    if (resultIdVote == null) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => DetailVotePage(idVote: resultIdVote!)),
    );
  }

  // Variant _pickImage yang balikin File langsung (bukan lewat callback +
  // setState parent) - dipakai bottom sheet finalis yang punya state sendiri.
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

  Future<void> _removeFinalis(int index) async {
    final idFinalis = finalisList[index]['id_finalis'] as String?;

    // Belum pernah ke-submit ke server (create-nya gagal/belum sempat) -
    // gak ada yang perlu di-delete di backend, langsung hapus lokal.
    if (idFinalis == null || idFinalis.isEmpty) {
      setState(() => finalisList.removeAt(index));
      return;
    }

    final valid = await isTokenStillValid(token);
    if (!mounted) return;
    if (!valid) {
      await forceLogoutToLogin(context);
      return;
    }

    showLoadingDialog(context, bahasa['memproses'] ?? 'Memproses...');

    final result = await ApiService.delete(
      '/api/v1/create-vote/$trayId/step3/finalis/$idFinalis',
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

    setState(() => finalisList.removeAt(index));
  }

  Future<bool> _saveFinalisToApi(Map<String, dynamic> data, {String? idFinalis}) async {
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
        '/api/v1/create-vote/$trayId/step3/finalis/upload-poster',
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
      posterTempId = _extractTempId(uploadResult);
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
      // if (idFinalis != null && idFinalis.isNotEmpty) "id_finalis": idFinalis,
    };

    final result = await ApiService.post(
      '/api/v1/create-vote/$trayId/step3/finalis',
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

    final savedData = Map<String, dynamic>.from(data);
    savedData['id_finalis'] = result?['data']?['saved_finalis']['id_finalis']?.toString() ?? idFinalis ?? '';

    setState(() {
      if (idFinalis != null && idFinalis.isNotEmpty) {
        final index = finalisList.indexWhere((f) => f['id_finalis'] == idFinalis);
        if (index != -1) finalisList[index] = savedData;
      } else {
        finalisList.add(savedData);
      }
    });

    return true;
  }

  Future<bool> _saveFinalisBulkToApi(List<Map<String, dynamic>> rows) async {
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
      '/api/v1/create-vote/$trayId/step3/finalis/bulk',
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

    final savedList = result?['data'];
    setState(() {
      if (savedList is List) {
        for (final item in savedList) {
          if (item is Map) {
            final saved = Map<String, dynamic>.from(item);
            saved['id_finalis'] = saved['id_finalis']?.toString() ?? '';
            saved.putIfAbsent('foto', () => null);
            finalisList.add(saved);
          }
        }
      } else {
        // Fallback kalau bentuk response beda dari dugaan - tetap simpan versi
        // lokal (tanpa id_finalis, jadi edit/hapus baris ini nanti hapus lokal saja).
        finalisList.addAll(rows);
      }
    });

    return true;
  }

  Future<bool> _updateFinalisToApi(Map<String, dynamic> data, {String? idFinalis}) async {
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
        '/api/v1/create-vote/$trayId/step3/finalis/upload-poster',
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
      posterTempId = _extractTempId(uploadResult);
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
      // if (idFinalis != null && idFinalis.isNotEmpty) "id_finalis": idFinalis,
    };

    final result = await ApiService.put(
      '/api/v1/create-vote/$trayId/step3/finalis/$idFinalis',
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

    final savedData = Map<String, dynamic>.from(data);
    savedData['id_finalis'] = result?['data']?['id_finalis']?.toString() ?? idFinalis ?? '';

    setState(() {
      if (idFinalis != null && idFinalis.isNotEmpty) {
        final index = finalisList.indexWhere((f) => f['id_finalis'] == idFinalis);
        if (index != -1) finalisList[index] = savedData;
      } else {
        finalisList.add(savedData);
      }
    });

    return true;
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
              child: isLoading
                ? _buildSkeleton()
                : _publishSuccess
                  ? _buildPublishSuccessView()
                  : _buildStepContentWrapper(),
            ),

            if (!isLoading && !_publishSuccess) _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildPublishSuccessView() {
    final buka = tanggalBukaVote != null ? DateFormat('d MMM yyyy, HH:mm').format(tanggalBukaVote!) : '-';
    final tutup = tanggalTutupVote != null ? DateFormat('d MMM yyyy, HH:mm').format(tanggalTutupVote!) : '-';
    final progress = (_redirectCountdown / 8).clamp(0.0, 1.0);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFE9FBF0), shape: BoxShape.circle),
                child: Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF34C759), width: 3),
                  ),
                  child: const Icon(Icons.check, color: Color(0xFF34C759), size: 32),
                ),
              ),

              const SizedBox(height: 20),
              Text(
                '🎉 ${bahasa['vote_berhasil_dipublikasikan'] ?? 'Vote Berhasil Dipublikasikan!'}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _judulController.text.trim().isEmpty ? '-' : _judulController.text.trim(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                bahasa['vote_aktif_desc'] ?? 'Event voting Anda sudah aktif dan siap menerima suara.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),

              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildPublishInfoBox(
                      label: bahasa['jenis_vote'] ?? 'Jenis Vote',
                      value: jenisVote == 'paid' ? 'Paid' : 'Free',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPublishInfoBox(
                      label: bahasa['buka_vote'] ?? 'Buka Vote',
                      value: buka,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildPublishInfoBox(
                label: bahasa['tutup_vote'] ?? 'Tutup Vote',
                value: tutup,
              ),

              const SizedBox(height: 20),
              Text.rich(
                TextSpan(
                  style: TextStyle(color: Colors.grey[600]),
                  children: [
                    TextSpan(text: '${bahasa['anda_akan_diarahkan_dalam'] ?? 'Anda akan diarahkan dalam'} '),
                    TextSpan(
                      text: '$_redirectCountdown',
                      style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: ' ${bahasa['detik'] ?? 'detik'}...'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: Colors.grey.shade200,
                  color: const Color(0xFFDC2626),
                ),
              ),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _goToDaftarVote,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        bahasa['ke_daftar_vote'] ?? 'Ke Daftar Vote',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _goToLihatVote,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        bahasa['lihat_vote'] ?? 'Lihat Vote',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPublishInfoBox({required String label, required String value}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
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
              bahasa['buat_vote'] ?? 'Buat Vote Baru',
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(6, (i) {
              return Expanded(
                child: Row(
                  children: [
                    Skeleton(width: 32, height: 32, borderRadius: 16),
                    if (i != 5) Expanded(child: Skeleton(width: double.infinity, height: 2, borderRadius: 1)),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          Skeleton(width: 220, height: 16, borderRadius: 4),
          const SizedBox(height: 20),
          Skeleton(width: 200, height: 28, borderRadius: 4),
          const SizedBox(height: 8),
          Skeleton(width: 260, height: 14, borderRadius: 4),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Skeleton(width: double.infinity, height: 150, borderRadius: 16)),
              const SizedBox(width: 12),
              Expanded(child: Skeleton(width: double.infinity, height: 150, borderRadius: 16)),
            ],
          ),

          const SizedBox(height: 20),
          Skeleton(width: 200, height: 28, borderRadius: 4),
          const SizedBox(height: 8),
          Skeleton(width: 260, height: 14, borderRadius: 4),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Skeleton(width: double.infinity, height: 150, borderRadius: 16)),
              const SizedBox(width: 12),
              Expanded(child: Skeleton(width: double.infinity, height: 150, borderRadius: 16)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Skeleton(width: double.infinity, height: 150, borderRadius: 16)),
              const SizedBox(width: 12),
              Expanded(child: Skeleton(width: double.infinity, height: 150, borderRadius: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepContentWrapper() {
    if (_lastScrolledStep != currentStep) {
      _lastScrolledStep = currentStep;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_stepScrollController.hasClients) {
          _stepScrollController.jumpTo(0);
        }
      });
    }

    return SingleChildScrollView(
      controller: _stepScrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepIndicator(),

          const SizedBox(height: 20),
          Text(
            "${bahasa['langkah'] ?? 'Langkah'} $currentStep ${bahasa['dari'] ?? 'dari'} $totalSteps — $stepLabel",
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),

          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(
              key: ValueKey(currentStep),
              child: _buildStepContent(),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: List.generate(totalSteps, (i) {
        final stepNum = i + 1;
        final isActive = stepNum == currentStep;
        final isDone = stepNum < currentStep;
        final isFilled = isActive || isDone;

        return Expanded(
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isFilled ? const Color(0xFFDC2626) : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  "$stepNum",
                  style: TextStyle(
                    color: isFilled ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),

              if (stepNum != totalSteps)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isDone ? const Color(0xFFDC2626) : Colors.grey.shade200,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildBottomBar() {
    final isLastStep = currentStep == totalSteps;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _onBack,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Icon(Icons.chevron_left, color: Colors.grey),
            ),
          ),
          
          const SizedBox(width: 12),
          if (isLastStep) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _onSaveDraft,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey.shade300),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  bahasa['simpan_draft'] ?? 'Simpan sebagai Draft',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  bahasa['publikasikan'] ?? 'Publikasikan',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ] else
            Expanded(
              child: ElevatedButton(
                onPressed: _onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  bahasa['lanjut'] ?? 'Lanjut',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    if (jenisVote == 'paid') {
      switch (currentStep) {
        case 1: return _buildStep1();
        case 2: return _buildStep2();
        case 3: return webCategory == '1' ? _buildStepCustomWeb() : _buildStep3();
        case 4: return _buildStep4();
        case 5: return _buildStep5();
        case 6: return _buildStepPengaturanPembayaran();
        case 7: return _buildStepPromoBoost();
      }
    } else {
      switch (currentStep) {
        case 1: return _buildStep1();
        case 2: return _buildStep2();
        case 3: return webCategory == '1' ? _buildStepCustomWeb() : _buildStep3();
        case 4: return _buildStep4();
        case 5: return _buildStep5();
        case 6: return _buildStepPromoBoost();
      }
    }
    return const SizedBox.shrink();
  }

  // Step 1
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        //pilih jenis vote
        Text(
          bahasa['jenis_vote_kategori'] ?? 'Jenis Vote & Kategori',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 6),
        Text(
          bahasa['jenis_vote_kategori_desc'] ?? 'Pilih jenis voting dan kategori event kamu.',
          style: TextStyle(color: Colors.grey[600]),
        ),

        const SizedBox(height: 20),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildCard(
                  value: 'free',
                  image: '/img/vote_img1.png',
                  title: bahasa['voting_gratis'] ?? 'Voting Gratis',
                  desc: bahasa['voting_gratis_desc'] ?? 'Voters vote tanpa dipungut biaya sama sekali.',
                  type: 'jenisvote'
                ),
              ),

              const SizedBox(width: 12),
              Expanded(
                child: _buildCard(
                  value: 'paid',
                  image: '/img/vote_img2.png',
                  title: bahasa['voting_berbayar'] ?? 'Voting Berbayar',
                  desc: bahasa['voting_berbayar_desc'] ?? 'Voters membeli vote untuk mendukung finalis favorit.',
                  type: 'jenisvote'
                ),
              ),
            ],
          ),
        ),
        if (_showError && errCodejenisVote) ... [
          const SizedBox(height: 6),
          Text(
            textErrJenisVote!, 
            style: TextStyle(color: Colors.red)
          ),
        ],

        // pilih kategori
        const SizedBox(height: 20),
        Text(
          bahasa['kategori_vote'] ?? 'Kategori Vote',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),

        const SizedBox(height: 6),
        Text(
          bahasa['kategori_voting_desc'] ?? 'Tentukan kategori voting untuk event Anda.',
          style: TextStyle(color: Colors.grey[600]),
        ),

        const SizedBox(height: 8),
        _buildKategoriList(),

        if (_showError && errCodekategoriVote) ... [
          const SizedBox(height: 6),
          Text(
            textErrKategoriVote!, 
            style: TextStyle(color: Colors.red)
          ),
        ],

        // pilih platform
        const SizedBox(height: 20),
        Text(
          bahasa['platform_voting'] ?? 'Platform Voting',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 6),
        Text(
          bahasa['platform_voting_desc'] ?? 'Pilih platform untuk menampilkan voting Anda.',
          style: TextStyle(color: Colors.grey[600]),
        ),

        const SizedBox(height: 20),
        // list platform
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildCard(
                  value: '0',
                  image: '/img/vote_img3.png',
                  title: bahasa['tampil_kreen'] ?? 'Tampil di KREEN',
                  desc: bahasa['tampil_kreen_desc'] ?? 'Voting Anda akan ditampilkan di platform KREEN',
                  type: 'platformvote'
                ),
              ),

              const SizedBox(width: 12),
              Expanded(
                child: _buildCard(
                  value: '1',
                  image: '/img/vote_img4.png',
                  title: bahasa['custom_voting_website'] ?? 'Custom Voting Website',
                  desc: bahasa['custom_voting_website_desc'] ?? 'Gunakan domain dan tampilan website sesuai kebutuhan Anda.',
                  type: 'platformvote'
                ),
              ),
            ],
          ),
        ),

        if (_showError && errCodeWebCategory) ... [
          const SizedBox(height: 6),
          Text(
            textErrPlatform!, 
            style: TextStyle(color: Colors.red)
          ),
        ],
      ],
    );
  }

  Widget _buildCard({
    required String value,
    required String image,
    required String title,
    required String desc,
    required String type
  }) {
    bool isSelected = false;
    if (type == 'jenisvote') {
      isSelected = jenisVote == value;
    } else if (type == 'kategorivote') {
      isSelected = kategoriVote == value;
    } else if (type == 'platformvote') {
      isSelected = webCategory == value;
    }

    return InkWell(
      onTap: () {
        setState(() {
          if (type == 'jenisvote') {
            jenisVote = value;
            errCodejenisVote = false;
          } else if (type == 'kategorivote') {
            kategoriVote = value;
            errCodekategoriVote = false;
          } else if (type == 'platformvote') {
            webCategory = value;
            errCodeWebCategory = false;
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFDC2626) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Image.network(
              '$baseUrl/$image',
              width: double.infinity,
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

            const SizedBox(height: 20),
            Text(
              title, 
              style: type == 'kategorivote'
                ? TextStyle(fontWeight: FontWeight.normal,)
                : TextStyle(fontWeight: FontWeight.bold,)
            ),

            if (type == 'kategorivote') ... [
              const SizedBox.shrink()
            ] else ... [
              const SizedBox(height: 6),
              Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildKategoriList() {
    final items = kategoriList
        .where((k) => k['show']?.toString() == '1')
        .toList();

    if (items.isEmpty) return const SizedBox.shrink();

    const perRow = 3;
    final rows = <Widget>[];

    for (var i = 0; i < items.length; i += perRow) {
      final chunk = items.skip(i).take(perRow).toList();
      final isLastRow = i + perRow >= items.length;

      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: isLastRow ? 0 : 12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(perRow, (index) {
                final isLastSlot = index == perRow - 1;

                if (index >= chunk.length) {
                  return const Expanded(child: SizedBox.shrink());
                }

                final kategori = chunk[index];
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: isLastSlot ? 0 : 12),
                    child: _buildCard(
                      value: kategori['id_kategori'].toString(),
                      image: kategori['banner'] ?? '',
                      title: kategori['nama_kategori'] ?? '-',
                      desc: kategori['tagline'] ?? '',
                      type: 'kategorivote',
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      );
    }

    return Column(children: rows);
  }

  //step 2
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          bahasa['informasi_vote'] ?? 'Informasi Vote',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          bahasa['informasi_vote_desc'] ?? 'Lengkapi detail utama event votingmu.',
          style: TextStyle(color: Colors.grey[600]),
        ),

        // Poster Vote
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bahasa['poster_vote'] ?? 'Poster Vote',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                bahasa['poster_vote_desc'] ??
                  'Gunakan gambar berukuran 1080 x 1350 px (Instagram feed). Maksimal ukuran file 10MB.',
                style: TextStyle(color: Colors.grey[600]),
              ),

              const SizedBox(height: 16),
              _buildImageUploadBox(
                image: posterVoteImage,
                onTap: () => _pickImage((file) => posterVoteImage = file),
                placeholder: bahasa['upload_poster'] ?? 'Ketuk untuk upload poster',
                aspectRatio: 4 / 5,
                existingImageUrl: existingBannerUrl,
              ),
            ],
          ),
        ),

        // Informasi Vote
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bahasa['informasi_vote'] ?? 'Informasi Vote',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                bahasa['informasi_vote_desc'] ?? 'Lengkapi detail utama event votingmu.',
                style: TextStyle(color: Colors.grey[600]),
              ),

              const SizedBox(height: 20),
              _buildLabeledField(
                label: bahasa['judul_vote'] ?? 'Judul Vote',
                required: true,
                controller: _judulController,
                hint: (bahasa['judul_vote_hint'] ?? 'Masukkan {text}')
                  .replaceAll('{text}', bahasa['judul_vote'] ?? 'Judul Vote'),
                errorText: _requiredError(_judulController, 'judul_vote', 'Judul Vote'),
              ),

              const SizedBox(height: 16),
              _buildLabeledField(
                label: bahasa['deskripsi_voting'] ?? 'Deskripsi Voting',
                required: true,
                controller: _deskripsiController,
                maxLines: 5,
                hint: bahasa['deskripsi_voting_hint'] ?? 'Tuliskan deskripsi voting',
                errorText: _requiredError(_deskripsiController, 'deskripsi_voting', 'Deskripsi Voting'),
              ),

              const SizedBox(height: 16),
              _buildLabeledField(
                label: bahasa['syarat_ketentuan'] ?? 'Syarat dan Ketentuan',
                controller: _syaratKetentuanController,
                maxLines: 5,
                hint: bahasa['syarat_ketentuan_hint'] ?? 'Masukkan syarat dan ketentuan voting',
              ),
              const SizedBox(height: 6),
              Text(
                bahasa['syarat_ketentuan_note'] ??
                  'Opsional. Jika dikosongkan, halaman voting akan menampilkan Syarat & Ketentuan default.',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),

        // Durasi Voting
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bahasa['durasi_voting'] ?? 'Durasi Voting',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                bahasa['durasi_voting_desc'] ??
                  'Tentukan kapan voting dimulai dan berakhir. (*Patokan Zona Waktu WIB)',
                style: TextStyle(color: Colors.grey[600]),
              ),

              const SizedBox(height: 20),
              _buildLabeledDropdown(
                label: bahasa['zona_waktu'] ?? 'Zona Waktu',
                value: zonaWaktu,
                items: const ['WIB', 'WITA', 'WIT'],
                onChanged: (v) => setState(() => zonaWaktu = v!),
              ),

              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildLabeledField(
                      label: bahasa['tanggal_jam_mulai_vote'] ?? 'Tanggal & Jam Mulai Vote',
                      required: true,
                      controller: _tanggalBukaController,
                      hint: 'dd/mm/yyyy, --.-- --',
                      readOnly: true,
                      onTap: () => _pickDateTime(_tanggalBukaController, (dt) => tanggalBukaVote = dt),
                      suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                      errorText: _requiredError(_tanggalBukaController, 'tanggal_jam_mulai_vote', 'Tanggal & Jam Mulai Vote'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildLabeledField(
                      label: bahasa['tanggal_jam_selesai_vote'] ?? 'Tanggal & Jam Selesai Vote',
                      required: true,
                      controller: _tanggalTutupController,
                      hint: 'dd/mm/yyyy, --.-- --',
                      readOnly: true,
                      onTap: () => _pickDateTime(_tanggalTutupController, (dt) => tanggalTutupVote = dt),
                      suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                      errorText: _requiredError(_tanggalTutupController, 'tanggal_jam_selesai_vote', 'Tanggal & Jam Selesai Vote'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Harga Voting (khusus paid)
        if (jenisVote == 'paid') ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bahasa['harga_voting'] ?? 'Harga Voting',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  bahasa['harga_voting_desc'] ?? 'Atur harga dan skema pembelian vote.',
                  style: TextStyle(color: Colors.grey[600]),
                ),

                const SizedBox(height: 20),
                _buildLabeledDropdown(
                  label: bahasa['mata_uang'] ?? 'Mata Uang',
                  value: mataUang,
                  items: currencies.keys.toList(),
                  onChanged: (v) => setState(() => mataUang = v!),
                ),

                const SizedBox(height: 16),
                _buildLabeledField(
                  label: bahasa['harga_per_vote'] ?? 'Harga per Vote',
                  required: true,
                  controller: _hargaController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  hint: bahasa['harga_per_vote_hint'] ?? 'Masukkan harga per vote',
                  errorText: _requiredError(_hargaController, 'harga_per_vote', 'Harga per Vote'),
                ),

                // const SizedBox(height: 16),
                // _buildLabeledField(
                //   label: bahasa['minimal_pembelian'] ?? 'Minimal Pembelian',
                //   required: true,
                //   controller: _minimalPembelianController,
                //   keyboardType: TextInputType.number,
                //   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                //   hint: bahasa['minimal_pembelian_hint'] ?? 'Masukkan jumlah minimal pembelian vote',
                //   errorText: _requiredError(_minimalPembelianController, 'minimal_pembelian', 'Minimal Pembelian'),
                // ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    Switch(
                      value: aktifkanPaket,
                      activeThumbColor: const Color(0xFFDC2626),
                      onChanged: (v) => setState(() {
                        aktifkanPaket = v;
                        if (v && paketList.isEmpty) _addPaket();
                      }),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      bahasa['aktifkan_paket'] ?? 'Aktifkan Paket',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),

                if (aktifkanPaket) ...[
                  const SizedBox(height: 4),
                  Text(
                    bahasa['paket_required_note'] ?? 'Wajib diisi jika paket diaktifkan',
                    style: TextStyle(color: Colors.red[400], fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  _buildPaketSection(),
                ],
              ],
            ),
          ),
        ],

        // Informasi Grand Final
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bahasa['informasi_grand_final'] ?? 'Informasi Grand Final',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                bahasa['informasi_grand_final_desc'] ?? 'Isi informasi pelaksanaan grand final.',
                style: TextStyle(color: Colors.grey[600]),
              ),

              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildLabeledField(
                      label: bahasa['tanggal'] ?? 'Tanggal',
                      required: true,
                      controller: _tanggalGrandFinalController,
                      hint: 'dd/mm/yyyy',
                      readOnly: true,
                      onTap: () => _pickDate(_tanggalGrandFinalController, (dt) => tanggalGrandFinal = dt),
                      suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                      errorText: _requiredError(_tanggalGrandFinalController, 'tanggal', 'Tanggal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildLabeledField(
                      label: bahasa['nama_tempat'] ?? 'Nama Tempat',
                      required: true,
                      controller: _namaTempatController,
                      hint: bahasa['nama_tempat_hint'] ?? 'Masukkan nama tempat',
                      errorText: _requiredError(_namaTempatController, 'nama_tempat', 'Nama Tempat'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildLabeledField(
                      label: bahasa['waktu_mulai'] ?? 'Waktu Mulai',
                      required: true,
                      controller: _waktuMulaiController,
                      hint: '--.-- --',
                      readOnly: true,
                      onTap: () => _pickTime(_waktuMulaiController, (t) => waktuMulaiGf = t),
                      suffixIcon: const Icon(Icons.access_time, size: 18),
                      errorText: _requiredError(_waktuMulaiController, 'waktu_mulai', 'Waktu Mulai'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildLabeledField(
                      label: bahasa['waktu_selesai'] ?? 'Waktu Selesai',
                      required: true,
                      controller: _waktuSelesaiController,
                      hint: '--.-- --',
                      readOnly: true,
                      onTap: () => _pickTime(_waktuSelesaiController, (t) => waktuSelesaiGf = t),
                      suffixIcon: const Icon(Icons.access_time, size: 18),
                      errorText: _requiredError(_waktuSelesaiController, 'waktu_selesai', 'Waktu Selesai'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              _buildLabeledField(
                label: bahasa['alamat_lengkap'] ?? 'Alamat Lengkap',
                required: true,
                controller: _alamatController,
                maxLines: 3,
                hint: bahasa['alamat_lengkap_hint'] ?? 'Masukkan alamat lengkap grand final',
                errorText: _requiredError(_alamatController, 'alamat_lengkap', 'Alamat Lengkap'),
              ),
            ],
          ),
        ),

        // Informasi Penyelenggara
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bahasa['informasi_penyelenggara'] ?? 'Informasi Penyelenggara',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                bahasa['informasi_penyelenggara_desc'] ?? 'Informasi mengenai pihak penyelenggara event Anda.',
                style: TextStyle(color: Colors.grey[600]),
              ),

              const SizedBox(height: 20),
              _buildLabeledField(
                label: bahasa['nama_penyelenggara'] ?? 'Nama Penyelenggara',
                required: true,
                controller: _namaPenyelenggaraController,
                hint: bahasa['nama_penyelenggara_hint'] ?? 'Masukkan nama penyelenggara',
                errorText: _requiredError(_namaPenyelenggaraController, 'nama_penyelenggara', 'Nama Penyelenggara'),
              ),

              const SizedBox(height: 16),
              _buildImageUploadBox(
                label: bahasa['logo_penyelenggara'] ?? 'Logo Penyelenggara',
                image: logoPenyelenggaraImage,
                required: true,
                onTap: () => _pickImage((file) => logoPenyelenggaraImage = file),
                placeholder: bahasa['upload_logo'] ?? 'Upload Logo (1:1)',
                height: 140,
                existingImageUrl: existingLogoPenyelenggaraUrl,
                errorText: (_showError && logoPenyelenggaraImage == null && existingLogoPenyelenggaraUrl == null)
                  ? (bahasa['err_step_1']?.toString() ?? '{varible} wajib diisi.')
                    .replaceAll('{varible}', bahasa['logo_penyelenggara'] ?? 'Logo Penyelenggara')
                  : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabeledField({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
            children: [
              if (required) const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),

        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          inputFormatters: inputFormatters,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: errorText != null ? Colors.red : Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: errorText != null ? Colors.red : const Color(0xFFDC2626)),
            ),
          ),
        ),

        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(errorText, style: const TextStyle(color: Colors.red)),
        ],
      ],
    );
  }

  // Samain kayak error di _buildStep1: pakai template bahasa['err_step_1']
  // ("{varible} wajib diisi.") dan cuma tampil kalau _showError aktif.
  String? _requiredError(TextEditingController controller, String labelKey, String fallbackLabel) {
    if (!_showError || controller.text.trim().isNotEmpty) return null;
    final template = bahasa['err_step_1']?.toString() ?? '{varible} wajib diisi.';
    return template.replaceAll('{varible}', bahasa[labelKey] ?? fallbackLabel);
  }

  Widget _buildLabeledDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
            children: [
              if (required) const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),

        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down),
              items: items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // Resolve string dari response GET (bisa full URL atau path relatif) jadi
  // URL yang bisa dipakai langsung di Image.network.
  String? _resolveImageUrl(dynamic raw) {
    final s = raw?.toString().trim();
    if (s == null || s.isEmpty) return null;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    return '$baseUrl$s';
  }

  Widget _buildImageUploadBox({
    required File? image,
    required VoidCallback onTap,
    required String placeholder,
    String? label,
    bool required = false,
    double height = 180,
    double? aspectRatio,
    String? errorText,
    String? existingImageUrl,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text.rich(
            TextSpan(
              text: label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
              children: [
                if (required) const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        _buildImageUploadTile(
          image: image,
          onTap: onTap,
          placeholder: placeholder,
          height: height,
          aspectRatio: aspectRatio,
          existingImageUrl: existingImageUrl,
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(errorText, style: const TextStyle(color: Colors.red)),
        ],
      ],
    );
  }

  Widget _buildImageUploadTile({
    required File? image,
    required VoidCallback onTap,
    required String placeholder,
    required double height,
    double? aspectRatio,
    String? existingImageUrl,
  }) {
    final hasExisting = image == null && existingImageUrl != null && existingImageUrl.isNotEmpty;
    final tile = Container(
      width: double.infinity,
      height: aspectRatio == null ? height : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.grey.shade50,
      ),
      child: image != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              image,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          )
        : hasExisting
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                existingImageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image_outlined, color: Colors.grey[400], size: 32),
                    const SizedBox(height: 8),
                    Text(
                      placeholder,
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined, color: Colors.grey[400], size: 32),
                const SizedBox(height: 8),
                Text(
                  placeholder,
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: aspectRatio == null ? tile : AspectRatio(aspectRatio: aspectRatio, child: tile),
    );
  }

  Future<void> _pickImage(void Function(File) onPicked) async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final file = File(picked.path);
    final sizeInMb = await file.length() / (1024 * 1024);
    if (sizeInMb > 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(bahasa['ukuran_file_terlalu_besar'] ?? 'Ukuran file maksimal 10MB')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => onPicked(file));
  }

  double _hitungHargaPaket(int qty) {
    final hargaPerVote = double.tryParse(_hargaController.text) ?? 0;
    return hargaPerVote * qty;
  }

  double _hitungHargaSetelahDiskon(double harga, double diskon, String tipe) {
    if (tipe == 'persen') {
      return (harga - (harga * diskon / 100)).clamp(0, double.infinity);
    }
    return (harga - diskon).clamp(0, double.infinity);
  }

  void _addPaket() {
    setState(() {
      paketList.add({
        'qty': TextEditingController(),
        'diskon': TextEditingController(),
      });
    });
  }

  void _removePaket(int index) {
    setState(() {
      paketList[index]['qty']?.dispose();
      paketList[index]['diskon']?.dispose();
      paketList.removeAt(index);
    });
  }

  // Paket Fix diskonnya selalu flat (gak ada toggle persen/flat), dan
  // label kolom harga-nya beda: "Harga Normal" / "Harga Akhir" alih-alih
  // "Harga" / "Harga Setelah Diskon" seperti mode Paket Diskon.
  bool get _isPaketFix => jenisPaket == 'fix';
  String get _tipeDiskonEfektif => _isPaketFix ? 'flat' : tipeDiskon;

  Widget _buildPaketSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildRadioOption(
              label: bahasa['paket_diskon'] ?? 'Paket Diskon',
              selected: jenisPaket == 'diskon',
              onTap: () => setState(() => jenisPaket = 'diskon'),
            ),
            const SizedBox(width: 16),
            _buildRadioOption(
              label: bahasa['paket_fix'] ?? 'Paket Fix',
              selected: jenisPaket == 'fix',
              onTap: () => setState(() => jenisPaket = 'fix'),
            ),
          ],
        ),

        if (!_isPaketFix) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              _buildRadioOption(
                label: bahasa['diskon_persen'] ?? 'Diskon Persen',
                selected: tipeDiskon == 'persen',
                onTap: () => setState(() => tipeDiskon = 'persen'),
              ),
              const SizedBox(width: 16),
              _buildRadioOption(
                label: bahasa['diskon_flat'] ?? 'Diskon Flat Harga',
                selected: tipeDiskon == 'flat',
                onTap: () => setState(() => tipeDiskon = 'flat'),
              ),
            ],
          ),
        ],

        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                bahasa['jumlah_paket_vote'] ?? 'Jumlah Paket Vote',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Text(
                '${bahasa['diskon'] ?? 'Diskon'} (${_tipeDiskonEfektif == 'persen' ? '%' : (bahasa['flat'] ?? 'Flat')})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Text(
                _isPaketFix ? (bahasa['harga_normal'] ?? 'Harga Normal') : (bahasa['harga'] ?? 'Harga'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Text(
                _isPaketFix
                  ? (bahasa['harga_akhir_label'] ?? 'Harga Akhir')
                  : (bahasa['harga_setelah_diskon'] ?? 'Harga Setelah Diskon'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 32),
          ],
        ),

        const SizedBox(height: 8),
        ...List.generate(paketList.length, (i) => _buildPaketRow(i)),

        const SizedBox(height: 4),
        InkWell(
          onTap: _addPaket,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 18, color: Color(0xFFDC2626)),
              const SizedBox(width: 4),
              Text(
                bahasa['tambah_paket'] ?? 'Tambah Paket',
                style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),
        Text(
          _isPaketFix
            ? (bahasa['paket_note_fix'] ?? '* Qty dan diskon flat wajib diisi untuk setiap paket')
            : (bahasa['paket_note'] ?? '* Qty dan diskon wajib diisi untuk setiap paket'),
          style: TextStyle(color: Colors.red[400], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPaketRow(int index) {
    final row = paketList[index];
    final qty = int.tryParse(row['qty']!.text) ?? 0;
    final diskon = double.tryParse(row['diskon']!.text) ?? 0;
    final harga = _hitungHargaPaket(qty);
    final hargaAkhir = _hitungHargaSetelahDiskon(harga, diskon, _tipeDiskonEfektif);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: _buildMiniInput(
              controller: row['qty']!,
              hint: bahasa['qty'] ?? 'Qty',
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _buildMiniInput(
              controller: row['diskon']!,
              hint: bahasa['diskon'] ?? 'Diskon',
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _buildMiniReadonly(qty > 0 ? formatCurrency(harga, mataUang) : (bahasa['harga'] ?? 'Harga')),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _buildMiniReadonly(
              qty > 0 ? formatCurrency(hargaAkhir, mataUang) : (bahasa['harga_akhir'] ?? 'Akhir'),
            ),
          ),
          SizedBox(
            width: 32,
            child: paketList.length > 1
              ? IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close, size: 18, color: Colors.red),
                  onPressed: () => _removePaket(index),
                )
              : null,
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            size: 18,
            color: selected ? const Color(0xFFDC2626) : Colors.grey,
          ),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildMiniInput({
    required TextEditingController controller,
    String? hint,
    required void Function(String) onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
      ),
    );
  }

  Widget _buildMiniReadonly(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        value,
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Future<void> _pickDateTime(TextEditingController controller, void Function(DateTime) onPicked) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;

    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      controller.text = DateFormat('dd/MM/yyyy, HH:mm').format(combined);
      onPicked(combined);
    });
  }

  Future<void> _pickDate(TextEditingController controller, void Function(DateTime) onPicked) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (date == null) return;
    setState(() {
      controller.text = DateFormat('dd/MM/yyyy').format(date);
      onPicked(date);
    });
  }

  Future<void> _pickTime(TextEditingController controller, void Function(TimeOfDay) onPicked) async {
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null || !mounted) return;
    setState(() {
      controller.text = time.format(context);
      onPicked(time);
    });
  }

  Widget _buildStep3() {
    final filtered = finalisSearch.trim().isEmpty
      ? finalisList
      : finalisList.where((f) {
          final nama = (f['nama_finalis'] as String? ?? '').toLowerCase();
          return nama.contains(finalisSearch.trim().toLowerCase());
        }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          bahasa['finalis'] ?? 'Tambah Finalis',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bahasa['daftar_finalis'] ?? 'Daftar Finalis', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                bahasa['daftar_finalis_desc'] ?? 'Lengkapi data finalis yang akan mengikuti voting.',
                style: TextStyle(color: Colors.grey[600]),
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openTambahBanyakFinalisSheet,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.menu, color: Colors.black87, size: 18),
                      label: Text(
                        bahasa['tambah_banyak'] ?? 'Tambah Banyak',
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openTambahFinalisSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        bahasa['tambah_finalis'] ?? 'Tambah Finalis',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => setState(() => finalisSearch = v),
                decoration: InputDecoration(
                  hintText: bahasa['cari_finalis'] ?? 'Cari finalis...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)),
                ),
              ),

              const SizedBox(height: 16),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.groups_outlined, size: 40, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          bahasa['belum_ada_finalis'] ?? 'Belum ada finalis',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bahasa['klik_tambah_finalis'] ?? 'Klik "Tambah Finalis" untuk menambahkan',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                ...filtered.map((f) => _buildFinalisCard(f)),
                const SizedBox(height: 4),
                Text(
                  '${bahasa['total'] ?? 'Total'} ${finalisList.length} ${bahasa['finalis_lowercase'] ?? 'finalis'}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],

              if (_showError && webCategory != '1' && finalisList.isEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  bahasa['finalis_wajib_1'] ?? 'Minimal 1 finalis wajib ditambahkan sebelum lanjut.',
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinalisCard(Map<String, dynamic> finalis) {
    final index = finalisList.indexOf(finalis);
    final foto = finalis['foto'] as File?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: foto != null
                    ? Image.file(foto, fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey.shade100,
                        child: Icon(Icons.image_outlined, color: Colors.grey[400], size: 18),
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '#${(finalis['nomor_urut'] ?? '').toString().padLeft(2, '0')} ',
                          style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: finalis['nama_finalis'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _viewFinalis(finalis),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(bahasa['lihat'] ?? 'View', style: const TextStyle(color: Colors.black87)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _openTambahFinalisSheet(editIndex: index, isEdit: true);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(bahasa['edit'] ?? 'Edit', style: const TextStyle(color: Colors.black87)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final confirmed = await _confirmDialog(
                      message: bahasa['yakin_hapus_finalis'] ?? 'Yakin ingin menghapus finalis ini?',
                    );
                    if (confirmed) _removeFinalis(index);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(bahasa['hapus'] ?? 'Hapus', style: const TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _viewFinalis(Map<String, dynamic> finalis) {
    final foto = finalis['foto'] as File?;
    final deskripsi = (finalis['deskripsi'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                color: const Color(0xFF1E293B),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        bahasa['detail_finalis'] ?? 'Detail Finalis',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 90,
                              height: 90,
                              child: foto != null
                                ? Image.file(foto, fit: BoxFit.cover)
                                : Container(
                                    color: Colors.grey.shade100,
                                    child: Icon(Icons.image_outlined, color: Colors.grey[400], size: 28),
                                  ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  finalis['nama_finalis'] ?? '-',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '# ${(finalis['nomor_urut'] ?? '').toString().padLeft(2, '0')}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  deskripsi.isEmpty ? '-' : deskripsi,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if ((finalis['nama_tambahan'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _viewRow(bahasa['nama_tambahan'] ?? 'Nama Tambahan', finalis['nama_tambahan']),
                      ],
                      if ((finalis['profesi'] ?? '').toString().isNotEmpty)
                        _viewRow(bahasa['profesi_aktivitas'] ?? 'Profesi / Aktivitas', finalis['profesi']),
                      if ((finalis['usia'] ?? '').toString().isNotEmpty)
                        _viewRow(bahasa['usia'] ?? 'Usia', finalis['usia']),
                      if ((finalis['video_profile'] ?? '').toString().isNotEmpty)
                        _viewRow('Video Profile', finalis['video_profile']),
                      if ((finalis['instagram'] ?? '').toString().isNotEmpty)
                        _viewRow('Instagram', finalis['instagram']),
                      if ((finalis['linkedin'] ?? '').toString().isNotEmpty)
                        _viewRow('LinkedIn', finalis['linkedin']),
                      if ((finalis['facebook'] ?? '').toString().isNotEmpty)
                        _viewRow('Facebook', finalis['facebook']),
                      if ((finalis['twitter'] ?? '').toString().isNotEmpty)
                        _viewRow('X / Twitter', finalis['twitter']),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _viewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _openTambahFinalisSheet({int? editIndex, bool isEdit = false}) {
    final existingIdFinalis = editIndex != null ? finalisList[editIndex]['id_finalis'] as String? : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TambahFinalisSheet(
        bahasa: bahasa,
        pickImage: _pickImageFile,
        initialData: editIndex != null ? finalisList[editIndex] : null,
        onSave: (data) => isEdit
          ? _updateFinalisToApi(data, idFinalis: existingIdFinalis)
          : _saveFinalisToApi(data, idFinalis: existingIdFinalis),
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
        onSaveMultiple: _saveFinalisBulkToApi,
      ),
    );
  }

  // Step 3 (khusus webCategory == '1') - Setup Custom Web
  Widget _buildStepCustomWeb() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          bahasa['setup_custom_web'] ?? 'Setup Custome Web',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        // Link Vote
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bahasa['link_vote'] ?? 'Link Vote', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                bahasa['link_vote_desc'] ?? 'Masukkan link halaman voting yang dapat diakses voter untuk memberikan suara.',
                style: TextStyle(color: Colors.grey[600]),
              ),

              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  text: bahasa['link_voting'] ?? 'Link Voting',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _linkVotingController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'vote-saya',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(11)),
                      ),
                      child: Text(baseCustomWeb, style: TextStyle(color: Colors.grey[600])),
                    ),
                  ],
                ),
              ),
              if (_requiredError(_linkVotingController, 'link_voting', 'Link Voting') != null) ...[
                const SizedBox(height: 6),
                Text(
                  _requiredError(_linkVotingController, 'link_voting', 'Link Voting')!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),

        // Bahasa
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bahasa['bahasa_website'] ?? 'Bahasa', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                bahasa['bahasa_website_desc'] ?? 'Pilih bahasa default yang akan ditampilkan di halaman voting.',
                style: TextStyle(color: Colors.grey[600]),
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildLanguageOption(code: 'id', flag: '🇮🇩', label: 'Indonesia')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildLanguageOption(code: 'en', flag: '🇬🇧', label: 'English')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildLanguageOption(code: 'th', flag: '🇹🇭', label: 'ไทย (Thailand)')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildLanguageOption(code: 'ms', flag: '🇲🇾', label: 'Bahasa Melayu (Malaysia)')),
                ],
              ),
            ],
          ),
        ),

        // Header Website
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bahasa['header_website'] ?? 'Header Website', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                bahasa['header_website_desc'] ??
                  'Lengkapi informasi header untuk halaman voting, termasuk mascot, banner, dan deskripsi.',
                style: TextStyle(color: Colors.grey[600]),
              ),

              const SizedBox(height: 16),
              _buildImageUploadBox(
                label: bahasa['upload_mascot'] ?? 'Upload Mascot Website',
                image: mascotImage,
                onTap: () => _pickImage((file) => mascotImage = file),
                placeholder: bahasa['upload_image_mascot'] ?? 'Upload Image (Mascot)',
                height: 160,
                existingImageUrl: existingMascotUrl,
              ),

              const SizedBox(height: 16),
              _buildImageUploadBox(
                label: bahasa['upload_hero_banner'] ?? 'Upload Hero Banner',
                required: true,
                image: heroBannerImage,
                onTap: () => _pickImage((file) => heroBannerImage = file),
                placeholder: bahasa['upload_image'] ?? 'Upload Image',
                height: 200,
                existingImageUrl: existingHeroBannerUrl,
                errorText: (_showError && heroBannerImage == null && existingHeroBannerUrl == null)
                  ? (bahasa['err_step_1']?.toString() ?? '{varible} wajib diisi.')
                    .replaceAll('{varible}', bahasa['upload_hero_banner'] ?? 'Upload Hero Banner')
                  : null,
              ),
            ],
          ),
        ),

        // Footer Website
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bahasa['footer_website'] ?? 'Footer Website', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                bahasa['footer_website_desc'] ?? 'Lengkapi informasi footer untuk halaman voting, termasuk deskripsi singkat.',
                style: TextStyle(color: Colors.grey[600]),
              ),

              const SizedBox(height: 16),
              _buildLabeledField(
                label: bahasa['deskripsi_footer'] ?? 'Deskripsi Footer',
                controller: _deskripsiFooterController,
                maxLines: 4,
                hint: bahasa['deskripsi_footer_hint'] ?? 'Tuliskan deskripsi footer',
              ),
            ],
          ),
        ),

        // Warna Template
        const SizedBox(height: 16),
        _buildWarnaTemplateSection(),

        // Tutorial Vote
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bahasa['tutorial_vote'] ?? 'Tutorial Vote', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                bahasa['tutorial_vote_desc'] ?? 'Tambahkan panduan bagi voter yang menggunakan layanan voting ini.',
                style: TextStyle(color: Colors.grey[600]),
              ),

              const SizedBox(height: 16),
              _buildLabeledField(
                label: bahasa['judul_video_tutorial'] ?? 'Judul Video Tutorial',
                controller: _judulVideoTutorialController,
                hint: bahasa['judul_video_tutorial'] ?? 'Judul Video Tutorial',
              ),

              const SizedBox(height: 16),
              _buildLabeledField(
                label: bahasa['url_video_tutorial'] ?? 'URL Video Tutorial',
                required: true,
                controller: _urlVideoTutorialController,
                hint: 'https://youtube.com/...',
                keyboardType: TextInputType.url,
                errorText: _requiredError(_urlVideoTutorialController, 'url_video_tutorial', 'URL Video Tutorial'),
              ),
            ],
          ),
        ),

        // FAQ
        const SizedBox(height: 16),
        _buildToggleSection(
          title: bahasa['faq_title'] ?? 'FAQ',
          desc: bahasa['faq_desc'] ??
            'Tambahkan pertanyaan dan jawaban yang sering ditanyakan oleh voter untuk memberikan informasi yang lebih lengkap, serta membantu meminimalisir pertanyaan berulang.',
          value: faqAktif,
          onChanged: (v) => setState(() {
            faqAktif = v;
            if (v && faqList.isEmpty) _addFaq();
          }),
          expandedChildren: [
            ...faqList.asMap().entries.map((e) => _buildFaqCard(e.key)),
            InkWell(
              onTap: _addFaq,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, size: 18, color: Color(0xFFDC2626)),
                  const SizedBox(width: 4),
                  Text(
                    bahasa['tambah_pertanyaan'] ?? 'Tambah Pertanyaan',
                    style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Teks Berjalan
        const SizedBox(height: 16),
        _buildTeksBerjalanSection(),

        // Social Media
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bahasa['social_media_title'] ?? 'Social Media', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                bahasa['social_media_desc'] ??
                  'Hubungkan akun social media untuk ditampilkan di halaman voting. Hanya isi yang ingin ditampilkan saja untuk update informasi.',
                style: TextStyle(color: Colors.grey[600]),
              ),

              const SizedBox(height: 16),
              _buildLabeledField(
                label: 'Instagram',
                controller: _instagramController,
                hint: 'https://instagram.com/...',
                keyboardType: TextInputType.url,
              ),

              const SizedBox(height: 16),
              _buildLabeledField(
                label: '↳ Twitter',
                controller: _twitterController,
                hint: 'https://twitter.com/...',
                keyboardType: TextInputType.url,
              ),

              const SizedBox(height: 16),
              _buildLabeledField(
                label: 'Youtube',
                controller: _youtubeController,
                hint: 'https://youtube.com/...',
                keyboardType: TextInputType.url,
              ),

              const SizedBox(height: 16),
              _buildLabeledField(
                label: 'TikTok',
                controller: _tiktokController,
                hint: 'https://tiktok.com/...',
                keyboardType: TextInputType.url,
              ),
            ],
          ),
        ),

        // Tambahkan Sponsor
        const SizedBox(height: 16),
        _buildSponsorSection(
          title: bahasa['tambahkan_sponsor_title'] ?? 'Tambahkan Sponsor',
          desc: bahasa['tambahkan_sponsor_desc'] ??
            'Tampilkan logo sponsor pada halaman voting. Logo klik area untuk menambah, hover untuk menghapus.',
        ),
      ],
    );
  }

  // Step 4 (khusus webCategory == '0') - Pengaturan Tampilan
  Widget _buildPengaturanTampilan() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          bahasa['pengaturan_tampilan'] ?? 'Pengaturan Tampilan',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 20),
        _buildVersiTampilanSection(),

        const SizedBox(height: 16),
        _buildWarnaTemplateSection(perRow: 2),

        const SizedBox(height: 16),
        _buildTeksBerjalanSection(),

        const SizedBox(height: 16),
        _buildSponsorSection(
          title: bahasa['logo_sponsor_title'] ?? 'Logo Sponsor',
          desc: bahasa['logo_sponsor_desc'] ?? 'Tampilkan logo sponsor pada halaman voting.',
          noteText: bahasa['logo_sponsor_note'] ?? 'Hover logo untuk menghapus, klik area untuk menambah.',
          noteColor: const Color(0xFFDC2626),
        ),
      ],
    );
  }

  Widget _buildVersiTampilanSection() {
    if (!_stepWebInitLoaded && !_stepWebInitLoading) {
      _stepWebInitLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadTemplatesAndThemes());
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(bahasa['pilih_versi_tampilan'] ?? 'Pilih Versi Tampilan', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            bahasa['pilih_versi_tampilan_desc'] ?? 'Pilih versi halaman voting yang ingin digunakan.',
            style: TextStyle(color: Colors.grey[600]),
          ),

          const SizedBox(height: 16),
          if (voteTemplates.isEmpty)
            _stepWebInitLoading
              ? const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(color: Colors.red),
                ))
              : Text(
                  bahasa['gagal_muat_versi_tampilan'] ?? 'Gagal memuat versi tampilan.',
                  style: TextStyle(color: Colors.grey[600]),
                )
          else
            ...voteTemplates.map((opt) {
              final id = opt['id']?.toString();
              final selected = versiTampilan == id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => setState(() => versiTampilan = id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFFDEDEA) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? const Color(0xFFDC2626) : Colors.grey.shade300,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 18,
                          color: selected ? const Color(0xFFDC2626) : Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(opt['nama']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(opt['view']?.toString() ?? '-', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildLanguageOption({required String code, required String flag, required String label}) {
    final selected = bahasaVote == code;
    return InkWell(
      onTap: () => setState(() => bahasaVote = code),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFDEDEA) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFFDC2626) : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? const Color(0xFFDC2626) : Colors.grey,
            ),
            const SizedBox(width: 10),
            Text(flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseRgbColor(String rgb) {
    final parts = rgb.split(',').map((p) => int.parse(p.trim())).toList();
    return Color.fromARGB(255, parts[0], parts[1], parts[2]);
  }

  List<Color> _gradientHexColors(String gradient) {
    return RegExp(r'#([0-9a-fA-F]{6})')
      .allMatches(gradient)
      .map((m) => Color(int.parse('FF${m.group(1)}', radix: 16)))
      .toList();
  }

  // Templates & themes ini vote-independent (bukan lewat {trayId}), jadi bisa
  // dipakai bareng buat "Pilih Versi Tampilan" dan "Warna Template".
  Future<void> _loadTemplatesAndThemes() async {
    final results = await Future.wait([
      ApiService.get('/api/v1/create-vote/templates', xLanguage: langCode, token: token),
      ApiService.get('/api/v1/create-vote/themes', xLanguage: langCode, token: token),
    ]);

    if (!mounted) return;

    final templatesData = results[0]?['data'];
    final templates = templatesData is Map ? templatesData['templates'] : null;
    final themesData = results[1]?['data'];
    final themes = themesData is Map ? themesData['themes'] : null;

    setState(() {
      var ok = false;
      if (templates is List) {
        voteTemplates = templates.map((t) => Map<String, dynamic>.from(t as Map)).toList();
        if (versiTampilan == null && voteTemplates.isNotEmpty) {
          versiTampilan = voteTemplates.first['id']?.toString();
        }
        ok = true;
      }
      if (themes is List) {
        voteThemes = themes.map((t) => Map<String, dynamic>.from(t as Map)).toList();
        ok = true;
      }
      _stepWebInitError = !ok;
      _stepWebInitLoaded = true;
      _stepWebInitLoading = false;
    });
  }

  Future<void> _loadPaymentMethods() async {
    final result = await ApiService.get(
      '/api/v1/create-vote/payment-methods',
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return;

    final data = result?['data'];
    final methods = data is Map ? data['payment_method'] : null;

    setState(() {
      if (methods is List) {
        _paymentMethods = methods.map((m) => Map<String, dynamic>.from(m as Map)).toList();
        for (final m in _paymentMethods) {
          final id = m['id']?.toString();
          if (id != null && m['flag_default']?.toString() == '1') {
            _selectedPaymentMethodIds.add(id);
          }
        }
        _paymentMethodsError = false;
      } else {
        _paymentMethodsError = true;
      }
      _paymentMethodsLoaded = true;
      _paymentMethodsLoading = false;
    });
  }

  List<Map<String, dynamic>> _methodsForPaymentRegionKey(String key) {
    switch (key) {
      case 'US':
        return _paymentMethods.where((m) => m['region'] == 'US').toList();
      case 'ID':
        return _paymentMethods.where((m) => m['region'] == 'ID').toList();
      case 'SG':
        return _paymentMethods.where((m) => m['region'] == 'SG' && m['region_pm'] == 'SG').toList();
      case 'PH':
        return _paymentMethods.where((m) => m['region'] == 'PH').toList();
      case 'MY':
        return _paymentMethods.where((m) => m['region'] == 'MY').toList();
      case 'TH':
        return _paymentMethods.where((m) => m['region'] == 'TH').toList();
      case 'EU':
        return _paymentMethods.where((m) =>
          m['region'] == 'SG' && ['EU', 'GB', 'PL'].contains(m['region_pm'])).toList();
      default:
        return [];
    }
  }

  TextEditingController _feeRpController(Map<String, dynamic> method) {
    final id = method['id'].toString();
    return _feeRpControllers.putIfAbsent(
      id,
      () => TextEditingController(text: (method['fee'] ?? 0).toString()),
    );
  }

  TextEditingController _feePercentController(Map<String, dynamic> method) {
    final id = method['id'].toString();
    return _feePercentControllers.putIfAbsent(
      id,
      () => TextEditingController(text: (method['fee_percent'] ?? 0).toString()),
    );
  }

  Widget _buildStepPengaturanPembayaran() {
    if (!_paymentMethodsLoaded && !_paymentMethodsLoading) {
      _paymentMethodsLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPaymentMethods());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          bahasa['pengaturan_pembayaran'] ?? 'Pengaturan Pembayaran',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        if (_paymentMethodsLoading)
          const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: CircularProgressIndicator(color: Colors.red),
          ))
        else if (_paymentMethodsError)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Text(
                    bahasa['gagal_muat_metode_pembayaran'] ?? 'Gagal memuat metode pembayaran.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => setState(() {
                      _paymentMethodsLoaded = false;
                      _paymentMethodsLoading = false;
                    }),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                    ),
                    child: Text(bahasa['muat_ulang'] ?? 'Muat Ulang'),
                  ),
                ],
              ),
            ),
          )
        else ...[
          _buildPaymentRegionGroupSection(
            title: bahasa['metode_pembayaran_global'] ?? 'Metode Pembayaran Global',
            regions: _paymentGlobalRegions,
          ),
          const SizedBox(height: 16),
          _buildPaymentRegionGroupSection(
            title: bahasa['metode_pembayaran_asia'] ?? 'Metode Pembayaran Asia',
            regions: _paymentAsiaRegions,
          ),
          const SizedBox(height: 16),
          _buildPaymentRegionGroupSection(
            title: bahasa['metode_pembayaran_eropa'] ?? 'Metode Pembayaran Eropa',
            regions: _paymentEuropeRegions,
          ),

          if (_showError && _selectedPaymentMethodIds.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              bahasa['metode_pembayaran_wajib_1'] ?? 'Minimal 1 metode pembayaran wajib dipilih sebelum lanjut.',
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildPaymentRegionGroupSection({
    required String title,
    required List<Map<String, String>> regions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        ...regions.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildPaymentRegionCard(r['key']!, r['name']!),
        )),
      ],
    );
  }

  Widget _buildPaymentRegionCard(String regionKey, String regionName) {
    final methods = _methodsForPaymentRegionKey(regionKey);
    final active = _activeRegions.contains(regionKey);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(regionName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      (bahasa['pilih_metode_pembayaran_desc'] ??
                        'Pilih metode pembayaran yang tersedia untuk pengguna di {region}.')
                        .replaceAll('{region}', regionName),
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: active,
                activeThumbColor: const Color(0xFFDC2626),
                onChanged: methods.isEmpty ? null : (v) => setState(() {
                  if (v) {
                    _activeRegions.add(regionKey);
                  } else {
                    _activeRegions.remove(regionKey);
                  }
                }),
              ),
            ],
          ),

          if (active && methods.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
              child: _buildPaymentMethodListForRegion(methods),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentMethodListForRegion(List<Map<String, dynamic>> methods) {
    final byCategory = <String, List<Map<String, dynamic>>>{};
    for (final m in methods) {
      final cat = m['id_category_payget']?.toString() ?? '-';
      byCategory.putIfAbsent(cat, () => []).add(m);
    }
    for (final list in byCategory.values) {
      list.sort((a, b) => ((a['sort'] as num?) ?? 9999).compareTo((b['sort'] as num?) ?? 9999));
    }

    final allIds = methods.map((m) => m['id'].toString()).toSet();
    final allSelected = allIds.isNotEmpty && allIds.every(_selectedPaymentMethodIds.contains);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCheckboxTile(
          value: allSelected,
          label: bahasa['pilih_semua'] ?? 'Pilih Semua',
          onChanged: (v) => setState(() {
            if (v) {
              _selectedPaymentMethodIds.addAll(allIds);
            } else {
              _selectedPaymentMethodIds.removeAll(allIds);
            }
          }),
        ),
        ...byCategory.entries.map((entry) {
          final label = _paymentCategoryLabels[entry.key] ?? (bahasa['lainnya'] ?? 'Lainnya');
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 12)),
                const SizedBox(height: 10),
                ...entry.value.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildPaymentMethodTile(m),
                )),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPaymentMethodTile(Map<String, dynamic> method) {
    final id = method['id'].toString();
    final selected = _selectedPaymentMethodIds.contains(id);
    final useDefault = !_customFeePaymentMethodIds.contains(id);
    final name = method['payment_name']?.toString() ?? '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() {
            if (selected) {
              _selectedPaymentMethodIds.remove(id);
            } else {
              _selectedPaymentMethodIds.add(id);
            }
          }),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: selected,
                  activeColor: const Color(0xFFDC2626),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) => setState(() {
                    if (v ?? false) {
                      _selectedPaymentMethodIds.add(id);
                    } else {
                      _selectedPaymentMethodIds.remove(id);
                    }
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
        ),

        if (selected) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCheckboxTile(
                  value: useDefault,
                  label: bahasa['samakan_dengan_default'] ?? 'Samakan dengan default',
                  onChanged: (v) => setState(() {
                    if (v) {
                      _customFeePaymentMethodIds.remove(id);
                    } else {
                      _customFeePaymentMethodIds.add(id);
                    }
                  }),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildLabeledField(
                        label: bahasa['fee_rp'] ?? 'Fee (Rp)',
                        controller: _feeRpController(method),
                        keyboardType: TextInputType.number,
                        readOnly: useDefault,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildLabeledField(
                        label: bahasa['fee_persen'] ?? 'Fee (%)',
                        controller: _feePercentController(method),
                        keyboardType: TextInputType.number,
                        readOnly: useDefault,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWarnaTemplateSection({int perRow = 3}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(bahasa['warna_template'] ?? 'Warna Template', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            bahasa['warna_template_desc'] ?? 'Tentukan warna template halaman voting.',
            style: TextStyle(color: Colors.grey[600]),
          ),

          const SizedBox(height: 16),
          _buildWarnaTemplateGrid(perRow: perRow),
        ],
      ),
    );
  }

  Widget _buildWarnaTemplateGrid({int perRow = 3}) {
    if (!_stepWebInitLoaded && !_stepWebInitLoading) {
      _stepWebInitLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadTemplatesAndThemes());
    }

    if (voteThemes.isEmpty) {
      if (_stepWebInitLoading) {
        return const Center(child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(color: Colors.red),
        ));
      }
      if (_stepWebInitError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(
                  bahasa['gagal_muat_warna_template'] ?? 'Gagal memuat warna template.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => setState(() {
                    _stepWebInitLoaded = false;
                    _stepWebInitLoading = false;
                  }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFDC2626)),
                  ),
                  child: Text(bahasa['muat_ulang'] ?? 'Muat Ulang'),
                ),
              ],
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final rows = <Widget>[];

    for (var i = 0; i < voteThemes.length; i += perRow) {
      final chunk = voteThemes.skip(i).take(perRow).toList();
      final isLastRow = i + perRow >= voteThemes.length;

      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: isLastRow ? 0 : 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(perRow, (index) {
              final isLastSlot = index == perRow - 1;
              if (index >= chunk.length) {
                return const Expanded(child: SizedBox.shrink());
              }
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: isLastSlot ? 0 : 12),
                  child: _buildColorSwatch(chunk[index]),
                ),
              );
            }),
          ),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildColorSwatch(Map<String, dynamic> theme) {
    final id = theme['id'] as int;
    final name = theme['name'] as String? ?? '-';
    final selected = themeId == id;

    final primary = _parseRgbColor(theme['primary'] as String? ?? '0,0,0');
    final gradientColors = _gradientHexColors(theme['primary_gradient'] as String? ?? '');
    final dots = <Color>[
      gradientColors.isNotEmpty ? gradientColors.first : primary,
      primary,
      gradientColors.length > 1 ? gradientColors.last : primary,
    ];

    final label = name == 'default' ? (bahasa['warna_default'] ?? 'default') : name;

    return InkWell(
      onTap: () => setState(() => themeId = id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? const Color(0xFFFDEDEA) : Colors.white,
          border: Border.all(
            color: selected ? const Color(0xFFDC2626) : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: dots
                .map((c) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  ),
                ))
                .toList(),
            ),
            const SizedBox(height: 10),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 16,
              color: selected ? const Color(0xFFDC2626) : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleSection({
    required String title,
    required String desc,
    required bool value,
    required void Function(bool) onChanged,
    List<Widget>? expandedChildren,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(desc, style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: value,
                activeThumbColor: const Color(0xFFDC2626),
                onChanged: onChanged,
              ),
            ],
          ),

          if (value && expandedChildren != null) ...[
            const SizedBox(height: 16),
            ...expandedChildren,
          ],
        ],
      ),
    );
  }

  void _addFaq() {
    setState(() {
      faqList.add({
        'pertanyaan': TextEditingController(),
        'jawaban': TextEditingController(),
      });
    });
  }

  void _removeFaq(int index) {
    setState(() {
      faqList[index]['pertanyaan']?.dispose();
      faqList[index]['jawaban']?.dispose();
      faqList.removeAt(index);
    });
  }

  Widget _buildFaqCard(int index) {
    final faq = faqList[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(bahasa['pertanyaan'] ?? 'Pertanyaan', style: const TextStyle(fontWeight: FontWeight.bold)),
              InkWell(
                onTap: () => _removeFaq(index),
                child: Icon(Icons.close, size: 18, color: Colors.grey[400]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: faq['pertanyaan'],
            decoration: InputDecoration(
              hintText: bahasa['masukkan_pertanyaan'] ?? 'Masukkan pertanyaan',
              hintStyle: TextStyle(color: Colors.grey[400]),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDC2626)),
              ),
            ),
          ),

          const SizedBox(height: 12),
          Text(bahasa['jawaban'] ?? 'Jawaban', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: faq['jawaban'],
            maxLines: 3,
            decoration: InputDecoration(
              hintText: bahasa['masukkan_jawaban'] ?? 'Masukkan jawaban',
              hintStyle: TextStyle(color: Colors.grey[400]),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDC2626)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeksBerjalanSection() {
    return _buildToggleSection(
      title: bahasa['teks_berjalan_title'] ?? 'Teks Berjalan',
      desc: bahasa['teks_berjalan_desc'] ?? 'Tampilkan teks berjalan pada halaman voting.',
      value: teksBerjalanAktif,
      onChanged: (v) => setState(() => teksBerjalanAktif = v),
      expandedChildren: [
        Text(
          bahasa['sesuaikan_warna_bg'] ?? 'Sesuaikan Warna Background',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: teksBerjalanColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: _pickTeksBerjalanColor,
              icon: const Icon(Icons.edit, size: 16),
              label: Text(bahasa['edit_warna'] ?? 'Edit Warna'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        _buildLabeledField(
          label: bahasa['masukkan_teks_berjalan'] ?? 'Masukkan Teks Berjalan',
          controller: _teksBerjalanController,
          hint: bahasa['masukkan_teks_berjalan_hint'] ?? 'Masukkan isi teks berjalan',
        ),

        const SizedBox(height: 16),
        Text(
          bahasa['preview_teks_berjalan'] ?? 'Preview Teks Berjalan',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: teksBerjalanColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: MarqueeText(
            text: _teksBerjalanController.text.isEmpty
              ? bahasa['masukkan_teks_berjalan_hint'] ?? 'Masukkan isi teks berjalan'
              : _teksBerjalanController.text,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
      ],
    );
  }

  Future<void> _pickTeksBerjalanColor() async {
    const colors = <Color>[
      Color(0xFF14B8A6),
      Color(0xFFDC2626),
      Color(0xFF3B82F6),
      Color(0xFFF59E0B),
      Color(0xFF8B5CF6),
      Color(0xFF10B981),
      Color(0xFFEC4899),
      Color(0xFF111827),
    ];

    final picked = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(bahasa['pilih_warna'] ?? 'Pilih Warna'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((c) {
            final selected = c.toARGB32() == teksBerjalanColor.toARGB32();
            return InkWell(
              onTap: () => Navigator.pop(context, c),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? Colors.black : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );

    if (picked != null) {
      setState(() => teksBerjalanColor = picked);
    }
  }

  Widget _buildSponsorSection({
    required String title,
    required String desc,
    String? noteText,
    Color? noteColor,
  }) {
    return _buildToggleSection(
      title: title,
      desc: desc,
      value: sponsorAktif,
      onChanged: (v) => setState(() => sponsorAktif = v),
      expandedChildren: [
        if (noteText != null) ...[
          Text(noteText, style: TextStyle(color: noteColor ?? Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 12),
        ],
        _buildSponsorRow(1, sponsorBaris1, existingSponsor1Url, (file) => sponsorBaris1 = file),
        const SizedBox(height: 16),
        _buildSponsorRow(2, sponsorBaris2, existingSponsor2Url, (file) => sponsorBaris2 = file),
        const SizedBox(height: 16),
        _buildSponsorRow(3, sponsorBaris3, existingSponsor3Url, (file) => sponsorBaris3 = file),
      ],
    );
  }

  Widget _buildSponsorRow(int nomor, File? image, String? existingImageUrl, void Function(File) onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${bahasa['baris'] ?? 'Baris'} $nomor', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildImageUploadTile(
          image: image,
          onTap: () => _pickImage(onPicked),
          placeholder: bahasa['klik_drag_drop_logo'] ?? 'Klik atau drag & drop logo di sini',
          height: 110,
          existingImageUrl: existingImageUrl,
        ),
      ],
    );
  }

  Widget _buildStep4() {
    return webCategory == '0' ? _buildPengaturanTampilan() : const Column();
  }

  // Step 5 - Pengaturan Lanjutan
  Widget _buildStep5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          bahasa['pengaturan_lanjutan'] ?? 'Pengaturan Lanjutan',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 20),
        _buildPengaturanVotingCard(),

        const SizedBox(height: 16),
        _buildUrutanFinalisSection(),

        const SizedBox(height: 16),
        _buildIndikatorDataPemilihSection(),

        const SizedBox(height: 16),
        _buildArtikelTerkaitSection(),

        const SizedBox(height: 16),
        _buildBatasanJumlahVoteSection(),
      ],
    );
  }

  // Step terakhir - Promo dan Booster
  Widget _buildStepPromoBoost() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          bahasa['promo_dan_booster'] ?? 'Promo dan Booster',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        _buildBoostVoteCard(),
        if (jenisVote == 'paid') ...[
          const SizedBox(height: 16),
          _buildVoteGratisHarianCard(),
        ],
      ],
    );
  }

  Widget _buildBoostVoteCard() {
    return _buildToggleSection(
      title: bahasa['boost_vote_title'] ?? 'Boost Vote 🚀',
      desc: bahasa['boost_vote_desc'] ?? 'Votes yang dibeli selama periode promo akan dikalikan sesuai kelipatan yang dipilih.',
      value: boostAktif,
      onChanged: (v) => setState(() => boostAktif = v),
      expandedChildren: [
        Text(
          bahasa['periode_promo'] ?? 'PERIODE PROMO',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildLabeledField(
                label: bahasa['mulai'] ?? 'Mulai',
                required: true,
                controller: _boostMulaiController,
                hint: 'dd/mm/yyyy, --.-- --',
                readOnly: true,
                onTap: () => _pickDateTime(_boostMulaiController, (dt) => boostMulai = dt),
                suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLabeledField(
                label: bahasa['selesai'] ?? 'Selesai',
                required: true,
                controller: _boostSelesaiController,
                hint: 'dd/mm/yyyy, --.-- --',
                readOnly: true,
                onTap: () => _pickDateTime(_boostSelesaiController, (dt) => boostSelesai = dt),
                suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        Text.rich(
          TextSpan(
            text: bahasa['kelipatan_votes'] ?? 'KELIPATAN VOTES',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600], fontSize: 12),
            children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildBoostMultiplierOption(2),
            const SizedBox(width: 10),
            _buildBoostMultiplierOption(3),
            const SizedBox(width: 10),
            _buildBoostMultiplierOption(5),
            const SizedBox(width: 10),
            _buildBoostMultiplierOption(10),
          ],
        ),

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEFCE8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: boostMengertiChecked,
                  activeColor: const Color(0xFFDC2626),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) => setState(() => boostMengertiChecked = v ?? false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(color: Colors.grey[800], fontSize: 13),
                    children: [
                      TextSpan(text: bahasa['boost_disclaimer_1'] ?? 'Saya mengerti bahwa dengan mengaktifkan '),
                      TextSpan(
                        text: bahasa['boost_vote_plain'] ?? 'Boost Vote',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: bahasa['boost_disclaimer_2'] ??
                          ', jumlah votes yang ditampilkan pada peserta akan bertambah sesuai kelipatan, namun ',
                      ),
                      TextSpan(
                        text: bahasa['boost_disclaimer_3'] ?? 'pendapatan dihitung hanya dari votes yang dibeli',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: bahasa['boost_disclaimer_4'] ?? ', bukan dari total votes setelah dikalikan.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBoostMultiplierOption(int value) {
    final selected = boostMultiplier == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => boostMultiplier = value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFDEDEA) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFFDC2626) : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                'x$value',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: selected ? const Color(0xFFDC2626) : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                bahasa['lipat'] ?? 'lipat',
                style: TextStyle(fontSize: 12, color: selected ? const Color(0xFFDC2626) : Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoteGratisHarianCard() {
    return _buildToggleSection(
      title: bahasa['vote_gratis_harian_title'] ?? 'Vote Gratis Harian',
      desc: bahasa['vote_gratis_harian_desc'] ??
        'Aktifkan fitur vote gratis yang dapat digunakan satu kali setiap hari oleh voter dengan login menggunakan email yang sama.',
      value: voteGratisHarianAktif,
      onChanged: (v) => setState(() => voteGratisHarianAktif = v),
      expandedChildren: [
        _buildLabeledField(
          label: bahasa['batas_vote_gratis_per_hari'] ?? 'Batas Vote Gratis per Hari',
          required: true,
          controller: _batasVoteGratisController,
          keyboardType: TextInputType.number,
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(bahasa['vote_unit'] ?? 'vote', style: TextStyle(color: Colors.grey[500])),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          bahasa['batas_vote_gratis_desc'] ?? 'Setiap email dapat menggunakan vote gratis sebanyak jumlah yang diisi setiap hari.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
      ],
    );
  }


  Widget _buildPengaturanVotingCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(bahasa['pengaturan_voting_title'] ?? 'Pengaturan Voting', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            bahasa['pengaturan_voting_desc'] ??
              'Optimalkan pengalaman voting dengan fitur pengaturan yang fleksibel dan mudah disesuaikan sesuai kebutuhan event.',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),

          _buildSimpleToggleRow(
            title: bahasa['private_voting_title'] ?? 'Private Voting',
            desc: bahasa['private_voting_desc'] ?? 'Batasi akses voting hanya untuk pengguna tertentu yang memiliki link khusus.',
            value: privateVotingAktif,
            onChanged: (v) => setState(() => privateVotingAktif = v),
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),

          _buildSimpleToggleRow(
            title: bahasa['vote_live_title'] ?? 'Vote Live',
            desc: bahasa['vote_live_desc'] ?? 'Tampilkan penanda "Voting Sedang Live" di halaman voting saat voting berlangsung.',
            value: voteLiveAktif,
            onChanged: (v) => setState(() => voteLiveAktif = v),
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),

          _buildSimpleToggleRow(
            title: bahasa['fitur_countdown_title'] ?? 'Fitur Countdown',
            desc: bahasa['fitur_countdown_desc'] ?? 'Tampilkan countdown waktu pada halaman voting.',
            value: fiturCountdownAktif,
            onChanged: (v) => setState(() => fiturCountdownAktif = v),
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),

          _buildSimpleToggleRow(
            title: bahasa['tutup_halaman_voting_title'] ?? 'Tutup Halaman Voting',
            desc: bahasa['tutup_halaman_voting_desc'] ?? 'Setelah jadwal voting berakhir, voters tidak dapat lagi mengakses halaman voting.',
            value: tutupHalamanVotingAktif,
            onChanged: (v) => setState(() => tutupHalamanVotingAktif = v),
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),

          _buildSimpleToggleRow(
            title: bahasa['sembunyikan_nomor_finalis_title'] ?? 'Sembunyikan Nomor Finalis',
            desc: bahasa['sembunyikan_nomor_finalis_desc'] ?? 'Sembunyikan nomor finalis di halaman voting.',
            value: sembunyikanNomorFinalisAktif,
            onChanged: (v) => setState(() => sembunyikanNomorFinalisAktif = v),
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),

          _buildSimpleToggleRow(
            title: bahasa['notifikasi_title'] ?? 'Notifikasi',
            desc: bahasa['notifikasi_desc'] ?? 'Aktifkan pengiriman notifikasi terkait vote ini.',
            value: notifikasiAktif,
            onChanged: (v) => setState(() => notifikasiAktif = v),
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),

          _buildSimpleToggleRow(
            title: bahasa['sembunyikan_leaderboard_title'] ?? 'Sembunyikan Leaderboard',
            desc: bahasa['sembunyikan_leaderboard_desc'] ?? 'Sembunyikan seluruh papan peringkat di halaman voting.',
            value: sembunyikanLeaderboardAktif,
            onChanged: (v) => setState(() => sembunyikanLeaderboardAktif = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleToggleRow({
    required String title,
    required String desc,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(value: value, activeThumbColor: const Color(0xFFDC2626), onChanged: onChanged),
      ],
    );
  }

  Widget _buildRadioTile({
    required bool selected,
    required String label,
    String? desc,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            size: 20,
            color: selected ? const Color(0xFFDC2626) : Colors.grey,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (desc != null) ...[
                  const SizedBox(height: 2),
                  Text(desc, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxTile({
    required bool value,
    required String label,
    String? desc,
    required void Function(bool) onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: value,
              activeColor: const Color(0xFFDC2626),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (v) => onChanged(v ?? false),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (desc != null) ...[
                  const SizedBox(height: 2),
                  Text(desc, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrutanFinalisSection() {
    final options = [
      {
        'value': 'nomor_urut',
        'label': bahasa['urutan_nomor_urut_title'] ?? 'Berdasarkan Nomor Urut',
        'desc': bahasa['urutan_nomor_urut_desc'] ?? 'Daftar finalis diurutkan sesuai nomor urut yang ditentukan panitia.',
      },
      {
        'value': 'abjad',
        'label': bahasa['urutan_abjad_title'] ?? 'Berdasarkan Abjad Nama',
        'desc': bahasa['urutan_abjad_desc'] ?? 'Daftar finalis diurutkan secara alfabet: A → Z.',
      },
      {
        'value': 'jumlah_vote',
        'label': bahasa['urutan_total_vote_title'] ?? 'Berdasarkan Total Vote',
        'desc': bahasa['urutan_total_vote_desc'] ?? 'Daftar finalis diurutkan dari yang memiliki jumlah vote terbanyak.',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bahasa['urutan_finalis_title'] ?? 'Urutan Daftar Finalis (Sort Finalists)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            bahasa['urutan_finalis_desc'] ?? 'Atur bagaimana daftar finalis ditampilkan saat pengguna memilih kandidat.',
            style: TextStyle(color: Colors.grey[600]),
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bahasa['opsi_urutan'] ?? 'Opsi Urutan', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...options.asMap().entries.map((e) {
                  final isLast = e.key == options.length - 1;
                  return Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                    child: _buildRadioTile(
                      selected: urutanFinalis == e.value['value'],
                      label: e.value['label']!,
                      desc: e.value['desc'],
                      onTap: () => setState(() => urutanFinalis = e.value['value']!),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dataPemilihLabel(String key) {
    return _dataPemilihFields.firstWhere((f) => f['key'] == key)['label']!;
  }

  Widget _buildDataWajibColumn(List<String> keys) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: keys.asMap().entries.map((e) {
        final key = e.value;
        final isLast = e.key == keys.length - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
          child: _buildCheckboxTile(
            value: dataWajibPemilih.contains(key),
            label: _dataPemilihLabel(key),
            onChanged: (v) => setState(() {
              if (v) {
                dataWajibPemilih.add(key);
              } else {
                dataWajibPemilih.remove(key);
              }
            }),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIndikatorDataPemilihSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(bahasa['indikator_data_pemilih_title'] ?? 'Indikator Data Pemilih', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            bahasa['indikator_data_pemilih_desc'] ?? 'Tentukan data wajib yang harus diisi pengguna sebelum melakukan voting.',
            style: TextStyle(color: Colors.grey[600]),
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bahasa['syarat_voting_title'] ?? 'Syarat Voting', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(
                  bahasa['syarat_voting_desc'] ?? 'Atur syarat yang harus dipenuhi pengguna untuk dapat melakukan voting.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 12),
                _buildCheckboxTile(
                  value: loginRequiredAktif,
                  label: bahasa['login_required_title'] ?? 'Login Required',
                  desc: bahasa['login_required_desc'] ?? 'Hanya pengguna yang telah login ke KREEN yang dapat melakukan voting.',
                  onChanged: (v) => setState(() => loginRequiredAktif = v),
                ),
                const SizedBox(height: 14),
                _buildCheckboxTile(
                  value: verifikasiEmailAktif,
                  label: bahasa['verifikasi_email_title'] ?? 'Verifikasi Email',
                  desc: bahasa['verifikasi_email_desc'] ?? 'Hanya pengguna yang telah melakukan verifikasi email yang dapat melakukan voting.',
                  onChanged: (v) => setState(() => verifikasiEmailAktif = v),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bahasa['data_wajib_pemilih_title'] ?? 'Data Wajib Pemilih (Required Fields)', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(
                  bahasa['data_wajib_pemilih_desc'] ?? 'Pilih data yang wajib diisi pengguna saat melakukan voting.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildDataWajibColumn(const ['no_hp', 'nip', 'npwp', 'visa', 'asal_daerah'])),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDataWajibColumn(const ['nim', 'nisn', 'nik', 'email'])),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtikelCard(Map<String, dynamic> artikel) {
    final id = artikel['id']?.toString();
    final selected = selectedArtikelId == id;
    return InkWell(
      onTap: () => setState(() {
        selectedArtikelId = id;
        selectedArtikelTitle = artikel['title']?.toString();
      }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? const Color(0xFFDC2626) : Colors.grey.shade300, width: selected ? 2 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? const Color(0xFFDC2626) : Colors.grey,
            ),
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: artikel['thumbnail'] != null
                ? Image.network(artikel['thumbnail'], width: 64, height: 64, fit: BoxFit.cover)
                : Container(width: 64, height: 64, color: Colors.grey.shade200),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(artikel['title'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(artikel['desc'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtikelTerkaitSection() {
    final filteredArtikel = _artikelSearch.trim().isEmpty
      ? artikelList
      : artikelList.where((a) {
          final title = (a['title'] ?? '').toString().toLowerCase();
          return title.contains(_artikelSearch.trim().toLowerCase());
        }).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(bahasa['artikel_terkait_title'] ?? 'Artikel Terkait', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            bahasa['artikel_terkait_desc'] ?? 'Kaitkan voting dengan artikel dari media KREEN.',
            style: TextStyle(color: Colors.grey[600]),
          ),

          const SizedBox(height: 16),
          Text(bahasa['cari_artikel_label'] ?? 'Cari Artikel', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _artikelSearch = v),
              decoration: InputDecoration(
                hintText: bahasa['cari_artikel_hint'] ?? 'Cari artikel...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 16),
          if (filteredArtikel.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  bahasa['belum_ada_artikel'] ?? 'Belum ada data artikel',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
            )
          else
            ...filteredArtikel.map((a) => _buildArtikelCard(a)),
        ],
      ),
    );
  }

  Widget _buildBatasanJumlahVoteSection() {
    return _buildToggleSection(
      title: bahasa['batasan_jumlah_vote_title'] ?? 'Batasan Jumlah Vote',
      desc: bahasa['batasan_jumlah_vote_desc'] ?? 'Atur batas maksimal jumlah vote dalam satu kali transaksi (checkout).',
      value: batasanJumlahVoteAktif,
      onChanged: (v) => setState(() => batasanJumlahVoteAktif = v),
      expandedChildren: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildLabeledField(
                label: bahasa['batas_qty_per_transaksi'] ?? 'Batas Qty per Transaksi',
                controller: _batasQtyPerTransaksiController,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLabeledField(
                label: bahasa['batas_transaksi_per_voter'] ?? 'Batas Transaksi per Voter',
                controller: _batasTransaksiPerVoterController,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bahasa['pilih_indikator_batas_title'] ?? 'Pilih Indikator Wajib yang berlaku sebagai batas:',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ..._dataPemilihFields.asMap().entries.map((e) {
                final isLast = e.key == _dataPemilihFields.length - 1;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                  child: _buildRadioTile(
                    selected: indikatorBatasVote == e.value['key'],
                    label: e.value['label']!,
                    onTap: () => setState(() => indikatorBatasVote = e.value['key']),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

// Bottom sheet tambah/edit 1 finalis - dipakai dari tombol "+" merah di
// Daftar Finalis. Punya state form sendiri, cuma manggil balik onSave
// waktu "Simpan" ditekan.
// Bottom sheet "Tambah Banyak Finalis" - dua tab: form manual berulang,
// atau import dari file CSV (upload_pakai file_picker, parsing CSV manual
// tanpa package tambahan karena formatnya kita yang tentukan sendiri lewat
// template yang di-generate). Hasil import ditaruh balik ke tab Form Manual
// biar user bisa cek/edit sebelum "Simpan Semua".
class TambahBanyakFinalisSheet extends StatefulWidget {
  final Map<String, dynamic> bahasa;
  final Future<bool> Function(List<Map<String, dynamic>> rows) onSaveMultiple;

  const TambahBanyakFinalisSheet({super.key, required this.bahasa, required this.onSaveMultiple});

  @override
  State<TambahBanyakFinalisSheet> createState() => _TambahBanyakFinalisSheetState();
}

class _TambahBanyakFinalisSheetState extends State<TambahBanyakFinalisSheet> {
  int _tabIndex = 0; // 0 = Form Manual, 1 = Import CSV/Excel
  final List<Map<String, TextEditingController>> _rows = [];
  bool _importing = false;
  bool _saving = false;
  String? _importedFileName;

  Map<String, dynamic> get bahasa => widget.bahasa;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 3; i++) {
      _addRow();
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      for (final c in row.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _rows.add({
        'nomor_urut': TextEditingController(text: '${_rows.length + 1}'),
        'nama_finalis': TextEditingController(),
        'nama_tambahan': TextEditingController(),
        'profesi': TextEditingController(),
        'usia': TextEditingController(),
        'instagram': TextEditingController(),
        'facebook': TextEditingController(),
        'twitter': TextEditingController(),
        'linkedin': TextEditingController(),
        'deskripsi': TextEditingController(),
      });
    });
  }

  void _removeRow(int index) {
    setState(() {
      for (final c in _rows[index].values) {
        c.dispose();
      }
      _rows.removeAt(index);
    });
  }

  static const List<String> _importColumns = [
    'nomor_urut', 'nama_finalis', 'nama_tambahan', 'profesi', 'usia',
    'instagram', 'facebook', 'twitter', 'linkedin', 'deskripsi',
  ];

  Future<void> _downloadTemplate() async {
    final excelFile = Excel.createExcel();
    const sheetName = 'Finalis';
    final defaultSheet = excelFile.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != sheetName) {
      excelFile.rename(defaultSheet, sheetName);
    }
    final sheet = excelFile[sheetName];

    sheet.appendRow(_importColumns.map((h) => TextCellValue(h)).toList());
    for (final cell in sheet.row(0)) {
      cell?.cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.white,
        backgroundColorHex: ExcelColor.fromHexString('FFDC2626'),
      );
    }

    const examples = [
      ['1', 'Budi Santoso', 'Budi', 'Pelajar', '18', 'budi_ig', 'budifb', 'budi_x', 'budi_in', 'Finalis dari Jakarta'],
      ['2', 'Sari Dewi', 'Sari', 'Mahasiswa', '20', 'sari_ig', '', '', '', 'Finalis dari Bandung'],
      ['3', 'Andi Kurniawan', '', 'Guru', '35', '', '', '', '', ''],
    ];
    for (final row in examples) {
      sheet.appendRow(row.map((v) => TextCellValue(v)).toList());
    }

    sheet.appendRow(const []);
    sheet.appendRow([
      TextCellValue(
        bahasa['template_finalis_note'] ??
          '* nomor_urut dan nama_finalis wajib diisi. Hapus baris contoh ini sebelum upload.',
      ),
    ]);

    final bytes = excelFile.encode();
    if (bytes == null) return;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/template_finalis.xlsx');
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles([XFile(file.path)], text: 'Template Finalis');
  }

  Future<void> _pickImportFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
    );
    if (result == null || result.files.single.path == null) return;

    setState(() => _importing = true);

    try {
      final path = result.files.single.path!;
      final isXlsx = path.toLowerCase().endsWith('.xlsx');

      List<List<String>> parsedRows;
      if (isXlsx) {
        final bytes = await File(path).readAsBytes();
        final excelFile = Excel.decodeBytes(bytes);
        final firstSheetName = excelFile.tables.keys.isNotEmpty ? excelFile.tables.keys.first : null;
        final sheet = firstSheetName != null ? excelFile.tables[firstSheetName] : null;
        parsedRows = (sheet?.rows ?? [])
          .map((row) => row.map((cell) => cell?.value?.toString().trim() ?? '').toList())
          .toList();
      } else {
        final content = await File(path).readAsString();
        parsedRows = content
          .split(RegExp(r'\r?\n'))
          .where((l) => l.trim().isNotEmpty)
          .map((l) => l.split(',').map((c) => c.trim()).toList())
          .toList();
      }

      if (parsedRows.length > 1) {
        for (final row in _rows) {
          for (final c in row.values) {
            c.dispose();
          }
        }
        _rows.clear();

        for (var i = 1; i < parsedRows.length; i++) {
          final cols = parsedRows[i];
          final nomorUrut = cols.isNotEmpty ? cols[0].trim() : '';
          final namaFinalis = cols.length > 1 ? cols[1].trim() : '';
          // Lewatin baris kosong/catatan template (mis. "* nomor_urut dan
          // nama_finalis wajib diisi...") yang gak punya nama_finalis.
          if (nomorUrut.isEmpty || namaFinalis.isEmpty) continue;

          _rows.add({
            'nomor_urut': TextEditingController(text: nomorUrut),
            'nama_finalis': TextEditingController(text: namaFinalis),
            'nama_tambahan': TextEditingController(text: cols.length > 2 ? cols[2].trim() : ''),
            'profesi': TextEditingController(text: cols.length > 3 ? cols[3].trim() : ''),
            'usia': TextEditingController(text: cols.length > 4 ? cols[4].trim() : ''),
            'instagram': TextEditingController(text: cols.length > 5 ? cols[5].trim() : ''),
            'facebook': TextEditingController(text: cols.length > 6 ? cols[6].trim() : ''),
            'twitter': TextEditingController(text: cols.length > 7 ? cols[7].trim() : ''),
            'linkedin': TextEditingController(text: cols.length > 8 ? cols[8].trim() : ''),
            'deskripsi': TextEditingController(text: cols.length > 9 ? cols[9].trim() : ''),
          });
        }

        if (_rows.isEmpty) _addRow();
      }

      setState(() {
        _importedFileName = result.files.single.name;
        _importing = false;
        _tabIndex = 0;
      });
    } catch (e) {
      setState(() => _importing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(bahasa['gagal_import_file'] ?? 'Gagal membaca file')),
        );
      }
    }
  }

  bool get _canSave =>
    _rows.any((r) => r['nama_finalis']!.text.trim().isNotEmpty && r['nomor_urut']!.text.trim().isNotEmpty);

  Future<void> _saveAll() async {
    final rows = _rows
      .where((r) => r['nama_finalis']!.text.trim().isNotEmpty && r['nomor_urut']!.text.trim().isNotEmpty)
      .map((r) => <String, dynamic>{
        'nomor_urut': r['nomor_urut']!.text.trim(),
        'nama_finalis': r['nama_finalis']!.text.trim(),
        'nama_tambahan': r['nama_tambahan']!.text.trim(),
        'usia': r['usia']!.text.trim(),
        'profesi': r['profesi']!.text.trim(),
        'instagram': r['instagram']!.text.trim(),
        'facebook': r['facebook']!.text.trim(),
        'twitter': r['twitter']!.text.trim(),
        'linkedin': r['linkedin']!.text.trim(),
        'deskripsi': r['deskripsi']!.text.trim(),
        'video_profile': '',
        'foto': null,
      })
      .toList();

    if (rows.isEmpty) return;

    setState(() => _saving = true);
    final success = await widget.onSaveMultiple(rows);

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
      initialChildSize: 0.9,
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
                    Text(
                      bahasa['tambah_banyak_finalis'] ?? 'Tambah Banyak Finalis',
                      style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Expanded(child: _tabButton(0, bahasa['form_manual'] ?? 'Form Manual')),
                          Expanded(child: _tabButton(1, bahasa['import_csv_excel'] ?? 'Import CSV/Excel')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: Colors.grey.shade200),
                  ],
                ),
              ),

              Expanded(
                child: _tabIndex == 0 ? _buildFormManual(scrollController) : _buildImportTab(scrollController),
              ),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100))),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _tabIndex == 0
                          ? (bahasa['isi_minimal_1_baris'] ?? 'Isi minimal 1 baris')
                          : (bahasa['upload_file_dulu'] ?? 'Upload file CSV/Excel terlebih dahulu'),
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(bahasa['batal'] ?? 'Batal', style: const TextStyle(color: Colors.black87)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: (_canSave && !_saving) ? _saveAll : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check, size: 16),
                      label: Text(
                        _saving ? (bahasa['menyimpan'] ?? 'Menyimpan...') : (bahasa['simpan_semua'] ?? 'Simpan Semua'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _tabButton(int index, String label) {
    final selected = _tabIndex == index;
    return InkWell(
      onTap: () => setState(() => _tabIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
            : null,
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? Colors.black87 : Colors.grey[600], fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildFormManual(ScrollController scrollController) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: bahasa['kolom_prefix'] ?? 'Kolom ',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    children: [
                      const TextSpan(text: '*', style: TextStyle(color: Colors.red)),
                      TextSpan(text: bahasa['wajib_diisi_suffix'] ?? ' wajib diisi.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _addRow,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFDC2626)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: Text(bahasa['tambah_baris'] ?? 'Tambah Baris', style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),

          const SizedBox(height: 16),
          ...List.generate(_rows.length, (i) => _buildRowCard(i)),
        ],
      ),
    );
  }

  Widget _buildRowCard(int index) {
    final row = _rows[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Color(0xFFFDEDEA), shape: BoxShape.circle),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                ),
              ),
              const Spacer(),
              if (_rows.length > 1)
                InkWell(
                  onTap: () => _removeRow(index),
                  child: Text(bahasa['hapus'] ?? 'Hapus', style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _miniField(bahasa['no_urut'] ?? 'No Urut', row['nomor_urut']!, required: true, keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: _miniField(bahasa['usia'] ?? 'Usia', row['usia']!, keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 10),
          _miniField(bahasa['nama_finalis'] ?? 'Nama Finalis', row['nama_finalis']!, required: true, hint: bahasa['nama_lengkap'] ?? 'Nama lengkap'),
          const SizedBox(height: 10),
          _miniField(bahasa['nama_tambahan'] ?? 'Nama Tambahan', row['nama_tambahan']!, hint: bahasa['nama_panggilan'] ?? 'Nama panggilan'),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _miniField(bahasa['profesi_aktivitas'] ?? 'Profesi / Aktivitas', row['profesi']!)),
              const SizedBox(width: 8),
              Expanded(child: _miniField('Instagram', row['instagram']!, hint: '@username')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _miniField('Facebook', row['facebook']!)),
              const SizedBox(width: 8),
              Expanded(child: _miniField('Twitter', row['twitter']!, hint: '@username')),
            ],
          ),
          const SizedBox(height: 10),
          _miniField('LinkedIn', row['linkedin']!),
          const SizedBox(height: 10),
          _miniField(bahasa['deskripsi'] ?? 'Deskripsi', row['deskripsi']!, maxLines: 2, hint: bahasa['deskripsi_singkat'] ?? 'Deskripsi singkat...'),
        ],
      ),
    );
  }

  Widget _miniField(
    String label,
    TextEditingController controller, {
    bool required = false,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            children: [if (required) const TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDC2626))),
          ),
        ),
      ],
    );
  }

  Widget _buildImportTab(ScrollController scrollController) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _stepDot(1, bahasa['download_template'] ?? 'Download template', true),
              _stepLine(),
              _stepDot(2, bahasa['upload_file'] ?? 'Upload file', _importedFileName != null),
              _stepLine(),
              _stepDot(3, bahasa['cek_edit_data'] ?? 'Cek & edit data', false),
            ],
          ),

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.grid_on, color: Color(0xFF3B82F6)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bahasa['download_template_excel'] ?? 'Download Template Excel',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bahasa['download_template_excel_desc'] ?? 'Template sudah terformat per-kolom. Isi data lalu upload kembali.',
                        style: const TextStyle(color: Color(0xFF1E3A8A), fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _downloadTemplate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.download, size: 16),
                        label: Text(bahasa['download_template_csv'] ?? 'Download Template (.xlsx)', style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          InkWell(
            onTap: _importing ? null : _pickImportFile,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                color: Colors.grey.shade50,
              ),
              child: _importing
                ? const Center(child: CircularProgressIndicator(color: Colors.red))
                : Column(
                    children: [
                      Icon(Icons.cloud_upload_outlined, color: Colors.grey[400], size: 32),
                      const SizedBox(height: 10),
                      Text(
                        _importedFileName ?? (bahasa['klik_untuk_pilih_file'] ?? 'Klik untuk memilih file'),
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text('.xlsx, .csv — maks 5MB', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepDot(int number, String label, bool active) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF3B82F6) : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Text('$number', style: TextStyle(color: active ? Colors.white : Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600]), textAlign: TextAlign.center, maxLines: 2),
        ],
      ),
    );
  }

  Widget _stepLine() {
    return Container(width: 24, height: 1, margin: const EdgeInsets.only(bottom: 20), color: Colors.grey.shade300);
  }
}