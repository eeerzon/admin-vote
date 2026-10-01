
// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:admin_vote_mobile/helper/global_function.dart';
import 'package:admin_vote_mobile/helper/global_widget.dart';
import 'package:admin_vote_mobile/pages/hasilVote/detail_hasil.dart';
import 'package:admin_vote_mobile/services/api_services.dart';
import 'package:admin_vote_mobile/services/lang_service.dart';
import 'package:admin_vote_mobile/services/storage_services.dart';
import 'package:flutter/material.dart';

class HasilVotePage extends StatefulWidget {
  final void Function(int index)? onNavigateToTab;
  const HasilVotePage({
    super.key,
    this.onNavigateToTab
  });

  @override
  State<HasilVotePage> createState() => _HasilVotePageState();
}

class _HasilVotePageState extends State<HasilVotePage> {
  final ScrollController _scrollController = ScrollController();
  String? token;
  String? langCode, currencyCode;
  
  Map<String, dynamic> bahasa = {};

  String? userName;
  
  int currentPage = 1;
  String searchFilter = '';
  String sortFilter = 'waktu_terdekat'; //waktu_terdekat, waktu_terjauh, nama_voting_az, nama_voting_za

  final _searchController = TextEditingController();

  bool isLoading = true;
  bool hasMore = true;
  Map<String, dynamic>? summaryData;

  bool searchLoading = false;
  Timer? _debounce;

  List<dynamic>? voteListData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
    
      if (!mounted) return;
      
      await _getBahasa();
      await _loadDataAtas();
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoading &&
          hasMore) {
        _loadMoreDataBawah();
      }
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
  }

  Future<void> _loadDataAtas() async {
    final valid = await isTokenStillValid(token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }

    final result = await ApiService.get(
      '/api/v1/vote-result/summary',
      xLanguage: langCode,
      token: await StorageService.getToken()
    );

    if (!mounted) return;

    setState(() {
      summaryData = result ?? {};
    });

    _loadDataBawah(searchFilter);
  }

  Future<void> _loadDataBawah(String? search, {bool loadMore = false}) async {
    final valid = await isTokenStillValid(token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }

    if (!loadMore) {
      currentPage = 1;
      hasMore = true;
    }

    final result = await ApiService.get(
      '/api/v1/vote-result?search=$search&sort=$sortFilter&page=$currentPage',
      xLanguage: langCode,
      token: await StorageService.getToken(),
    );

    if (!mounted) return;

    final List<dynamic> newData = result?['data']?['votes'] ?? [];
    final int? lastPage = result?['data']?['last_page'];

    setState(() {
      if (loadMore) {
        voteListData = [...(voteListData ?? []), ...newData];
      } else {
        voteListData = newData;
      }

      hasMore = lastPage != null ? currentPage < lastPage : newData.isNotEmpty;
      isLoading = false;
      searchLoading = false;
    });
  }

  Future<void> _loadMoreDataBawah() async {
    if (!hasMore) return;

    hasMore = false; // guard sementara, cegah trigger dobel saat masih fetch
    currentPage++;
    await _loadDataBawah(searchFilter, loadMore: true);
  }

  Future<void> _refresh() async {
    await Future.delayed(Duration(seconds: 1));
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
                // Skeleton(width: 36, height: 36, borderRadius: 18),
                // const SizedBox(width: 8),
                Skeleton(width: 36, height: 36, borderRadius: 20),
              ],
            ),

            // Title "Vote"
            const SizedBox(height: 20),
            Skeleton(width: 100, height: 28, borderRadius: 4),

            //rangkuman
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildStatBoxSkeleton()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatBoxSkeleton()),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildStatBoxSkeleton()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatBoxSkeleton()),
                  ],
                ),
              ],
            ),

            //search bar
            const SizedBox(height: 20),
            Skeleton(width: double.infinity, height: 36, borderRadius: 12),

            //list item
            const SizedBox(height: 20),
            _buildEventItemSkeleton(),
            const SizedBox(height: 20),
            _buildEventItemSkeleton(),
          ],
        ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          buildHeader(context, userName, token, bahasa, widget.onNavigateToTab),

          const SizedBox(height: 10),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bahasa['bot_nav_3'] ?? 'Hasil Vote',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatBox(
                        title: bahasa['total_event'] ?? 'Total Event',
                        value: thousandSeparator(
                          (summaryData?['data']?['total_event'] as num?)?.toInt() ?? 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatBox(
                        title: bahasa['jumlah_voters'] ?? 'Jumlah Voters',
                        value: thousandSeparator(
                          (summaryData?['data']?['total_voters'] as num?)?.toInt() ?? 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatBox(
                        title: bahasa['jumlah_vote'] ?? 'Jumlah Vote',
                        value: thousandSeparator(
                          (summaryData?['data']?['jumlah_vote'] as num?)?.toInt() ?? 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatBox(
                        title: bahasa['total_pendapatan'] ?? 'Total Revenue',
                        value: formatCurrency(summaryData?['data']?['total_price'] ?? 0, 'IDR'),
                      ),
                    ),
                  ],
                ),
                
                //search
                const SizedBox(height: 20),
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {}); // update tombol X
                    if (_debounce?.isActive ?? false) _debounce!.cancel();

                    _debounce = Timer(const Duration(milliseconds: 500), () {
                      if (!mounted) return;
                      setState(() {
                        searchFilter = value;
                        searchLoading = true;
                      });
                      _loadDataBawah(searchFilter);
                    });
                  },
                  decoration: InputDecoration(
                    hintText: bahasa['search_event'] ?? 'Cari event...',
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
                              searchLoading = true;
                            });
                            _loadDataBawah(searchFilter);
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

                // dropdown filter
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    color: Colors.white,
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
                          value: 'waktu_terdekat',
                          child: Text(bahasa['waktu_terdekat'] ?? 'Waktu Terdekat'),
                        ),
                        DropdownMenuItem(
                          value: 'waktu_terjauh',
                          child: Text(bahasa['waktu_terjauh'] ?? 'Waktu Terjauh'),
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

                        _loadDataBawah(searchFilter);
                      },
                    ),
                  ),
                ),

                //list data
                const SizedBox(height: 20),
                if (searchLoading) ... [ 
                  _buildEventItemSkeleton(),
                  const SizedBox(height: 20),
                  _buildEventItemSkeleton(),
                ] else ... [
                  _buildVoteSection(voteList: voteListData ?? []),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoteSection({required List<dynamic> voteList}) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: voteList.length + 1,
        itemBuilder: (context, index) {
          if (index < voteList.length) {
            final vote = voteList[index];

            return InkWell(
              onTap: () async {
                await Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => DetailHasilVotePage(idVote: vote['id_vote'],)),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // judul event
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            vote['judul_vote'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
                          decoration: BoxDecoration(
                            color: vote['flag_selesai_gf'] == '1'
                                ? Colors.grey.shade200
                                : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            vote['flag_selesai_gf'] == '1'
                                ? (bahasa['selesai'] ?? 'Selesai')
                                : (bahasa['aktif'] ?? 'Aktif'),
                            style: TextStyle(
                              color: vote['flag_selesai_gf'] == '1'
                                  ? Colors.black
                                  : Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // tanggal event
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          vote['nama_penyelenggara'] ?? '-',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(width: 4),
                        const Text('-', style: TextStyle(color: Colors.grey)),
                        const SizedBox(width: 4),
                        buildAdaptiveDateText(
                          langCode,
                          vote['tanggal_grandfinal_mulai']?.toString(),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),

                    // jumlah votes + pendapatan
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              bahasa['pendapatan'] ?? 'Pendapatan',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              formatCurrency(vote['total_pendapatan'] ?? 0, 'IDR'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              toInt(vote['voters']) > 0
                                  ? (bahasa['text_votes'] ?? 'Votes')
                                  : (bahasa['text_vote'] ?? 'Vote'),
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              thousandSeparator(toInt(vote['voters'])),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              toInt(vote['total_voters']) != 1
                                  ? (bahasa['text_voters'] ?? 'Voters')
                                  : (bahasa['text_voter'] ?? 'Voter'),
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              thousandSeparator(toInt(vote['total_voters'])),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              )
            );
          } else {
            if (hasMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(color: Colors.red)),
              );
            } else {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    bahasa['no_more'] ?? 'Tidak ada data lagi',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }
          }
        },
      ),
    );
  }
}

Widget _buildStatBoxSkeleton() {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Skeleton(width: 80, height: 20, borderRadius: 4),
        const SizedBox(height: 8),
        Skeleton(width: 100, height: 20, borderRadius: 4),
      ],
    ),
  );
}

Widget _buildEventItemSkeleton() {
  return Container(
    padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row (
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Skeleton(width: 170, height: 20, borderRadius: 4),
              Skeleton(width: 50, height: 20, borderRadius: 4),
            ],
          ),

          const SizedBox(height: 10),
          Skeleton(width: 130, height: 20, borderRadius: 4),

          const SizedBox(height: 30),
          Row (
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Skeleton(width: 100, height: 20, borderRadius: 4),
                  const SizedBox(height: 10),
                  Skeleton(width: 70, height: 20, borderRadius: 4),
                ],
              ),

              Column(
                children: [
                  Skeleton(width: 100, height: 20, borderRadius: 4),
                  const SizedBox(height: 10),
                  Skeleton(width: 70, height: 20, borderRadius: 4),
                ],
              ),

              Column(
                children: [
                  Skeleton(width: 100, height: 20, borderRadius: 4),
                  const SizedBox(height: 10),
                  Skeleton(width: 70, height: 20, borderRadius: 4),
                ],
              ),
            ],
          ),
        ],
      ),
  );
}