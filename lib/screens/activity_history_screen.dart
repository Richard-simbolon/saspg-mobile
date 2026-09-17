import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/activity_feed.dart';
import '../services/field_data_state.dart';
import '../widgets/async_state.dart';
import '../widgets/activity_feed_list.dart';

const _pageSize = 10;

/// Full history behind the Beranda "Aktivitas Terkini" preview — every
/// check-in, laporan kunjungan, cuti, penjualan, and gaji event for this SPG.
/// Fetched all at once (a handful of small per-SPG lists merged client-side),
/// but only 10 are rendered at a time — "Muat Lebih Banyak" reveals another
/// page from what's already in memory rather than refetching.
class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<ActivityEvent> _events = [];
  int _visibleCount = _pageSize;

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
    try {
      final data = context.read<FieldDataState>();
      // Kicked off together (each call starts running up to its first await
      // immediately), then awaited one by one for clean per-type results.
      final attendanceFuture = data.api.listAttendanceForSpg(data.spgId);
      final approvalsFuture = data.api.listApprovals(spgId: data.spgId);
      final leavesFuture = data.api.listMyLeaveRequests(data.spgId);
      final salesFuture = data.api.listDailySalesReports(spgId: data.spgId);
      final payslipsFuture = data.api.listMyPayslips();
      final visitSessionsFuture = data.api.listVisitSessions(spgId: data.spgId);
      final locationRegistrationsFuture = data.api.searchMyLocationRegistrations(pageSize: 100);

      final events = buildActivityEvents(
        attendance: await attendanceFuture,
        approvals: await approvalsFuture,
        leaves: await leavesFuture,
        salesReports: await salesFuture,
        payslips: await payslipsFuture,
        visitSessions: await visitSessionsFuture,
        locationRegistrations: (await locationRegistrationsFuture).items,
      );
      if (!mounted) return;
      setState(() {
        _events = events;
        _visibleCount = _pageSize;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aktivitas', style: TextStyle(fontSize: 16))),
      body: _loading
          ? const LoadingState()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                    children: [
                      ActivityFeedList(events: _events.take(_visibleCount).toList()),
                      if (_visibleCount < _events.length) ...[
                        const SizedBox(height: 4),
                        Center(
                          child: TextButton(
                            onPressed: () => setState(
                              () => _visibleCount = (_visibleCount + _pageSize).clamp(0, _events.length),
                            ),
                            child: const Text('Muat Lebih Banyak'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
