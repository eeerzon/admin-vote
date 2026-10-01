
import 'dart:async';

import 'package:admin_vote_mobile/helper/global_function.dart';
import 'package:admin_vote_mobile/helper/global_widget.dart';
import 'package:admin_vote_mobile/services/api_services.dart';
import 'package:admin_vote_mobile/services/lang_service.dart';
import 'package:admin_vote_mobile/services/storage_services.dart';
import 'package:flutter/material.dart';

class LeaderboardPage extends StatefulWidget {
  final String idVote;
  final List<dynamic> leaderboardList;
  const LeaderboardPage({
    super.key,
    required this.idVote,
    required this.leaderboardList,
  });

  @override
  State<LeaderboardPage> createState() => LeaderboardState();
}

class LeaderboardState extends State<LeaderboardPage> {
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isLoading = true;
  bool hasMore = false;

  List<Map<String, dynamic>> leaderboardList = [];
  bool isLeaderboardLoading = true;

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

  Future<void> _loadLeaderboardList(String idVote, String searchFilter) async {
    final valid = await isTokenStillValid(token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }

    final result = await ApiService.get(
      '/api/v1/vote-result/${widget.idVote}/leaderboard?search=$searchFilter',
      xLanguage: langCode,
      token: token
    );

    if (!mounted) return;
    setState(() {
      final rawList = result?['data']['finalis'] as List<dynamic>? ?? [];
      leaderboardList = rawList.map((e) => e as Map<String, dynamic>).toList();
      isLeaderboardLoading = false;
      searchLoading = false;
    });
  }

  Future<void> _refresh() async {
    await Future.delayed(Duration(seconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = searchFilter.isNotEmpty;
    final activeList = isSearching ? leaderboardList : widget.leaderboardList;

    final top3 = isSearching ? <dynamic>[] : activeList.take(3).toList();
    final rest = isSearching
      ? activeList
      : (activeList.length > 3 ? activeList.sublist(3) : <dynamic>[]);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          return false;
        },
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Leaderboard',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              
              const SizedBox(height: 8,),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      bahasa['leaderboard_desc'] ?? 'Peringkat finalis berdasarkan jumlah vote',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),

                  const SizedBox(width: 8,),
                  InkWell(
                    onTap: () => downloadExcel(context, widget.idVote, activeList),
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
                onChanged: (value) {
                  setState(() {});

                  if (_debounce?.isActive ?? false) _debounce!.cancel();

                  _debounce = Timer(const Duration(milliseconds: 500), () async {
                    if (!mounted) return;

                    setState(() {
                      searchFilter = value;
                      searchLoading = true;
                    });

                    if (value.isNotEmpty) {
                      _loadLeaderboardList(widget.idVote, searchFilter);
                    } else {
                      setState(() {
                        searchLoading = false;
                      });
                    }
                  });
                },
                decoration: InputDecoration(
                  hintText: bahasa['search_finalis'] ?? 'Cari Finalis ...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                  suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close, color: Colors.grey[400]),
                        onPressed: () {
                          _searchController.clear();

                          if (_debounce?.isActive ?? false) _debounce!.cancel();

                          setState(() {
                            searchFilter = '';
                            searchLoading = false;
                          });
                        },
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
                const Center(child: CircularProgressIndicator(color: Colors.red))
              else if (activeList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      searchFilter.isNotEmpty
                          ? (bahasa['finalis_tidak_ada'] ?? 'Finalis tidak ditemukan',)
                          : (bahasa['no_finalis'] ?? 'Belum ada finalis'),
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ),
                )
              else
                ListView(
                  controller: _scrollController,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(0),
                  children: [
                    if (top3.isNotEmpty) _buildTop3Row(top3),
                    if (top3.isNotEmpty) const SizedBox(height: 20),

                    ...rest.asMap().entries.map((entry) {
                      final item = entry.value;
                      final rank = isSearching
                        ? (item['rank'] ?? item['position'] ?? entry.key + 1)
                        : entry.key + 4;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildRankListItem(rank, item),
                      );
                    }),

                    const SizedBox(height: 20),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTop3Row(List<dynamic> top3) {
    // urutan tampil: rank2 (kiri), rank1 (tengah), rank3 (kanan)
    final rank1 = top3.isNotEmpty ? top3[0] : null;
    final rank2 = top3.length > 1 ? top3[1] : null;
    final rank3 = top3.length > 2 ? top3[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: rank2 != null
              ? _buildTop3Card(rank2, 2, isCenter: false)
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: rank1 != null
              ? _buildTop3Card(rank1, 1, isCenter: true)
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: rank3 != null
              ? _buildTop3Card(rank3, 3, isCenter: false)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildTop3Card(Map<String, dynamic> item, int rank, {required bool isCenter}) {
    final hasPoster = item['poster_finalis'] != null && item['poster_finalis'].toString().isNotEmpty;

    Color borderColor;
    Color badgeColor;
    Color badgeTextColor;

    switch (rank) {
      case 1:
        borderColor = const Color(0xFFF4C430); // kuning/emas
        badgeColor = const Color(0xFFF4C430);
        badgeTextColor = Colors.black;
        break;
      case 3:
        borderColor = const Color(0xFFF08C3B); // oranye
        badgeColor = const Color(0xFFF08C3B);
        badgeTextColor = Colors.white;
        break;
      default:
        borderColor = Colors.grey.shade300;
        badgeColor = Colors.grey.shade400;
        badgeTextColor = Colors.white;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: rank == 2 ? 1 : 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: AspectRatio(
                  aspectRatio: isCenter ? 4 / 6.5 : 4 / 5,
                  child: hasPoster
                    ? Image.network(
                        item['poster_finalis'],
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
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    "$rank",
                    style: TextStyle(
                      color: badgeTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['nama_finalis'] ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item['nama_tambahan'] != null && item['nama_tambahan'].toString().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  item['nama_tambahan'],
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
                const SizedBox(height: 6),
                Text(
                  thousandSeparator(toIntInline(item['total_voters'])),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  formatPercent(item['percent']),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankListItem(int rank, Map<String, dynamic> item) {
    final hasPoster = item['poster_finalis'] != null && item['poster_finalis'].toString().isNotEmpty;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Text(
            "$rank",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600], fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 44,
            height: 44,
            child: hasPoster
              ? Image.network(
                  item['poster_finalis'],
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
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['nama_finalis'] ?? '-',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (item['nama_tambahan'] != null && item['nama_tambahan'].toString().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  item['nama_tambahan'],
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              thousandSeparator(toIntInline(item['total_voters'])),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              formatPercent(item['percent']),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ],
    );
  }
}