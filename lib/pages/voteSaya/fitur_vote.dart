// ignore_for_file: use_build_context_synchronously

import 'package:admin_vote_mobile/helper/global_function.dart';
import 'package:admin_vote_mobile/helper/global_widget.dart';
import 'package:admin_vote_mobile/helper/loading_page.dart';
import 'package:admin_vote_mobile/services/api_services.dart';
import 'package:admin_vote_mobile/services/lang_service.dart';
import 'package:admin_vote_mobile/services/storage_services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Halaman "Fitur Vote" - dibuka dari menu grid detail_vote.dart, isinya
// Promo dan Booster (persis konten step terakhir wizard new_vote.dart),
// tapi berdiri sendiri karena vote-nya sudah publish (bukan bagian wizard).
class FiturVotePage extends StatefulWidget {
  final String idVote;
  final String judulVote;

  const FiturVotePage({super.key, required this.idVote, required this.judulVote});

  @override
  State<FiturVotePage> createState() => _FiturVotePageState();
}

class _FiturVotePageState extends State<FiturVotePage> {
  String? token;
  String? langCode;
  String? userName;
  Map<String, dynamic> bahasa = {};

  bool _dataLoading = true;
  bool _dataError = false;
  bool _saving = false;
  String? jenisVote; // 'paid' | 'free' - dari step2

  bool boostAktif = true;
  final _boostMulaiController = TextEditingController();
  final _boostSelesaiController = TextEditingController();
  DateTime? boostMulai;
  DateTime? boostSelesai;
  int boostMultiplier = 2;
  bool boostMengertiChecked = false;

  bool voteGratisHarianAktif = false;
  final _batasVoteGratisController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      await _getBahasa();
      await _loadData();
    });
  }

  @override
  void dispose() {
    _boostMulaiController.dispose();
    _boostSelesaiController.dispose();
    _batasVoteGratisController.dispose();
    super.dispose();
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

  Future<void> _loadData() async {
    final valid = await isTokenStillValid(token);
    if (!mounted) return;
    if (!valid) {
      await forceLogoutToLogin(context);
      return;
    }

    setState(() => _dataLoading = true);

    final results = await Future.wait([
      ApiService.get('/api/v1/create-vote/${widget.idVote}/step2', xLanguage: langCode, token: token),
      ApiService.get('/api/v1/create-vote/${widget.idVote}/step-promo', xLanguage: langCode, token: token),
    ]);

    if (!mounted) return;

    final step2 = results[0];
    final stepPromo = results[1];

    var ok = false;

    final vote2 = _voteOf(step2);
    if (vote2 != null) {
      jenisVote = _str(vote2['jenis_vote']);
      ok = true;
    }

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
      ok = true;
    }

    setState(() {
      _dataError = !ok;
      _dataLoading = false;
    });
  }

  Future<void> _submitPromo() async {
    final valid = await isTokenStillValid(token);
    if (!mounted) return;
    if (!valid) {
      await forceLogoutToLogin(context);
      return;
    }

    setState(() => _saving = true);
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
      '/api/v1/create-vote/${widget.idVote}/step-promo',
      body: body,
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return;
    hideLoadingDialog(context);
    setState(() => _saving = false);

    if (result?['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(bahasa['tersimpan'] ?? 'Tersimpan')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_extractErrorMessage(result))),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _dataLoading
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
                  "${bahasa['fitur_vote'] ?? 'Fitur Vote'} 🚀",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  widget.judulVote,
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
                  onPressed: _loadData,
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

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _submitPromo,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              bahasa['simpan'] ?? 'Simpan',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
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

  Widget _buildLabeledField({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool required = false,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
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
          readOnly: readOnly,
          onTap: onTap,
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
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDC2626)),
            ),
          ),
        ),
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
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
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
      onChanged: (v) => setState(() {
        voteGratisHarianAktif = v;
        if (v && _batasVoteGratisController.text.trim().isEmpty) {
          _batasVoteGratisController.text = '1';
        }
      }),
      expandedChildren: [
        _buildLabeledField(
          label: bahasa['batas_vote_gratis_per_hari'] ?? 'Batas Vote Gratis per Hari',
          required: true,
          controller: _batasVoteGratisController,
          keyboardType: TextInputType.number,
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              widthFactor: 1,
              child: Text(bahasa['vote_unit'] ?? 'vote', style: TextStyle(color: Colors.grey[500])),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          bahasa['batas_vote_gratis_desc'] ?? 'Setiap email dapat menggunakan vote gratis sebanyak jumlah yang diisi setiap hari.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 16),
        _buildFreeQuotaInfoCard(),
      ],
    );
  }

  Widget _buildFreeQuotaInfoCard() {
    final quotaText = _batasVoteGratisController.text.trim();
    final quota = quotaText.isEmpty ? '0' : quotaText;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(color: Color(0xFF3652CC), fontSize: 13, height: 1.5),
          children: [
            TextSpan(
              text: bahasa['free_quota_info_1'] ??
                'Vote gratis akan direset setiap hari berdasarkan email voter. Jika diisi ',
            ),
            TextSpan(text: quota, style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(
              text: bahasa['free_quota_info_2'] ?? ', maka setiap email dapat melakukan ',
            ),
            TextSpan(
              text: '$quota${bahasa['free_quota_info_bold_suffix'] ?? ' vote gratis per hari'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: bahasa['free_quota_info_3'] ?? '.'),
          ],
        ),
      ),
    );
  }
}
