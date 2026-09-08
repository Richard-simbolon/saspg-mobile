import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/auth_state.dart';
import '../services/field_data_state.dart';
import '../services/location_service.dart';
import '../services/wifi_service.dart';
import '../theme/nocturne_theme.dart';
import '../widgets/location_error_card.dart';

typedef _StockRef = ({int value, String date});

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key, required this.location});
  final OutletLocation location;

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Map<int, TextEditingController> _openCtrls = {};
  final Map<int, TextEditingController> _closeCtrls = {};
  final _kendalaCtrl = TextEditingController();

  bool _loading = true;
  final Map<int, StockCheck> _todayByProduct = {};
  final Map<int, _StockRef> _latestOpen = {};
  final Map<int, _StockRef> _latestClose = {};

  bool _submitting = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _openCtrls.values) {
      c.dispose();
    }
    for (final c in _closeCtrls.values) {
      c.dispose();
    }
    _kendalaCtrl.dispose();
    super.dispose();
  }

  TextEditingController _openFor(int productId) => _openCtrls.putIfAbsent(productId, () => TextEditingController());
  TextEditingController _closeFor(int productId) => _closeCtrls.putIfAbsent(productId, () => TextEditingController());

  Future<void> _loadHistory() async {
    final auth = context.read<AuthState>();
    final data = context.read<FieldDataState>();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final checks = await data.api.listStockChecks(
        spgId: auth.user!.spgId!,
        brandId: widget.location.brandId,
        outlet: widget.location.name,
      );
      for (final c in checks) {
        if (c.date == today) {
          _todayByProduct.putIfAbsent(c.productId, () => c);
          continue;
        }
        if (c.stockOpen != null && !_latestOpen.containsKey(c.productId)) {
          _latestOpen[c.productId] = (value: c.stockOpen!, date: c.date);
        }
        if (c.stockClose != null && !_latestClose.containsKey(c.productId)) {
          _latestClose[c.productId] = (value: c.stockClose!, date: c.date);
        }
      }
      for (final entry in _todayByProduct.entries) {
        if (entry.value.stockOpen != null) _openFor(entry.key).text = '${entry.value.stockOpen}';
        if (entry.value.stockClose != null) _closeFor(entry.key).text = '${entry.value.stockClose}';
      }
    } catch (_) {
      // non-fatal — riwayat hanya referensi, laporan tetap bisa diisi tanpa itu
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit(List<Product> products) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final auth = context.read<AuthState>();
    final data = context.read<FieldDataState>();

    try {
      // Proves the SPG is actually at THIS outlet right now — required for later
      // stops in a multi-store day, which don't get their own check-in.
      final position = await LocationService.getPosition();
      final wifiSsid = await WifiService.currentSsid();

      for (final p in products) {
        final openText = _openCtrls[p.id]?.text.trim() ?? '';
        final closeText = _closeCtrls[p.id]?.text.trim() ?? '';
        final openVal = openText.isEmpty ? null : int.tryParse(openText);
        final closeVal = closeText.isEmpty ? null : int.tryParse(closeText);
        final existing = _todayByProduct[p.id];
        final openChanged = openVal != null && openVal != existing?.stockOpen;
        final closeChanged = closeVal != null && closeVal != existing?.stockClose;
        if (openChanged || closeChanged) {
          await data.api.upsertStockCheck(
            spgId: auth.user!.spgId!,
            brandId: widget.location.brandId,
            outlet: widget.location.name,
            productId: p.id,
            stockOpen: openChanged ? openVal : null,
            stockClose: closeChanged ? closeVal : null,
          );
        }
      }

      final kendala = _kendalaCtrl.text.trim();
      await data.api.createApproval(
        spgId: auth.user!.spgId!,
        brandId: widget.location.brandId,
        outlet: widget.location.name,
        note: kendala.isEmpty ? 'Laporan kunjungan.' : 'Kendala: $kendala',
        lat: position.latitude,
        lng: position.longitude,
        wifiSsid: wifiSsid,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Map<int, int> _soldToday(FieldDataState data) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final sold = <int, int>{};
    for (final r in data.mySalesReports) {
      if (r.outlet != widget.location.name || r.date != today) continue;
      for (final item in r.items) {
        sold[item.productId] = (sold[item.productId] ?? 0) + item.qty;
      }
    }
    return sold;
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<FieldDataState>();
    final products = data.brandById(widget.location.brandId)?.products ?? const <Product>[];
    final soldToday = _soldToday(data);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Kunjungan', style: TextStyle(fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: NocturneColors.accent,
          unselectedLabelColor: NocturneColors.textMuted(0.55),
          indicatorColor: NocturneColors.accent,
          tabs: const [Tab(text: 'Stok Buka'), Tab(text: 'Stok Tutup')],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _StockList(
                        products: products,
                        controllerFor: _openFor,
                        referenceFor: _latestOpen,
                        hint: 'Stok saat buka',
                      ),
                      _StockList(
                        products: products,
                        controllerFor: _closeFor,
                        referenceFor: _latestClose,
                        hint: 'Stok saat tutup',
                        soldToday: soldToday,
                        stockOpenFor: (productId) => _todayByProduct[productId]?.stockOpen,
                      ),
                    ],
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: NocturneColors.divider))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kendala di Lapangan', style: TextStyle(fontSize: 12, color: Color(0x99E9E9ED))),
                const SizedBox(height: 6),
                TextField(
                  controller: _kendalaCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'mis. rak kosong, banner rusak...', isDense: true),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  _error is LocationFailure
                      ? LocationErrorCard(failure: _error as LocationFailure, onRetry: () => _submit(products))
                      : Text(_error.toString(), style: TextStyle(color: NocturneColors.danger, fontSize: 12.5)),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : () => _submit(products),
                    child: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Kirim Laporan'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StockList extends StatelessWidget {
  const _StockList({
    required this.products,
    required this.controllerFor,
    required this.referenceFor,
    required this.hint,
    this.soldToday,
    this.stockOpenFor,
  });
  final List<Product> products;
  final TextEditingController Function(int) controllerFor;
  final Map<int, _StockRef> referenceFor;
  final String hint;
  /// Non-null only for the "Stok Tutup" tab — qty already terjual hari ini per produk, dari Input
  /// Penjualan. Kalau > 0, sisa stok dihitung otomatis (stok buka − terjual) dan field dikunci.
  final Map<int, int>? soldToday;
  final int? Function(int)? stockOpenFor;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Text('Belum ada produk untuk brand ini.', style: TextStyle(fontSize: 12.5, color: NocturneColors.textMuted(0.5))),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      itemCount: products.length,
      itemBuilder: (context, i) {
        final p = products[i];
        final ref = referenceFor[p.id];
        final sold = soldToday?[p.id] ?? 0;
        final stockOpen = stockOpenFor?.call(p.id);
        final locked = soldToday != null && sold > 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                      locked
                          ? (stockOpen != null
                              ? 'Otomatis: stok buka $stockOpen − terjual $sold'
                              : 'Terjual $sold — isi & kirim Stok Buka dulu agar sisa stok terhitung')
                          : (ref != null ? 'Terakhir: ${ref.value} (${ref.date})' : 'Belum ada riwayat'),
                      style: TextStyle(fontSize: 10.5, color: NocturneColors.textMuted(0.45)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (locked)
                SizedBox(
                  width: 100,
                  height: 36,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: NocturneColors.divider),
                      borderRadius: BorderRadius.circular(8),
                      color: NocturneColors.textMuted(0.06),
                    ),
                    child: Text(
                      stockOpen != null ? '${stockOpen - sold}' : '—',
                      style: TextStyle(fontSize: 13, color: NocturneColors.textMuted(0.7)),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: 100,
                  height: 36,
                  child: TextField(
                    controller: controllerFor(p.id),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(hintText: hint, isDense: true),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
