import 'dart:async';


import 'package:admin_vote_mobile/helper/global_function.dart';
import 'package:admin_vote_mobile/helper/global_widget.dart';
import 'package:admin_vote_mobile/pages/hasilVote/modal_datail_transaksi_finalis.dart';
import 'package:admin_vote_mobile/services/api_services.dart';
import 'package:admin_vote_mobile/services/lang_service.dart';
import 'package:admin_vote_mobile/services/storage_services.dart';
import 'package:flutter/material.dart';

class TransaksiPerFinalisPage extends StatefulWidget {
  final String idVote;
  final List<Map<String, dynamic>> listTransaksiPerFinalis;
  final int currentPage;
  const TransaksiPerFinalisPage({
    super.key,
    required this.idVote,
    required this.listTransaksiPerFinalis,
    required this.currentPage,
  });

  @override
  State<TransaksiPerFinalisPage> createState() => TransaksiPerFinalisPageState();
}

class TransaksiPerFinalisPageState extends State<TransaksiPerFinalisPage> {
  final _searchController = TextEditingController();
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  int currentPage = 1;
  int lastPage = 1;

  List<Map<String, dynamic>> listTransaksiPerFinalis = [];

  String? langCode, token;
  Map<String, dynamic> bahasa = {};

  bool searchLoading = false;
  Timer? _debounce;
  String searchFilter = '';

  @override
  void initState() {
    super.initState();
    currentPage = widget.currentPage;
    listTransaksiPerFinalis = widget.listTransaksiPerFinalis;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _getBahasa();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getBahasa() async {
    token = await StorageService.getToken();
    final code = await StorageService.getLanguage();
    if (!mounted) return;
    setState(() {
      langCode = code;
    });

    final tempbahasa = await LangService.getJsonData(langCode!, "bahasa");

    if (!mounted) return;
    setState(() {
      bahasa = tempbahasa;
      isLoading = false;
    });
  }
  
  Future<void> loadMore() async {
    if (!hasMore || isLoadingMore || searchLoading) return;

    setState(() => isLoadingMore = true);
    currentPage++;

    final valid = await isTokenStillValid(token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }

    final result = await ApiService.get(
      '/api/v1/vote-result/${widget.idVote}/transaksi-per-finalis?page=$currentPage&search=$searchFilter',
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return;

    final rawList = result?['data']?['data'] as List<dynamic>? ?? [];
    final newData = rawList.map((e) => e as Map<String, dynamic>).toList();
    final fetchedLastPage = result?['data']?['last_page'] as int? ?? lastPage;

    setState(() {
      listTransaksiPerFinalis.addAll(newData);
      lastPage = fetchedLastPage;
      hasMore = currentPage < lastPage;
      isLoadingMore = false;
    });
  }

  Future<void> _loadListTransaksi(String idVote, String search) async {
    final valid = await isTokenStillValid(token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }

    final result = await ApiService.get(
      '/api/v1/vote-result/${widget.idVote}/transaksi-per-finalis?page=1&search=$search',
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return;

    final rawList = result?['data']?['data'] as List<dynamic>? ?? [];

    setState(() {
      listTransaksiPerFinalis = rawList.map((e) => e as Map<String, dynamic>).toList();
      currentPage = result?['data']?['current_page'] as int? ?? 1;
      lastPage = result?['data']?['last_page'] as int? ?? 1;
      hasMore = currentPage < lastPage;
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
        _loadListTransaksi(widget.idVote, value);
      } else {
        setState(() {
          listTransaksiPerFinalis = widget.listTransaksiPerFinalis;
          currentPage = widget.currentPage;
          hasMore = true;
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
      listTransaksiPerFinalis = widget.listTransaksiPerFinalis;
      currentPage = widget.currentPage;
      hasMore = true;
      searchLoading = false;
    });
  }

  Future<void> _refresh() async {
    if (searchFilter.isNotEmpty) {
      await _loadListTransaksi(widget.idVote, searchFilter);
    } else {
      setState(() {
        listTransaksiPerFinalis = widget.listTransaksiPerFinalis;
        currentPage = widget.currentPage;
        hasMore = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    bahasa['transaksi_per_finalis'] ?? 'Transaksi Per Finalis',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => {},
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(width: 1, color: Colors.grey),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
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
                hintText: bahasa['search_finalis'] ?? 'Cari finalis ...',
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
            else if (listTransaksiPerFinalis.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    searchFilter.isNotEmpty
                        ? (bahasa['no_data'] ?? 'Data tidak ditemukan')
                        : (bahasa['belum_ada_transaksi'] ?? 'Belum ada transaksi'),
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ),
              )
            else
              _buildConten(listTransaksiPerFinalis),

            if (isLoadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConten(List<Map<String, dynamic>> listTransaksiPerFinalis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: listTransaksiPerFinalis.asMap().entries.map((entry) {
        final index = entry.key;
        final transaksi = entry.value;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openDetailTransaksiSheet(transaksi),
            child: Container(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          transaksi['nama_finalis'] ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "#${index + 1}",
                        style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  

                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        bahasa['total_vote'] ?? 'Total Vote',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        thousandSeparator(toInt(transaksi['total_vote'])),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        bahasa['jumlah_voters'] ?? 'Jumlah Voters',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        thousandSeparator(toInt(transaksi['jumlah_voters'])),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        bahasa['pendapatan'] ?? 'Pendapatan',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        formatCurrency(
                          transaksi['total_pendapatan_idr'] ?? 0,
                          'IDR',
                        ),
                        style: const TextStyle(color: Colors.green),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _openDetailTransaksiSheet(Map<String, dynamic> transaksi) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DetailTransaksiFinalisSheet(
          idVote: widget.idVote,
          idFinalis: transaksi['id_finalis'] ?? '',
          namaFinalis: transaksi['nama_finalis'] ?? '-',
          langCode: langCode,
          token: token,
          bahasa: bahasa,
        );
      },
    );
  }
}