import 'package:flutter/material.dart';
import '../models/models.dart';
import 'api_client.dart';

/// Aggregates everything the field app needs for the logged-in SPG: the
/// brands they're assigned to, the outlets (locations) assigned to them
/// across those brands, and today's attendance — fetched once and shared
/// across the Beranda/Jadwal/Training/Kinerja tabs.
class FieldDataState extends ChangeNotifier {
  FieldDataState({required this.api, required this.spgId});

  final ApiClient api;
  final int spgId;

  List<Brand> myBrands = [];
  List<OutletLocation> myLocations = [];
  List<AttendanceRecord> todayAttendance = [];
  List<AttendanceRecord> myAttendanceHistory = [];
  List<LeaveRequest> myLeaveRequests = [];
  List<DailySalesReport> mySalesReports = [];
  List<ApprovalReport> myApprovalsToday = [];
  List<CompetitorActivity> myCompetitorActivitiesToday = [];
  List<VisitSession> myVisitSessionsToday = [];
  final Map<int, List<int>> trainingCompletions = {}; // trainingId -> completed spgIds
  int unreadNotificationCount = 0;
  bool loading = true;
  String? error;

  static String get _today => DateTime.now().toIso8601String().substring(0, 10);

  List<TrainingSession> get myTrainings => myBrands.expand((b) => b.training).toList();

  /// The training scheduled on [date], if any — matched against `scheduleDate`
  /// (the real ISO date), not the free-text `tanggal` display string. Older
  /// trainings whose `tanggal` never resolved to a clean date never match here.
  TrainingSession? trainingOn(DateTime date) {
    final iso = _isoDate(date);
    for (final t in myTrainings) {
      if (t.scheduleDate == iso) return t;
    }
    return null;
  }

  TrainingSession? get todayTraining => trainingOn(DateTime.now());

  /// Full day: no store visit today — check-in happens at the training instead,
  /// and the store schedule/activities are blocked for the day.
  bool get isFullDayTrainingToday => todayTraining?.isFullDay ?? false;

  // ── Schedule (Jadwal calendar, arbitrary dates) ─────────────────────────
  // Fetched lazily per "YYYY-MM" as the calendar is navigated — schedules are set explicitly per
  // month now (no rotation formula), so unlike everything else above this can't be computed from
  // a single up-front snapshot.
  final Map<String, List<BrandScheduleEntry>> _scheduleByDate = {};
  final Set<String> _loadedSchedulePeriods = {};

  Future<void> ensureSchedulePeriodLoaded(String period) async {
    if (_loadedSchedulePeriods.contains(period)) return;
    // `myBrands` is only populated partway through `loadAll()` — if the Jadwal tab's first frame
    // lands before that finishes (very possible right after login/cold start), looping over an
    // empty list here would silently mark the period "loaded" with zero entries and never
    // retry. Bail without marking it, so the caller's next attempt (once loadAll() notifies) picks
    // this back up instead of leaving the month permanently blank.
    if (myBrands.isEmpty) return;
    _loadedSchedulePeriods.add(period);
    try {
      final parts = period.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final from = '$period-01';
      final lastDay = DateTime(year, month + 1, 0).day;
      final to = '$period-${lastDay.toString().padLeft(2, '0')}';
      for (final brand in myBrands) {
        final byDate = await api.getBrandSchedule(brand.id, from, to);
        byDate.forEach((date, entries) {
          final mine = entries.where((e) => e.spgId == spgId).toList();
          if (mine.isEmpty) return;
          _scheduleByDate[date] = [...(_scheduleByDate[date] ?? []), ...mine];
        });
      }
      notifyListeners();
    } catch (_) {
      _loadedSchedulePeriods.remove(period); // allow a retry on next navigation
    }
  }

  List<BrandScheduleEntry> scheduleEntriesOn(DateTime date) => _scheduleByDate[_isoDate(date)] ?? [];

  Future<void> loadAll() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final allBrands = await api.listBrands();
      myBrands = allBrands.where((b) => b.assignedSpgIds.contains(spgId)).toList();

      final locLists = await Future.wait(
        myBrands.map((b) => api.listLocations(b.id, brandName: b.name)),
      );
      myLocations = locLists.expand((l) => l).where((loc) => loc.assignedSpgIds.contains(spgId)).toList();

      todayAttendance = await api.attendanceToday(spgId);
      myAttendanceHistory = await api.listAttendanceForSpg(spgId);
      myLeaveRequests = await api.listMyLeaveRequests(spgId);
      mySalesReports = await api.listDailySalesReports(spgId: spgId);
      myApprovalsToday = await api.listApprovals(spgId: spgId, date: _today);
      myCompetitorActivitiesToday = await api.listCompetitorActivities(spgId: spgId, date: _today);
      myVisitSessionsToday = await api.listVisitSessions(spgId: spgId, date: _today);

      trainingCompletions.clear();
      for (final t in myTrainings) {
        trainingCompletions[t.id] = await api.listTrainingCompletions(t.brandId, t.id);
      }

      unreadNotificationCount = await api.unreadNotificationCount();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  AttendanceRecord? attendanceFor(OutletLocation loc) {
    for (final a in todayAttendance) {
      if (a.brandId == loc.brandId && a.outlet == loc.name) return a;
    }
    return null;
  }

  /// The single attendance record for today, if any — check-in is once per
  /// day (the first store of the day), not per outlet, so on a multi-store
  /// day this is the ONLY row `todayAttendance` will ever contain with a
  /// non-null `checkin`.
  AttendanceRecord? get todaysCheckin {
    for (final a in todayAttendance) {
      if (a.checkin != null) return a;
    }
    return null;
  }

  bool get hasCheckedInToday => todaysCheckin != null;

  bool isCheckedIn(OutletLocation loc) => attendanceFor(loc)?.checkin != null;
  bool isVisitCompleted(OutletLocation loc) {
    final a = attendanceFor(loc);
    return a != null && a.checkin != null && a.checkout != null;
  }

  /// Whether there's proof the SPG was actually at [loc] today — either it's
  /// the outlet they checked in at, or they've logged a presence-validated
  /// activity there (foto/laporan/penjualan/aktivitas kompetitor). Later
  /// stops in a multi-store day never get their own check-in/out row, so
  /// this is what "visited" means for them.
  bool hasVisitedToday(OutletLocation loc) {
    if (attendanceFor(loc)?.checkin != null) return true;
    if (approvalFor(loc) != null) return true;
    if (hasSalesReportToday(loc)) return true;
    if (hasCompetitorActivityToday(loc)) return true;
    return false;
  }

  OutletLocation? get nextOutlet {
    for (final loc in myLocations) {
      if (!hasVisitedToday(loc)) return loc;
    }
    return myLocations.isEmpty ? null : myLocations.first;
  }

  int get visitedTodayCount => myLocations.where(hasVisitedToday).length;

  num get todaySalesTotal =>
      mySalesReports.where((r) => r.date == _today).fold<num>(0, (sum, r) => sum + r.total);

  ApprovalReport? approvalFor(OutletLocation loc) {
    for (final a in myApprovalsToday.reversed) {
      if (a.brandId == loc.brandId && a.outlet == loc.name) return a;
    }
    return null;
  }

  bool hasSalesReportToday(OutletLocation loc) =>
      mySalesReports.any((r) => r.outlet == loc.name && r.date == _today);

  bool hasCompetitorActivityToday(OutletLocation loc) =>
      myCompetitorActivitiesToday.any((c) => c.brandId == loc.brandId && c.outlet == loc.name);

  /// Today's Mulai/Akhiri Kunjungan session for [loc], if one's been started.
  VisitSession? visitSessionFor(OutletLocation loc) {
    for (final v in myVisitSessionsToday) {
      if (v.brandId == loc.brandId && v.outlet == loc.name) return v;
    }
    return null;
  }

  static String _isoDate(DateTime date) => date.toIso8601String().substring(0, 10);

  /// The leave request (of any status) covering [date], if any — approved takes
  /// priority over pending/rejected when more than one somehow overlaps. Callers
  /// that decide whether to hide the day's schedule must check `.status == 'approved'`
  /// themselves — a pending or rejected request is still returned here (for display)
  /// but should never hide the schedule on its own.
  LeaveRequest? leaveOn(DateTime date) {
    final iso = _isoDate(date);
    LeaveRequest? other;
    for (final l in myLeaveRequests) {
      if (l.startDate.compareTo(iso) > 0 || l.endDate.compareTo(iso) < 0) continue;
      if (l.status == 'approved') return l;
      other ??= l;
    }
    return other;
  }

  /// This SPG's attendance record for [date] at any outlet, if one exists.
  AttendanceRecord? attendanceOn(DateTime date) {
    final iso = _isoDate(date);
    for (final a in myAttendanceHistory) {
      if (a.date == iso) return a;
    }
    return null;
  }

  bool isTrainingCompleted(TrainingSession t) => trainingCompletions[t.id]?.contains(spgId) ?? false;

  Future<void> completeTraining(TrainingSession t) async {
    await api.markTrainingCompletion(t.brandId, t.id, spgId);
    trainingCompletions[t.id] = [...?trainingCompletions[t.id], spgId];
    notifyListeners();
  }

  Brand? brandById(int id) {
    for (final b in myBrands) {
      if (b.id == id) return b;
    }
    return null;
  }

  Future<void> refreshAttendance() async {
    todayAttendance = await api.attendanceToday(spgId);
    notifyListeners();
  }

  Future<void> refreshVisitSessions() async {
    myVisitSessionsToday = await api.listVisitSessions(spgId: spgId, date: _today);
    notifyListeners();
  }

  Future<void> refreshNotificationCount() async {
    unreadNotificationCount = await api.unreadNotificationCount();
    notifyListeners();
  }
}
