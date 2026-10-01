import 'package:admin_vote_mobile/helper/global_function.dart';
import 'package:admin_vote_mobile/helper/global_widget.dart';
import 'package:admin_vote_mobile/pages/voteSaya/detail_vote.dart';
import 'package:admin_vote_mobile/services/api_services.dart';
import 'package:admin_vote_mobile/services/lang_service.dart';
import 'package:admin_vote_mobile/services/storage_services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EventAktif extends StatefulWidget {
  final List<dynamic> eventAktif;
  final int currentPage;
  final String searchFilter;
  final String sortFilter;
  const EventAktif({
    super.key, 
    required this.eventAktif, 
    required this.currentPage,
    required this.searchFilter,
    required this.sortFilter
  });

  @override
  State<EventAktif> createState() => EventAktifState();
}

class EventAktifState extends State<EventAktif> {
  final ScrollController _scrollController = ScrollController();
  bool isLoading = true;
  bool hasMore = true;
  int currentPage = 1;

  String? langCode, token;
  Map<String, dynamic> bahasa = {};
  final formatterNUmber = NumberFormat.decimalPattern("en_US");

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _getBahasa();
      currentPage = widget.currentPage;
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoading &&
          hasMore) {
        loadMoreAktif();
      }
    });
  }

  // Widget ini di-keep-alive lewat GlobalKey di vote_saya_page.dart, jadi
  // saat search/sort filter berubah di parent, State ini didaur ulang (bukan
  // instance baru) - currentPage/hasMore lokal harus di-resync manual di sini,
  // kalau enggak "load more" abis ganti filter bakal pakai currentPage basi.
  @override
  void didUpdateWidget(covariant EventAktif oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchFilter != widget.searchFilter ||
        oldWidget.sortFilter != widget.sortFilter) {
      currentPage = widget.currentPage;
      hasMore = true;
    }
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

  Future<void> loadMoreAktif() async {
    setState(() => currentPage++);
    await _fetchDraft(loadMore: true);
  }

  Future<void> _fetchDraft({bool loadMore = false}) async {
    if (isLoading) return;

    setState(() => isLoading = true);

    if (!loadMore) {
      currentPage = 1;
      hasMore = true;
    }

    final valid = await isTokenStillValid(token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }

    final result = await ApiService.get(
      '/api/v1/votes?page=$currentPage&tab=aktif&sort=${widget.sortFilter}&search=${widget.searchFilter}',
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return;

    final List<dynamic> newData = result?['data']?['data'] ?? [];

    setState(() {
      if (loadMore) {
        widget.eventAktif.addAll(newData);
      }
      
      hasMore = newData.isNotEmpty;
      isLoading = false;
    });
  }

  Future<void> _refresh() async {
    await Future.delayed(Duration(seconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (!isLoading &&
              scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
            loadMoreAktif();
          }
          return false;
        },
        child: ListView.builder(
          controller: _scrollController,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.eventAktif.length + 1,
          itemBuilder: (context, index) {
            if (index < widget.eventAktif.length) {
              final item = widget.eventAktif[index];
              String jenisVote = item['jenis_vote'] ?? '-';
              if (jenisVote == 'free') {
                jenisVote = bahasa['voting_free'] ?? 'Voting Gratis';
              } else if (jenisVote == 'paid') {
                jenisVote = bahasa['voting_paid'] ?? 'Voting Berbayar';
              } else {
                jenisVote = '-';
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: InkWell(
                  onTap: () {},
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 4 / 5,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: Image.network(
                              item['banner'] ?? '',
                              fit: BoxFit.cover,
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
                          ),
                        ),

                        SizedBox(height: 12,),
                        Padding(
                          padding: EdgeInsetsGeometry.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['judul_vote'] ?? '-',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),

                              SizedBox(height: 12,),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      item['nama_kategori'] ?? '-',
                                    ),
                                  ),

                                  SizedBox(width: 10,),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      jenisVote
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 12,),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Grand Final',
                                        style: TextStyle(color: Colors.grey),
                                      ),

                                      SizedBox(height: 8,),
                                      buildAdaptiveDateText(
                                        langCode,
                                        item['tanggal_grandfinal_mulai'],
                                      ),
                                    ],
                                  ),
                                  
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        bahasa['harga_per_vote'] ?? "Harga per Vote",
                                        style: TextStyle(color: Colors.grey),
                                      ),

                                      SizedBox(height: 8,),
                                      Text(
                                        formatCurrency(item['harga'], item['currency']),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              SizedBox(height: 12,),
                              Text(
                                bahasa['lokasi_vote'] ?? "Lokasi Vote",
                                style: TextStyle(color: Colors.grey),
                              ),
                              SizedBox(height: 8,),
                              Text(
                                item['lokasi_nama_tempat'] ?? '-'
                              ),

                              SizedBox(height: 12,),
                              InkWell(
                                onTap: () async {
                                  await Navigator.push(
                                    context, 
                                    MaterialPageRoute(builder: (_) => DetailVotePage(idVote: item['id_vote'],)),
                                  );
                                },
                                child: Container(
                                  height: 48,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    bahasa['detail_vote'] ?? 'Detail Vote',
                                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              SizedBox(height: 12,),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            } else {
              if (isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator(color: Colors.red,)),
                );
              } else if (!hasMore) {
                return Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      bahasa['no_more'] ?? 'Tidak ada data lagi',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              } else {
                return const SizedBox.shrink();
              }
            }
          },
        ),
      ),
    );
  }
}