
// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:admin_vote_mobile/helper/global_function.dart';
import 'package:admin_vote_mobile/helper/global_var.dart';
import 'package:admin_vote_mobile/helper/global_widget.dart';
import 'package:admin_vote_mobile/pages/voteSaya/event_aktif.dart';
import 'package:admin_vote_mobile/pages/voteSaya/event_draft.dart';
import 'package:admin_vote_mobile/pages/voteSaya/event_lalu.dart';
import 'package:admin_vote_mobile/pages/voteSaya/new_vote.dart';
import 'package:admin_vote_mobile/services/api_services.dart';
import 'package:admin_vote_mobile/services/lang_service.dart';
import 'package:admin_vote_mobile/services/storage_services.dart';
import 'package:flutter/material.dart';

class VoteSayaPage extends StatefulWidget {
  final void Function(int index)? onNavigateToTab;
  const VoteSayaPage({
    super.key,
    this.onNavigateToTab
  });

  @override
  State<VoteSayaPage> createState() => _VoteSayaPageState();
}

class _VoteSayaPageState extends State<VoteSayaPage> with SingleTickerProviderStateMixin, RouteAware {
  String? token;
  String? langCode, currencyCode;
  
  Map<String, dynamic> bahasa = {};

  String? userName;

  int currentPageAktif = 1;
  int currentPageDraft = 1;
  int currentPageLalu = 1;
  String searchFilter = '';
  String sortFilter = 'waktu_terdekat'; //waktu_terdekat, waktu_terjauh, nama_voting_az, nama_voting_za
  int indexTab = 0;
  String tabFilter = 'aktif'; //aktif, draft, lalu

  final _searchController = TextEditingController();
  late TabController _tabController;
  final ScrollController _pageScrollController = ScrollController();

  final GlobalKey<EventAktifState> _eventAktifKey = GlobalKey<EventAktifState>();
  final GlobalKey<EventDraftState> _eventDraftKey = GlobalKey<EventDraftState>();
  final GlobalKey<EventLaluState> _eventLaluKey = GlobalKey<EventLaluState>();

  bool isAktifLoading = true;
  bool isDraftLoading = true;
  bool isLaluLoading = true;

  final bool _aktifLoaded = false;
  final bool _draftLoaded = false;
  final bool _laluLoaded = false;

  List<dynamic> voteAktifData = [];
  List<dynamic> voteDraftData = [];
  List<dynamic> voteLaluData = [];

  bool searchLoading = false;
  Timer? _debounce;

  bool _isScrolledDown = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _pageScrollController.addListener(_onPageScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
    
      if (!mounted) return;
      
      await _getBahasa();
      await _loadVoteAktifData(currentPageAktif, searchFilter, sortFilter);
    });

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
        final index = _tabController.index;
        
        if (index == 0 && !_aktifLoaded) {
          _loadVoteAktifData(currentPageAktif, searchFilter, sortFilter);
        } else if (index == 1 && !_draftLoaded) {
          _loadVoteDraftData(currentPageDraft, searchFilter, sortFilter);
        } else if (index == 2 && !_laluLoaded) {
          _loadVoteLaluData(currentPageLalu, searchFilter, sortFilter);
        }
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

  Future<void> _loadVoteAktifData(int page, String? search, String? sort) async {
    final valid = await isTokenStillValid(token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }

    final result = await ApiService.get(
      '/api/v1/votes?page=$page&search=$search&sort=$sort&tab=aktif',
      xLanguage: langCode,
      token: token
    );
    
    if (!mounted) return;
    setState(() {
      if (result == null) {
        voteAktifData = [];
      } else {
        voteAktifData = result['data']['data'] ?? [];
      }
      isAktifLoading = false;
      searchLoading = false;
    });
  }

  Future<void> _loadVoteDraftData(int page, String? search, String? sort) async {
    final valid = await isTokenStillValid(token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }
    
    final result = await ApiService.get(
      '/api/v1/votes?page=$page&search=$search&sort=$sort&tab=draft',
      xLanguage: langCode,
      token: token
    );
    
    if (!mounted) return;
    setState(() {
      if (result == null) {
        voteDraftData = [];
      } else {
        voteDraftData = result['data']['data'] ?? [];
      }
      isDraftLoading = false;
      searchLoading = false;
    });
  }

  Future<void> _loadVoteLaluData(int page, String? search, String? sort) async {
    final valid = await isTokenStillValid(token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }

    final result = await ApiService.get(
      '/api/v1/votes?page=$page&search=$search&sort=$sort&tab=lalu',
      xLanguage: langCode,
      token: token
    );
    
    if (!mounted) return;
    setState(() {
      if (result == null) {
        voteLaluData = [];
      } else {
        voteLaluData = result['data']['data'] ?? [];
      }
      isLaluLoading = false;
      searchLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: isAktifLoading ? _buildSkeleton() : _buildContent(),
      ),
      floatingActionButton: isAktifLoading ? null : _buildFab(),
    );
  }

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (logo)
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

          const SizedBox(height: 20),
          // Card "Vote Saya" (search, filter, tabs)
          _buildVoteSayaCardSkeleton(),
          
          // List event cards
          const SizedBox(height: 20),
          _buildVoteEventCardSkeleton(),
          const SizedBox(height: 20),
          _buildVoteEventCardSkeleton(),
          const SizedBox(height: 20),
          _buildVoteEventCardSkeleton(),
        ],
      ),
    );
  }

  Widget _buildVoteSayaCardSkeleton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Vote Saya" title + button "Buat Votemu Sekarang"

          // Search bar
          Skeleton(width: double.infinity, height: 48, borderRadius: 12),
          const SizedBox(height: 20),

          // Dropdown "Waktu Terdekat"
          Skeleton(width: double.infinity, height: 48, borderRadius: 12),
          const SizedBox(height: 20),

          // Tabs (Event Aktif, Event Draft, Event Lalu)
          Row(
            children: [
              Skeleton(width: 90, height: 18, borderRadius: 4),
              const SizedBox(width: 24),
              Skeleton(width: 90, height: 18, borderRadius: 4),
              const SizedBox(width: 24),
              Skeleton(width: 90, height: 18, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoteEventCardSkeleton() {
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
          // Gambar thumbnail
          AspectRatio(
            aspectRatio: 4 / 5,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Skeleton(
                width: double.infinity,
                height: double.infinity,
                borderRadius: 12,
              ),
            ),
          ),

          // Judul event
          const SizedBox(height: 20),
          Skeleton(width: 220, height: 22, borderRadius: 4),

          // Tags (National Vote, Voting Berbayar)
          const SizedBox(height: 20),
          Row(
            children: [
              Skeleton(width: 110, height: 22, borderRadius: 12),
              const SizedBox(width: 8),
              Skeleton(width: 130, height: 22, borderRadius: 12),
            ],
          ),

          // Tanggal Grandfinal Mulai + Harga per Vote
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 150, height: 22, borderRadius: 4),
                    const SizedBox(height: 8),
                    Skeleton(width: 100, height: 22, borderRadius: 4),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 110, height: 22, borderRadius: 4),
                    const SizedBox(height: 8),
                    Skeleton(width: 80, height: 22, borderRadius: 4),
                  ],
                ),
              ),
            ],
          ),

          // Lokasi Vote
          const SizedBox(height: 20),
          Skeleton(width: 100, height: 22, borderRadius: 4),
          const SizedBox(height: 8),
          Skeleton(width: 260, height: 22, borderRadius: 4),

          // Tombol Detail Vote
          const SizedBox(height: 20),
          Skeleton(width: double.infinity, height: 38, borderRadius: 12),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      controller: _pageScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          buildHeader(context, userName, token, bahasa, widget.onNavigateToTab),

          const SizedBox(height: 10),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bahasa['bot_nav_2'] ?? 'Vote Saya',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  // Search bar
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {});

                      if (_debounce?.isActive ?? false) _debounce!.cancel();

                      _debounce = Timer(const Duration(milliseconds: 500), () async {
                        if (!mounted) return;

                        if (value.isNotEmpty) {
                          setState(() {
                            searchFilter = value;
                            currentPageAktif = 1;
                            currentPageDraft = 1;
                            currentPageLalu = 1;
                            searchLoading = true;
                          });
                        } else {
                          setState(() {
                            searchFilter = '';
                            currentPageAktif = 1;
                            currentPageDraft = 1;
                            currentPageLalu = 1;
                            searchLoading = true;
                          });
                        }

                        _loadVoteAktifData(currentPageAktif, searchFilter, sortFilter);
                        _loadVoteDraftData(currentPageDraft, searchFilter, sortFilter);
                        _loadVoteLaluData(currentPageLalu, searchFilter, sortFilter);
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
                                currentPageAktif = 1;
                                currentPageDraft = 1;
                                currentPageLalu = 1;
                                searchLoading = true;
                              });

                              _loadVoteAktifData(currentPageAktif, searchFilter, sortFilter);
                              _loadVoteDraftData(currentPageDraft, searchFilter, sortFilter);
                              _loadVoteLaluData(currentPageLalu, searchFilter, sortFilter);
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
                  const SizedBox(height: 10),
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
                            currentPageAktif = 1;
                            currentPageDraft = 1;
                            currentPageLalu = 1;
                            searchLoading = true;
                          });

                          _loadVoteAktifData(currentPageAktif, searchFilter, sortFilter);
                          _loadVoteDraftData(currentPageDraft, searchFilter, sortFilter);
                          _loadVoteLaluData(currentPageLalu, searchFilter, sortFilter);
                        },
                      ),
                    ),
                  ),

                  // tab filter
                  const SizedBox(height: 10),
                  Material(
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

                        if (index == 0 && !_aktifLoaded) {
                          _loadVoteAktifData(currentPageAktif, searchFilter, sortFilter);
                        } else if (index == 1 && !_draftLoaded) {
                          _loadVoteDraftData(currentPageDraft, searchFilter, sortFilter);
                        } else if (index == 2 && !_laluLoaded) {
                          _loadVoteLaluData(currentPageLalu, searchFilter, sortFilter);
                        }
                      },
                      tabs: [
                      Tab(icon: null, text: bahasa['event_aktif']),
                      Tab(icon: null, text: bahasa['event_draft']),
                      Tab(icon: null, text: bahasa['event_lalu']),
                    ],
                    ),
                  ),
                ]
              ),
            ),
          ),
          
          const SizedBox(height: 10,),
          searchLoading ? _buildVoteEventCardSkeleton() : _buildTabContent()
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tabController.index) {
      case 0:
        return isAktifLoading
            ? _buildVoteEventCardSkeleton()
            : voteAktifData.isNotEmpty
                ? EventAktif(
                    key: _eventAktifKey,
                    eventAktif: voteAktifData, 
                    currentPage: currentPageAktif,
                    searchFilter: searchFilter,
                    sortFilter: sortFilter
                  )
                : const NoOrder();
      case 1:
        return isDraftLoading
            ? _buildVoteEventCardSkeleton()
            : voteDraftData.isNotEmpty
                ? EventDraft(
                    key: _eventDraftKey, 
                    eventDraft: voteDraftData,
                    currentPage: currentPageDraft,
                    searchFilter: searchFilter,
                    sortFilter: sortFilter,
                  )
                : const NoOrder();
      case 2:
        return isLaluLoading
            ? _buildVoteEventCardSkeleton()
            : voteLaluData.isNotEmpty
                ? EventLalu(
                    key: _eventLaluKey,
                    eventLalu: voteLaluData, 
                    currentPage: currentPageLalu,
                    searchFilter: searchFilter,
                    sortFilter: sortFilter
                  )
                : const NoOrder();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFab() {
    return AnimatedSwitcher(
    duration: const Duration(milliseconds: 200),
    transitionBuilder: (child, animation) {
      return ScaleTransition(scale: animation, child: child);
    },
    child: _isScrolledDown
      ? FloatingActionButton(
          key: const ValueKey('fab_icon'),
          backgroundColor: Colors.red,
          onPressed: () async {
            // navigasi ke halaman buat vote
            await Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => NewVotePage()),
            );
          },
          child: const Icon(Icons.add, color: Colors.white),
        )
      : FloatingActionButton.extended(
          key: const ValueKey('fab_extended'),
          backgroundColor: Colors.red,
          onPressed: () async {
            // navigasi ke halaman buat vote
            await Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => NewVotePage()),
            );
          },
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(
            bahasa['buat_votemu'] ?? 'Buat Votemu',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
    );
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
        _loadMoreAktif();
      } else if (_tabController.index == 1) {
        _loadMoreDraft();
      } else if (_tabController.index == 2) {
        _loadMoreLalu();
      }
    }
  }

  void _loadMoreAktif() {
    _eventAktifKey.currentState?.loadMoreAktif();
  }

  void _loadMoreDraft() {
    _eventDraftKey.currentState?.loadMoreDraft();
  }
  void _loadMoreLalu() {
    _eventLaluKey.currentState?.loadMoreLalu();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    voteRouteObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  // Kepanggil waktu route yang ditumpuk di atas VoteSayaPage (new_vote.dart,
  // langsung atau lewat detail_vote.dart) di-pop dan halaman ini kelihatan
  // lagi. Dipakai buat auto-switch ke tab Draft setelah "Simpan Draft".
  @override
  void didPopNext() {
    if (pendingSwitchToDraftTab) {
      pendingSwitchToDraftTab = false;
      _tabController.animateTo(1);
      setState(() {
        currentPageDraft = 1;
      });
      _loadVoteDraftData(currentPageDraft, searchFilter, sortFilter);
    }
  }

  @override
  void dispose() {
    voteRouteObserver.unsubscribe(this);
    _tabController.dispose();
    _pageScrollController.removeListener(_onPageScroll);
    _pageScrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}