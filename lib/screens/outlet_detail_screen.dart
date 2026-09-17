import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/field_data_state.dart';
import '../theme/nocturne_theme.dart';
import '../utils/image_provider.dart';
import '../widgets/nocturne_card.dart';
import '../widgets/activity_log_section.dart';
import 'laporan_screen.dart';
import 'foto_screen.dart';
import 'penjualan_screen.dart';
import 'competitor_activity_screen.dart';

class OutletDetailScreen extends StatefulWidget {
  const OutletDetailScreen({super.key, required this.location});
  final OutletLocation location;

  @override
  State<OutletDetailScreen> createState() => _OutletDetailScreenState();
}

class _OutletDetailScreenState extends State<OutletDetailScreen> {
  Future<void> _refresh() async {
    await context.read<FieldDataState>().loadAll();
  }

  /// Prompts to Check In right from an activity step, instead of leaving the
  /// SPG to scroll down and tap the Check In row themselves first — lets them
  /// start the visit session directly from this dialog and carry straight on.
  Future<bool> _confirmCheckIn(OutletLocation loc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NocturneColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NocturneRadius.lg)),
        title: const Text('Belum Check In', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
        content: Text(
          'Anda perlu Check In di ${loc.name} dulu sebelum mengisi laporan kunjungan.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Check In')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;

    final data = context.read<FieldDataState>();
    try {
      await data.api.startVisitSession(spgId: data.spgId, brandId: loc.brandId, outlet: loc.name);
      await _refresh();
      return true;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      return false;
    }
  }

  void _showHistory(AttendanceRecord attendance) {
    ImageProvider? selfie(String? uri) => resolveImageProvider(uri);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NocturneColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NocturneRadius.lg)),
        title: const Text('Riwayat Absensi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HistoryRow(label: 'Absen Masuk (${attendance.outlet})', time: attendance.checkin, image: selfie(attendance.checkinSelfieUrl)),
            const SizedBox(height: 12),
            _HistoryRow(label: 'Absen Pulang', time: attendance.checkout, image: selfie(attendance.checkoutSelfieUrl)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Tutup')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<FieldDataState>();
    final loc = widget.location;
    final myShift = loc.shiftFor(data.spgId);
    final scheduledToday = loc.isScheduledOn(data.spgId, DateTime.now());
    final myOutletAttendance = data.attendanceFor(loc);
    final todaysCheckin = data.todaysCheckin;
    final approval = data.approvalFor(loc);
    final laporanDone = approval != null;
    final fotoDone = approval?.photoUrls?.isNotEmpty ?? false;
    final penjualanDone = data.hasSalesReportToday(loc);
    final competitorDone = data.hasCompetitorActivityToday(loc);
    final visitSession = data.visitSessionFor(loc);
    final canEndVisit = laporanDone && fotoDone && penjualanDone;
    // Absen Masuk (attendance) is what unlocks the Check In row below — a rep
    // visiting several stores absens once, at the first store; a full-day
    // training overrides all of that, since no store visit is expected that day.
    final canStartVisit = data.hasCheckedInToday && !data.isFullDayTrainingToday;
    // But filling out the actual activities needs more than just Absen Masuk —
    // the SPG must have Check In'd at THIS specific store, or the report would
    // have nothing to attach to. Tapping a step before that prompts to Check In
    // right there (see _confirmCheckIn) instead of just sitting disabled.
    final canDoActivities = visitSession != null && visitSession.isOngoing;

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Kunjungan', style: TextStyle(fontSize: 16))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          NocturneCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (loc.category != null) CardKicker(loc.category!),
                const SizedBox(height: 2),
                Text(loc.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
                if (loc.address != null) ...[
                  const SizedBox(height: 2),
                  Text(loc.address!, style: TextStyle(fontSize: 13, color: NocturneColors.textMuted(0.8))),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.storefront_outlined, size: 12, color: NocturneColors.textMuted(0.5)),
                    const SizedBox(width: 4),
                    Text(loc.brandName, style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.5))),
                  ],
                ),
                if (myShift != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule_outlined, size: 12, color: NocturneColors.accent),
                      const SizedBox(width: 4),
                      Text(
                        '${myShift.name} · ${myShift.startTime}-${myShift.endTime}',
                        style: TextStyle(fontSize: 11, color: NocturneColors.accent, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _AttendanceRow(
            location: loc,
            myOutletAttendance: myOutletAttendance,
            todaysCheckin: todaysCheckin,
            scheduledToday: scheduledToday,
            onShowHistory: () => _showHistory(todaysCheckin!),
          ),
          const SizedBox(height: 8),
          _StepRow(
            icon: Icons.assignment_outlined,
            label: 'Laporan Kunjungan',
            done: laporanDone,
            enabled: canDoActivities,
            onTap: () async {
              if (!canDoActivities) {
                final started = await _confirmCheckIn(loc);
                if (!started || !mounted) return;
              }
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => LaporanScreen(location: loc)));
              _refresh();
            },
          ),
          const SizedBox(height: 8),
          _StepRow(
            icon: Icons.camera_alt_outlined,
            label: 'Foto Bukti Display',
            done: fotoDone,
            enabled: canDoActivities,
            onTap: () async {
              if (!canDoActivities) {
                final started = await _confirmCheckIn(loc);
                if (!started || !mounted) return;
              }
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => FotoScreen(location: loc, existingApprovalId: approval?.id)),
              );
              _refresh();
            },
          ),
          const SizedBox(height: 8),
          _StepRow(
            icon: Icons.point_of_sale_outlined,
            label: 'Input Penjualan',
            done: penjualanDone,
            enabled: canDoActivities,
            onTap: () async {
              if (!canDoActivities) {
                final started = await _confirmCheckIn(loc);
                if (!started || !mounted) return;
              }
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PenjualanScreen(location: loc)));
              _refresh();
            },
          ),
          const SizedBox(height: 8),
          _StepRow(
            icon: Icons.groups_outlined,
            label: 'Aktivitas Kompetitor',
            done: competitorDone,
            enabled: canDoActivities,
            onTap: () async {
              if (!canDoActivities) {
                final started = await _confirmCheckIn(loc);
                if (!started || !mounted) return;
              }
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CompetitorActivityScreen(location: loc)),
              );
              _refresh();
            },
          ),
          if (canDoActivities) ...[
            const SizedBox(height: 18),
            ActivityLogSection(brandId: loc.brandId, outlet: loc.name),
          ],
          const SizedBox(height: 20),
          const NocturneDivider(),
          const SizedBox(height: 16),
          _VisitSessionRow(
            location: loc,
            session: visitSession,
            canStart: canStartVisit,
            canEnd: canEndVisit,
            onChanged: _refresh,
          ),
        ],
      ),
    );
  }
}

/// Check-in happens once per day (the first store) and decides "telat"; every
/// later stop in the day skips straight to a free/flexible check-out — this
/// row has to represent both "I'm at my first store" and "I'm at a later
/// store, already checked in elsewhere" without conflating the two.
class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({
    required this.location,
    required this.myOutletAttendance,
    required this.todaysCheckin,
    required this.scheduledToday,
    required this.onShowHistory,
  });

  final OutletLocation location;
  /// This specific outlet's attendance row — only non-null if THIS is the store the SPG checked in at today.
  final AttendanceRecord? myOutletAttendance;
  /// The one attendance record for today, at whichever store the SPG checked in at (any outlet).
  final AttendanceRecord? todaysCheckin;
  final bool scheduledToday;
  final VoidCallback onShowHistory;

  @override
  Widget build(BuildContext context) {
    final checkedInHere = myOutletAttendance?.checkin != null;
    final checkedOut = todaysCheckin?.checkout != null;

    if (checkedInHere && checkedOut) {
      return NocturneCard(
        borderColor: NocturneColors.accent800,
        onTap: onShowHistory,
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 18, color: NocturneColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Kunjungan Selesai', style: TextStyle(fontSize: 13.5)),
                  Text(
                    'Absen Masuk ${todaysCheckin!.checkin} · Absen Pulang ${todaysCheckin!.checkout}',
                    style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.55)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: NocturneColors.textMuted(0.4)),
          ],
        ),
      );
    }

    if (checkedInHere) {
      // Check-out lives on Beranda, not here — it's a single global action that
      // doesn't belong to any one store's detail page on a multi-store day.
      return NocturneCard(
        child: Row(
          children: [
            Icon(Icons.meeting_room_outlined, size: 18, color: NocturneColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sedang Berkunjung', style: TextStyle(fontSize: 13.5)),
                  Text(
                    'Absen masuk pukul ${todaysCheckin!.checkin} — absen pulang dari halaman Beranda.',
                    style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.55)),
                  ),
                ],
              ),
            ),
            const NocturneTag('Berlangsung', variant: TagVariant.outline),
          ],
        ),
      );
    }

    // Checked in at a DIFFERENT outlet today — no check-in needed here, just
    // a flexible check-out option (or nothing further, if the day's already closed).
    if (todaysCheckin != null) {
      if (checkedOut) {
        return NocturneCard(
          borderColor: NocturneColors.accent800,
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, size: 18, color: NocturneColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Hari kerja selesai — absen masuk di ${todaysCheckin!.outlet}, absen pulang ${todaysCheckin!.checkout}.',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
        );
      }
      return NocturneCard(
        child: Row(
          children: [
            Icon(Icons.meeting_room_outlined, size: 18, color: NocturneColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Belum Absen Pulang', style: TextStyle(fontSize: 13.5)),
                  Text(
                    'Sudah absen masuk pukul ${todaysCheckin!.checkin} di ${todaysCheckin!.outlet} — absen pulang dari halaman Beranda.',
                    style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.55)),
                  ),
                ],
              ),
            ),
            const NocturneTag('Berlangsung', variant: TagVariant.outline),
          ],
        ),
      );
    }

    if (!scheduledToday) {
      return Opacity(
        opacity: 0.5,
        child: NocturneCard(
          child: Row(
            children: [
              Icon(Icons.event_busy_outlined, size: 18, color: NocturneColors.textMuted(0.6)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Anda tidak dijadwalkan bekerja di sini hari ini', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      );
    }

    // Check-in itself now only happens from Beranda — this page has nothing to
    // trigger here, just the fact that it hasn't happened yet.
    return NocturneCard(
      child: Row(
        children: [
          Icon(Icons.fingerprint, size: 18, color: NocturneColors.textMuted(0.6)),
          const SizedBox(width: 10),
          const Expanded(child: Text('Belum absen — absen masuk dari halaman Beranda.', style: TextStyle(fontSize: 13))),
          const NocturneTag('Belum', variant: TagVariant.neutral),
        ],
      ),
    );
  }
}

/// "Mulai Kunjungan" opens a work session at this specific outlet; "Akhiri
/// Kunjungan" closes it, but only once the required activities (laporan,
/// foto, penjualan) are actually submitted — the backend enforces the same
/// gate, this is just what keeps the button visibly disabled until then.
class _VisitSessionRow extends StatefulWidget {
  const _VisitSessionRow({
    required this.location,
    required this.session,
    required this.canStart,
    required this.canEnd,
    required this.onChanged,
  });

  final OutletLocation location;
  final VisitSession? session;
  final bool canStart;
  final bool canEnd;
  final Future<void> Function() onChanged;

  @override
  State<_VisitSessionRow> createState() => _VisitSessionRowState();
}

class _VisitSessionRowState extends State<_VisitSessionRow> {
  bool _submitting = false;

  Future<void> _start() async {
    final data = context.read<FieldDataState>();
    setState(() => _submitting = true);
    try {
      await data.api.startVisitSession(spgId: data.spgId, brandId: widget.location.brandId, outlet: widget.location.name);
      await widget.onChanged();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _end() async {
    final data = context.read<FieldDataState>();
    setState(() => _submitting = true);
    try {
      await data.api.endVisitSession(widget.session!.id);
      await widget.onChanged();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;

    if (session != null && !session.isOngoing) {
      return NocturneCard(
        borderColor: NocturneColors.accent800,
        child: Row(
          children: [
            Icon(Icons.event_available_outlined, size: 18, color: NocturneColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Check Out pukul ${session.endTime} (${session.durationMinutes ?? 0} menit)',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ),
      );
    }

    if (session != null) {
      return Opacity(
        opacity: widget.canEnd ? 1 : 0.6,
        child: NocturneCard(
          onTap: (widget.canEnd && !_submitting) ? _end : null,
          child: Row(
            children: [
              Icon(Icons.flag_outlined, size: 18, color: NocturneColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Check Out', style: TextStyle(fontSize: 13.5)),
                    Text(
                      widget.canEnd
                          ? 'Dimulai pukul ${session.startTime}'
                          : 'Lengkapi laporan, foto, dan penjualan dulu',
                      style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.55)),
                    ),
                  ],
                ),
              ),
              if (_submitting)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
      );
    }

    return Opacity(
      opacity: widget.canStart ? 1 : 0.5,
      child: NocturneCard(
        onTap: (widget.canStart && !_submitting) ? _start : null,
        child: Row(
          children: [
            Icon(Icons.play_circle_outline, size: 18, color: NocturneColors.accent),
            const SizedBox(width: 10),
            const Expanded(child: Text('Check In', style: TextStyle(fontSize: 13.5))),
            if (_submitting)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else
              const NocturneTag('Belum', variant: TagVariant.neutral),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.label, required this.time, required this.image});
  final String label;
  final String? time;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: NocturneColors.bg,
            image: image == null ? null : DecorationImage(image: image!, fit: BoxFit.cover),
          ),
          child: image == null ? Icon(Icons.person_outline, size: 18, color: NocturneColors.textMuted(0.4)) : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.55))),
              Text(time ?? '-', style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.icon,
    required this.label,
    required this.done,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool done;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: NocturneCard(
        // Always tappable, even while dimmed — tapping before Check In prompts
        // to Check In right there (see _confirmCheckIn) instead of doing nothing.
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 18, color: NocturneColors.accent),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5))),
            NocturneTag(done ? 'Selesai' : 'Belum', variant: done ? TagVariant.accent : TagVariant.neutral),
          ],
        ),
      ),
    );
  }
}
