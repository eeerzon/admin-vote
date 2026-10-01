import 'dart:async';

import 'package:admin_vote_mobile/helper/global_function.dart';
import 'package:admin_vote_mobile/services/api_services.dart';
import 'package:flutter/material.dart';

class DetailTransaksiFinalisSheet extends StatefulWidget {
  final String idVote;
  final String idFinalis;
  final String namaFinalis;
  final String? langCode;
  final String? token;
  final Map<String, dynamic> bahasa;

  const DetailTransaksiFinalisSheet({
    super.key, 
    required this.idVote,
    required this.idFinalis,
    required this.namaFinalis,
    required this.langCode,
    required this.token,
    required this.bahasa,
  });

  @override
  State<DetailTransaksiFinalisSheet> createState() => _DetailTransaksiFinalisSheetState();
}

class _DetailTransaksiFinalisSheetState extends State<DetailTransaksiFinalisSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  List<Map<String, dynamic>> listData = [];
  int currentPage = 1;
  int lastPage = 1;
  int total = 0;
  String searchFilter = '';

  final DraggableScrollableController _sheetController = DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _sheetController.dispose();
    super.dispose();
  }
  
  double _calculateChildSize() {
    if (isLoading) return 0.5;
    if (listData.isEmpty) return 0.45;

    const baseSize = 0.32;
    const perItemSize = 0.075;

    final calculated = baseSize + (listData.length * perItemSize);
    return calculated.clamp(0.45, 0.92);
  }

  void _resizeSheet() {
    if (_sheetController.isAttached) {
      final targetSize = _calculateChildSize();
      _sheetController.animateTo(
        targetSize,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _fetchData({bool reset = true}) async {
    if (reset) {
      setState(() {
        isLoading = true;
        currentPage = 1;
        hasMore = true;
      });
    }

    final valid = await isTokenStillValid(widget.token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }

    final result = await ApiService.get(
      '/api/v1/vote-result/${widget.idVote}/transaksi-per-finalis/${widget.idFinalis}?page=$currentPage&search=$searchFilter',
      xLanguage: widget.langCode,
      token: widget.token,
    );

    if (!mounted) return;

    final rawList = result?['data']?['data'] as List<dynamic>? ?? [];
    final newData = rawList.map((e) => e as Map<String, dynamic>).toList();

    setState(() {
      listData = newData;
      lastPage = result?['data']?['last_page'] as int? ?? 1;
      total = result?['data']?['total'] as int? ?? listData.length;
      hasMore = currentPage < lastPage;
      isLoading = false;
    });

    _resizeSheet();
  }

  Future<void> _loadMore() async {
    if (!hasMore || isLoadingMore || isLoading) return;

    setState(() => isLoadingMore = true);
    currentPage++;

    final valid = await isTokenStillValid(widget.token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }

    final result = await ApiService.get(
      '/api/v1/vote-result/${widget.idVote}/transaksi-per-finalis/${widget.idFinalis}?page=$currentPage&search=$searchFilter',
      xLanguage: widget.langCode,
      token: widget.token,
    );

    if (!mounted) return;

    final rawList = result?['data']?['data'] as List<dynamic>? ?? [];
    final newData = rawList.map((e) => e as Map<String, dynamic>).toList();

    setState(() {
      listData.addAll(newData);
      lastPage = result?['data']?['last_page'] as int? ?? lastPage;
      hasMore = currentPage < lastPage;
      isLoadingMore = false;
    });

    _resizeSheet();
  }

  void _onSearchChanged(String value) {
    setState(() {});

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      searchFilter = value;
      _fetchData(reset: true);
    });
  }

  void _onSearchCleared() {
    _searchController.clear();
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    searchFilter = '';
    _fetchData(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final bahasa = widget.bahasa;
    final childSize = _calculateChildSize();

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: childSize,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // handle bar
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.emoji_events_outlined, color: Colors.red),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bahasa['detail_transaksi_finalis'] ?? 'Detail Transaksi Finalis',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${bahasa['daftar_transaksi_pembeli'] ?? 'Daftar transaksi pembeli'} - ${widget.namaFinalis}",
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: bahasa['cari_nama_email_order'] ?? 'Cari nama, telepon, email, atau ID order...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close, color: Colors.grey[400]),
                            onPressed: _onSearchCleared,
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
              ),

              // List (infinite scroll)
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.red))
                    : listData.isEmpty
                        ? Center(
                            child: Text(
                              bahasa['transaksi_tidak_ditemukan'] ?? 'Transaksi tidak ditemukan',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          )
                        : NotificationListener<ScrollNotification>(
                            onNotification: (scrollInfo) {
                              if (!isLoadingMore &&
                                  hasMore &&
                                  scrollInfo.metrics.pixels >=
                                      scrollInfo.metrics.maxScrollExtent - 150) {
                                _loadMore();
                              }
                              return false;
                            },
                            child: ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: listData.length + (hasMore ? 1 : 0),
                              separatorBuilder: (_, __) => Divider(height: 24, color: Colors.grey.shade200),
                              itemBuilder: (context, index) {
                                if (index >= listData.length) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: isLoadingMore
                                          ? const CircularProgressIndicator(color: Colors.red)
                                          : const SizedBox.shrink(),
                                    ),
                                  );
                                }

                                final item = listData[index];
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.person_outline, size: 18, color: Colors.blue[300]),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['full_name'] ?? '-',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "${item['phone'] ?? '-'} · ${item['email'] ?? '-'}",
                                            style: TextStyle(color: Colors.grey[600]),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "ID: ${item['id'] ?? '-'} · ${item['created_at'] ?? '-'}",
                                            style: TextStyle( color: Colors.grey[400]),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          item['qty'] > 1 
                                            ? bahasa['text_votes'] ?? 'Vote'
                                            : bahasa['text_vote'] ?? 'Vote',
                                          style: TextStyle(color: Colors.grey[500]),
                                        ),
                                        Text(
                                          thousandSeparator(toInt(item['qty'])),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          formatCurrency(item['subtotal_idr'] ?? 0, 'IDR'),
                                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}