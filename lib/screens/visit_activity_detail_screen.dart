import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/field_data_state.dart';
import '../theme/nocturne_theme.dart';
import '../utils/format.dart';
import '../utils/image_provider.dart';
import '../widgets/async_state.dart';
import '../widgets/nocturne_card.dart';

/// Read-only recap of everything an SPG submitted for one outlet on one past
/// day — laporan, foto, stok, penjualan, aktivitas kompetitor, plus any admin
/// comments on the laporan. Opened by tapping a past day's schedule card;
/// past visits have no check-in flow to offer, only this.
class VisitActivityDetailScreen extends StatefulWidget {
  const VisitActivityDetailScreen({super.key, required this.location, required this.day});
  final OutletLocation location;
  final DateTime day;

  @override
  State<VisitActivityDetailScreen> createState() => _VisitActivityDetailScreenState();
}

class _VisitActivityDetailScreenState extends State<VisitActivityDetailScreen> {
  bool _loading = true;
  String? _error;
  ApprovalReport? _approval;
  List<ApprovalComment> _comments = [];
  List<StockCheck> _stock = [];
  DailySalesReport? _sales;
  List<CompetitorActivity> _competitor = [];

  String get _dateStr =>
      '${widget.day.year}-${widget.day.month.toString().padLeft(2, '0')}-${widget.day.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final data = context.read<FieldDataState>();
    final loc = widget.location;
    try {
      final approvalsF = data.api.listApprovals(spgId: data.spgId, date: _dateStr);
      final competitorF = data.api.listCompetitorActivities(spgId: data.spgId, date: _dateStr);
      final salesF = data.api.listDailySalesReports(spgId: data.spgId);
      final stockF = data.api.listStockChecks(spgId: data.spgId, brandId: loc.brandId, outlet: loc.name);

      final approvals = (await approvalsF).where((a) => a.brandId == loc.brandId && a.outlet == loc.name).toList();
      final approval = approvals.isEmpty ? null : approvals.first;
      final comments = approval == null ? <ApprovalComment>[] : await data.api.listApprovalComments(approval.id);
      final competitor = (await competitorF).where((c) => c.brandId == loc.brandId && c.outlet == loc.name).toList();
      final sales = (await salesF).where((s) => s.outlet == loc.name && s.date == _dateStr).toList();
      final stock = (await stockF).where((s) => s.date == _dateStr && (s.stockOpen != null || s.stockClose != null)).toList();

      if (!mounted) return;
      setState(() {
        _approval = approval;
        _comments = comments;
        _competitor = competitor;
        _sales = sales.isEmpty ? null : sales.first;
        _stock = stock;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _productName(FieldDataState data, int productId) {
    final products = data.brandById(widget.location.brandId)?.products ?? const <Product>[];
    for (final p in products) {
      if (p.id == productId) return p.name;
    }
    return 'Produk #$productId';
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<FieldDataState>();
    const weekdays = ['Senin', 'Selasa', 'Rabu', 'Kamis', "Jum'at", 'Sabtu', 'Minggu'];
    const monthNames = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final dateLabel = '${weekdays[widget.day.weekday - 1]}, ${widget.day.day} ${monthNames[widget.day.month - 1]} ${widget.day.year}';

    final hasAnyActivity = _approval != null || _sales != null || _competitor.isNotEmpty || _stock.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(widget.location.name, style: const TextStyle(fontSize: 16))),
      body: _loading
          ? const LoadingState()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                    children: [
                      Text(dateLabel, style: const TextStyle(fontSize: 13, color: Color(0x99E9E9ED))),
                      const SizedBox(height: 14),
                      if (!hasAnyActivity)
                        const EmptyState(label: 'Tidak ada aktivitas yang tercatat pada kunjungan ini.')
                      else ...[
                        _Section(
                          title: 'Laporan Kunjungan',
                          child: _approval == null
                              ? _emptyLine('Belum ada laporan.')
                              : Text(_approval!.note, style: const TextStyle(fontSize: 12.5)),
                        ),
                        const SizedBox(height: 16),
                        _Section(
                          title: _approval?.photoUrls?.isNotEmpty == true ? 'Foto Bukti (${_approval!.photoUrls!.length})' : 'Foto Bukti',
                          child: (_approval?.photoUrls?.isEmpty ?? true)
                              ? _emptyLine('Tidak ada foto.')
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _approval!.photoUrls!
                                      .map((uri) => Container(
                                            width: 72,
                                            height: 72,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: NocturneColors.divider),
                                              image: DecorationImage(image: resolveImageProvider(uri)!, fit: BoxFit.cover),
                                            ),
                                          ))
                                      .toList(),
                                ),
                        ),
                        const SizedBox(height: 16),
                        _Section(
                          title: 'Stok Buka / Tutup',
                          child: _stock.isEmpty
                              ? _emptyLine('Belum ada data stok.')
                              : Column(
                                  children: _stock
                                      .map((s) => Padding(
                                            padding: const EdgeInsets.only(bottom: 6),
                                            child: Row(
                                              children: [
                                                Expanded(child: Text(_productName(data, s.productId), style: const TextStyle(fontSize: 12.5))),
                                                Text('Buka: ${s.stockOpen ?? '-'}', style: TextStyle(fontSize: 11.5, color: NocturneColors.textMuted(0.6))),
                                                const SizedBox(width: 10),
                                                Text('Tutup: ${s.stockClose ?? '-'}', style: TextStyle(fontSize: 11.5, color: NocturneColors.textMuted(0.6))),
                                              ],
                                            ),
                                          ))
                                      .toList(),
                                ),
                        ),
                        const SizedBox(height: 16),
                        _Section(
                          title: 'Penjualan',
                          child: _sales == null
                              ? _emptyLine('Belum ada data penjualan.')
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ..._sales!.items.map((i) => Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Row(
                                            children: [
                                              Expanded(child: Text(_productName(data, i.productId), style: const TextStyle(fontSize: 12.5))),
                                              Text('${i.qty}x', style: TextStyle(fontSize: 11.5, color: NocturneColors.textMuted(0.6))),
                                              const SizedBox(width: 10),
                                              Text(formatRp(i.lineTotal), style: const TextStyle(fontSize: 12)),
                                            ],
                                          ),
                                        )),
                                    const SizedBox(height: 4),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text('Total: ${formatRp(_sales!.total)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 16),
                        _Section(
                          title: 'Aktivitas Kompetitor',
                          child: _competitor.isEmpty
                              ? _emptyLine('Tidak ada laporan aktivitas kompetitor.')
                              : Column(
                                  children: _competitor
                                      .map((c) => Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: NocturneCard(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(c.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                                  const SizedBox(height: 4),
                                                  Text(c.description, style: TextStyle(fontSize: 12, color: NocturneColors.textMuted(0.75))),
                                                  if (c.photoUrls?.isNotEmpty == true) ...[
                                                    const SizedBox(height: 8),
                                                    Wrap(
                                                      spacing: 6,
                                                      runSpacing: 6,
                                                      children: c.photoUrls!
                                                          .map((uri) => Container(
                                                                width: 52,
                                                                height: 52,
                                                                decoration: BoxDecoration(
                                                                  borderRadius: BorderRadius.circular(6),
                                                                  border: Border.all(color: NocturneColors.divider),
                                                                  image: DecorationImage(image: resolveImageProvider(uri)!, fit: BoxFit.cover),
                                                                ),
                                                              ))
                                                          .toList(),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ),
                        ),
                        if (_approval != null) ...[
                          const SizedBox(height: 16),
                          _Section(
                            title: 'Komentar Admin',
                            child: _comments.isEmpty
                                ? _emptyLine('Belum ada komentar.')
                                : Column(
                                    children: _comments
                                        .map((c) => Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: NocturneColors.bg,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(c.authorName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                                        Text(
                                                          '${c.createdAt.toLocal().day}/${c.createdAt.toLocal().month} ${c.createdAt.toLocal().hour.toString().padLeft(2, '0')}:${c.createdAt.toLocal().minute.toString().padLeft(2, '0')}',
                                                          style: TextStyle(fontSize: 10, color: NocturneColors.textMuted(0.45)),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(c.message, style: const TextStyle(fontSize: 12.5)),
                                                  ],
                                                ),
                                              ),
                                            ))
                                        .toList(),
                                  ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _emptyLine(String label) => Text(label, style: TextStyle(fontSize: 12, color: NocturneColors.textMuted(0.5)));
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: NocturneColors.textMuted(0.55)),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
