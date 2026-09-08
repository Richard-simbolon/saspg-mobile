import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/activity_feed.dart';
import '../services/field_data_state.dart';
import '../services/location_service.dart';
import '../theme/nocturne_theme.dart';
import '../utils/format.dart';
import '../widgets/nocturne_card.dart';
import '../widgets/async_state.dart';
import '../widgets/activity_feed_list.dart';
import '../widgets/outlet_status_tag.dart';
import 'activity_history_screen.dart';
import 'checkin_screen.dart';
import 'checkout_screen.dart';
import 'outlet_detail_screen.dart';
import 'shell_navigation.dart';
import 'training_checkin_screen.dart';
import 'training_checkout_screen.dart';

const _leaveTypeLabel = {
  'tahunan': 'cuti tahunan',
  'sakit': 'sakit',
  'izin': 'izin',
  'lainnya': 'cuti',
};

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Position? _position;
  List<ActivityEvent> _recentActivity = [];
  bool _activityLoading = true;

  @override
  void initState() {
    super.initState();
    LocationService.tryGetPosition().then((p) {
      if (mounted) setState(() => _position = p);
    });
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    final data = context.read<FieldDataState>();
    try {
      // Started together (each call runs up to its first await immediately), awaited one by one for clean typing.
      final attendanceFuture = data.api.listAttendanceForSpg(data.spgId);
      final approvalsFuture = data.api.listApprovals(spgId: data.spgId);
      final leavesFuture = data.api.listMyLeaveRequests(data.spgId);
      final salesFuture = data.api.listDailySalesReports(spgId: data.spgId);
      final payslipsFuture = data.api.listMyPayslips();
      final visitSessionsFuture = data.api.listVisitSessions(spgId: data.spgId);

      final events = buildActivityEvents(
        attendance: await attendanceFuture,
        approvals: await approvalsFuture,
        leaves: await leavesFuture,
        salesReports: await salesFuture,
        payslips: await payslipsFuture,
        visitSessions: await visitSessionsFuture,
      );
      if (mounted) setState(() => _recentActivity = events);
    } catch (_) {
      // A failed activity fetch shouldn't block the rest of Beranda — just leave the section empty.
    } finally {
      if (mounted) setState(() => _activityLoading = false);
    }
  }

  double? _distanceTo(OutletLocation loc) {
    if (_position == null || loc.lat == null || loc.lng == null) return null;
    return Geolocator.distanceBetween(_position!.latitude, _position!.longitude, loc.lat!, loc.lng!);
  }

  Future<void> _handleCheckin(OutletLocation loc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NocturneColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NocturneRadius.lg)),
        title: const Text('Check-in', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
        content: Text('Apakah Anda ingin melanjutkan Check-in di ${loc.name}?', style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Lanjutkan')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final data = context.read<FieldDataState>();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CheckinScreen(location: loc)));
    if (mounted) data.refreshAttendance();
  }

  Future<void> _handleTrainingCheckin(TrainingSession training) async {
    final venue = training.venueName?.trim().isNotEmpty == true ? training.venueName! : training.topik;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NocturneColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NocturneRadius.lg)),
        title: const Text('Check-in Training', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
        content: Text('Apakah Anda ingin melanjutkan Check-in di $venue?', style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Lanjutkan')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final data = context.read<FieldDataState>();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrainingCheckinScreen(training: training)));
    if (mounted) data.refreshAttendance();
  }

  /// Check-out isn't tied to a specific store's detail page — the SPG picks
  /// wherever they currently are, since on a multi-store day that's often a
  /// different outlet than the one they checked in at this morning. On a
  /// full-day training day there's only ever one place to check out from —
  /// the training itself — so that path skips the picker entirely.
  Future<void> _handleCheckout(FieldDataState data) async {
    final attendance = data.todaysCheckin;
    if (attendance == null) return;

    if (attendance.trainingSessionId != null) {
      TrainingSession? training;
      for (final t in data.myTrainings) {
        if (t.id == attendance.trainingSessionId) {
          training = t;
          break;
        }
      }
      if (training == null) return;
      final resolvedTraining = training;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrainingCheckoutScreen(training: resolvedTraining, attendance: attendance)));
      if (mounted) data.refreshAttendance();
      return;
    }

    final chosen = await showModalBottomSheet<OutletLocation>(
      context: context,
      backgroundColor: NocturneColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(NocturneRadius.lg))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Anda sedang di toko mana?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ),
            ...data.myLocations.map(
              (loc) => ListTile(
                leading: Icon(Icons.storefront_outlined, color: NocturneColors.textMuted(0.6)),
                title: Text(loc.name, style: const TextStyle(fontSize: 13.5)),
                onTap: () => Navigator.of(sheetContext).pop(loc),
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CheckoutScreen(location: chosen, attendance: attendance)));
    if (mounted) data.refreshAttendance();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<FieldDataState>();

    if (data.loading) return const LoadingState();
    if (data.error != null) {
      return ErrorState(message: data.error!, onRetry: data.loadAll);
    }

    // Only outlets actually scheduled today are offered for check-in — matches the gate the
    // backend already enforces (`isScheduledOnPeriod`) and what OutletDetailScreen already shows
    // ("Anda tidak dijadwalkan bekerja di sini hari ini") for a store with no schedule today.
    final scheduledToday = data.myLocations.where((loc) => loc.isScheduledOn(data.spgId, DateTime.now())).toList();
    final preview = scheduledToday.take(3).toList();
    final todaysCheckin = data.todaysCheckin;
    final hasCheckedInToday = data.hasCheckedInToday;
    final dayComplete = todaysCheckin?.checkout != null;
    // Only an APPROVED leave request removes today's schedule — a pending
    // request needs no special handling (schedule stays as-is until decided),
    // and a rejected one goes right back to a normal work day.
    final todayLeave = data.leaveOn(DateTime.now());
    final onLeaveToday = todayLeave != null && todayLeave.status == 'approved';
    // Full day: no store schedule today, check-in happens at the training instead.
    // Half day: training just shows alongside the normal store schedule below.
    final todayTraining = data.todayTraining;
    final fullDayTraining = todayTraining != null && todayTraining.isFullDay;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([data.loadAll(), _loadActivity()]);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          NocturneCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CardKicker('Status Hari Ini'),
                          const SizedBox(height: 2),
                          Text(
                            dayComplete
                                ? 'Selesai hari ini'
                                : hasCheckedInToday
                                    ? 'Sedang berkunjung'
                                    : 'Belum check-in',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                          ),
                          if (todaysCheckin != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              dayComplete
                                  ? 'Check-in ${todaysCheckin.checkin} · Check-out ${todaysCheckin.checkout}'
                                  : 'Check-in ${todaysCheckin.checkin}',
                              style: TextStyle(fontSize: 11.5, color: NocturneColors.textMuted(0.6)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    NocturneTag(
                      dayComplete ? 'Selesai' : hasCheckedInToday ? 'Aktif' : 'Standby',
                      variant: dayComplete
                          ? TagVariant.neutral
                          : hasCheckedInToday
                              ? TagVariant.accent
                              : TagVariant.neutral,
                    ),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: NocturneDivider()),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        value: '${data.visitedTodayCount}/${scheduledToday.length}',
                        label: 'Toko dikunjungi',
                      ),
                    ),
                    Expanded(
                      child: _Stat(value: formatRp(data.todaySalesTotal), label: 'Penjualan hari ini'),
                    ),
                  ],
                ),
                if (hasCheckedInToday && !dayComplete) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton(
                      onPressed: () => _handleCheckout(data),
                      child: const Text('Check Out', style: TextStyle(fontSize: 12.5)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Jadwal Hari Ini', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              TextButton(onPressed: () => ShellNavigation.goToTab(context, 1), child: const Text('Lihat semua')),
            ],
          ),
          const SizedBox(height: 4),
          if (onLeaveToday)
            NocturneCard(
              borderColor: NocturneColors.accent2,
              child: Row(
                children: [
                  Icon(Icons.event_busy_outlined, size: 18, color: NocturneColors.accent2),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Anda sedang ${_leaveTypeLabel[todayLeave.type] ?? 'cuti'} hari ini — tidak ada jadwal.',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            )
          else if (fullDayTraining)
            _TrainingDayCard(
              training: todayTraining,
              todaysCheckin: todaysCheckin,
              onCheckin: () => _handleTrainingCheckin(todayTraining),
            )
          else ...[
            if (todayTraining != null) ...[
              _TrainingDayCard(
                training: todayTraining,
                todaysCheckin: todaysCheckin,
                onCheckin: null, // half day — check-in happens at a store below, not here
              ),
              const SizedBox(height: 8),
            ],
            if (preview.isEmpty)
              EmptyState(
                label: data.myLocations.isEmpty
                    ? 'Belum ada lokasi yang ditugaskan kepada Anda.'
                    : 'Tidak ada jadwal kunjungan toko hari ini.',
              )
            else
              ...preview.map((o) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: NocturneCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OutletDetailScreen(location: o))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(o.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 2),
                                Text(
                                  [if (o.category != null) o.category!, if (_distanceTo(o) != null) formatDistance(_distanceTo(o)!)]
                                      .join(' · '),
                                  style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.55)),
                                ),
                              ],
                            ),
                          ),
                          OutletStatusTag(data: data, location: o),
                        ],
                      ),
                      // Check-in only makes sense before the day's first check-in — once that's
                      // done, check-out is a single global action on the card above, not per outlet.
                      if (!hasCheckedInToday) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 36,
                          child: OutlinedButton(
                            onPressed: () => _handleCheckin(o),
                            child: const Text('Check In', style: TextStyle(fontSize: 12.5)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Aktivitas Terkini', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ActivityHistoryScreen())),
                child: const Text('Lihat Detail'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          NocturneCard(
            child: _activityLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                : ActivityFeedList(events: _recentActivity.take(5).toList()),
          ),
        ],
      ),
    );
  }
}

/// Full day: shows a Check-in Training button (until checked in, then just
/// status) and nothing else — this card stands in for the whole schedule.
/// Half day: purely informational, rendered above the normal store list.
class _TrainingDayCard extends StatelessWidget {
  const _TrainingDayCard({required this.training, required this.todaysCheckin, required this.onCheckin});
  final TrainingSession training;
  final AttendanceRecord? todaysCheckin;
  final VoidCallback? onCheckin;

  @override
  Widget build(BuildContext context) {
    final venue = training.venueName?.trim().isNotEmpty == true ? training.venueName! : training.topik;
    final checkedInHere = todaysCheckin != null && todaysCheckin!.trainingSessionId == training.id;
    final dayComplete = checkedInHere && todaysCheckin!.checkout != null;

    return NocturneCard(
      borderColor: NocturneColors.accent2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school_outlined, size: 18, color: NocturneColors.accent2),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(training.topik, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text('$venue · ${training.waktu}', style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.55))),
                  ],
                ),
              ),
              NocturneTag(
                training.isFullDay ? 'Full Day' : 'Half Day',
                variant: training.isFullDay ? TagVariant.accent : TagVariant.outline,
              ),
            ],
          ),
          if (onCheckin != null && !checkedInHere) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton(
                onPressed: onCheckin,
                child: const Text('Check-in Training', style: TextStyle(fontSize: 12.5)),
              ),
            ),
          ] else if (checkedInHere) ...[
            const SizedBox(height: 8),
            Text(
              dayComplete
                  ? 'Check-in ${todaysCheckin!.checkin} · Check-out ${todaysCheckin!.checkout}'
                  : 'Sedang training — check-in pukul ${todaysCheckin!.checkin}',
              style: TextStyle(fontSize: 11.5, color: NocturneColors.textMuted(0.6)),
            ),
          ] else if (onCheckin == null) ...[
            const SizedBox(height: 6),
            Text(
              'Half day — kunjungan toko tetap berjalan seperti biasa.',
              style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.55)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
        Text(label, style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.55))),
      ],
    );
  }
}
