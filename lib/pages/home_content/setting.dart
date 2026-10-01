
// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';

import 'package:admin_vote_mobile/helper/global_function.dart';
import 'package:admin_vote_mobile/helper/global_var.dart';
import 'package:admin_vote_mobile/helper/global_widget.dart';
import 'package:admin_vote_mobile/helper/loading_page.dart';
import 'package:admin_vote_mobile/services/api_services.dart';
import 'package:admin_vote_mobile/services/lang_service.dart';
import 'package:admin_vote_mobile/services/storage_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';

class SettingPage extends StatefulWidget {
  final bool autoExpandAkun;
  final void Function(int index)? onNavigateToTab;
  const SettingPage({
    super.key,
    this.autoExpandAkun = false,
    this.onNavigateToTab
  });

  @override
  State<SettingPage> createState() => SettingPageState();
}

class SettingPageState extends State<SettingPage> {
  String? token;
  String? langCode;
  
  Map<String, dynamic> bahasa = {};

  String? userName;

  bool isLoading = true;

  bool akunOpen = false;
  bool currencyOpen = false;
  bool penyelenggaraOpen = false;
  bool legalOpen = false;

  bool editNamaAkun = false;
  bool editEmail = false;
  bool editNomorHp = false;
  bool editPassword = false;
  bool editNamaPenyelenggara = false;
  bool editDeskripsi = false;
  bool editInstagram = false;
  bool editTwitter = false;
  bool editFacebook = false;
  bool editLinkedin = false;
  bool editYoutube = false;
  bool editWeb = false;
  bool editLegal = false;

  final _namaAkunController = TextEditingController();
  final _emailController = TextEditingController();
  final _nomorHpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _namaPenyelenggaraController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _instagramController = TextEditingController();
  final _twitterController = TextEditingController();
  final _facebookController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _webController = TextEditingController();

  // Legal
  final _ktpNameController = TextEditingController();
  final _ktpNumberController = TextEditingController();
  final _ktpAddressController = TextEditingController();
  final _npwpNameController = TextEditingController();
  final _npwpNumberController = TextEditingController();
  final _npwpAddressController = TextEditingController();
  final _nibNameController = TextEditingController();
  final _nibNumberController = TextEditingController();
  final _nibAddressController = TextEditingController();
  String jenisMerchant = '1'; // '1' | '2'
  String? ktpFileUrl;
  String? npwpFileUrl;
  String? nibFileUrl;
  File? ktpFileNew;
  File? npwpFileNew;
  File? nibFileNew;
  final ImagePicker _imagePicker = ImagePicker();

  String namaAkun = '';
  String email = '';
  String nomorHp = '';
  String namaPenyelenggara = '';
  String deskripsiPenyelenggara = '';
  String instagramValue = '';
  String twitterValue = '';
  String facebookValue = '';
  String linkedinValue = '';
  String youtubeValue = '';
  String webValue = '';

  List<Map<String, dynamic>> currencyList = [
    {
      'code': 'EUR',
      'name': 'Euro',
      'active': false,
    },
    {
      'code': 'IDR',
      'name': 'Rupiah Indonesia',
      'active': false,
    },
    {
      'code': 'MYR',
      'name': 'Malaysia Ringgit',
      'active': false,
    },
    {
      'code': 'PHP',
      'name': 'Philipine Peso',
      'active': false,
    },
    {
      'code': 'SGD',
      'name': 'Singapure Dollar',
      'active': false,
    },
    {
      'code': 'THB',
      'name': 'Thai Bath',
      'active': false,
    },
    {
      'code': 'USD',
      'name': 'US Dollar',
      'active': false,
    },
    {
      'code': 'VND',
      'name': 'Vietnam Dong',
      'active': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    akunOpen = widget.autoExpandAkun;

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
    setState(() {
      langCode = templangCode;
    });

    final tempbahasa = await LangService.getJsonData(langCode!, "bahasa");

    final storedUserData = await StorageService.getUser();
    final storedToken = await StorageService.getToken();

    if (!mounted) return;
    setState(() {
      bahasa = tempbahasa;
      userName = storedUserData['name'] ?? '';
      token = storedToken;
    });

    await _loadSettings();
  }

  Map<String, dynamic>? _mapOf(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;

  Future<void> _loadSettings() async {
    final results = await Future.wait([
      ApiService.get('/api/v1/settings', xLanguage: langCode, token: token),
      ApiService.get('/api/v1/settings/currencies', xLanguage: langCode, token: token),
    ]);

    if (!mounted) return;

    final data = _mapOf(results[0]?['data']);
    final account = _mapOf(data?['account']);
    final organizer = _mapOf(data?['organizer']);
    final legal = _mapOf(data?['legal']);
    final currentCurrency = data?['currency']?.toString();
    final currencies = results[1]?['data'];

    setState(() {
      if (account != null) {
        namaAkun = account['name']?.toString() ?? '';
        email = account['email']?.toString() ?? '';
        nomorHp = account['phone']?.toString() ?? '';
      }

      if (organizer != null) {
        namaPenyelenggara = organizer['name']?.toString() ?? namaAkun;
        deskripsiPenyelenggara = organizer['short_description']?.toString() ?? '';
        instagramValue = organizer['name_ig']?.toString() ?? '';
        twitterValue = organizer['name_twitter']?.toString() ?? '';
        facebookValue = organizer['link_fb']?.toString() ?? '';
        linkedinValue = organizer['name_linkedin']?.toString() ?? '';
        youtubeValue = organizer['link_youtube']?.toString() ?? '';
        webValue = organizer['link_web']?.toString() ?? '';
      } else {
        namaPenyelenggara = namaAkun;
      }

      if (legal != null) {
        jenisMerchant = legal['jenis_merchant']?.toString() ?? '1';
        _ktpNameController.text = legal['ktp_name']?.toString() ?? '';
        _ktpNumberController.text = legal['ktp_number']?.toString() ?? '';
        _ktpAddressController.text = legal['ktp_address']?.toString() ?? '';
        _npwpNameController.text = legal['npwp_name']?.toString() ?? '';
        _npwpNumberController.text = legal['npwp_number']?.toString() ?? '';
        _npwpAddressController.text = legal['npwp_address']?.toString() ?? '';
        _nibNameController.text = legal['nib_name']?.toString() ?? '';
        _nibNumberController.text = legal['nib_number']?.toString() ?? '';
        _nibAddressController.text = legal['nib_address']?.toString() ?? '';
        ktpFileUrl = legal['ktp_file_url']?.toString();
        npwpFileUrl = legal['npwp_file_url']?.toString();
        nibFileUrl = legal['nib_file_url']?.toString();
      }

      _namaAkunController.text = namaAkun;
      _emailController.text = email;
      _nomorHpController.text = nomorHp;
      _namaPenyelenggaraController.text = namaPenyelenggara;
      _deskripsiController.text = deskripsiPenyelenggara;
      _instagramController.text = instagramValue;
      _twitterController.text = twitterValue;
      _facebookController.text = facebookValue;
      _linkedinController.text = linkedinValue;
      _youtubeController.text = youtubeValue;
      _webController.text = webValue;

      if (currencies is List && currencies.isNotEmpty) {
        currencyList = currencies.map<Map<String, dynamic>>((c) {
          final m = _mapOf(c) ?? <String, dynamic>{};
          return {
            'code': m['code']?.toString() ?? '',
            'name': m['currency']?.toString() ?? '',
            'active': m['code']?.toString() == currentCurrency,
          };
        }).toList();
      } else {
        for (var i = 0; i < currencyList.length; i++) {
          currencyList[i]['active'] = currencyList[i]['code'] == currentCurrency;
        }
      }

      isLoading = false;
    });

    if (currentCurrency != null && currentCurrency.isNotEmpty) {
      await StorageService.setCurrency(currentCurrency);
    }
  }

  String _errorMessage(Map<String, dynamic>? result) {
    final message = result?['message'];
    if (message is String && message.isNotEmpty) return message;
    return bahasa['error'] ?? 'Terjadi kesalahan';
  }

  Future<void> _saveAccount() async {
    showLoadingDialog(context, bahasa['memproses'] ?? 'Memproses...');

    final result = await ApiService.patch(
      '/api/v1/settings/account',
      body: {
        'name': namaAkun,
        'email': email,
        'phone': nomorHp,
      },
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return;
    hideLoadingDialog(context);

    if (result != null && result['success'] == true) {
      final data = _mapOf(result['data']);
      if (data != null) {
        setState(() {
          namaAkun = data['name']?.toString() ?? namaAkun;
          email = data['email']?.toString() ?? email;
          nomorHp = data['phone']?.toString() ?? nomorHp;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(result))),
      );
    }
  }

  Future<void> _savePassword() async {
    if (_passwordController.text.isEmpty || _passwordConfirmController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(bahasa['password_wajib_diisi'] ?? 'Password wajib diisi.')),
      );
      return;
    }
    if (_passwordController.text != _passwordConfirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(bahasa['password_tidak_sama'] ?? 'Konfirmasi password tidak sama.')),
      );
      return;
    }

    showLoadingDialog(context, bahasa['memproses'] ?? 'Memproses...');

    final result = await ApiService.patch(
      '/api/v1/settings/password',
      body: {
        'password': _passwordController.text,
        'password_confirmation': _passwordConfirmController.text,
      },
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return;
    hideLoadingDialog(context);

    if (result != null && result['success'] == true) {
      _passwordController.clear();
      _passwordConfirmController.clear();
      setState(() => editPassword = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? (bahasa['password_diperbarui'] ?? 'Password berhasil diperbarui.'))),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(result))),
      );
    }
  }

  Future<void> _saveOrganizer() async {
    showLoadingDialog(context, bahasa['memproses'] ?? 'Memproses...');

    final result = await ApiService.patch(
      '/api/v1/settings/organizer',
      body: {
        'name': namaPenyelenggara,
        'short_description': deskripsiPenyelenggara,
        'name_ig': instagramValue,
        'name_twitter': twitterValue,
        'link_fb': facebookValue,
        'name_linkedin': linkedinValue,
        'link_youtube': youtubeValue,
        'link_web': webValue,
      },
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return;
    hideLoadingDialog(context);

    if (result != null && result['success'] == true) {
      final data = _mapOf(result['data']);
      if (data != null) {
        setState(() {
          namaPenyelenggara = data['name']?.toString() ?? namaPenyelenggara;
          deskripsiPenyelenggara = data['short_description']?.toString() ?? deskripsiPenyelenggara;
          instagramValue = data['name_ig']?.toString() ?? instagramValue;
          twitterValue = data['name_twitter']?.toString() ?? twitterValue;
          facebookValue = data['link_fb']?.toString() ?? facebookValue;
          linkedinValue = data['name_linkedin']?.toString() ?? linkedinValue;
          youtubeValue = data['link_youtube']?.toString() ?? youtubeValue;
          webValue = data['link_web']?.toString() ?? webValue;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(result))),
      );
    }
  }

  Future<void> _saveCurrency(String code) async {
    final result = await ApiService.patch(
      '/api/v1/settings/currency',
      body: {'currency': code},
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return;

    if (result != null && result['success'] == true) {
      await StorageService.setCurrency(code);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(result))),
      );
    }
  }

  Future<String?> _fileToBase64(File? file) async {
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  Future<void> _pickLegalFile(void Function(File) onPicked) async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => onPicked(File(picked.path)));
  }

  Future<void> _saveLegal() async {
    showLoadingDialog(context, bahasa['memproses'] ?? 'Memproses...');

    final ktpBase64 = await _fileToBase64(ktpFileNew);
    final npwpBase64 = await _fileToBase64(npwpFileNew);
    final nibBase64 = await _fileToBase64(nibFileNew);

    final result = await ApiService.patch(
      '/api/v1/settings/legal',
      body: {
        'jenis_merchant': jenisMerchant,
        'ktp_name': _ktpNameController.text.trim(),
        'ktp_number': _ktpNumberController.text.trim(),
        'ktp_address': _ktpAddressController.text.trim().isEmpty ? null : _ktpAddressController.text.trim(),
        'npwp_name': _npwpNameController.text.trim().isEmpty ? null : _npwpNameController.text.trim(),
        'npwp_number': _npwpNumberController.text.trim().isEmpty ? null : _npwpNumberController.text.trim(),
        'npwp_address': _npwpAddressController.text.trim().isEmpty ? null : _npwpAddressController.text.trim(),
        'nib_name': _nibNameController.text.trim().isEmpty ? null : _nibNameController.text.trim(),
        'nib_number': _nibNumberController.text.trim().isEmpty ? null : _nibNumberController.text.trim(),
        'nib_address': _nibAddressController.text.trim().isEmpty ? null : _nibAddressController.text.trim(),
        if (ktpBase64 != null) 'ktp_file_base64': ktpBase64,
        if (npwpBase64 != null) 'npwp_file_base64': npwpBase64,
        if (nibBase64 != null) 'nib_file_base64': nibBase64,
      },
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return;
    hideLoadingDialog(context);

    if (result != null && result['success'] == true) {
      setState(() {
        editLegal = false;
        ktpFileNew = null;
        npwpFileNew = null;
        nibFileNew = null;
      });
      await _loadSettings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(result))),
      );
    }
  }

  @override
  void dispose() {
    _namaAkunController.dispose();
    _emailController.dispose();
    _nomorHpController.dispose();
    _namaPenyelenggaraController.dispose();
    _deskripsiController.dispose();
    _instagramController.dispose();
    _twitterController.dispose();
    _facebookController.dispose();
    _linkedinController.dispose();
    _youtubeController.dispose();
    _webController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _ktpNameController.dispose();
    _ktpNumberController.dispose();
    _ktpAddressController.dispose();
    _npwpNameController.dispose();
    _npwpNumberController.dispose();
    _npwpAddressController.dispose();
    _nibNameController.dispose();
    _nibNumberController.dispose();
    _nibAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: isLoading ? _buildSkeleton() : _buildContent(),
      ),
    );
  }

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Skeleton(width: 40, height: 40, borderRadius: 20),
              const SizedBox(width: 12),
              Skeleton(width: 120, height: 20, borderRadius: 4),
              const Spacer(),
              Skeleton(width: 36, height: 36, borderRadius: 20),
            ],
          ),

          // Title "Pengaturan"
          const SizedBox(height: 20),
          Skeleton(width: 160, height: 28, borderRadius: 4),

          // Card menu
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildSettingItemSkeleton(),
                _buildSettingItemSkeleton(),
                _buildSettingItemSkeleton(),
                _buildSettingItemSkeleton(showDivider: false),
              ],
            ),
          ),

          // Tombol Logout
          const SizedBox(height: 20),
          Skeleton(width: double.infinity, height: 48, borderRadius: 12),
        ],
      ),
    );
  }

  Widget _buildSettingItemSkeleton({bool showDivider = true}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: Colors.grey.shade200))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Skeleton(width: 160, height: 20, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 10),
          Skeleton(width: double.infinity, height: 14, borderRadius: 4),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          buildHeader(context, userName, token, bahasa, widget.onNavigateToTab),

          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bahasa['bot_nav_4'] ?? 'Pengaturan',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: Column(
                      children: [
                        _buildSectionHeader(
                          title: bahasa['akun_keamanan'] ?? 'Akun dan Keamanan',
                          desc: bahasa['akun_keamanan_desc'] ??
                              'Kelola akun dan password untuk login serta keamanan akun Anda.',
                          isOpen: akunOpen,
                          onTap: () => setState(() => akunOpen = !akunOpen),
                        ),
                        if (akunOpen) _buildAkunKeamananContent(),

                        _buildSectionHeader(
                          title: bahasa['currency'] ?? 'Currency',
                          desc: bahasa['currency_desc'] ??
                              'Kelola mata uang yang digunakan pada event votingmu.',
                          isOpen: currencyOpen,
                          onTap: () =>
                              setState(() => currencyOpen = !currencyOpen),
                        ),
                        if (currencyOpen) _buildCurrencyContent(),

                        _buildSectionHeader(
                          title: bahasa['informasi_penyelenggara'] ??
                              'Informasi Penyelenggara',
                          isOpen: penyelenggaraOpen,
                          onTap: () => setState(
                              () => penyelenggaraOpen = !penyelenggaraOpen),
                        ),
                        if (penyelenggaraOpen) _buildPenyelenggaraContent(),

                        _buildSectionHeader(
                          title: bahasa['informasi_legal'] ?? 'Informasi Legal',
                          isOpen: legalOpen,
                          onTap: () => setState(() => legalOpen = !legalOpen),
                          showDivider: false,
                        ),
                        if (legalOpen) _buildLegalContent(showDivider: false),
                      ],
                    ),
                  ),
                ),

                // Tombol Logout
                const SizedBox(height: 20),
                InkWell(
                  onTap: () => confirmLogout(context, token!),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.logout, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          bahasa['logout'] ?? 'Logout',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? desc,
    required bool isOpen,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: (showDivider && !isOpen)
              ? Border(bottom: BorderSide(color: Colors.grey.shade200))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(
                  isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.grey,
                ),
              ],
            ),
            if (desc != null) ...[
              const SizedBox(height: 10),
              Text(
                desc,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFieldRow({
    required String label,
    required String value,
    required bool isEditing,
    required TextEditingController controller,
    required VoidCallback onEditTap,
    required VoidCallback onSave,
    required VoidCallback onCancel,
    String? footnote,
    bool isMultiline = false,
    bool showDivider = true,
    String? iconAsset,
    Color? iconColor,
    IconData? iconData,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: Colors.grey.shade200))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (iconAsset != null) ...[
                      SvgPicture.asset(
                        iconAsset,
                        width: 18,
                        height: 18,
                        colorFilter: iconColor != null
                            ? ColorFilter.mode(iconColor, BlendMode.srcIn)
                            : null,
                      ),
                      const SizedBox(width: 8),
                    ] else if (iconData != null) ...[
                      Icon(iconData, size: 18, color: iconColor ?? Colors.grey[700]),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isEditing)
                InkWell(
                  onTap: onEditTap,
                  child: Text(
                    bahasa['edit'] ?? 'Edit',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),

          if (!isEditing) ...[
            Text(
              value.isNotEmpty
                  ? value
                  : (bahasa['belum_diisi'] ?? 'Belum diisi'),
              style: TextStyle(color: Colors.grey[700]),
            ),
            if (footnote != null) ...[
              const SizedBox(height: 6),
              Text(
                footnote,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ] else ...[
            if (footnote != null) ...[
              Text(
                footnote,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: controller,
              maxLines: isMultiline ? 4 : 1,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.red.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.red.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(
                  onPressed: onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isMultiline
                        ? (bahasa['simpan_deskripsi'] ?? 'Simpan Deskripsi')
                        : '${bahasa['simpan'] ?? 'Simpan'} $label',
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(bahasa['batal'] ?? 'Batal'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAkunKeamananContent() {
    return Column(
      children: [
        _buildFieldRow(
          label: bahasa['nama_akun'] ?? 'Nama Akun',
          value: namaAkun,
          isEditing: editNamaAkun,
          controller: _namaAkunController,
          footnote: bahasa['nama_akun_footnote'] ??
              'Nama ini sama dengan Nama Penyelenggara di tab Penyelenggara — mengubah salah satu akan mengubah keduanya.',
          onEditTap: () => setState(() => editNamaAkun = true),
          onSave: () {
            setState(() {
              namaAkun = _namaAkunController.text;
              namaPenyelenggara = _namaAkunController.text;
              _namaPenyelenggaraController.text = namaAkun;
              editNamaAkun = false;
            });
            _saveAccount();
          },
          onCancel: () {
            setState(() {
              _namaAkunController.text = namaAkun;
              editNamaAkun = false;
            });
          },
          showDivider: false
        ),
        _buildFieldRow(
          label: 'Email',
          value: email,
          isEditing: editEmail,
          controller: _emailController,
          onEditTap: () => setState(() => editEmail = true),
          onSave: () {
            setState(() {
              email = _emailController.text;
              editEmail = false;
            });
            _saveAccount();
          },
          onCancel: () {
            setState(() {
              _emailController.text = email;
              editEmail = false;
            });
          },
          showDivider: false
        ),
        _buildFieldRow(
          label: bahasa['nomor_hp'] ?? 'Nomor HP',
          value: nomorHp,
          isEditing: editNomorHp,
          controller: _nomorHpController,
          showDivider: true,
          onEditTap: () => setState(() => editNomorHp = true),
          onSave: () {
            setState(() {
              nomorHp = _nomorHpController.text;
              editNomorHp = false;
            });
            _saveAccount();
          },
          onCancel: () {
            setState(() {
              _nomorHpController.text = nomorHp;
              editNomorHp = false;
            });
          },
        ),
        _buildPasswordRow(),
      ],
    );
  }

  Widget _buildPasswordRow() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                bahasa['ubah_password'] ?? 'Ubah Password',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (!editPassword)
                InkWell(
                  onTap: () => setState(() => editPassword = true),
                  child: Text(
                    bahasa['edit'] ?? 'Edit',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),

          if (!editPassword)
            Text('••••••••', style: TextStyle(color: Colors.grey[700]))
          else ...[
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: bahasa['password_baru'] ?? 'Password Baru',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.red.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.red.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordConfirmController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: bahasa['konfirmasi_password_baru'] ?? 'Konfirmasi Password Baru',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.red.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.red.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _savePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(bahasa['simpan_password'] ?? 'Simpan Password'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    _passwordController.clear();
                    _passwordConfirmController.clear();
                    setState(() => editPassword = false);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(bahasa['batal'] ?? 'Batal'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrencyContent() {
    return Column(
      children: currencyList.asMap().entries.map((entry) {
        final index = entry.key;
        final currency = entry.value;
        final isActive = currency['active'] == true;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: InkWell(
            onTap: () async {
              setState(() {
                for (var i = 0; i < currencyList.length; i++) {
                  currencyList[i]['active'] = (i == index);
                }
              });
              await _saveCurrency(currency['code']);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${currency['code']} — ${currency['name']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    setState(() {
                      for (var i = 0; i < currencyList.length; i++) {
                        currencyList[i]['active'] = (i == index);
                      }
                    });
                    await _saveCurrency(currency['code']);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green.shade50 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      isActive
                          ? (bahasa['aktif'] ?? 'Aktif')
                          : (bahasa['nonaktif'] ?? 'Nonaktif'),
                      style: TextStyle(
                        color: isActive ? Colors.green[700] : Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPenyelenggaraContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldRow(
          label: bahasa['nama_penyelenggara'] ?? 'Nama Penyelenggara',
          value: namaPenyelenggara,
          isEditing: editNamaPenyelenggara,
          controller: _namaPenyelenggaraController,
          onEditTap: () => setState(() => editNamaPenyelenggara = true),
          onSave: () {
            setState(() {
              namaPenyelenggara = _namaPenyelenggaraController.text;
              namaAkun = _namaPenyelenggaraController.text;
              _namaAkunController.text = namaPenyelenggara;
              editNamaPenyelenggara = false;
            });
            _saveOrganizer();
          },
          onCancel: () {
            setState(() {
              _namaPenyelenggaraController.text = namaPenyelenggara;
              editNamaPenyelenggara = false;
            });
          },
          showDivider: false
        ),
        _buildFieldRow(
          label: bahasa['deskripsi'] ?? 'Deskripsi',
          value: deskripsiPenyelenggara,
          isEditing: editDeskripsi,
          controller: _deskripsiController,
          isMultiline: true,
          showDivider: true,
          onEditTap: () => setState(() => editDeskripsi = true),
          onSave: () {
            setState(() {
              deskripsiPenyelenggara = _deskripsiController.text;
              editDeskripsi = false;
            });
            _saveOrganizer();
          },
          onCancel: () {
            setState(() {
              _deskripsiController.text = deskripsiPenyelenggara;
              editDeskripsi = false;
            });
          },
        ),

        SizedBox(height: 16,),
        Padding(
          padding: EdgeInsetsGeometry.fromLTRB(20, 0, 20, 0),
          child: Text(
            bahasa['sosial_media'].toString().toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        
        _buildFieldRow(
          label: 'Instagram',
          value: instagramValue,
          isEditing: editInstagram,
          controller: _instagramController,
          iconAsset: 'assets/icons/instagram.svg',
          iconColor: const Color(0xFFE1306C),
          onEditTap: () => setState(() => editInstagram = true),
          onSave: () {
            setState(() {
              instagramValue = _instagramController.text;
              editInstagram = false;
            });
            _saveOrganizer();
          },
          onCancel: () {
            setState(() {
              _instagramController.text = instagramValue;
              editInstagram = false;
            });
          },
          showDivider: false
        ),
        _buildFieldRow(
          label: 'Twitter',
          value: twitterValue,
          isEditing: editTwitter,
          controller: _twitterController,
          iconAsset: 'assets/icons/twitter.svg',
          iconColor: Colors.black,
          onEditTap: () => setState(() => editTwitter = true),
          onSave: () {
            setState(() {
              twitterValue = _twitterController.text;
              editTwitter = false;
            });
            _saveOrganizer();
          },
          onCancel: () {
            setState(() {
              _twitterController.text = twitterValue;
              editTwitter = false;
            });
          },
          showDivider: false
        ),
        _buildFieldRow(
          label: 'facebook',
          value: facebookValue,
          isEditing: editFacebook,
          controller: _facebookController,
          iconAsset: 'assets/icons/facebook.svg',
          iconColor: const Color(0xFF1877F2),
          onEditTap: () => setState(() => editFacebook = true),
          onSave: () {
            setState(() {
              facebookValue = _facebookController.text;
              editFacebook = false;
            });
            _saveOrganizer();
          },
          onCancel: () {
            setState(() {
              _facebookController.text = facebookValue;
              editFacebook = false;
            });
          },
          showDivider: false
        ),
        _buildFieldRow(
          label: 'LinkedIn',
          value: linkedinValue,
          isEditing: editLinkedin,
          controller: _linkedinController,
          iconAsset: 'assets/icons/linkedin.svg',
          iconColor: const Color(0xFF0A66C2),
          onEditTap: () => setState(() => editLinkedin = true),
          onSave: () {
            setState(() {
              linkedinValue = _linkedinController.text;
              editLinkedin = false;
            });
            _saveOrganizer();
          },
          onCancel: () {
            setState(() {
              _linkedinController.text = linkedinValue;
              editLinkedin = false;
            });
          },
          showDivider: false
        ),
        _buildFieldRow(
          label: 'Youtube',
          value: youtubeValue,
          isEditing: editYoutube,
          controller: _youtubeController,
          iconAsset: 'assets/icons/youtube.svg',
          iconColor: const Color(0xFFFF0000),
          onEditTap: () => setState(() => editYoutube = true),
          onSave: () {
            setState(() {
              youtubeValue = _youtubeController.text;
              editYoutube = false;
            });
            _saveOrganizer();
          },
          onCancel: () {
            setState(() {
              _youtubeController.text = youtubeValue;
              editYoutube = false;
            });
          },
          showDivider: false
        ),
        _buildFieldRow(
          label: 'Website',
          value: webValue,
          isEditing: editWeb,
          controller: _webController,
          iconData: Icons.language,
          iconColor: Colors.grey[700],
          onEditTap: () => setState(() => editWeb = true),
          onSave: () {
            setState(() {
              webValue = _webController.text;
              editWeb = false;
            });
            _saveOrganizer();
          },
          onCancel: () {
            setState(() {
              _webController.text = webValue;
              editWeb = false;
            });
          },
          showDivider: true
        ),
      ],
    );
  }

  Widget _buildLegalContent({bool showDivider = true}) {
    if (!editLegal) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: Colors.grey.shade200))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  jenisMerchant == '2'
                    ? (bahasa['badan_usaha'] ?? 'Badan Usaha')
                    : (bahasa['perorangan'] ?? 'Perorangan'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                InkWell(
                  onTap: () => setState(() => editLegal = true),
                  child: Text(
                    bahasa['edit'] ?? 'Edit',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(bahasa['ktp'] ?? 'KTP', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              _ktpNameController.text.isNotEmpty
                ? '${_ktpNameController.text} — ${_ktpNumberController.text}'
                : (bahasa['belum_diisi'] ?? 'Belum diisi'),
              style: TextStyle(color: Colors.grey[600]),
            ),
            Text(
              ktpFileUrl != null
                ? (bahasa['dokumen_tersimpan'] ?? 'Dokumen sudah diunggah')
                : (bahasa['dokumen_legalitas_kosong'] ?? 'Belum ada dokumen diunggah'),
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            ),

            const SizedBox(height: 12),
            Text('NPWP', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              _npwpNameController.text.isNotEmpty
                ? '${_npwpNameController.text} — ${_npwpNumberController.text}'
                : (bahasa['npwp_kosong'] ?? 'Belum ditambahkan'),
              style: TextStyle(color: Colors.grey[600]),
            ),

            const SizedBox(height: 12),
            Text('NIB', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              _nibNameController.text.isNotEmpty
                ? '${_nibNameController.text} — ${_nibNumberController.text}'
                : (bahasa['belum_diisi'] ?? 'Belum diisi'),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: Colors.grey.shade200))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(bahasa['jenis_merchant'] ?? 'Jenis Merchant', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildJenisMerchantOption('1', bahasa['perorangan'] ?? 'Perorangan'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildJenisMerchantOption('2', bahasa['badan_usaha'] ?? 'Badan Usaha'),
              ),
            ],
          ),

          const SizedBox(height: 16),
          _buildLegalDocumentSection(
            title: 'KTP',
            documentType: 'ktp',
            nameController: _ktpNameController,
            numberController: _ktpNumberController,
            addressController: _ktpAddressController,
            existingFileUrl: ktpFileUrl,
            newFile: ktpFileNew,
            onPickFile: () => _pickLegalFile((f) => ktpFileNew = f),
          ),

          const SizedBox(height: 16),
          _buildLegalDocumentSection(
            title: 'NPWP',
            documentType: 'npwp',
            nameController: _npwpNameController,
            numberController: _npwpNumberController,
            addressController: _npwpAddressController,
            existingFileUrl: npwpFileUrl,
            newFile: npwpFileNew,
            onPickFile: () => _pickLegalFile((f) => npwpFileNew = f),
          ),

          const SizedBox(height: 16),
          _buildLegalDocumentSection(
            title: 'NIB',
            documentType: 'nib',
            nameController: _nibNameController,
            numberController: _nibNumberController,
            addressController: _nibAddressController,
            existingFileUrl: nibFileUrl,
            newFile: nibFileNew,
            onPickFile: () => _pickLegalFile((f) => nibFileNew = f),
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton(
                onPressed: _saveLegal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(bahasa['simpan'] ?? 'Simpan'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => setState(() {
                  editLegal = false;
                  ktpFileNew = null;
                  npwpFileNew = null;
                  nibFileNew = null;
                }),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(bahasa['batal'] ?? 'Batal'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJenisMerchantOption(String value, String label) {
    final selected = jenisMerchant == value;
    return InkWell(
      onTap: () => setState(() => jenisMerchant = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.red.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? Colors.red : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? Colors.red : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildLegalDocumentSection({
    required String title,
    required String documentType,
    required TextEditingController nameController,
    required TextEditingController numberController,
    required TextEditingController addressController,
    required String? existingFileUrl,
    required File? newFile,
    required VoidCallback onPickFile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            text: '${bahasa['nama_sesuai'] ?? 'Nama Sesuai'} $title',
            style: const TextStyle(fontWeight: FontWeight.bold),
            children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: nameController,
          decoration: InputDecoration(
            hintText: '${bahasa['nama'] ?? 'Nama'} $title',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            text: '${bahasa['nomor'] ?? 'Nomor'} $title',
            style: const TextStyle(fontWeight: FontWeight.bold),
            children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: numberController,
          decoration: InputDecoration(
            hintText: '${bahasa['nomor'] ?? 'Nomor'} $title',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${bahasa['alamat_sesuai'] ?? 'Alamat Sesuai'} $title',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: addressController,
          decoration: InputDecoration(
            hintText: bahasa['alamat'] ?? 'Alamat',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 12),
        if (newFile != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              newFile,
              width: 160,
              height: 160,
              fit: BoxFit.fill,
            ),
          ),
          const SizedBox(height: 12),
        ] else if (existingFileUrl != null && existingFileUrl.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              '$baseUrl/api/v1/settings/legal/$documentType/file',
              headers: {'Authorization': 'Bearer $token'},
              width: 160,
              height: 160,
              fit: BoxFit.fill,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 160,
                  alignment: Alignment.center,
                  color: Colors.grey.shade100,
                  child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                height: 160,
                alignment: Alignment.center,
                color: Colors.grey.shade100,
                child: Icon(Icons.broken_image_outlined, color: Colors.grey[400]),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        InkWell(
          onTap: onPickFile,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.upload_file, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    newFile != null
                      ? newFile.path.split('/').last
                      : existingFileUrl != null
                        ? (bahasa['dokumen_tersimpan'] ?? 'Dokumen sudah diunggah - ketuk untuk ganti')
                        : (bahasa['upload_dokumen'] ?? 'Ketuk untuk upload dokumen'),
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void openAkunKeamanan() {
    if (!mounted) return;

    setState(() {
      akunOpen = true;
    });
  }
}