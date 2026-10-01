import 'dart:async';

import 'package:admin_vote_mobile/helper/global_function.dart';
import 'package:admin_vote_mobile/helper/global_widget.dart';
import 'package:admin_vote_mobile/services/api_services.dart';
import 'package:admin_vote_mobile/services/lang_service.dart';
import 'package:admin_vote_mobile/services/storage_services.dart';
import 'package:flutter/material.dart';

class DukunganPage extends StatefulWidget{
  final String idVote;
  final List<Map<String, dynamic>> listDukungan;
  const DukunganPage({
    super.key,
    required this.idVote,
    required this.listDukungan,
  });

  @override
  State<DukunganPage> createState() => DukunganPageState();
}

class DukunganPageState extends State<DukunganPage> {
  final _searchController = TextEditingController();
  bool isLoading = true;
  bool hasMore = false;

  List<Map<String, dynamic>> listDukungan = [];
  bool isDukunganLoading = true;

  String? langCode, token;
  Map<String, dynamic> bahasa = {};

  bool searchLoading = false;
  Timer? _debounce;
  String searchFilter = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _getBahasa();
      if (!mounted) return;
      setState(() {
        listDukungan = widget.listDukungan;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future <void> _getBahasa() async {
    token = await StorageService.getToken();
    final code = await StorageService.getLanguage();
    setState(() {
      langCode = code;
    });

    final tempbahasa = await LangService.getJsonData(langCode!, "bahasa");

    setState(() {
      bahasa = tempbahasa;

      isLoading = false;
    });
  }

  Future<void> _loadListDukungan(String idVote, String searchFilter) async {
    final valid = await isTokenStillValid(token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }

    final result = await ApiService.get(
      '/api/v1/vote-result/${widget.idVote}/dukungan?search=$searchFilter',
      xLanguage: langCode,
      token: token
    );

    if (!mounted) return;
    setState(() {
      final rawList = result?['data']?['dukungan']?['data'] as List<dynamic>? ?? [];
      listDukungan = rawList.map((e) => e as Map<String, dynamic>).toList();
      isDukunganLoading = false;
      searchLoading = false;
    });
  }

  void _onSearchChanged(String value) {
    setState(() {});

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      setState(() {
        searchFilter = value;
      });

      if (value.isNotEmpty) {
        setState(() => searchLoading = true);
        _loadListDukungan(widget.idVote, value);
      } else {
        setState(() {
          listDukungan = widget.listDukungan;
          searchLoading = false;
        });
      }
    });
  }

  void _onSearchCleared() {
    _searchController.clear();

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    setState(() {
      searchFilter = '';
      listDukungan = widget.listDukungan;
      searchLoading = false;
    });
  }

  Future<void> _refresh() async {
    if (searchFilter.isNotEmpty) {
      await _loadListDukungan(widget.idVote, searchFilter);
    } else {
      setState(() {
        listDukungan = widget.listDukungan;
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    return RefreshIndicator(
      onRefresh: _refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          return false;
        },
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bahasa['dukungan'] ?? 'Dukungan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              
              const SizedBox(height: 8,),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      bahasa['dukungan_desc'] ?? 'Pesan dukungan yang ditinggalkan voter',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),

                  const SizedBox(width: 8,),
                  InkWell(
                    onTap: () {},
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(width: 1, color: Colors.grey)
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Download Excel',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: bahasa['search_dukungan'] ?? 'Cari nama atau pesan dukungan...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close, color: Colors.grey[400]),
                          onPressed: _onSearchCleared,
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              if (searchLoading)
                buildSkeletonDetailHasil()
              else if (listDukungan.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      searchFilter.isNotEmpty
                          ? (bahasa['dukungan_tidak_ditemukan'] ?? 'Dukungan tidak ditemukan')
                          : (bahasa['belum_ada_dukungan'] ?? 'Belum ada dukungan'),
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ),
                )
              else
                _buildConten(listDukungan),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConten(List<Map<String, dynamic>> listDukungan) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(width: 1, color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var dukungan in listDukungan.asMap().entries)
            Padding(
              padding: EdgeInsets.only(
                bottom: dukungan.key != listDukungan.length - 1 ? 16 : 0,
              ),
              child: Container(
                decoration: BoxDecoration(
                  border: dukungan.key != listDukungan.length - 1
                      ? Border(bottom: BorderSide(color: Colors.grey.shade200))
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nama pemberi dukungan (atau "Anonim" kalau hide_name)
                    Text(
                      dukungan.value['hide_name'] == '1'
                          ? (bahasa['anonim'] ?? 'Anonim')
                          : (dukungan.value['nama'] ?? '-'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),

                    const SizedBox(height: 4),
                    // Nama finalis yang didukung (bisa lebih dari 1)
                    if (dukungan.value['nama_finalis'] != null &&
                        (dukungan.value['nama_finalis'] as List).isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: (dukungan.value['nama_finalis'] as List)
                            .map<Widget>((nama) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    nama.toString(),
                                    style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                                  ),
                                ))
                            .toList(),
                      ),

                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          bahasa['tanggal'] ?? 'Tanggal',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        buildAdaptiveDateText(
                          langCode,
                          dukungan.value['created_at']?.toString(),
                          includeTime: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Divider(height: 1, color: Colors.grey.shade200),

                    const SizedBox(height: 8),
                    Text(
                      bahasa['pesan_dukungan'] ?? 'Pesan Dukungan',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dukungan.value['dukungan'] ?? '-',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}