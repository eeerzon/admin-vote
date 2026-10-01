import 'package:admin_vote_mobile/helper/global_function.dart';
import 'package:admin_vote_mobile/services/api_services.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DetailTransaksiSheet extends StatefulWidget {
  final String idOrder;
  final String? langCode;
  final String? token;
  final Map<String, dynamic> bahasa;

  const DetailTransaksiSheet({
    super.key,
    required this.idOrder,
    required this.langCode,
    required this.token,
    required this.bahasa,
  });

  @override
  State<DetailTransaksiSheet> createState() => _DetailTransaksiSheetState();
}

class _DetailTransaksiSheetState extends State<DetailTransaksiSheet> {
  bool isLoading = true;
  bool isError = false;
  Map<String, dynamic>? order;
  List<Map<String, dynamic>> items = [];

  Map<String, dynamic> get bahasa => widget.bahasa;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
      isError = false;
    });

    final valid = await isTokenStillValid(widget.token);
    if (!valid) {
      if (!mounted) return;
      await forceLogoutToLogin(context);
      return;
    }

    final result = await ApiService.get(
      '/api/v1/vote-result/transaksi/${widget.idOrder}',
      xLanguage: widget.langCode,
      token: widget.token,
    );

    if (!mounted) return;

    final data = result?['data'];
    final orderData = data is Map ? data['order'] : null;
    final itemsData = data is Map ? data['items'] : null;

    if (result?['success'] != true || orderData is! Map) {
      setState(() {
        isLoading = false;
        isError = true;
      });
      return;
    }

    setState(() {
      order = Map<String, dynamic>.from(orderData);
      items = itemsData is List
        ? itemsData.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList()
        : [];
      isLoading = false;
    });
  }

  ({String label, Color color, Color colorShade}) _statusInfo(dynamic status) {
    switch (status?.toString()) {
      case '0':
        return (label: bahasa['status_0'] ?? 'Gagal', color: Colors.red, colorShade: Colors.red.shade100);
      case '1':
        return (label: bahasa['status_1'] ?? 'Paid', color: Colors.blue, colorShade: Colors.blue.shade100);
      case '2':
        return (label: bahasa['status_2'] ?? 'Batal', color: Colors.red, colorShade: Colors.red.shade100);
      case '3':
        return (label: bahasa['status_3'] ?? 'Menunggu', color: Colors.orange, colorShade: Colors.orange.shade100);
      case '4':
        return (label: bahasa['status_4'] ?? 'Refund', color: Colors.red, colorShade: Colors.red.shade100);
      case '20':
        return (label: bahasa['status_20'] ?? 'Expired', color: Colors.red, colorShade: Colors.red.shade100);
      case '404':
        return (label: bahasa['status_404'] ?? 'Hidden', color: Colors.red, colorShade: Colors.red.shade100);
      default:
        return (label: status?.toString() ?? '-', color: Colors.grey, colorShade: Colors.grey.shade100);
    }
  }

  Future<void> _openSuccessUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
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

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_long_outlined, color: Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bahasa['detail_transaksi'] ?? 'Detail Transaksi',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            bahasa['detail_transaksi_desc'] ?? 'Informasi lengkap transaksi Anda',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
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

              Expanded(
                child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.red))
                  : isError
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              bahasa['gagal_muat_data'] ?? 'Gagal memuat data.',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _fetchData,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                side: const BorderSide(color: Color(0xFFDC2626)),
                              ),
                              child: Text(bahasa['muat_ulang'] ?? 'Muat Ulang'),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: _buildBody(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    final o = order!;
    final status = _statusInfo(o['status']);
    final successUrl = o['success_url']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow(
                icon: Icons.calendar_today_outlined,
                label: bahasa['tanggal_pemesanan'] ?? 'Tanggal Pemesanan',
                value: buildAdaptiveDateText(
                  widget.langCode,
                  o['created_at']?.toString(),
                  includeTime: true,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              const SizedBox(height: 14),
              _infoRow(
                icon: Icons.event_available_outlined,
                label: bahasa['tanggal_pembayaran'] ?? 'Tanggal Pembayaran',
                value: buildAdaptiveDateText(
                  widget.langCode,
                  o['updated_at']?.toString(),
                  includeTime: true,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              const SizedBox(height: 14),
              _infoRow(
                icon: Icons.tag,
                label: bahasa['id_order'] ?? 'ID Order',
                value: Text(
                  o['id']?.toString() ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              const SizedBox(height: 14),
              _infoRow(
                icon: Icons.attach_money,
                label: bahasa['nominal'] ?? 'Nominal',
                value: Text(
                  formatCurrency(o['total_harga_idr'] ?? 0, 'IDR'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(height: 14),
              _infoRow(
                icon: Icons.info_outline,
                label: bahasa['status'] ?? 'Status',
                value: Container(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                  decoration: BoxDecoration(
                    color: status.colorShade,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.label,
                    style: TextStyle(color: status.color, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),

              if (successUrl != null && successUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openSuccessUrl(successUrl),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue,
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(
                      bahasa['lihat_halaman_success'] ?? 'Lihat Halaman Success',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_outline, size: 18, color: Colors.blue),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    bahasa['data_pemesan'] ?? 'Data Pemesan',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _labeledValue(bahasa['nama'] ?? 'Nama', o['full_name']?.toString() ?? '-'),
              const SizedBox(height: 12),
              _labeledValue(bahasa['no_hp'] ?? 'No HP', o['phone']?.toString() ?? '-'),
              const SizedBox(height: 12),
              _labeledValue(bahasa['email'] ?? 'Email', o['email']?.toString() ?? '-'),
            ],
          ),
        ),

        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.shopping_bag_outlined, size: 18, color: Colors.purple[300]),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${bahasa['vote'] ?? 'Vote'} ${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _labeledValue(
                    bahasa['product_name'] ?? 'Product Name',
                    item['nama_finalis']?.toString() ?? '-',
                  ),
                  const SizedBox(height: 12),
                  _labeledValue(
                    bahasa['quantity'] ?? 'Quantity',
                    '${thousandSeparator(toInt(item['qty']))} ${bahasa['vote'] ?? 'Vote'}',
                  ),
                  const SizedBox(height: 12),
                  _labeledValue(
                    bahasa['subtotal'] ?? 'Subtotal',
                    formatCurrency(item['subtotal_idr'] ?? 0, 'IDR'),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _infoRow({required IconData icon, required String label, required Widget value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: Colors.grey[400]),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ),
        value,
      ],
    );
  }

  Widget _labeledValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }
}
