// ignore_for_file: use_build_context_synchronously

import 'package:admin_vote_mobile/helper/global_function.dart';
import 'package:admin_vote_mobile/helper/global_widget.dart';
import 'package:admin_vote_mobile/pages/voteSaya/detail_vote.dart';
import 'package:admin_vote_mobile/services/api_services.dart';
import 'package:admin_vote_mobile/services/lang_service.dart';
import 'package:admin_vote_mobile/services/storage_services.dart';
import 'package:flutter/material.dart';

class DashboardPage extends StatefulWidget {
  final void Function(int index)? onNavigateToTab;
  const DashboardPage({super.key, this.onNavigateToTab});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ScrollController _scrollController = ScrollController();
  String? token;
  String? langCode, currencyCode;

  Map<String, dynamic> bahasa = {};
  Map<String, dynamic>? resultIndex;

  String? userName;
  
  bool isLoadingDataAtas = true;
  bool isLoadingDataBawah = true;

  int selectedYear = DateTime.now().year;
  late List<int> yearList;
  bool isSummaryLoading = false;
  Map<String, dynamic>? summaryData;
  List<Map<String, dynamic>>? voteListData;

  @override
  void initState() {
    super.initState();

    final currentYear = DateTime.now().year;
    yearList = List.generate(5, (index) => currentYear + 1 - index);
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      await _getBahasa();
      await _loadDataAtas(selectedYear);
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

  Future<void> _loadDataAtas(int year) async {
    final valid = await isTokenStillValid(token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }
    
    final results = await Future.wait([
      ApiService.get("/api/v1/dashboard", params: null, xLanguage: langCode, token: await StorageService.getToken()),
      ApiService.get("/api/v1/dashboard/summary", params: {"year": year.toString()}, xLanguage: langCode, token: await StorageService.getToken()),
      
    ]);

    final resultDashboardIndex = results[0];
    final resultDashboardSummary = results[1];

    if (!mounted) return;

    setState(() {
      resultIndex = resultDashboardIndex;
      summaryData = resultDashboardSummary;
      isLoadingDataAtas = false;
    });

    _loadDataBawah(year);
  }

  Future<void> _summaryByYear(int year, {double? restoreOffset}) async {
    final valid = await isTokenStillValid(token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }

    setState(() {
      isSummaryLoading = true;
    });

    final result = await ApiService.get(
      "/api/v1/dashboard/summary",
      params: {"year": year.toString()},
      xLanguage: langCode,
      token: await StorageService.getToken(),
    );

    if (!mounted) return;
    setState(() {
      summaryData = result;
      isSummaryLoading = false;
    });
    
    if (restoreOffset != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            restoreOffset.clamp(
              0,
              _scrollController.position.maxScrollExtent,
            ),
          );
        }
      });
    }
  }

  void _onYearSelected(int year) {
    if (year == selectedYear) return;

    final double currentOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0;

    setState(() {
      selectedYear = year;
    });

    _summaryByYear(year, restoreOffset: currentOffset);
  }

  Future <void> _loadDataBawah(int year) async {
    final valid = await isTokenStillValid(token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }

    final result = await ApiService.get(
      "/api/v1/dashboard/vote-list", 
      params: {
        "per_page": "5",
        "search": "",
        "sort": "waktu_terjauh", // waktu_terjauh, waktu_terdekat, nama A-Z, nama Z-A
        "year": year.toString()
        }, 
      xLanguage: langCode, 
      token: await StorageService.getToken());

    if (result != null) {
      if (!mounted) return;
      setState(() {
        voteListData = List<Map<String, dynamic>>.from(result['data']['data'] ?? []);
        isLoadingDataBawah = false;
      });
    } else {
      if (!mounted) return;
      setState(() {
        voteListData = [];
        isLoadingDataBawah = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: isLoadingDataAtas ? _buildSkeleton() : _buildContent(),
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
          const SizedBox(height: 20),

          // "Home" title + subtitle
          Skeleton(width: 100, height: 26, borderRadius: 4),

          const SizedBox(height: 8),
          Skeleton(width: 200, height: 16, borderRadius: 4),

          // Dua card ringkasan (Jumlah Penjualan & Saldo)
          const SizedBox(height: 20),
          _buildSummaryCardSkeleton(),
          const SizedBox(height: 20),
          _buildSummaryCardSkeleton(),

          const SizedBox(height: 20),
          // Rangkuman
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 130, height: 20, borderRadius: 4),
                const SizedBox(height: 20),

                // Tahun chips
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 6,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, __) => Skeleton(
                      width: 64,
                      height: 36,
                      borderRadius: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                Row(
                  children: [
                    Expanded(child: _buildStatBoxSkeleton()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatBoxSkeleton()),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _buildStatBoxSkeleton()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatBoxSkeleton()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCardSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Skeleton(width: 32, height: 32, borderRadius: 12),
              const SizedBox(width: 8),
              Expanded(child: Skeleton(width: double.infinity, height: 14, borderRadius: 4)),
            ],
          ),
          const SizedBox(height: 20),
          Skeleton(width: 100, height: 24, borderRadius: 4),
          const SizedBox(height: 8),
          Skeleton(width: 140, height: 12, borderRadius: 4),
        ],
      ),
    );
  }

  Widget _buildStatBoxSkeleton() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: 80, height: 12, borderRadius: 4),
          const SizedBox(height: 8),
          Skeleton(width: 40, height: 20, borderRadius: 4),
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
              Skeleton(width: 180, height: 20, borderRadius: 4),
              Skeleton(width: 30, height: 20, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 20),
          Row (
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Skeleton(width: 120, height: 20, borderRadius: 4),
              Skeleton(width: 100, height: 20, borderRadius: 4),
            ],
          ),

          const SizedBox(height: 20),
          Row (
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Skeleton(width: 130, height: 20, borderRadius: 4),
              Skeleton(width: 80, height: 20, borderRadius: 4),
            ],
          ),

          const SizedBox(height: 20),
          Row (
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Skeleton(width: 120, height: 20, borderRadius: 4),
              Skeleton(width: 100, height: 20, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    currencyCode = resultIndex?['data']?['estimate']['currency']?.toString() ?? 'IDR';

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          buildHeader(context, userName, token, bahasa, widget.onNavigateToTab),

          const SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Text(
              bahasa['bot_nav_1'] ?? 'Home',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Text(
              "${bahasa['top_nav'] ?? 'Selamat Datang Kembali'}, "
              "$userName",
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),

          //total saldo
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: _buildSummaryCard(
              title: bahasa['jumlah_penjualan'] ?? 'Jumlah Penjualan',
              value: formatCurrency(resultIndex?['data']?['total_revenue']['total'] ?? 0, currencyCode!),
              valueDesc: bahasa['jumlah_penjualan_desc'] ?? 'Estimated Total Sales',
              icon: Icons.attach_money_outlined,
              iconColor: Colors.red,
              bgColor: Colors.red[50]!,
            ),
          ),
          
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: _buildSummaryCard(
              title: bahasa['saldo_saat_ini'] ?? 'Current Balance',
              value: formatCurrency(resultIndex?['data']?['total_revenue']['remaining_balance'] ?? 0, currencyCode!),
              valueDesc: bahasa['saldo_saat_ini_desc'] ?? 'Can be withdrawn at any time',
              icon: Icons.credit_card_outlined,
              iconColor: Colors.red,
              bgColor: Colors.red[50]!,
            ),
          ),

          //rangkuman
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bahasa['rangkuman'] ?? 'Summary',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),

                  // Tahun chips
                  const SizedBox(height: 20),
                  _buildYearChips(),

                  if (isSummaryLoading) ... [
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _buildStatBoxSkeleton()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatBoxSkeleton()),
                      ],
                    ),

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _buildStatBoxSkeleton()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatBoxSkeleton()),
                      ],
                    )
                  ] else ... [
                    const SizedBox(height: 20),
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatBox(
                            title: bahasa['total_voter'] ?? 'Total Voter',
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
                            title: bahasa['total_vote'] ?? 'Total Vote',
                            value: thousandSeparator(
                              (summaryData?['data']?['total_votes'] as num?)?.toInt() ?? 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatBox(
                            title: bahasa['total_pendapatan'] ?? 'Total Revenue',
                            value: formatCurrency(resultIndex?['data']?['total_revenue']['total'] ?? 0, currencyCode!),
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                ],
              ),
            ),
          ),

          //list vote
          const SizedBox(height: 20),
          if (isLoadingDataBawah) ... [
            Padding (
              padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Skeleton(width: 130, height: 20, borderRadius: 4),
                      Skeleton(width: 80, height: 20, borderRadius: 4),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildEventItemSkeleton(),
                  const SizedBox(height: 10),
                  _buildEventItemSkeleton(),
                ],
              ),
            ),
          ] else ... [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        bahasa['event_terbaru'] ?? 'Latest Event',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () async {
                          widget.onNavigateToTab?.call(1);
                        },
                        child: Text(
                          bahasa['see_all'] ?? 'See All',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  _buildVoteSection(voteList: voteListData ?? []),
                  
                ],
              ),
            ),
            
          ]
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    String? valueDesc,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              buildIconCircle(
                icon: icon,
                iconColor: iconColor,
                bgColor: bgColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          
          const SizedBox(height: 20),
          Text(
            valueDesc?? '',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildYearChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: yearList.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final year = yearList[index];
          final isActive = year == selectedYear;

          return GestureDetector(
            onTap: () => _onYearSelected(year),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFB5482F) : const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  year.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
            ),
          );
        },
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
        color: const Color(0xFFF5F5F7),
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

  Widget _buildVoteSection({
    required List<Map<String, dynamic>> voteList
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var vote in voteList.asMap().entries)
          InkWell(
            onTap: () async {
              await Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => DetailVotePage(idVote: vote.value['id_vote'],)),
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
                  //judul event
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          vote.value['judul_vote'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
      
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () async {
                          await Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (_) => DetailVotePage(idVote: vote.value['id_vote'],)),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(10,2,10,2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300)
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            bahasa['view'] ?? 'Lihat',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
      
                  //tanggal event
                  const SizedBox(height: 4),
                  buildAdaptiveDateText(
                    langCode,
                    vote.value['tanggal_grandfinal_mulai']?.toString(),
                    style: const TextStyle(color: Colors.grey),
                  ),
      
                  //jumlah votes + pendapatan
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        vote.value['total_votes'] > 0
                          ? bahasa['text_votes']
                          : bahasa['text_vote'],
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),

                      SizedBox(width: 4,),
                      Text(
                        thousandSeparator((vote.value['total_votes'] as num?)?.toInt() ?? 0),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      SizedBox(width: 10,),
                      Text(
                        formatCurrency(vote.value['final_price_idr'] ?? 0, currencyCode!),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.green
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}