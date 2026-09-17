import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/field_data_state.dart';
import '../theme/nocturne_theme.dart';
import '../utils/format.dart';
import '../widgets/async_state.dart';
import '../widgets/nocturne_card.dart';
import 'catat_penjualan_keliling_screen.dart';
import 'penjualan_keliling_detail_screen.dart';

const _pageSize = 20;

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// "Daftar Penjualan Saya" — paginated (20/page, lazy-loaded on scroll), searchable, and
/// date-filterable, with a running total for whatever's currently filtered. Mirrors the
/// pagination pattern already built for "Daftar Toko Saya" (`daftar_toko_screen.dart`).
class PenjualanKelilingListScreen extends StatefulWidget {
  const PenjualanKelilingListScreen({super.key, required this.brandId});
  final int brandId;

  @override
  State<PenjualanKelilingListScreen> createState() => _PenjualanKelilingListScreenState();
}

class _PenjualanKelilingListScreenState extends State<PenjualanKelilingListScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounce;
  DateTimeRange? _dateRange;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  List<DailySalesReport> _reports = [];
  int _total = 0;
  num _totalAmount = 0;
  int _page = 1;

  bool get _hasMore => _reports.length < _total;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_loading || _loadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _loadFirstPage);
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _loadFirstPage();
    }
  }

  void _clearDateRange() {
    setState(() => _dateRange = null);
    _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = context.read<FieldDataState>();
      final result = await data.api.searchMyDailySalesReports(
        search: _searchController.text.trim(),
        from: _dateRange != null ? _isoDate(_dateRange!.start) : null,
        to: _dateRange != null ? _isoDate(_dateRange!.end) : null,
        page: 1,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _reports = result.items;
        _total = result.total;
        _totalAmount = result.totalAmount;
        _page = 1;
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

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final data = context.read<FieldDataState>();
      final nextPage = _page + 1;
      final result = await data.api.searchMyDailySalesReports(
        search: _searchController.text.trim(),
        from: _dateRange != null ? _isoDate(_dateRange!.start) : null,
        to: _dateRange != null ? _isoDate(_dateRange!.end) : null,
        page: nextPage,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _reports = [..._reports, ...result.items];
        _total = result.total;
        _totalAmount = result.totalAmount;
        _page = nextPage;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat lebih banyak: $e')));
    }
  }

  String _formatDate(String isoDate) {
    final d = DateTime.tryParse(isoDate);
    if (d == null) return isoDate;
    return '${d.day}/${d.month}/${d.year}';
  }

  Future<void> _openForm() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CatatPenjualanKelilingScreen(brandId: widget.brandId)),
    );
    if (submitted == true) _loadFirstPage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Penjualan Saya', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.add), tooltip: 'Catat Penjualan', onPressed: _openForm),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: 'Cari catatan lokasi…',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDateRange,
                        icon: const Icon(Icons.date_range_outlined, size: 15),
                        label: Text(
                          _dateRange == null ? 'Filter Tanggal' : '${_formatDate(_isoDate(_dateRange!.start))} - ${_formatDate(_isoDate(_dateRange!.end))}',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (_dateRange != null) ...[
                      const SizedBox(width: 6),
                      IconButton(icon: const Icon(Icons.close, size: 18), tooltip: 'Hapus filter tanggal', onPressed: _clearDateRange),
                    ],
                  ],
                ),
                if (!_loading && _error == null) ...[
                  const SizedBox(height: 8),
                  NocturneCard(
                    borderColor: NocturneColors.accent800,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Penjualan ($_total transaksi)', style: TextStyle(fontSize: 12, color: NocturneColors.textMuted(0.6))),
                        Text(formatRp(_totalAmount), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingState()
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _loadFirstPage)
                    : _reports.isEmpty
                        ? const EmptyState(label: 'Belum ada penjualan tercatat.')
                        : RefreshIndicator(
                            onRefresh: _loadFirstPage,
                            child: ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                              itemCount: _reports.length + (_hasMore ? 1 : 0),
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                if (i >= _reports.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  );
                                }
                                final report = _reports[i];
                                return InkWell(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => PenjualanKelilingDetailScreen(report: report)),
                                  ),
                                  borderRadius: BorderRadius.circular(NocturneRadius.md),
                                  child: NocturneCard(
                                    child: Row(
                                      children: [
                                        if (report.photoUrl != null) ...[
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(report.photoUrl!, width: 40, height: 40, fit: BoxFit.cover),
                                          ),
                                          const SizedBox(width: 10),
                                        ],
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(report.outlet, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(Icons.calendar_today_outlined, size: 11, color: NocturneColors.textMuted(0.5)),
                                                  const SizedBox(width: 4),
                                                  Text(_formatDate(report.date), style: TextStyle(fontSize: 11.5, color: NocturneColors.textMuted(0.6))),
                                                  const SizedBox(width: 10),
                                                  Text('${report.items.length} produk', style: TextStyle(fontSize: 11.5, color: NocturneColors.textMuted(0.5))),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(formatRp(report.total), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
