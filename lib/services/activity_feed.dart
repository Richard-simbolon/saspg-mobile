import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/nocturne_theme.dart';
import '../utils/format.dart';
import '../widgets/nocturne_card.dart';

const _leaveTypeLabel = {'tahunan': 'Cuti Tahunan', 'sakit': 'Sakit', 'izin': 'Izin', 'lainnya': 'Lainnya'};
const _approvalStatusLabel = {'pending': 'Menunggu', 'approved': 'Disetujui', 'rejected': 'Ditolak'};
const _leaveStatusLabel = {'pending': 'Menunggu', 'approved': 'Disetujui', 'rejected': 'Ditolak'};
const _locationRegistrationStatusLabel = {'pending': 'Menunggu', 'approved': 'Disetujui', 'rejected': 'Ditolak'};

String _periodLabel(String period) {
  const months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];
  final parts = period.split('-');
  final month = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
  return '${months[(month - 1).clamp(0, 11)]} ${parts[0]}';
}

/// One row in the merged "Aktivitas" feed — check-ins, laporan kunjungan,
/// cuti, and payroll events, all normalized to one timeline shape.
class ActivityEvent {
  ActivityEvent({
    required this.id,
    required this.date,
    required this.color,
    required this.title,
    required this.description,
    this.badgeLabel,
    this.badgeVariant,
  });

  final String id;
  final DateTime date;
  final Color color;
  final String title;
  final String description;
  final String? badgeLabel;
  final TagVariant? badgeVariant;
}

/// Merges every dated record this SPG has into one chronological feed, newest first.
List<ActivityEvent> buildActivityEvents({
  required List<AttendanceRecord> attendance,
  required List<ApprovalReport> approvals,
  required List<LeaveRequest> leaves,
  required List<DailySalesReport> salesReports,
  required List<Payslip> payslips,
  List<VisitSession> visitSessions = const [],
  List<LocationRegistrationRequest> locationRegistrations = const [],
}) {
  final events = <ActivityEvent>[];

  for (final a in attendance) {
    if (a.checkin != null) {
      final late = a.status == 'telat';
      final color = a.status == 'ok'
          ? NocturneColors.accent
          : a.status == 'telat'
              ? const Color(0xFFE0B96A)
              : a.status == 'nocheckout'
                  ? const Color(0xFFC9784F)
                  : NocturneColors.danger;
      events.add(ActivityEvent(
        id: 'att-${a.id}',
        date: DateTime.tryParse('${a.date}T${a.checkin}:00') ?? DateTime.parse(a.date),
        color: color,
        title: late ? 'Absen Masuk Terlambat — ${a.outlet}' : 'Absen Masuk — ${a.outlet}',
        description: 'Pukul ${a.checkin}',
      ));
      if (a.checkout != null) {
        events.add(ActivityEvent(
          id: 'att-checkout-${a.id}',
          date: DateTime.tryParse('${a.date}T${a.checkout}:00') ?? DateTime.parse(a.date),
          color: NocturneColors.accent,
          title: 'Absen Pulang — ${a.outlet}',
          description: a.durationMinutes != null ? '${a.checkin} – ${a.checkout} (${a.durationMinutes} menit)' : '${a.checkin} – ${a.checkout}',
        ));
      }
    } else if (a.status == 'alpha') {
      events.add(ActivityEvent(
        id: 'att-${a.id}',
        date: DateTime.tryParse('${a.date}T12:00:00') ?? DateTime.parse(a.date),
        color: NocturneColors.danger,
        title: 'Tidak hadir (alpha) — ${a.outlet}',
        description: 'Tidak ada catatan absen pada jadwal ini.',
      ));
    }
  }

  for (final r in approvals) {
    events.add(ActivityEvent(
      id: 'apr-${r.id}',
      date: DateTime.tryParse('${r.date}T12:00:00') ?? DateTime.parse(r.date),
      color: r.status == 'approved'
          ? NocturneColors.accent
          : r.status == 'rejected'
              ? NocturneColors.danger
              : const Color(0xFFE0B96A),
      title: 'Laporan kunjungan — ${r.outlet}',
      description: 'Status: ${_approvalStatusLabel[r.status] ?? r.status}',
      badgeLabel: _approvalStatusLabel[r.status] ?? r.status,
      badgeVariant: r.status == 'approved' ? TagVariant.accent : (r.status == 'rejected' ? TagVariant.neutral : TagVariant.outline),
    ));
  }

  for (final l in leaves) {
    events.add(ActivityEvent(
      id: 'leave-${l.id}',
      date: l.createdAt,
      color: NocturneColors.accent2,
      title: 'Mengajukan ${_leaveTypeLabel[l.type] ?? l.type}',
      description: (l.reason?.isNotEmpty ?? false) ? l.reason! : '${l.startDate} – ${l.endDate}',
      badgeLabel: _leaveStatusLabel[l.status] ?? l.status,
      badgeVariant: l.status == 'approved' ? TagVariant.accent : (l.status == 'rejected' ? TagVariant.neutral : TagVariant.outline),
    ));
  }

  for (final r in salesReports) {
    events.add(ActivityEvent(
      id: 'sale-${r.id}',
      date: DateTime.tryParse('${r.date}T12:00:00') ?? DateTime.parse(r.date),
      color: NocturneColors.accent,
      title: 'Penjualan tercatat — ${r.outlet}',
      description: formatRp(r.total),
    ));
  }

  for (final v in visitSessions) {
    events.add(ActivityEvent(
      id: 'visit-start-${v.id}',
      date: DateTime.tryParse('${v.date}T${v.startTime}:00') ?? DateTime.parse(v.date),
      color: NocturneColors.accent,
      title: 'Check In — ${v.outlet}',
      description: 'Pukul ${v.startTime}',
    ));
    if (v.endTime != null) {
      events.add(ActivityEvent(
        id: 'visit-end-${v.id}',
        date: DateTime.tryParse('${v.date}T${v.endTime}:00') ?? DateTime.parse(v.date),
        color: NocturneColors.accent,
        title: 'Check Out — ${v.outlet}',
        description: '${v.startTime} – ${v.endTime} (${v.durationMinutes ?? 0} menit)',
      ));
    }
  }

  for (final r in locationRegistrations) {
    events.add(ActivityEvent(
      id: 'locreg-${r.id}',
      date: r.createdAt,
      color: NocturneColors.accent2,
      title: 'Mendaftarkan toko baru — ${r.name}',
      description: (r.address?.isNotEmpty ?? false) ? r.address! : 'Menunggu tinjauan admin',
      badgeLabel: _locationRegistrationStatusLabel[r.status] ?? r.status,
      badgeVariant: r.status == 'approved' ? TagVariant.accent : (r.status == 'rejected' ? TagVariant.neutral : TagVariant.outline),
    ));
    if (r.reviewedAt != null) {
      final approved = r.status == 'approved';
      events.add(ActivityEvent(
        id: 'locreg-review-${r.id}',
        date: r.reviewedAt!,
        color: approved ? NocturneColors.accent : NocturneColors.danger,
        title: approved ? 'Toko "${r.name}" disetujui' : 'Toko "${r.name}" ditolak',
        description: (r.reviewNote?.isNotEmpty ?? false) ? r.reviewNote! : (approved ? 'Sudah masuk jadwal kunjungan.' : 'Lihat catatan di Daftar Toko Saya.'),
      ));
    }
  }

  for (final p in payslips) {
    if (p.paidAt != null) {
      events.add(ActivityEvent(
        id: 'pay-${p.id}',
        date: p.paidAt!,
        color: NocturneColors.accent,
        title: 'Gaji ${_periodLabel(p.period)} dibayar',
        description: formatRp(p.netSalary),
      ));
    }
  }

  events.sort((a, b) => b.date.compareTo(a.date));
  return events;
}

String activityRelativeTime(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.isNegative) {
    return '${date.day}/${date.month}/${date.year}';
  }
  if (diff.inMinutes < 1) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  return '${date.day}/${date.month}/${date.year}';
}
