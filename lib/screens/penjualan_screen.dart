import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/auth_state.dart';
import '../services/field_data_state.dart';
import '../services/location_service.dart';
import '../services/wifi_service.dart';
import '../theme/nocturne_theme.dart';
import '../utils/format.dart';
import '../widgets/location_error_card.dart';
import '../widgets/nocturne_card.dart';

class PenjualanScreen extends StatefulWidget {
  const PenjualanScreen({super.key, required this.location});
  final OutletLocation location;

  @override
  State<PenjualanScreen> createState() => _PenjualanScreenState();
}

class _PenjualanScreenState extends State<PenjualanScreen> {
  final Map<int, int> _qty = {};
  bool _submitting = false;
  Object? _error;

  num _total(List<Product> products) =>
      products.fold<num>(0, (sum, p) => sum + (p.price * (_qty[p.id] ?? 0)));

  Future<void> _submit(List<Product> products) async {
    final items = products
        .where((p) => (_qty[p.id] ?? 0) > 0)
        .map((p) => {'productId': p.id, 'qty': _qty[p.id]!})
        .toList();
    if (items.isEmpty) return;

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

      final today = DateTime.now().toIso8601String().substring(0, 10);
      await data.api.createDailySalesReport(
        spgId: auth.user!.spgId!,
        brandId: widget.location.brandId,
        outlet: widget.location.name,
        date: today,
        items: items,
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

  @override
  Widget build(BuildContext context) {
    final data = context.watch<FieldDataState>();
    final products = data.brandById(widget.location.brandId)?.products ?? const <Product>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Input Penjualan', style: TextStyle(fontSize: 16))),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              children: products
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: NocturneCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 2),
                                  Text('${formatRp(p.price)} / bungkus', style: TextStyle(fontSize: 11.5, color: NocturneColors.textMuted(0.55))),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                _QtyButton(
                                  icon: Icons.remove,
                                  onTap: () => setState(() => _qty[p.id] = ((_qty[p.id] ?? 0) - 1).clamp(0, 9999)),
                                ),
                                SizedBox(
                                  width: 28,
                                  child: Text('${_qty[p.id] ?? 0}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
                                ),
                                _QtyButton(icon: Icons.add, onTap: () => setState(() => _qty[p.id] = (_qty[p.id] ?? 0) + 1)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: NocturneColors.divider))),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Penjualan', style: TextStyle(fontSize: 13, color: NocturneColors.textMuted(0.6))),
                    Text(formatRp(_total(products)), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                  ],
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
                        : const Text('Kirim Data Penjualan'),
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

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: NocturneColors.divider), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 13),
      ),
    );
  }
}
