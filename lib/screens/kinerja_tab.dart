import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_state.dart';
import '../services/field_data_state.dart';
import '../theme/nocturne_theme.dart';
import '../utils/format.dart';
import '../widgets/async_state.dart';
import '../widgets/nocturne_card.dart';

class KinerjaTab extends StatefulWidget {
  const KinerjaTab({super.key});

  @override
  State<KinerjaTab> createState() => _KinerjaTabState();
}

class _KinerjaTabState extends State<KinerjaTab> {
  bool _loadingExtra = true;
  bool _extraRequested = false;
  int? _rank;
  int? _teamSize;
  List<int> _weeklyVisits = List.filled(6, 0);
  int? _avgDurationMinutes;

  Future<void> _loadExtra() async {
    final auth = context.read<AuthState>();
    final data = context.read<FieldDataState>();
    final spgId = auth.user!.spgId!;
    try {
      // "Peringkat di Tim" means ranked against teammates — GET /spg returns every SPG
      // system-wide (used for admin lists elsewhere), so it must be narrowed down to just
      // the brand(s) this SPG is actually assigned to before ranking/sizing the team.
      final allSpg = await auth.api.listSpg();
      final myBrandIds = data.myBrands.map((b) => b.id).toSet();
      final team = allSpg.where((s) => myBrandIds.contains(s.brandId)).toList();
      final sorted = [...team]..sort((a, b) => b.achievementPct.compareTo(a.achievementPct));
      final rank = sorted.indexWhere((s) => s.id == spgId) + 1;

      final rows = <Map<String, dynamic>>[];
      for (final b in data.myBrands) {
        rows.addAll(await auth.api.listAttendance(brandId: b.id));
      }
      final mine = rows.where((a) => a['spgId'] == spgId).toList();

      final durations = mine.map((a) => a['durationMinutes']).whereType<int>().toList();
      final avgDuration = durations.isEmpty ? null : durations.reduce((a, b) => a + b) ~/ durations.length;

      final now = DateTime.now();
      final buckets = List.filled(6, 0);
      for (final a in mine) {
        if (a['checkin'] == null) continue;
        final date = DateTime.tryParse(a['date'] as String? ?? '');
        if (date == null) continue;
        final diffDays = now.difference(date).inDays;
        if (diffDays < 0 || diffDays >= 42) continue;
        final bucketIndex = 5 - (diffDays ~/ 7);
        buckets[bucketIndex]++;
      }

      if (!mounted) return;
      setState(() {
        _rank = rank > 0 ? rank : null;
        _teamSize = sorted.length;
        _avgDurationMinutes = avgDuration;
        _weeklyVisits = buckets;
        _loadingExtra = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingExtra = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final data = context.watch<FieldDataState>();
    final spg = auth.spgProfile;

    if (data.loading || spg == null) return const LoadingState();
    if (data.error != null) return ErrorState(message: data.error!, onRetry: data.loadAll);

    // `data.myBrands` is only guaranteed populated once `loading` flips to false — requesting
    // this any earlier (e.g. from initState, before FieldDataState.loadAll() finishes) would
    // race ahead of it and permanently leave rank/average/trend blank for the rest of the
    // session, since `_loadExtra()` never gets called again. Safe to request here every build:
    // `_extraRequested` makes it fire exactly once.
    if (!_extraRequested) {
      _extraRequested = true;
      _loadExtra();
    }

    final maxVisit = _weeklyVisits.isEmpty ? 1 : _weeklyVisits.reduce((a, b) => a > b ? a : b).clamp(1, 999);

    return RefreshIndicator(
      onRefresh: () async {
        await data.loadAll();
        await auth.refreshSpgProfile();
        await _loadExtra();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          NocturneCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CardKicker('Target vs Realisasi — Bulan Ini'),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(formatRp(spg.realisasi), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Text('/ ${formatRp(spg.target)}', style: TextStyle(fontSize: 12, color: NocturneColors.textMuted(0.5))),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (spg.achievementPct / 100).clamp(0, 1).toDouble(),
                    minHeight: 6,
                    backgroundColor: NocturneColors.neutral900,
                    valueColor: AlwaysStoppedAnimation(NocturneColors.accent),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${spg.achievementPct}% pencapaian · ${data.visitedTodayCount}/${data.myLocations.length} kunjungan hari ini',
                  style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.1,
            children: [
              _MetricCard(label: 'Kehadiran Bulan Ini', value: '${spg.attendanceRate}%'),
              _MetricCard(label: 'Peringkat di Tim', value: _rank != null ? '$_rank dari $_teamSize' : '-'),
              _MetricCard(
                label: 'Rata-rata / Kunjungan',
                value: _avgDurationMinutes != null ? '$_avgDurationMinutes mnt' : '-',
              ),
              _MetricCard(label: 'Training Selesai', value: '${spg.trainingCompleted}/${spg.trainingTotal}'),
            ],
          ),
          const SizedBox(height: 10),
          NocturneCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CardKicker('Tren Kunjungan 6 Minggu Terakhir'),
                const SizedBox(height: 10),
                if (_loadingExtra)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LoadingState())
                else
                  SizedBox(
                    height: 70,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(_weeklyVisits.length, (i) {
                        final v = _weeklyVisits[i];
                        final pct = v / maxVisit;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                FractionallySizedBox(
                                  heightFactor: pct.clamp(0.03, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: NocturneColors.accent,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text('M${i + 1}', style: TextStyle(fontSize: 9.5, color: NocturneColors.textMuted(0.5))),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          NocturneCard(
            borderColor: NocturneColors.accent800,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CardKicker('Estimasi Insentif Bulan Ini'),
                const SizedBox(height: 2),
                Text(formatRp(spg.incentive), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  'Dihitung otomatis dari pencapaian target penjualan & kehadiran',
                  style: TextStyle(fontSize: 12, color: NocturneColors.textMuted(0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return NocturneCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CardKicker(label),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
