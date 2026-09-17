import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/models.dart';
import '../services/field_data_state.dart';
import '../theme/nocturne_theme.dart';
import '../widgets/async_state.dart';
import '../widgets/nocturne_card.dart';
import 'outlet_detail_screen.dart';
import 'visit_activity_detail_screen.dart';

const _leaveTypeLabel = {
  'tahunan': 'Cuti Tahunan',
  'sakit': 'Sakit',
  'izin': 'Izin',
  'lainnya': 'Lainnya',
};

const _monthNames = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];
const _weekdayShort = ['Sen', 'Sel', 'Rab', 'Kam', "Jum'at", 'Sab', 'Min'];

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _periodOf(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

// Same red/yellow/green/gray attendance-status scheme as the admin dashboard's brand schedule
// calendar (dashboard-web's BrandScheduleCalendar) — kept in sync so a day reads the same way
// whether an admin looks at it on web or the SPG looks at it here.
enum _ScheduleStatus { hijau, merah, kuning, abu }

const _colorHijau = Color(0xFF7CBF8A);
const _colorMerah = Color(0xFFE08D84);
const _colorKuning = Color(0xFFE0B96A);

const _statusLabel = {
  _ScheduleStatus.hijau: 'Masuk',
  _ScheduleStatus.merah: 'Tidak Masuk',
  _ScheduleStatus.kuning: 'Izin/Sakit/Lainnya',
  _ScheduleStatus.abu: 'Belum Lewat Jadwal',
};

Color _statusColor(_ScheduleStatus status) {
  switch (status) {
    case _ScheduleStatus.hijau:
      return _colorHijau;
    case _ScheduleStatus.merah:
      return _colorMerah;
    case _ScheduleStatus.kuning:
      return _colorKuning;
    case _ScheduleStatus.abu:
      return NocturneColors.textMuted(0.4);
  }
}

/// Checked-in wins first, then today/future is "not due yet," then an approved leave, then a
/// scheduled day that's already passed with nothing to show for it.
_ScheduleStatus _statusFor(FieldDataState data, DateTime day) {
  if (data.attendanceOn(day)?.checkin != null) return _ScheduleStatus.hijau;
  if (!_dateOnly(day).isBefore(_dateOnly(DateTime.now()))) return _ScheduleStatus.abu;
  final leave = data.leaveOn(day);
  if (leave != null && leave.status == 'approved') return _ScheduleStatus.kuning;
  return _ScheduleStatus.merah;
}

/// Month-grid schedule calendar built on `table_calendar` (a proven, widely
/// used grid — hand-rolling our own grid layout previously failed to render
/// date numbers reliably). Each day cell shows the date (drawn by the
/// package itself, so it's guaranteed correct) plus a chip per scheduled
/// shift, layered in via `markerBuilder`. Tapping a day opens a sheet with
/// that day's full placement detail. Schedule data itself comes from
/// `FieldDataState.scheduleEntriesOn`, fetched per visible month — shifts
/// are set explicitly per month on the admin side, so unlike everything
/// else in this app it can't be derived from a single cached snapshot.
class JadwalTab extends StatefulWidget {
  const JadwalTab({super.key});

  @override
  State<JadwalTab> createState() => _JadwalTabState();
}

class _JadwalTabState extends State<JadwalTab> {
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
  }

  void _openDay(FieldDataState data, DateTime day) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NocturneColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(NocturneRadius.lg))),
      isScrollControlled: true,
      builder: (_) => _DayDetailSheet(data: data, day: day),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<FieldDataState>();
    if (data.loading) return const LoadingState();
    if (data.error != null) return ErrorState(message: data.error!, onRetry: data.loadAll);
    if (data.myLocations.isEmpty) {
      return const EmptyState(label: 'Belum ada lokasi yang ditugaskan kepada Anda.');
    }

    // Safe to call on every build — it's a no-op once this month is already loaded (or still
    // waiting on `myBrands`), and by this point `loading` is false so `myBrands` is populated.
    data.ensureSchedulePeriodLoaded(_periodOf(_focusedDay));

    final today = DateTime.now();

    return RefreshIndicator(
      onRefresh: data.loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          const _StatusLegend(),
          const SizedBox(height: 10),
          NocturneCard(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: TableCalendar<Object>(
              locale: 'id_ID',
              firstDay: DateTime(today.year, today.month - 6, 1),
              lastDay: DateTime(today.year, today.month + 6, 0),
              focusedDay: _focusedDay,
              currentDay: today,
              rowHeight: 78,
              daysOfWeekHeight: 22,
              startingDayOfWeek: StartingDayOfWeek.monday,
              onPageChanged: (focused) {
                setState(() => _focusedDay = focused);
                data.ensureSchedulePeriodLoaded(_periodOf(focused));
              },
              onDaySelected: (selected, focused) {
                setState(() => _focusedDay = focused);
                _openDay(data, selected);
              },
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                leftChevronIcon: Icon(Icons.chevron_left, color: NocturneColors.text),
                rightChevronIcon: Icon(Icons.chevron_right, color: NocturneColors.text),
                titleTextStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                titleTextFormatter: (date, locale) => '${_monthNames[date.month - 1]} ${date.year}',
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                dowTextFormatter: (date, locale) => _weekdayShort[date.weekday - 1],
                weekdayStyle: TextStyle(color: NocturneColors.textMuted(0.5), fontSize: 10.5),
                weekendStyle: TextStyle(color: NocturneColors.textMuted(0.5), fontSize: 10.5),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: true,
                cellMargin: const EdgeInsets.all(1),
                defaultTextStyle: TextStyle(color: NocturneColors.text, fontSize: 12, fontWeight: FontWeight.w600),
                weekendTextStyle: TextStyle(color: NocturneColors.text, fontSize: 12, fontWeight: FontWeight.w600),
                outsideTextStyle: TextStyle(color: NocturneColors.textMuted(0.3), fontSize: 12),
                todayDecoration: BoxDecoration(color: NocturneColors.accent, shape: BoxShape.circle),
                todayTextStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                selectedDecoration: BoxDecoration(color: NocturneColors.accent.withValues(alpha: 0.4), shape: BoxShape.circle),
                cellAlignment: Alignment.topCenter,
                markersAutoAligned: false,
                markerMargin: EdgeInsets.zero,
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) => _buildDayMarkers(data, day),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildDayMarkers(FieldDataState data, DateTime day) {
    final leave = data.leaveOn(day);
    final training = data.trainingOn(day);
    final entries = data.scheduleEntriesOn(day);
    if (leave == null && training == null && entries.isEmpty) return null;

    // Only an APPROVED leave request or a FULL-DAY training replaces the day's
    // schedule — pending/rejected leave and half-day training are shown
    // alongside it instead, since the store schedule still stands either way.
    final approvedLeave = leave != null && leave.status == 'approved';
    final fullDayTraining = training != null && training.isFullDay;

    const maxChips = 2;
    final chips = <Widget>[];
    if (approvedLeave) {
      // Approved leave (any type — matches the admin calendar's "kuning" rule) replaces the
      // day's schedule entirely, so the whole day just reads as one yellow leave chip.
      chips.add(_chip(_colorKuning, _leaveTypeLabel[leave.type] ?? 'Cuti'));
    } else if (fullDayTraining) {
      chips.add(_chip(NocturneColors.accent2, 'Training'));
    } else {
      if (leave != null) {
        chips.add(_chip(NocturneColors.textMuted(0.4), _leaveTypeLabel[leave.type] ?? 'Cuti'));
      }
      if (training != null) {
        chips.add(_chip(NocturneColors.accent2, 'Training'));
      }
      final slotsLeft = maxChips - chips.length;
      final shown = entries.take(slotsLeft < 0 ? 0 : slotsLeft).toList();
      final statusColor = _statusColor(_statusFor(data, day));
      for (final e in shown) {
        final text = e.startTime != null ? '${e.startTime} ${e.locationName}' : e.locationName;
        chips.add(_chip(statusColor, text));
      }
      if (entries.length > shown.length) {
        chips.add(Text('+${entries.length - shown.length} lainnya', style: TextStyle(fontSize: 8.5, color: NocturneColors.textMuted(0.5))));
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(mainAxisSize: MainAxisSize.min, children: chips),
    );
  }

  Widget _chip(Color color, String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Same legend as the admin dashboard's brand schedule calendar, so the color coding reads the
/// same way on both sides.
class _StatusLegend extends StatelessWidget {
  const _StatusLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: _ScheduleStatus.values.map((status) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(color: _statusColor(status), shape: BoxShape.circle),
            ),
            Text(_statusLabel[status]!, style: TextStyle(fontSize: 10.5, color: NocturneColors.textMuted(0.6))),
          ],
        );
      }).toList(),
    );
  }
}

class _DayDetailSheet extends StatelessWidget {
  const _DayDetailSheet({required this.data, required this.day});
  final FieldDataState data;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final leave = data.leaveOn(day);
    final training = data.trainingOn(day);
    final entries = data.scheduleEntriesOn(day);
    final today = _dateOnly(DateTime.now());
    final isToday = _sameDay(day, today);
    // Only an APPROVED leave request or a FULL-DAY training removes the day's
    // schedule — pending/rejected leave and half-day training still leave the
    // schedule in place, just shown together with their own info.
    final approvedLeave = leave != null && leave.status == 'approved';
    final fullDayTraining = training != null && training.isFullDay;

    const weekdays = ['Senin', 'Selasa', 'Rabu', 'Kamis', "Jum'at", 'Sabtu', 'Minggu'];
    final dateLabel = '${weekdays[day.weekday - 1]}, ${day.day} ${_monthNames[day.month - 1]} ${day.year}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: NocturneColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
            Text(dateLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (leave != null) ...[
              _LeaveBanner(leave: leave),
              const SizedBox(height: 8),
            ],
            if (training != null) ...[
              _TrainingBanner(training: training),
              const SizedBox(height: 8),
            ],
            if (approvedLeave)
              Text(
                'Anda sedang cuti — tidak perlu absen hari ini.',
                style: TextStyle(fontSize: 12, color: NocturneColors.textMuted(0.55)),
              )
            else if (fullDayTraining)
              Text(
                'Training full day — tidak ada kunjungan toko hari ini.',
                style: TextStyle(fontSize: 12, color: NocturneColors.textMuted(0.55)),
              )
            else if (entries.isEmpty)
              Text('Tidak ada jadwal di hari ini.', style: TextStyle(fontSize: 12.5, color: NocturneColors.textMuted(0.5)))
            else
              ...entries.map((e) {
                OutletLocation? loc;
                for (final l in data.myLocations) {
                  if (l.id == e.locationId) {
                    loc = l;
                    break;
                  }
                }
                if (loc == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ScheduleCard(data: data, location: loc, entry: e, day: day, isToday: isToday),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _LeaveBanner extends StatelessWidget {
  const _LeaveBanner({required this.leave});
  final LeaveRequest leave;

  @override
  Widget build(BuildContext context) {
    final approved = leave.status == 'approved';
    final color = approved ? _colorKuning : NocturneColors.textMuted(0.5);
    return NocturneCard(
      borderColor: color,
      child: Row(
        children: [
          Icon(Icons.event_busy_outlined, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _leaveTypeLabel[leave.type] ?? leave.type,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                ),
                Text(
                  approved ? 'Disetujui' : leave.status == 'pending' ? 'Menunggu persetujuan' : 'Ditolak',
                  style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.55)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingBanner extends StatelessWidget {
  const _TrainingBanner({required this.training});
  final TrainingSession training;

  @override
  Widget build(BuildContext context) {
    final venue = training.venueName?.trim().isNotEmpty == true ? training.venueName! : training.topik;
    return NocturneCard(
      borderColor: NocturneColors.accent2,
      child: Row(
        children: [
          Icon(Icons.school_outlined, size: 18, color: NocturneColors.accent2),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(training.topik, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                Text(
                  '$venue · ${training.waktu} · ${training.isFullDay ? 'Full Day' : 'Half Day'}',
                  style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.55)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.data, required this.location, required this.entry, required this.day, required this.isToday});
  final FieldDataState data;
  final OutletLocation location;
  final BrandScheduleEntry entry;
  final DateTime day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isPast = _dateOnly(day).isBefore(_dateOnly(now));
    final attendance = isToday || isPast ? data.attendanceOn(day) : null;

    // Today opens the check-in/aktivitas flow; a past day has no check-in to offer,
    // so it opens a read-only recap of whatever was actually submitted instead. A
    // future day isn't tappable yet — there's nothing to show until it arrives.
    return Opacity(
      opacity: isToday || isPast ? 1 : 0.65,
      child: NocturneCard(
        onTap: isToday
            ? () {
                Navigator.of(context).pop(); // close the sheet first
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => OutletDetailScreen(location: location)));
              }
            : isPast
                ? () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => VisitActivityDetailScreen(location: location, day: day)));
                  }
                : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(location.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.storefront_outlined, size: 11, color: NocturneColors.textMuted(0.5)),
                      const SizedBox(width: 4),
                      Text(location.brandName, style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.5))),
                      if (entry.startTime != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.schedule_outlined, size: 11, color: NocturneColors.textMuted(0.5)),
                        const SizedBox(width: 4),
                        Text('${entry.startTime}-${entry.endTime}', style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.5))),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isPast && attendance == null)
              NocturneTag('Alpha', color: _colorMerah)
            else if (attendance?.checkout != null)
              NocturneTag('Selesai', color: _colorHijau)
            else if (attendance?.checkin != null)
              NocturneTag('Berlangsung', color: _colorHijau)
            else if (isToday)
              const NocturneTag('Belum', variant: TagVariant.neutral),
          ],
        ),
      ),
    );
  }
}
