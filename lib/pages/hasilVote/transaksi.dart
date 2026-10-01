import 'dart:async';

import 'package:admin_vote_mobile/helper/global_function.dart';
import 'package:admin_vote_mobile/helper/global_widget.dart';
import 'package:admin_vote_mobile/pages/hasilVote/modal_detail_transaksi.dart';
import 'package:admin_vote_mobile/services/api_services.dart';
import 'package:admin_vote_mobile/services/lang_service.dart';
import 'package:admin_vote_mobile/services/storage_services.dart';
import 'package:flutter/material.dart';

class TransaksiPage extends StatefulWidget {
  final String idVote;
  final List<Map<String, dynamic>> listTransaksi;
  final int currentPage;
  const TransaksiPage({
    super.key,
    required this.idVote,
    required this.listTransaksi,
    required this.currentPage
  });

  @override
  State<TransaksiPage> createState() => TransaksiPageState();
}

class TransaksiPageState extends State<TransaksiPage> {
  final _searchController = TextEditingController();
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  int currentPage = 1;
  int lastPage = 1;

  List<Map<String, dynamic>> listTransaksi = [];
  bool isTransaksiLoading = true;

  String? langCode, token;
  Map<String, dynamic> bahasa = {};

  bool searchLoading = false;
  Timer? _debounce;
  String searchFilter = '';
  String statusFilter = '';
  String sortFilter = 'terbaru';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _getBahasa();
      if (!mounted) return;
      setState(() {
        listTransaksi = widget.listTransaksi;
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
      '/api/v1/vote-result/${widget.idVote}/transaksi?page=$currentPage&search=$searchFilter&status=$statusFilter&sort=$sortFilter',
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return;

    final rawList = result?['data']?['data'] as List<dynamic>? ?? [];
    final newData = rawList.map((e) => e as Map<String, dynamic>).toList();
    final fetchedLastPage = result?['data']?['last_page'] as int? ?? lastPage;

    setState(() {
      listTransaksi.addAll(newData);
      lastPage = fetchedLastPage;
      hasMore = currentPage < lastPage;
      isLoadingMore = false;
    });
  }

  Future<void> _loadListTransaksi(String idVote, String searchFilter, String statusFilter, String sortFilter) async {
    final valid = await isTokenStillValid(token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }

    currentPage = 1;
    hasMore = true;

    final result = await ApiService.get(
      '/api/v1/vote-result/${widget.idVote}/transaksi?search=$searchFilter&status=$statusFilter&sort=$sortFilter',
      xLanguage: langCode,
      token: token
    );

    if (!mounted) return;
    setState(() {
      final rawList = result?['data']?['data'] as List<dynamic>? ?? [];
      listTransaksi = rawList.map((e) => e as Map<String, dynamic>).toList();
      lastPage = result?['data']?['last_page'] as int? ?? 1;
      hasMore = currentPage < lastPage;
      isTransaksiLoading = false;
      searchLoading = false;
    });
  }

  // Kembali ke listTransaksi awal (tanpa hit API) cuma valid kalau semua
  // filter lagi kosong/default - kalau ada status/sort aktif, tetep harus
  // fetch supaya filter itu gak diam-diam kebuang.
  bool get _hasActiveFilter =>
    searchFilter.isNotEmpty || statusFilter.isNotEmpty || sortFilter != 'terbaru';

  void _onSearchChanged(String value) {
    setState(() {});

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      setState(() {
        searchFilter = value;
      });

      if (_hasActiveFilter) {
        setState(() => searchLoading = true);
        _loadListTransaksi(widget.idVote, value, statusFilter, sortFilter);
      } else {
        setState(() {
          listTransaksi = widget.listTransaksi;
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
    });

    if (_hasActiveFilter) {
      setState(() => searchLoading = true);
      _loadListTransaksi(widget.idVote, '', statusFilter, sortFilter);
    } else {
      setState(() {
        listTransaksi = widget.listTransaksi;
        searchLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    if (_hasActiveFilter) {
      await _loadListTransaksi(widget.idVote, searchFilter, statusFilter, sortFilter);
    } else {
      setState(() {
        listTransaksi = widget.listTransaksi;
      });
    }
  }

  void _openDetailTransaksi(Map<String, dynamic> item) {
    final idOrder = item['id']?.toString();
    if (idOrder == null || idOrder.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DetailTransaksiSheet(
        idOrder: idOrder,
        langCode: langCode,
        token: token,
        bahasa: bahasa,
      ),
    );
  }

  // String _statusLabel(dynamic status) {
  //   switch (status) {
  //     case '0': return bahasa['status_0'] ?? 'Status 0';
  //     case '1': return bahasa['status_1'] ?? 'Paid';
  //     case '2': return bahasa['status_2'] ?? 'Status 2';
  //     case '3': return bahasa['status_3'] ?? 'Status 3';
  //     case '4': return bahasa['status_4'] ?? 'Refund';
  //     case '20': return bahasa['status_20'] ?? 'Status 20';
  //     case '404': return bahasa['status_404'] ?? 'Status 404';
  //     default: return status?.toString() ?? '-';
  //   }
  // }

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      bahasa['transaksi'] ?? 'Transaksi',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(width: 8,),
                  InkWell(
                    onTap: () => {},
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
                  hintText: bahasa['search_transaksi'] ?? 'Cari nama pembeli...',
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

              // dropdown status filter
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: statusFilter,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(bahasa['semua_status'] ?? 'Semua Status'),
                      ),
                      DropdownMenuItem(
                        value: '1',
                        child: Text(bahasa['status_1'] ?? 'Paid'),
                      ),
                      DropdownMenuItem(
                        value: '4',
                        child: Text(bahasa['status_4'] ?? 'Refund'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;

                      if (_debounce?.isActive ?? false) _debounce!.cancel();

                      setState(() {
                        statusFilter = value;
                        searchLoading = true;
                      });
                      
                      _loadListTransaksi(widget.idVote, searchFilter, statusFilter, sortFilter);
                    },
                  ),
                ),
              ),

              // dropdown filter
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: sortFilter,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'terbaru',
                        child: Text(bahasa['terbaru'] ?? 'Terbaru'),
                      ),
                      DropdownMenuItem(
                        value: 'terlama',
                        child: Text(bahasa['terlama'] ?? 'Terlama'),
                      ),
                      DropdownMenuItem(
                        value: 'nama_voting_az',
                        child: Text(bahasa['nama_a_z'] ?? 'Nama A-Z'),
                      ),
                      DropdownMenuItem(
                        value: 'nama_voting_za',
                        child: Text(bahasa['nama_z_a'] ?? 'Nama Z-A'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;

                      if (_debounce?.isActive ?? false) _debounce!.cancel();

                      setState(() {
                        sortFilter = value;
                        searchLoading = true;
                      });

                      _loadListTransaksi(widget.idVote, searchFilter, statusFilter, sortFilter);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),
              if (searchLoading)
                buildSkeletonDetailHasil()
              else if (listTransaksi.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      searchFilter.isNotEmpty
                          ? (bahasa['transaksi_tidak_ditemukan'] ?? 'Dukungan tidak ditemukan')
                          : (bahasa['belum_ada_transaksi'] ?? 'Belum ada dukungan'),
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ),
                )
              else
                _buildConten(listTransaksi),

              if (isLoadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConten(List<Map<String, dynamic>> listTransaksi) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: listTransaksi.asMap().entries.map((entry) {
        final item = entry.value;

        String status = '';
        Color color = Colors.grey;
        Color colorshade = Colors.grey.shade100;
        if (item['status'] == '0') {
          status = bahasa['status_0'];
          color = Colors.red;
          colorshade = Colors.red.shade100;
        } else if (item['status'] == '1') {
          status = bahasa['status_1'];
          color = Colors.blue;
          colorshade = Colors.blue.shade100;
        } else if (item['status'] == '2') {
          status = bahasa['status_2'];
          color = Colors.red;
          colorshade = Colors.red.shade100;
        } else if (item['status'] == '3') {
          status = bahasa['status_3'];
          color = Colors.orange;
          colorshade = Colors.orange.shade100;
        } else if (item['status'] == '4') {
          status = bahasa['status_4'];
          color = Colors.red;
          colorshade = Colors.red.shade100;
        } else if (item['status'] == '20') {
          status = bahasa['status_20'];
          color = Colors.red;
          colorshade = Colors.red.shade100;
        } else if (item['status'] == '404') {
          status = bahasa['status_404'];
          color = Colors.red;
          colorshade = Colors.red.shade100;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openDetailTransaksi(item),
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
                        item['nama'] ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
                      decoration: BoxDecoration(
                        color: colorshade,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        status,
                        style: TextStyle(color: color, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      bahasa['tanggal'] ?? 'Tanggal',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    buildAdaptiveDateText(
                      langCode,
                      item['created_at']?.toString(),
                      includeTime: true,
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Updated',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    buildAdaptiveDateText(
                      langCode,
                      item['updated_at']?.toString(),
                      includeTime: true,
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Qty',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Text(
                      thousandSeparator(toIntInline((item['qty'] ?? 0) * (item['multiplier'] ?? 1))),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Text(
                      formatCurrency(item['total_harga_idr'] ?? 0, 'IDR'),
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
}