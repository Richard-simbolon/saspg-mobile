import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/field_data_state.dart';
import '../theme/nocturne_theme.dart';
import '../utils/format.dart';
import '../widgets/nocturne_card.dart';

/// Read-only detail of one recorded sale — no edit/approval flow, this is just a settled
/// transaction record (unlike the pending-toko registration detail screen).
class PenjualanKelilingDetailScreen extends StatelessWidget {
  const PenjualanKelilingDetailScreen({super.key, required this.report});
  final DailySalesReport report;

  String _formatDate(String isoDate) {
    final d = DateTime.tryParse(isoDate);
    if (d == null) return isoDate;
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<FieldDataState>();
    final productById = {
      for (final b in data.myBrands) for (final p in b.products) p.id: p,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Penjualan', style: TextStyle(fontSize: 16))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 12, color: NocturneColors.textMuted(0.5)),
              const SizedBox(width: 6),
              Text(_formatDate(report.date), style: TextStyle(fontSize: 12.5, color: NocturneColors.textMuted(0.6))),
            ],
          ),
          const SizedBox(height: 4),
          Text(report.outlet, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          if (report.photoUrl != null) ...[
            const Text('Bukti Foto', style: TextStyle(fontSize: 12, color: Color(0x99E9E9ED))),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(NocturneRadius.md),
              child: Image.network(report.photoUrl!, width: double.infinity, height: 200, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
          ],
          if (report.lat != null && report.lng != null) ...[
            NocturneCard(
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: NocturneColors.textMuted(0.6)),
                  const SizedBox(width: 8),
                  Text(
                    'Titik GPS: ${report.lat!.toStringAsFixed(5)}, ${report.lng!.toStringAsFixed(5)}',
                    style: TextStyle(fontSize: 12.5, color: NocturneColors.textMuted(0.7)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          const Text('Produk Terjual', style: TextStyle(fontSize: 12, color: Color(0x99E9E9ED))),
          const SizedBox(height: 8),
          ...report.items.map((item) {
            final product = productById[item.productId];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NocturneCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product?.name ?? 'Produk #${item.productId}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text('${item.qty} × ${formatRp(item.unitPrice)}', style: TextStyle(fontSize: 11.5, color: NocturneColors.textMuted(0.55))),
                        ],
                      ),
                    ),
                    Text(formatRp(item.lineTotal), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          NocturneCard(
            borderColor: NocturneColors.accent800,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Penjualan', style: TextStyle(fontSize: 13, color: NocturneColors.textMuted(0.6))),
                Text(formatRp(report.total), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
