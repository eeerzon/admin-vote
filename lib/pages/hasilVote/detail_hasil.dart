// ignore_for_file: use_build_context_synchronously

import 'package:admin_vote_mobile/helper/global_function.dart';
import 'package:admin_vote_mobile/helper/global_widget.dart';
import 'package:admin_vote_mobile/pages/hasilVote/dukungan.dart';
import 'package:admin_vote_mobile/pages/hasilVote/leaderboard.dart';
import 'package:admin_vote_mobile/pages/hasilVote/transaksi_per_finalis.dart';
import 'package:admin_vote_mobile/pages/hasilVote/transaksi.dart';
import 'package:admin_vote_mobile/services/api_services.dart';
import 'package:admin_vote_mobile/services/lang_service.dart';
import 'package:admin_vote_mobile/services/storage_services.dart';
import 'package:flutter/material.dart';

class DetailHasilVotePage extends StatefulWidget {
  final String idVote;
  const DetailHasilVotePage({super.key, required this.idVote});

  @override
  State<DetailHasilVotePage> createState() => _DetailHasilVotePageState();
}

class _DetailHasilVotePageState extends State<DetailHasilVotePage> with SingleTickerProviderStateMixin {
  String? token;
  String? langCode;
  String? userName;
  Map<String, dynamic> bahasa = {};

  bool isLoading = true;
  Map<String, dynamic>? voteData;
  
  late TabController _tabController;
  final ScrollController _pageScrollController = ScrollController();
  int indexTab = 0;
  bool searchLoading = true;
  bool _isScrolledDown = false;

  bool isLeaderboardLoading = true;
  bool isDukunganLoading = true;
  bool isTransaksiLoading = true;
  bool isTransaksiPerFinalisLoading = true;

  final GlobalKey<LeaderboardState> _leaderboardKey = GlobalKey<LeaderboardState>();
  final GlobalKey<DukunganPageState> _dukunganKey = GlobalKey<DukunganPageState>();
  final GlobalKey<TransaksiPageState> _transaksiKey = GlobalKey<TransaksiPageState>();
  final GlobalKey<TransaksiPerFinalisPageState> _transaksiperfinalisKey = GlobalKey<TransaksiPerFinalisPageState>();

  List<dynamic> leaderboardList = [];
  List<Map<String, dynamic>> listDukungan = [];
  List<Map<String, dynamic>> listTransaksi = [];
  List<Map<String, dynamic>> listTransaksiPerFinalis = [];
  
  int currentPageTransaksi = 1;
  int currentPageTransaksiPerFinalis = 1;
  String searchFilter = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _pageScrollController.addListener(_onPageScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      await _getBahasa();
      await _loadDetailHasilVote();
      await _loadLeaderboardList(widget.idVote);
    });

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
        final index = _tabController.index;
        
        if (index == 0) {
          //load leaderboard
          _loadLeaderboardList(widget.idVote);
        } else if (index == 1) {
          //load dukungan
          _loadListDukungan(widget.idVote);
        } else if (index == 2) {
          //load transaksi
          _loadListTransaksi(widget.idVote);
        } else if (index == 3) {
          //load transaksi per finalis
          _loadListTransaksiPerFinalis(widget.idVote);
        }
      }
    });
  }

  @override
  void dispose() {
    _pageScrollController.removeListener(_onPageScroll);
    _pageScrollController.dispose();
    super.dispose();
  }

  void _onPageScroll() {
    final scrolledDown = _pageScrollController.offset > 100;
    if (scrolledDown != _isScrolledDown) {
      setState(() {
        _isScrolledDown = scrolledDown;
      });
    }
    
    if (_pageScrollController.position.pixels >=
        _pageScrollController.position.maxScrollExtent - 200) {
      // trigger load more sesuai tab yang sedang aktif
      if (_tabController.index == 0) {
        //tab leaderboard
      } else if (_tabController.index == 1) {
        //tab dukungan
      } else if (_tabController.index == 2) {
        //tab transaksi
        _transaksiKey.currentState?.loadMore();
      } else if (_tabController.index == 3) {
        //tab transaksi per finalis
        _transaksiperfinalisKey.currentState?.loadMore();
      }
    }
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

  Future <void> _loadDetailHasilVote() async {
    final valid = await isTokenStillValid(token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }

    final result = await ApiService.get(
      '/api/v1/vote-result/${widget.idVote}',
      xLanguage: langCode,
      token: token,
    );

    if (!mounted) return;
    setState(() {
      voteData = result?['data'];
      isLoading = false;
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
              child: isLoading ? _buildSkeleton() : _buildContent(),
            )
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
            child: Text(
              bahasa['detail_hasil'] ?? 'Detail Hasil Vote',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),

          buildIconCircle(
            child: Text(
              getInitial(userName ?? 'K'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFE04E39),
              ),
            ),
            bgColor: const Color(0xFFFDEDEA),
            onTap: () => showLogoutMenu(context, token!),
          ),
        ],
      ),
    );
  }

  void showLogoutMenu(BuildContext context, String token) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + renderBox.size.width,
        offset.dy + 60,
        offset.dx,
        0,
      ),
      items: [
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout, size: 18, color: Colors.red),
              const SizedBox(width: 8),
              Text(bahasa['logout'] ?? 'Logout'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'logout') {
        confirmLogout(context, token);
      }
    });
  }

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 4 / 5,
                  child: Skeleton(width: double.infinity, height: double.infinity, borderRadius: 8),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(width: 200, height: 22, borderRadius: 8),

                      const SizedBox(height: 20),
                      Skeleton(width: 80, height: 22, borderRadius: 8),
                      const SizedBox(height: 8),
                      Skeleton(width: 200, height: 22, borderRadius: 8),

                      const SizedBox(height: 20),
                      Skeleton(width: 100, height: 22, borderRadius: 8),
                      const SizedBox(height: 8),
                      Skeleton(width: 120, height: 22, borderRadius: 8),

                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: Skeleton(width: double.infinity, height: 60, borderRadius: 12)),
                          const SizedBox(width: 8),
                          Expanded(child: Skeleton(width: double.infinity, height: 60, borderRadius: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: Skeleton(width: double.infinity, height: 60, borderRadius: 12)),
                          const SizedBox(width: 8),
                          Expanded(child: Skeleton(width: double.infinity, height: 60, borderRadius: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final vote = voteData?['vote'] ?? {};

    return CustomScrollView(
      controller: _pageScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Bagian atas: event card + stat box, scroll biasa (tidak sticky)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEventCard(vote),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatBox(
                        title: bahasa['total_pendapatan'] ?? 'Total Revenue',
                        value: formatCurrency(
                          voteData?['vote']?['total_pendapatan'] ?? 0,
                          // voteData?['vote']?['currency'],
                          'IDR'
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatBox(
                        title: bahasa['jumlah_vote'] ?? 'Jumlah Vote',
                        value: thousandSeparator(
                          (voteData?['statistik']?['total_votes'] as num?)?.toInt() ?? 0,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildStatBox(
                          title: bahasa['jumlah_voters'] ?? 'Jumlah Voters',
                          value: thousandSeparator(
                            (voteData?['statistik']?['total_voters'] as num?)?.toInt() ?? 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatBox(
                          title: bahasa['total_kandidat'] ?? 'Total Kandidat',
                          value: thousandSeparator(
                            (voteData?['statistik']?['jumlah_kandidat'] as num?)?.toInt() ?? 0,
                          ),
                          isTotalKandidat: true,
                          valueAktif: thousandSeparator(
                            (voteData?['statistik']?['jumlah_aktif'] as num?)?.toInt() ?? 0,
                          ),
                          valueNonaktif: thousandSeparator(
                            (voteData?['statistik']?['jumlah_nonaktif'] as num?)?.toInt() ?? 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),

        // TabBar sticky — akan menempel di atas saat discroll
        SliverPersistentHeader(
          pinned: true,
          delegate: StickyTabBarDelegate(
            height: 56,
            child: Padding(
              padding: EdgeInsetsGeometry.fromLTRB(20, 0, 20, 0),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.red,
                      labelColor: Colors.red,
                      unselectedLabelColor: Colors.grey,
                      onTap: (index) {
                        setState(() {
                          indexTab = index;
                          _tabController.animateTo(index);
                        });

                        if (index == 0) {
                          _loadLeaderboardList(widget.idVote);
                        } else if (index == 1) {
                          _loadListDukungan(widget.idVote);
                        } else if (index == 2) {
                          // load transaksi
                        } else if (index == 3) {
                          // load transaksi per finalis
                        }
                      },
                      tabs: [
                        const Tab(icon: null, text: 'Leaderboard'),
                        Tab(icon: null, text: bahasa['dukungan'] ?? 'Dukungan'),
                        Tab(icon: null, text: bahasa['transaksi'] ?? 'Transaksi'),
                        Tab(icon: null, text: bahasa['transaksi_per_finalis'] ?? 'Transaksi Per Finalis'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Konten tab, tetap scroll normal di bawah tab bar yang sudah sticky
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          sliver: SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLeaderboardLoading ? _buildTabDataSkeleton(indexTab) : _buildTabContent(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(Map<dynamic, dynamic> vote) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //banner
          AspectRatio(
            aspectRatio: 4 / 5,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                vote['banner'] ?? '',
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

          //konten
          SizedBox(height: 12,),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vote['judul_vote'] ?? '-',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                SizedBox(height: 12,),
                Text(
                  bahasa['durasi_vote'] ?? 'Durasi Vote',
                  style: TextStyle(color: Colors.grey),
                ),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    buildAdaptiveDateText(
                      langCode,
                      vote['tanggal_buka_vote']?.toString(),
                    ),
                    Text(' - '),
                    buildAdaptiveDateText(
                      langCode,
                      vote['tanggal_tutup_vote']?.toString(),
                    ),
                  ],
                ),

                SizedBox(height: 12,),
                Text(
                  bahasa['harga_per_vote'] ?? 'Harga per Vote',
                  style: TextStyle(color: Colors.grey),
                ),
                
                Text(
                  formatCurrency(vote['harga'] ?? 0, vote['currency']),
                ),
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
    bool isTotalKandidat = false,
    String? valueAktif,
    String? valueNonaktif,
    double? minHeight,
  }) {
    return Container(
      width: double.infinity,
      constraints: minHeight != null
        ? BoxConstraints(minHeight: minHeight)
        : const BoxConstraints(),
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
          if (isTotalKandidat) ... [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  '$valueAktif ${bahasa['aktif']}',
                  style: TextStyle(color: Colors.green),
                ),
                Text(' · ', style: TextStyle(color: Colors.grey),),
                Text(
                  '$valueNonaktif ${bahasa['nonaktif']}',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildTabDataSkeleton(int tabIndex) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //judul tab
          Skeleton(width: 220, height: 22, borderRadius: 4),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Skeleton(width: 150, height: 22, borderRadius: 12),
              const SizedBox(width: 8),
              Skeleton(width: 130, height: 22, borderRadius: 12),
            ],
          ),

          // Search bar
          const SizedBox(height: 20),
          Skeleton(width: double.infinity, height: 48, borderRadius: 12),

          //konten
          const SizedBox(height: 20),
          tabIndex == 0
            ? _buildRankingSkeletonList()
            : _buildTablain()
        ],
      ),
    );
  }

  Widget _buildRankingSkeletonList() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRankingCardSkeleton(),
        const SizedBox(width: 10),
        _buildRankingCardSkeleton(),
        const SizedBox(width: 10),
        _buildRankingCardSkeleton(),
      ],
    );
  }

  Widget _buildRankingCardSkeleton() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto + badge ranking
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AspectRatio(
                    aspectRatio: 4 / 5,
                    child: Skeleton(
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: 0,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Skeleton(width: 28, height: 28, borderRadius: 14),
                ),
              ],
            ),

            // Nama + jumlah vote + persentase
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 70, height: 16, borderRadius: 4),
                  const SizedBox(height: 8),
                  Skeleton(width: 50, height: 18, borderRadius: 4),
                  const SizedBox(height: 8),
                  Skeleton(width: 55, height: 13, borderRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTablain() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Skeleton(width: 130, height: 22, borderRadius: 4),
              const SizedBox(width: 8,),
              Skeleton(width: 100, height: 22, borderRadius: 4),
            ],
          ),

          const SizedBox(height: 20,),
          Skeleton(width: double.infinity, height: 22, borderRadius: 4),
          const SizedBox(height: 20,),
          Skeleton(width: double.infinity, height: 22, borderRadius: 4),

          const SizedBox(height: 20,),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(width: 1, color: Colors.grey.shade300)
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 220, height: 22, borderRadius: 4),
                const SizedBox(height: 20),
                Skeleton(width: 110, height: 22, borderRadius: 12),
                const SizedBox(height: 20),
                Skeleton(width: 130, height: 22, borderRadius: 12),
                const SizedBox(height: 20),
                Skeleton(width: double.infinity, height: 22, borderRadius: 12),
                const SizedBox(height: 20),
                Skeleton(width: double.infinity, height: 22, borderRadius: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tabController.index) {
      case 0:
        return isLeaderboardLoading
          ? _buildRankingSkeletonList()
          : leaderboardList.isNotEmpty
            ? LeaderboardPage(
                key: _leaderboardKey,
                idVote: widget.idVote, 
                leaderboardList: leaderboardList,
              )
            : const NoOrder();

        case 1:
        return isDukunganLoading
          ? _buildTablain()
          : listDukungan.isNotEmpty
            ? DukunganPage(
                key: _dukunganKey,
                idVote: widget.idVote, 
                listDukungan: listDukungan,
              )
            : const NoOrder();

        case 2:
        return isTransaksiLoading
          ? _buildTablain()
          : listTransaksi.isNotEmpty
            ? TransaksiPage(
                key: _transaksiKey,
                idVote: widget.idVote, 
                listTransaksi: listTransaksi,
                currentPage: currentPageTransaksi,
              )
            : const NoOrder();

        case 3:
        return isTransaksiPerFinalisLoading
          ? _buildTablain()
          : listTransaksiPerFinalis.isNotEmpty
            ? TransaksiPerFinalisPage(
                key: _transaksiperfinalisKey,
                idVote: widget.idVote, 
                listTransaksiPerFinalis: listTransaksiPerFinalis,
                currentPage: 1,
              )
            : const NoOrder();
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _loadLeaderboardList(String idVote) async {
    final valid = await isTokenStillValid(token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }

    final result = await ApiService.get(
      '/api/v1/vote-result/${widget.idVote}/leaderboard',
      xLanguage: langCode,
      token: token
    );

    if (!mounted) return;
    setState(() {
      if (result == null) {
        leaderboardList = [];
      } else {
        leaderboardList = result['data']['finalis'] ?? [];
      }
      isLeaderboardLoading = false;
      searchLoading = false;
    });
  }

  Future<void> _loadListDukungan(String idVote) async {
    final valid = await isTokenStillValid(token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }

    final result = await ApiService.get(
      '/api/v1/vote-result/${widget.idVote}/dukungan',
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

  Future<void> _loadListTransaksi(String idVote) async {
    final valid = await isTokenStillValid(token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }

    final result = await ApiService.get(
      '/api/v1/vote-result/${widget.idVote}/transaksi',
      xLanguage: langCode,
      token: token
    );

    if (!mounted) return;
    setState(() {
      final rawList = result?['data']?['data'] as List<dynamic>? ?? [];
      listTransaksi = rawList.map((e) => e as Map<String, dynamic>).toList();
      isTransaksiLoading = false;
      searchLoading = false;
    });
  }

  Future<void> _loadListTransaksiPerFinalis(String idVote) async {
    final valid = await isTokenStillValid(token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }

    final result = await ApiService.get(
      '/api/v1/vote-result/${widget.idVote}/transaksi-per-finalis',
      xLanguage: langCode,
      token: token
    );

    if (!mounted) return;
    setState(() {
      final rawList = result?['data']?['data'] as List<dynamic>? ?? [];
      listTransaksiPerFinalis = rawList.map((e) => e as Map<String, dynamic>).toList();
      isTransaksiPerFinalisLoading = false;
      searchLoading = false;
    });
  }
}