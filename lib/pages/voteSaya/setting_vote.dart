
// ignore_for_file: deprecated_member_use, non_constant_identifier_names, use_build_context_synchronously

import 'dart:io';

import 'package:admin_vote_mobile/helper/global_function.dart';
import 'package:admin_vote_mobile/helper/global_widget.dart';
import 'package:admin_vote_mobile/services/api_services.dart';
import 'package:admin_vote_mobile/services/lang_service.dart';
import 'package:admin_vote_mobile/services/storage_services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class SettingVote extends StatefulWidget {
  final String JudulVote;
  final String idVote;
  final List<dynamic> finalisList;
  const SettingVote({
    super.key,
    required this.JudulVote,
    required this.idVote,
    this.finalisList = const [],
  });

  @override
  State<SettingVote> createState() => SettingVoteState();
}

class SettingVoteState extends State<SettingVote> {
  String? token;
  String? langCode;
  String? userName;
  Map<String, dynamic> bahasa = {};

  bool isLoading = true;
  bool _dataLoading = true;
  bool _dataError = false;
  String? jenisVote; // 'paid' | 'free' - dari step2

  bool isMenuSetting = true;
  bool isDurasiVote = false;
  bool isUrutanFinalis = false;
  bool isPaymentMethod = false;
  bool iscustomTheme = false;
  bool isNextSetting = false;
  bool isRanking = false;
  bool isJadwalTutup = false;

  final ImagePicker _imagePicker = ImagePicker();

  // Durasi Vote
  String zonaWaktu = 'WIB';
  final _tanggalMulaiController = TextEditingController();
  final _tanggalSelesaiController = TextEditingController();
  DateTime? tanggalMulai;
  DateTime? tanggalSelesai;

  // Urutan Finalis
  late List<dynamic> _finalisUrutan;
  bool urutanTerkunci = true;

  // Metode Pembayaran - diambil dari GET step6, sama seperti wizard new_vote.
  final Set<String> _activeRegionsVote = {};
  final Set<String> _selectedPaymentIds = {};
  List<Map<String, dynamic>> _paymentMethods = [];

  // id_category_payget -> label tampilan (sama seperti mapping di new_vote.dart)
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

  static const List<Map<String, String>> _paymentRegionsAll = [
    {'key': 'ID', 'name': 'Indonesia'},
    {'key': 'SG', 'name': 'Singapore'},
    {'key': 'PH', 'name': 'Philippines'},
    {'key': 'MY', 'name': 'Malaysia'},
    {'key': 'TH', 'name': 'Thailand'},
    {'key': 'EU', 'name': 'Eropa'},
    {'key': 'US', 'name': 'United States'},
  ];

  List<Map<String, dynamic>> _methodsForPaymentRegionKeyVote(String key) {
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

  // Custom Tampilan
  String? versiTampilanVote; // vote_template_id, diambil dari GET create-vote/templates
  List<Map<String, dynamic>> voteTemplates = [];
  int themeIdVote = 0;
  bool teksBerjalanVoteAktif = false;
  Color teksBerjalanVoteColor = const Color(0xFFDC2626);
  final _teksBerjalanVoteController = TextEditingController();
  bool logoSponsorVoteAktif = false;
  File? sponsorVoteBaris1;
  File? sponsorVoteBaris2;
  File? sponsorVoteBaris3;

  // Warna Template - diambil dari GET step-web (voteThemes), sama seperti wizard.
  List<Map<String, dynamic>> voteThemes = [];

  // Pengaturan Lanjutan
  bool privateVotingVote = false;
  bool voteLiveVote = true;
  bool fiturCountdownVote = false;
  bool tutupHalamanVotingVote = false;
  bool sembunyikanNomorFinalisVote = false;
  bool notifikasiVote = true;
  String urutanDaftarFinalisVote = 'nomor_urut'; // 'nomor_urut' | 'abjad' | 'jumlah_vote'

  // Papan Peringkat
  bool sembunyikanLeaderboardVote = false;
  String tampilanJumlahVoteVote = 'angka'; // 'sembunyikan' | 'angka' | 'persentase'
  String jumlahFinalisDitampilkanVote = 'top10'; // 'top10' | 'top5' | 'top3'

  // Jadwal Tutup
  List<Map<String, dynamic>> jadwalTutupList = [];

  @override
  void initState() {
    super.initState();
    _finalisUrutan = List<dynamic>.from(widget.finalisList);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      await _getBahasa();
    });
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
      isLoading = false;
    });

    await _loadVoteSettingsData();
  }

  Map<String, dynamic>? _mapOf(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;

  Map<String, dynamic>? _voteOf(Map<String, dynamic>? result) {
    final vote = _mapOf(result?['data'])?['vote'];
    return vote is Map ? Map<String, dynamic>.from(vote) : null;
  }

  String? _str(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  // Ambil data yang sudah tersimpan lewat GET step2/step4/step-web/step5/step6,
  // persis pola yang dipakai di new_vote.dart mode edit.
  Future<void> _loadVoteSettingsData() async {
    final results = await Future.wait([
      ApiService.get('/api/v1/create-vote/${widget.idVote}/step2', xLanguage: langCode, token: token),
      ApiService.get('/api/v1/create-vote/${widget.idVote}/step4', xLanguage: langCode, token: token),
      ApiService.get('/api/v1/create-vote/templates', xLanguage: langCode, token: token),
      ApiService.get('/api/v1/create-vote/themes', xLanguage: langCode, token: token),
      ApiService.get('/api/v1/create-vote/${widget.idVote}/step5', xLanguage: langCode, token: token),
      ApiService.get('/api/v1/create-vote/${widget.idVote}/step6', xLanguage: langCode, token: token),
    ]);

    if (!mounted) return;

    final step2 = results[0];
    final step4 = results[1];
    final templatesResult = results[2];
    final themesResult = results[3];
    final step5 = results[4];
    final step6 = results[5];

    var hasAnyData = false;

    setState(() {
      // Step 2 - Durasi Vote
      final vote2 = _voteOf(step2);
      if (vote2 != null) {
        hasAnyData = true;
        jenisVote = _str(vote2['jenis_vote']);
        zonaWaktu = _str(vote2['code_timezone']) ?? zonaWaktu;

        final mulai = DateTime.tryParse(_str(vote2['tanggal_buka_vote']) ?? '');
        if (mulai != null) {
          tanggalMulai = mulai;
          _tanggalMulaiController.text = DateFormat('dd/MM/yyyy, HH:mm').format(mulai);
        }
        final selesai = DateTime.tryParse(_str(vote2['tanggal_tutup_vote']) ?? '');
        if (selesai != null) {
          tanggalSelesai = selesai;
          _tanggalSelesaiController.text = DateFormat('dd/MM/yyyy, HH:mm').format(selesai);
        }
      }

      // Step 4 - Custom Tampilan
      final vote4 = _voteOf(step4);
      if (vote4 != null) {
        hasAnyData = true;
        versiTampilanVote = _str(vote4['vote_template_id']) ?? versiTampilanVote;
        final serverThemeId = int.tryParse(_str(vote4['id_theme']) ?? '');
        if (serverThemeId != null) themeIdVote = serverThemeId;
        teksBerjalanVoteAktif = _str(vote4['flag_running_text']) == '1';
        if (_str(vote4['running_text']) != null) _teksBerjalanVoteController.text = vote4['running_text'];
        logoSponsorVoteAktif = _str(vote4['flag_sponsor']) == '1';
      }

      // Daftar Pilih Versi Tampilan (create-vote/templates)
      final templates = _mapOf(templatesResult?['data'])?['templates'];
      if (templates is List) {
        voteTemplates = templates.map((t) => Map<String, dynamic>.from(t as Map)).toList();
        if (versiTampilanVote == null && voteTemplates.isNotEmpty) {
          versiTampilanVote = voteTemplates.first['id']?.toString();
        }
      }

      // Daftar Warna Template (create-vote/themes)
      final themes = _mapOf(themesResult?['data'])?['themes'];
      if (themes is List) {
        voteThemes = themes.map((t) => Map<String, dynamic>.from(t as Map)).toList();
      }

      // Step 5 - Pengaturan Lanjutan (+ Sembunyikan Leaderboard buat Papan Peringkat)
      final vote5 = _voteOf(step5);
      if (vote5 != null) {
        hasAnyData = true;
        privateVotingVote = _str(vote5['private_voting']) == '1';
        voteLiveVote = _str(vote5['flag_live']) == '1';
        fiturCountdownVote = _str(vote5['flag_countdown']) == '1';
        tutupHalamanVotingVote = _str(vote5['flag_tutup_view']) == '1';
        sembunyikanNomorFinalisVote = _str(vote5['flag_hide_nomor_urut']) == '1';
        sembunyikanLeaderboardVote = _str(vote5['flag_hide_leaderboard']) == '1';
        notifikasiVote = _str(vote5['flag_notif']) == '1';
        urutanDaftarFinalisVote = _str(vote5['urutan_total_voting']) ?? urutanDaftarFinalisVote;
      }

      // Step 6 - Metode Pembayaran (khusus paid)
      final payment = _mapOf(step6?['data'])?['payment'];
      if (payment is Map) {
        final paymentMap = Map<String, dynamic>.from(payment);
        final methods = paymentMap['payment_method'];
        if (methods is List) {
          _paymentMethods = methods.map((m) => Map<String, dynamic>.from(m as Map)).toList();
        }
        final selected = paymentMap['selected_payment'];
        if (selected is List) {
          _selectedPaymentIds
            ..clear()
            ..addAll(selected.where((e) => e != null).map((e) => e.toString()));
        }
        // Region dianggap aktif kalau ada minimal 1 metode yang sudah dipilih di sana.
        for (final r in _paymentRegionsAll) {
          final regionMethodIds = _methodsForPaymentRegionKeyVote(r['key']!).map((m) => m['id'].toString());
          if (regionMethodIds.any(_selectedPaymentIds.contains)) {
            _activeRegionsVote.add(r['key']!);
          }
        }
      }

      _dataError = !hasAnyData;
      _dataLoading = false;
    });
  }

  @override
  void dispose() {
    _tanggalMulaiController.dispose();
    _tanggalSelesaiController.dispose();
    _teksBerjalanVoteController.dispose();
    for (final j in jadwalTutupList) {
      (j['mulaiController'] as TextEditingController?)?.dispose();
      (j['selesaiController'] as TextEditingController?)?.dispose();
    }
    super.dispose();
  }

  void _backToMenu() {
    setState(() {
      isMenuSetting = true;
      isDurasiVote = false;
      isUrutanFinalis = false;
      isPaymentMethod = false;
      iscustomTheme = false;
      isNextSetting = false;
      isRanking = false;
      isJadwalTutup = false;
    });
  }

  void _openSection(void Function() setFlag) {
    setState(() {
      isMenuSetting = false;
      isDurasiVote = false;
      isUrutanFinalis = false;
      isPaymentMethod = false;
      iscustomTheme = false;
      isNextSetting = false;
      isRanking = false;
      isJadwalTutup = false;
      setFlag();
    });
  }

  void _showSavedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(bahasa['tersimpan'] ?? 'Tersimpan')),
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
              child: (isLoading || _dataLoading)
                ? const Center(child: CircularProgressIndicator(color: Colors.red))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _buildBody(),
                  ),
            ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bahasa['bot_nav_4'] ?? 'Pengaturan',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  widget.JudulVote,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          buildIconCircle(
            child: Text(
              getInitial(userName ?? 'K'),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE04E39)),
            ),
            bgColor: const Color(0xFFFDEDEA),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (isMenuSetting) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_dataError) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      bahasa['gagal_muat_data_pengaturan'] ?? 'Gagal memuat data pengaturan.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      setState(() => _dataLoading = true);
                      _loadVoteSettingsData();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                    ),
                    child: Text(bahasa['muat_ulang'] ?? 'Muat Ulang'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _buildMenuList(),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _backToMenu,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chevron_left, size: 20, color: Colors.grey),
                Text(
                  bahasa['kembali_ke_pengaturan'] ?? 'Kembali ke Pengaturan',
                  style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (isDurasiVote) _buildDurasiVoteContent(),
          if (isUrutanFinalis) _buildUrutanFinalisContent(),
          if (isPaymentMethod) _buildPaymentMethodContent(),
          if (iscustomTheme) _buildCustomTampilanContent(),
          if (isNextSetting) _buildPengaturanLanjutanContent(),
          if (isRanking) _buildPapanPeringkatContent(),
          if (isJadwalTutup) _buildJadwalTutupContent(),
        ],
      ),
    );
  }

  Widget _buildMenuList() {
    final items = <Map<String, dynamic>>[
      {'title': bahasa['durasi_vote'] ?? 'Durasi Vote', 'onTap': () => _openSection(() => isDurasiVote = true)},
      {'title': bahasa['urutan_finalis_menu'] ?? 'Urutan Finalis', 'onTap': () => _openSection(() => isUrutanFinalis = true)},
      if (jenisVote == 'paid')
        {'title': bahasa['metode_pembayaran'] ?? 'Metode Pembayaran', 'onTap': () => _openSection(() => isPaymentMethod = true)},
      {'title': bahasa['custom_tampilan'] ?? 'Custom Tampilan', 'onTap': () => _openSection(() => iscustomTheme = true)},
      {'title': bahasa['pengaturan_lanjutan'] ?? 'Pengaturan Lanjutan', 'onTap': () => _openSection(() => isNextSetting = true)},
      {'title': bahasa['papan_peringkat'] ?? 'Papan Peringkat', 'onTap': () => _openSection(() => isRanking = true)},
      {'title': bahasa['jadwal_tutup'] ?? 'Jadwal Tutup', 'onTap': () => _openSection(() => isJadwalTutup = true)},
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final isLast = entry.key == items.length - 1;
          final item = entry.value;
          return InkWell(
            onTap: item['onTap'],
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item['title'],
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------- Shared small widgets ----------

  Widget _buildSectionTitleDesc(String title, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(desc, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildSaveButton(VoidCallback onPressed, {String? label}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFDC2626),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          label ?? (bahasa['simpan'] ?? 'Simpan'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
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

  Widget _buildToggleSection({
    required String title,
    required String desc,
    required bool value,
    required void Function(bool) onChanged,
    List<Widget>? expandedChildren,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSimpleToggleRow(title: title, desc: desc, value: value, onChanged: onChanged),
          if (value && expandedChildren != null) ...[
            const SizedBox(height: 16),
            ...expandedChildren,
          ],
        ],
      ),
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
    required void Function(bool) onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
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

  Widget _buildDateTimeField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: true,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: 'dd/mm/yyyy, --.-- --',
            hintStyle: TextStyle(color: Colors.grey[400]),
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage(void Function(File) onPicked) async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => onPicked(File(picked.path)));
  }

  // ---------- Durasi Vote ----------

  Widget _buildDurasiVoteContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitleDesc(
          bahasa['durasi_vote'] ?? 'Durasi Vote',
          bahasa['durasi_vote_desc'] ?? 'Tentukan kapan voting dimulai dan berakhir, serta zona waktu.',
        ),
        const SizedBox(height: 20),
        Text(bahasa['zona_waktu'] ?? 'Zona Waktu', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: zonaWaktu,
          items: const ['WIB', 'WITA', 'WIT']
            .map((z) => DropdownMenuItem(value: z, child: Text(z)))
            .toList(),
          onChanged: (v) => setState(() => zonaWaktu = v!),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildDateTimeField(
          label: bahasa['tanggal_jam_mulai_vote'] ?? 'Tanggal & Jam Mulai Vote',
          controller: _tanggalMulaiController,
          onTap: () => _pickDateTime(_tanggalMulaiController, (dt) => tanggalMulai = dt),
        ),
        const SizedBox(height: 16),
        _buildDateTimeField(
          label: bahasa['tanggal_jam_selesai_vote'] ?? 'Tanggal & Jam Selesai Vote',
          controller: _tanggalSelesaiController,
          onTap: () => _pickDateTime(_tanggalSelesaiController, (dt) => tanggalSelesai = dt),
        ),
        const SizedBox(height: 20),
        _buildSaveButton(_showSavedSnackBar),
      ],
    );
  }

  // ---------- Urutan Finalis ----------

  Widget _buildUrutanFinalisContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildSectionTitleDesc(
                bahasa['urutan_finalis_menu'] ?? 'Urutan Finalis',
                bahasa['urutan_finalis_drag_desc'] ?? 'Buka kunci, lalu drag kartu untuk mengubah posisi finalis.',
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => setState(() => urutanTerkunci = !urutanTerkunci),
              icon: Icon(urutanTerkunci ? Icons.lock_outline : Icons.lock_open_outlined, size: 16),
              label: Text(urutanTerkunci ? (bahasa['buka_kunci'] ?? 'Buka Kunci') : (bahasa['kunci_urutan'] ?? 'Kunci Urutan')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_finalisUrutan.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                bahasa['no_finalis'] ?? 'Belum ada finalis',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ),
          )
        else if (!urutanTerkunci)
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _finalisUrutan.removeAt(oldIndex);
                _finalisUrutan.insert(newIndex, item);
              });
            },
            children: _finalisUrutan.asMap().entries.map((e) {
              return Padding(
                key: ValueKey(e.value['id_finalis'] ?? e.key),
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildFinalisUrutanCard(e.value, draggable: true),
              );
            }).toList(),
          )
        else
          Column(
            children: _finalisUrutan.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildFinalisUrutanCard(f, draggable: false),
            )).toList(),
          ),

        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: urutanTerkunci ? null : () => setState(() {
                  _finalisUrutan = List<dynamic>.from(widget.finalisList);
                }),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey.shade300),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(bahasa['batal'] ?? 'Batal'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: urutanTerkunci ? null : () {
                  setState(() => urutanTerkunci = true);
                  _showSavedSnackBar();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(bahasa['simpan_urutan'] ?? 'Simpan Urutan'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFinalisUrutanCard(Map<String, dynamic> finalis, {required bool draggable}) {
    final poster = finalis['poster_finalis']?.toString();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
      ),
      child: Row(
        children: [
          if (draggable) ...[
            Icon(Icons.drag_indicator, color: Colors.grey[400]),
            const SizedBox(width: 8),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 40,
              height: 40,
              child: (poster != null && poster.isNotEmpty)
                ? Image.network(poster, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade100))
                : Container(color: Colors.grey.shade100, child: Icon(Icons.image_outlined, color: Colors.grey[400], size: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '#${(finalis['nomor_urut'] ?? '').toString().padLeft(2, '0')} ',
                    style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: finalis['nama_finalis']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Metode Pembayaran ----------

  Widget _buildPaymentMethodContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitleDesc(
          bahasa['metode_pembayaran'] ?? 'Metode Pembayaran',
          bahasa['metode_pembayaran_vote_desc'] ?? 'Aktifkan wilayah, lalu pilih metode pembayaran yang tersedia untuk voter di sana.',
        ),
        const SizedBox(height: 20),
        if (_paymentMethods.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                bahasa['gagal_muat_metode_pembayaran'] ?? 'Gagal memuat metode pembayaran.',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ),
          )
        else
          ..._paymentRegionsAll.map((r) {
            final methods = _methodsForPaymentRegionKeyVote(r['key']!);
            if (methods.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildRegionCardVote(r['key']!, r['name']!, methods),
            );
          }),
        const SizedBox(height: 8),
        _buildSaveButton(_showSavedSnackBar),
      ],
    );
  }

  Widget _buildRegionCardVote(String code, String name, List<Map<String, dynamic>> methods) {
    final active = _activeRegionsVote.contains(code);

    final byCategory = <String, List<Map<String, dynamic>>>{};
    for (final m in methods) {
      final cat = m['id_category_payget']?.toString() ?? '-';
      byCategory.putIfAbsent(cat, () => []).add(m);
    }
    for (final list in byCategory.values) {
      list.sort((a, b) => ((a['sort'] as num?) ?? 9999).compareTo((b['sort'] as num?) ?? 9999));
    }

    final allIds = methods.map((m) => m['id'].toString()).toSet();
    final allSelected = allIds.isNotEmpty && allIds.every(_selectedPaymentIds.contains);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
      ),
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
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      (bahasa['pilih_metode_pembayaran_desc'] ?? 'Pilih metode pembayaran untuk voter di {region}.')
                        .replaceAll('{region}', name),
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: active,
                activeThumbColor: const Color(0xFFDC2626),
                onChanged: (v) => setState(() {
                  if (v) { _activeRegionsVote.add(code); } else { _activeRegionsVote.remove(code); }
                }),
              ),
            ],
          ),

          if (active) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCheckboxTile(
                    value: allSelected,
                    label: bahasa['pilih_semua'] ?? 'Pilih Semua',
                    onChanged: (v) => setState(() {
                      if (v) { _selectedPaymentIds.addAll(allIds); } else { _selectedPaymentIds.removeAll(allIds); }
                    }),
                  ),
                  ...byCategory.entries.map((entry) {
                    final label = _paymentCategoryLabels[entry.key] ?? (bahasa['lainnya'] ?? 'Lainnya');
                    return Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 12)),
                          const SizedBox(height: 10),
                          ...entry.value.map((m) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildPaymentItemRowVote(m['id'].toString(), m['payment_name']?.toString() ?? '-'),
                          )),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentItemRowVote(String id, String name) {
    final selected = _selectedPaymentIds.contains(id);
    return InkWell(
      onTap: () => setState(() {
        if (selected) { _selectedPaymentIds.remove(id); } else { _selectedPaymentIds.add(id); }
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
                if (v ?? false) { _selectedPaymentIds.add(id); } else { _selectedPaymentIds.remove(id); }
              }),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey[700]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  // ---------- Custom Tampilan ----------

  Widget _buildCustomTampilanContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitleDesc(
          bahasa['pilih_versi_tampilan'] ?? 'Pilih Versi Tampilan',
          bahasa['pilih_versi_tampilan_template_desc'] ?? 'Pilih template layout untuk halaman voting.',
        ),
        const SizedBox(height: 12),
        if (voteTemplates.isEmpty)
          Text(
            bahasa['gagal_muat_versi_tampilan'] ?? 'Gagal memuat versi tampilan.',
            style: TextStyle(color: Colors.grey[500]),
          )
        else
          ...voteTemplates.map((opt) {
            final id = opt['id']?.toString();
            final selected = versiTampilanVote == id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFFDEDEA) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _buildRadioTile(
                  selected: selected,
                  label: opt['nama']?.toString() ?? '-',
                  desc: opt['view']?.toString(),
                  onTap: () => setState(() => versiTampilanVote = id),
                ),
              ),
            );
          }),

        const SizedBox(height: 20),
        Text(bahasa['warna_template'] ?? 'Warna Template', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 6),
        Text(
          bahasa['warna_template_tampilan_desc'] ?? 'Pilih warna template untuk tampilan halaman voting.',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        _buildThemeGridVote(),

        const SizedBox(height: 20),
        _buildToggleSection(
          title: bahasa['teks_berjalan_title'] ?? 'Teks Berjalan',
          desc: bahasa['teks_berjalan_desc'] ?? 'Tampilkan teks berjalan pada halaman voting.',
          value: teksBerjalanVoteAktif,
          onChanged: (v) => setState(() => teksBerjalanVoteAktif = v),
          expandedChildren: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: teksBerjalanVoteColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _teksBerjalanVoteController,
                    decoration: InputDecoration(
                      hintText: bahasa['masukkan_teks_berjalan_hint'] ?? 'Masukkan isi teks berjalan',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildToggleSection(
          title: bahasa['logo_sponsor_title'] ?? 'Logo Sponsor',
          desc: bahasa['logo_sponsor_upload_desc'] ?? 'Unggah logo sponsor untuk ditampilkan di halaman voting.',
          value: logoSponsorVoteAktif,
          onChanged: (v) => setState(() => logoSponsorVoteAktif = v),
          expandedChildren: [
            _buildSponsorRowVote(1, sponsorVoteBaris1, (f) => sponsorVoteBaris1 = f),
            const SizedBox(height: 12),
            _buildSponsorRowVote(2, sponsorVoteBaris2, (f) => sponsorVoteBaris2 = f),
            const SizedBox(height: 12),
            _buildSponsorRowVote(3, sponsorVoteBaris3, (f) => sponsorVoteBaris3 = f),
          ],
        ),

        const SizedBox(height: 20),
        _buildSaveButton(_showSavedSnackBar),
      ],
    );
  }

  Color _parseRgbColor(String rgb) {
    final parts = rgb.split(',').map((p) => int.tryParse(p.trim()) ?? 0).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return Color.fromARGB(255, parts[0], parts[1], parts[2]);
  }

  List<Color> _gradientHexColors(String gradient) {
    return RegExp(r'#([0-9a-fA-F]{6})')
      .allMatches(gradient)
      .map((m) => Color(int.parse('FF${m.group(1)}', radix: 16)))
      .toList();
  }

  Widget _buildThemeGridVote() {
    if (voteThemes.isEmpty) {
      return Text(
        bahasa['gagal_muat_warna_template'] ?? 'Gagal memuat warna template.',
        style: TextStyle(color: Colors.grey[500]),
      );
    }

    const perRow = 2;
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
              if (index >= chunk.length) return const Expanded(child: SizedBox.shrink());
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index == perRow - 1 ? 0 : 12),
                  child: _buildThemeCardVote(chunk[index]),
                ),
              );
            }),
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _buildThemeCardVote(Map<String, dynamic> theme) {
    final id = theme['id'] as int;
    final name = theme['name'] as String? ?? '-';
    final selected = themeIdVote == id;

    final primary = _parseRgbColor(theme['primary'] as String? ?? '0,0,0');
    final gradientColors = _gradientHexColors(theme['primary_gradient'] as String? ?? '');
    final dots = <Color>[
      gradientColors.isNotEmpty ? gradientColors.first : primary,
      primary,
      gradientColors.length > 1 ? gradientColors.last : primary,
    ];
    final label = name == 'default' ? (bahasa['warna_default'] ?? 'default') : name;

    return InkWell(
      onTap: () => setState(() => themeIdVote = id),
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
              children: dots.map((c) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(width: 16, height: 16, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
              )).toList(),
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

  Widget _buildSponsorRowVote(int nomor, File? image, void Function(File) onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${bahasa['baris'] ?? 'Baris'} $nomor', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _pickImage(onPicked),
          child: Container(
            width: double.infinity,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.grey.shade50,
            ),
            child: image != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(image, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
                )
              : Center(
                  child: Text(
                    bahasa['klik_drag_drop_logo'] ?? 'Klik atau drag & drop logo di sini',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ),
          ),
        ),
      ],
    );
  }

  // ---------- Pengaturan Lanjutan ----------

  Widget _buildPengaturanLanjutanContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitleDesc(
          bahasa['pengaturan_lanjutan'] ?? 'Pengaturan Lanjutan',
          bahasa['pengaturan_lanjutan_event_desc'] ?? 'Optimalkan pengalaman voting sesuai kebutuhan event kamu.',
        ),
        const SizedBox(height: 16),
        Text(bahasa['pengaturan_voting_title'] ?? 'Pengaturan Voting', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),

        _buildSimpleToggleRow(
          title: bahasa['private_voting_title'] ?? 'Private Voting',
          desc: bahasa['private_voting_desc'] ?? 'Batasi akses voting hanya untuk pengguna dengan link khusus.',
          value: privateVotingVote,
          onChanged: (v) => setState(() => privateVotingVote = v),
        ),
        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
        _buildSimpleToggleRow(
          title: bahasa['vote_live_title'] ?? 'Vote Live',
          desc: bahasa['vote_live_desc'] ?? 'Tampilkan penanda "Voting Sedang Live" saat voting berlangsung.',
          value: voteLiveVote,
          onChanged: (v) => setState(() => voteLiveVote = v),
        ),
        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
        _buildSimpleToggleRow(
          title: bahasa['fitur_countdown_title'] ?? 'Fitur Countdown',
          desc: bahasa['fitur_countdown_desc'] ?? 'Tampilkan countdown waktu pada halaman voting.',
          value: fiturCountdownVote,
          onChanged: (v) => setState(() => fiturCountdownVote = v),
        ),
        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
        _buildSimpleToggleRow(
          title: bahasa['tutup_halaman_voting_title'] ?? 'Tutup Halaman Voting',
          desc: bahasa['tutup_halaman_voting_vote_desc'] ?? 'Voter tidak dapat lagi mengakses halaman setelah jadwal berakhir.',
          value: tutupHalamanVotingVote,
          onChanged: (v) => setState(() => tutupHalamanVotingVote = v),
        ),
        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
        _buildSimpleToggleRow(
          title: bahasa['sembunyikan_nomor_finalis_title'] ?? 'Sembunyikan Nomor Finalis',
          desc: bahasa['sembunyikan_nomor_finalis_desc'] ?? 'Sembunyikan nomor finalis di halaman voting.',
          value: sembunyikanNomorFinalisVote,
          onChanged: (v) => setState(() => sembunyikanNomorFinalisVote = v),
        ),
        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
        _buildSimpleToggleRow(
          title: bahasa['notifikasi_title'] ?? 'Notifikasi',
          desc: bahasa['notifikasi_desc'] ?? 'Aktifkan pengiriman notifikasi terkait vote ini.',
          value: notifikasiVote,
          onChanged: (v) => setState(() => notifikasiVote = v),
        ),

        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bahasa['urutan_finalis_title'] ?? 'Urutan Daftar Finalis', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text(
                bahasa['urutan_finalis_desc'] ?? 'Atur bagaimana daftar finalis ditampilkan saat voter memilih kandidat.',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              _buildRadioTile(
                selected: urutanDaftarFinalisVote == 'nomor_urut',
                label: bahasa['urutan_nomor_urut_title'] ?? 'Berdasarkan Nomor Urut',
                desc: bahasa['urutan_nomor_urut_desc'] ?? 'Diurutkan sesuai nomor urut yang ditentukan panitia.',
                onTap: () => setState(() => urutanDaftarFinalisVote = 'nomor_urut'),
              ),
              const SizedBox(height: 14),
              _buildRadioTile(
                selected: urutanDaftarFinalisVote == 'abjad',
                label: bahasa['urutan_abjad_title'] ?? 'Berdasarkan Abjad',
                desc: bahasa['urutan_abjad_desc'] ?? 'Diurutkan secara alfabet: A → Z.',
                onTap: () => setState(() => urutanDaftarFinalisVote = 'abjad'),
              ),
              const SizedBox(height: 14),
              _buildRadioTile(
                selected: urutanDaftarFinalisVote == 'jumlah_vote',
                label: bahasa['urutan_total_vote_title'] ?? 'Berdasarkan Total Vote',
                desc: bahasa['urutan_total_vote_desc'] ?? 'Diurutkan dari yang memiliki jumlah vote terbanyak.',
                onTap: () => setState(() => urutanDaftarFinalisVote = 'jumlah_vote'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        _buildSaveButton(_showSavedSnackBar),
      ],
    );
  }

  // ---------- Papan Peringkat ----------

  Widget _buildPapanPeringkatContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitleDesc(
          bahasa['papan_peringkat'] ?? 'Papan Peringkat',
          bahasa['papan_peringkat_desc'] ?? 'Atur tampilan jumlah vote pada leaderboard dan berapa finalis yang ditampilkan.',
        ),
        const SizedBox(height: 16),
        _buildSimpleToggleRow(
          title: bahasa['sembunyikan_leaderboard_title'] ?? 'Sembunyikan Leaderboard',
          desc: bahasa['sembunyikan_leaderboard_desc'] ?? 'Sembunyikan seluruh papan peringkat di halaman voting.',
          value: sembunyikanLeaderboardVote,
          onChanged: (v) => setState(() => sembunyikanLeaderboardVote = v),
        ),
        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),

        Text(bahasa['tampilan_jumlah_vote'] ?? 'Tampilan Jumlah Vote', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 14),
        _buildRadioTile(
          selected: tampilanJumlahVoteVote == 'sembunyikan',
          label: bahasa['sembunyikan_jumlah_vote'] ?? 'Sembunyikan jumlah vote',
          desc: bahasa['sembunyikan_jumlah_vote_desc'] ?? 'Jumlah vote setiap kandidat akan disembunyikan.',
          onTap: () => setState(() => tampilanJumlahVoteVote = 'sembunyikan'),
        ),
        const SizedBox(height: 14),
        _buildRadioTile(
          selected: tampilanJumlahVoteVote == 'angka',
          label: bahasa['tampilkan_dalam_angka'] ?? 'Tampilkan dalam Angka',
          desc: bahasa['tampilkan_dalam_angka_desc'] ?? 'Finalis diurutkan dari jumlah vote terbanyak.',
          onTap: () => setState(() => tampilanJumlahVoteVote = 'angka'),
        ),
        const SizedBox(height: 14),
        _buildRadioTile(
          selected: tampilanJumlahVoteVote == 'persentase',
          label: bahasa['tampilkan_dalam_persentase'] ?? 'Tampilkan dalam Persentase',
          desc: bahasa['tampilkan_dalam_persentase_desc'] ?? 'Total voting finalis ditampilkan secara transparan dalam persen.',
          onTap: () => setState(() => tampilanJumlahVoteVote = 'persentase'),
        ),

        const SizedBox(height: 20),
        Text(bahasa['jumlah_finalis_ditampilkan'] ?? 'Jumlah Finalis yang Ditampilkan', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 14),
        _buildRadioTile(
          selected: jumlahFinalisDitampilkanVote == 'top10',
          label: bahasa['top_10_finalis'] ?? 'Top 10 finalis',
          onTap: () => setState(() => jumlahFinalisDitampilkanVote = 'top10'),
        ),
        const SizedBox(height: 12),
        _buildRadioTile(
          selected: jumlahFinalisDitampilkanVote == 'top5',
          label: bahasa['top_5_finalis'] ?? 'Top 5 finalis',
          onTap: () => setState(() => jumlahFinalisDitampilkanVote = 'top5'),
        ),
        const SizedBox(height: 12),
        _buildRadioTile(
          selected: jumlahFinalisDitampilkanVote == 'top3',
          label: bahasa['top_3_finalis'] ?? 'Top 3 finalis',
          onTap: () => setState(() => jumlahFinalisDitampilkanVote = 'top3'),
        ),

        const SizedBox(height: 20),
        _buildSaveButton(_showSavedSnackBar),
      ],
    );
  }

  // ---------- Jadwal Tutup ----------

  void _addJadwalTutup() {
    setState(() {
      jadwalTutupList.add({
        'mulaiController': TextEditingController(),
        'selesaiController': TextEditingController(),
        'mulai': null,
        'selesai': null,
        'halamanVote': false,
        'leaderboard': false,
        'hasilVote': false,
      });
    });
  }

  void _removeJadwalTutup(int index) {
    setState(() {
      (jadwalTutupList[index]['mulaiController'] as TextEditingController).dispose();
      (jadwalTutupList[index]['selesaiController'] as TextEditingController).dispose();
      jadwalTutupList.removeAt(index);
    });
  }

  Widget _buildJadwalTutupContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitleDesc(
          bahasa['jadwal_tutup_sementara'] ?? 'Jadwal Tutup Sementara',
          bahasa['jadwal_tutup_sementara_desc'] ?? 'Atur periode penutupan sementara di tengah jadwal voting, dan bagian mana saja yang ditutup.',
        ),
        const SizedBox(height: 16),

        if (jadwalTutupList.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                bahasa['belum_ada_jadwal_tutup'] ?? 'Belum ada jadwal tutup sementara.',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ),
          )
        else
          ...jadwalTutupList.asMap().entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildJadwalTutupCard(entry.key, entry.value),
          )),

        const SizedBox(height: 12),
        InkWell(
          onTap: _addJadwalTutup,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 18, color: Color(0xFFDC2626)),
              const SizedBox(width: 4),
              Text(
                bahasa['tambah_jadwal'] ?? 'Tambah Jadwal',
                style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        _buildSaveButton(_showSavedSnackBar),
      ],
    );
  }

  Widget _buildJadwalTutupCard(int index, Map<String, dynamic> jadwal) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () => _removeJadwalTutup(index),
                child: Icon(Icons.close, size: 18, color: Colors.grey[400]),
              ),
            ],
          ),
          _buildDateTimeField(
            label: bahasa['mulai_tutup'] ?? 'Mulai Tutup',
            controller: jadwal['mulaiController'],
            onTap: () => _pickDateTime(jadwal['mulaiController'], (dt) => jadwal['mulai'] = dt),
          ),
          const SizedBox(height: 12),
          _buildDateTimeField(
            label: bahasa['selesai_tutup'] ?? 'Selesai Tutup',
            controller: jadwal['selesaiController'],
            onTap: () => _pickDateTime(jadwal['selesaiController'], (dt) => jadwal['selesai'] = dt),
          ),
          const SizedBox(height: 12),
          Text(bahasa['bagian_yang_ditutup'] ?? 'Bagian yang Ditutup', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildCheckboxTile(
                value: jadwal['halamanVote'],
                label: bahasa['halaman_vote'] ?? 'Halaman Vote',
                onChanged: (v) => setState(() => jadwal['halamanVote'] = v),
              ),
              _buildCheckboxTile(
                value: jadwal['leaderboard'],
                label: bahasa['leaderboard'] ?? 'Leaderboard',
                onChanged: (v) => setState(() => jadwal['leaderboard'] = v),
              ),
              _buildCheckboxTile(
                value: jadwal['hasilVote'],
                label: bahasa['hasil_vote'] ?? 'Hasil Vote',
                onChanged: (v) => setState(() => jadwal['hasilVote'] = v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
