int _asInt(dynamic v) => v is int ? v : (v as num).toInt();
double _asDouble(dynamic v) => v is double ? v : (v as num).toDouble();
double? _asDoubleOrNull(dynamic v) => v == null ? null : _asDouble(v);
int? _asIntOrNull(dynamic v) => v == null ? null : _asInt(v);

class AuthUser {
  AuthUser({required this.id, required this.username, required this.name, required this.role, required this.spgId});
  final int id;
  final String username;
  final String name;
  final String role;
  final int? spgId;

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: _asInt(j['id']),
        username: j['username'] as String,
        name: j['name'] as String,
        role: j['role'] as String,
        spgId: _asIntOrNull(j['spgId']),
      );

  Map<String, dynamic> toJson() => {'id': id, 'username': username, 'name': name, 'role': role, 'spgId': spgId};
}

class Spg {
  Spg({
    required this.id,
    required this.name,
    required this.region,
    required this.attendanceRate,
    required this.kunjunganDone,
    required this.kunjunganTotal,
    required this.target,
    required this.realisasi,
    required this.incentive,
    required this.violationsCount,
    required this.trainingCompleted,
    required this.trainingTotal,
    required this.achievementPct,
    this.contract,
    this.leaveStatus,
    this.contact,
    this.brandId,
    this.brandName,
    this.photoUrl,
    this.nik,
    this.birthPlace,
    this.birthDate,
    this.gender,
    this.address,
    this.maritalStatus,
    this.education,
    this.email,
    this.joinDate,
    this.statusNote,
    this.statusNoteUpdatedAt,
  });
  final int id;
  final String name;
  final String region;
  final int attendanceRate;
  final int kunjunganDone;
  final int kunjunganTotal;
  final num target;
  final num realisasi;
  final num incentive;
  final int violationsCount;
  final int trainingCompleted;
  final int trainingTotal;
  final int achievementPct;

  // Profile fields — present on GET /spg/:id, not always fetched via lighter list endpoints.
  final String? contract;
  final String? leaveStatus;
  final String? contact;
  final int? brandId;
  final String? brandName;
  final String? photoUrl;
  final String? nik;
  final String? birthPlace;
  final String? birthDate;
  final String? gender;
  final String? address;
  final String? maritalStatus;
  final String? education;
  final String? email;
  final String? joinDate;

  /// WhatsApp-style "about" text — set by the SPG themselves or an admin.
  final String? statusNote;
  final DateTime? statusNoteUpdatedAt;

  factory Spg.fromJson(Map<String, dynamic> j) => Spg(
        id: _asInt(j['id']),
        name: j['name'] as String,
        region: j['region'] as String,
        attendanceRate: _asInt(j['attendanceRate']),
        kunjunganDone: _asInt(j['kunjunganDone']),
        kunjunganTotal: _asInt(j['kunjunganTotal']),
        target: j['target'] as num,
        realisasi: j['realisasi'] as num,
        incentive: j['incentive'] as num,
        violationsCount: _asInt(j['violationsCount']),
        trainingCompleted: _asInt(j['trainingCompleted']),
        trainingTotal: _asInt(j['trainingTotal']),
        achievementPct: _asInt(j['achievementPct']),
        contract: j['contract'] as String?,
        leaveStatus: j['leaveStatus'] as String?,
        contact: j['contact'] as String?,
        brandId: _asIntOrNull(j['brandId']),
        brandName: j['brandName'] as String?,
        photoUrl: j['photoUrl'] as String?,
        nik: j['nik'] as String?,
        birthPlace: j['birthPlace'] as String?,
        birthDate: j['birthDate'] as String?,
        gender: j['gender'] as String?,
        address: j['address'] as String?,
        maritalStatus: j['maritalStatus'] as String?,
        education: j['education'] as String?,
        email: j['email'] as String?,
        joinDate: j['joinDate'] as String?,
        statusNote: j['statusNote'] as String?,
        statusNoteUpdatedAt: j['statusNoteUpdatedAt'] == null ? null : DateTime.tryParse(j['statusNoteUpdatedAt'] as String),
      );
}

class Product {
  Product({required this.id, required this.name, required this.price, required this.brandId});
  final int id;
  final String name;
  final num price;
  final int brandId;

  factory Product.fromJson(Map<String, dynamic> j) =>
      Product(id: _asInt(j['id']), name: j['name'] as String, price: j['price'] as num, brandId: _asInt(j['brandId']));
}

class TrainingSession {
  TrainingSession({
    required this.id,
    required this.topik,
    required this.trainer,
    required this.tanggal,
    required this.scheduleDate,
    required this.waktu,
    required this.status,
    required this.dayType,
    required this.venueName,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    required this.brandId,
    this.brandName = '',
  });
  final int id;
  final String topik;
  final String trainer;
  final String tanggal;
  /// The real "YYYY-MM-DD" this training happens — null for older rows whose
  /// `tanggal` was never a clean ISO date. This is what Jadwal/Beranda match against.
  final String? scheduleDate;
  final String waktu;
  final String status;
  /// 'full' = SPG checks in AT the training instead of any store that day, and
  /// store visit activities are blocked. 'half' = training just shows on the
  /// schedule; store check-in/visits happen as normal alongside it.
  final String dayType;
  final String? venueName;
  final double? lat;
  final double? lng;
  final int? radiusMeters;
  final int brandId;
  final String brandName;

  bool get isFullDay => dayType == 'full';

  factory TrainingSession.fromJson(Map<String, dynamic> j, {int? brandId, String brandName = ''}) => TrainingSession(
        id: _asInt(j['id']),
        topik: j['topik'] as String,
        trainer: j['trainer'] as String,
        tanggal: j['tanggal'] as String,
        scheduleDate: j['scheduleDate'] as String?,
        waktu: j['waktu'] as String,
        status: j['status'] as String,
        dayType: j['dayType'] as String? ?? 'half',
        venueName: j['venueName'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        radiusMeters: _asIntOrNull(j['radiusMeters']),
        brandId: brandId ?? _asInt(j['brandId']),
        brandName: brandName,
      );
}

class Brand {
  Brand({
    required this.id,
    required this.name,
    required this.category,
    required this.products,
    required this.assignedSpgIds,
    required this.training,
    required this.spgWorkMode,
  });
  final int id;
  final String name;
  final String category;
  final List<Product> products;
  final List<int> assignedSpgIds;
  final List<TrainingSession> training;
  /// 'toko_tetap' | 'toko_mandiri' | 'penjualan_keliling'
  final String spgWorkMode;

  bool get isTokoMandiri => spgWorkMode == 'toko_mandiri';
  bool get isPenjualanKeliling => spgWorkMode == 'penjualan_keliling';

  factory Brand.fromJson(Map<String, dynamic> j) => Brand(
        id: _asInt(j['id']),
        name: j['name'] as String,
        category: j['category'] as String,
        products: (j['products'] as List).map((e) => Product.fromJson(e)).toList(),
        assignedSpgIds: (j['assignedSpgIds'] as List).map((e) => _asInt(e)).toList(),
        training: (j['training'] as List)
            .map((e) => TrainingSession.fromJson(e, brandId: _asInt(j['id']), brandName: j['name'] as String))
            .toList(),
        spgWorkMode: j['spgWorkMode'] as String? ?? 'toko_tetap',
      );
}

class LocationShift {
  LocationShift({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.graceMinutes,
  });
  final int id;
  final String name;
  final String startTime;
  final String endTime;
  final int graceMinutes;

  factory LocationShift.fromJson(Map<String, dynamic> j) => LocationShift(
        id: _asInt(j['id']),
        name: j['name'] as String,
        startTime: j['startTime'] as String,
        endTime: j['endTime'] as String,
        graceMinutes: _asInt(j['graceMinutes']),
      );
}

/// One SPG's placement terms at a location for the *current* month — which days of the week
/// (0=Minggu..6=Sabtu) they work, and which shift (if any) applies each of those days. Schedules
/// are set explicitly per month on the admin side now (no rotation formula), so this snapshot is
/// only meaningful for "today" — it's resolved server-side against the current calendar month.
class SpgLocationSchedule {
  SpgLocationSchedule({required this.spgId, required this.workDays, required this.weekdayShifts});
  final int spgId;
  final List<int> workDays;
  /// Index 0=Minggu..6=Sabtu — shiftId worked that day, or null.
  final List<int?> weekdayShifts;

  factory SpgLocationSchedule.fromJson(Map<String, dynamic> j) => SpgLocationSchedule(
        spgId: _asInt(j['spgId']),
        workDays: ((j['workDays'] as List?) ?? []).map((e) => _asInt(e)).toList(),
        weekdayShifts: ((j['weekdayShifts'] as List?) ?? []).map((e) => _asIntOrNull(e)).toList(),
      );
}

class OutletLocation {
  OutletLocation({
    required this.id,
    required this.brandId,
    required this.brandName,
    required this.name,
    required this.address,
    required this.category,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    required this.requireWifiValidation,
    required this.wifiSsid,
    required this.assignedSpgIds,
    required this.shifts,
    required this.spgSchedules,
  });
  final int id;
  final int brandId;
  final String brandName;
  final String name;
  final String? address;
  final String? category;
  final double? lat;
  final double? lng;
  final int? radiusMeters;
  final bool requireWifiValidation;
  final String? wifiSsid;
  final List<int> assignedSpgIds;
  final List<LocationShift> shifts;
  /// spgId -> placement schedule (workDays/rotation/anchor shift)
  final Map<int, SpgLocationSchedule> spgSchedules;

  /// The shift this SPG is assigned to at this location right now (today).
  LocationShift? shiftFor(int spgId) => effectiveShiftOn(spgId, DateTime.now());

  /// Whether [spgId] is expected to work at this location on [date]. Only accurate for dates
  /// within the *current* calendar month — `spgSchedules` reflects just that month's admin-set
  /// pattern (schedules are set per month now, not a formula, so other months aren't knowable
  /// from this snapshot; see `FieldDataState.scheduleEntriesOn` for arbitrary-date lookups).
  bool isScheduledOn(int spgId, DateTime date) {
    final schedule = spgSchedules[spgId];
    if (schedule == null) return false;
    final dow = date.weekday % 7; // Dart: Mon=1..Sun=7 -> 0=Minggu..6=Sabtu
    return schedule.workDays.contains(dow);
  }

  /// The shift for [date]'s weekday, per the current month's pattern — see `isScheduledOn`'s
  /// caveat about only being accurate within the current calendar month.
  LocationShift? effectiveShiftOn(int spgId, DateTime date) {
    final schedule = spgSchedules[spgId];
    if (schedule == null) return null;
    final dow = date.weekday % 7;
    if (!schedule.workDays.contains(dow)) return null;
    final shiftId = dow < schedule.weekdayShifts.length ? schedule.weekdayShifts[dow] : null;
    if (shiftId == null) return null;
    for (final s in shifts) {
      if (s.id == shiftId) return s;
    }
    return null;
  }

  factory OutletLocation.fromJson(Map<String, dynamic> j, {String brandName = ''}) => OutletLocation(
        id: _asInt(j['id']),
        brandId: _asInt(j['brandId']),
        brandName: brandName,
        name: j['name'] as String,
        address: j['address'] as String?,
        category: j['category'] as String?,
        lat: _asDoubleOrNull(j['lat']),
        lng: _asDoubleOrNull(j['lng']),
        radiusMeters: _asIntOrNull(j['radiusMeters']),
        requireWifiValidation: j['requireWifiValidation'] as bool? ?? false,
        wifiSsid: j['wifiSsid'] as String?,
        assignedSpgIds: (j['assignedSpgIds'] as List).map((e) => _asInt(e)).toList(),
        shifts: ((j['shifts'] as List?) ?? []).map((e) => LocationShift.fromJson(e as Map<String, dynamic>)).toList(),
        spgSchedules: {
          for (final e in (j['spgShifts'] as List?) ?? [])
            _asInt((e as Map<String, dynamic>)['spgId']): SpgLocationSchedule.fromJson(e),
        },
      );
}

/// One SPG/location/shift resolved onto a single calendar day — from `GET
/// /brands/:id/schedule`, the source of truth for arbitrary-date lookups (unlike
/// `OutletLocation.spgSchedules`, which only reflects the current month).
class BrandScheduleEntry {
  BrandScheduleEntry({
    required this.spgId,
    required this.locationId,
    required this.locationName,
    required this.shiftName,
    required this.startTime,
    required this.endTime,
  });
  final int spgId;
  final int locationId;
  final String locationName;
  final String? shiftName;
  final String? startTime;
  final String? endTime;

  factory BrandScheduleEntry.fromJson(Map<String, dynamic> j) => BrandScheduleEntry(
        spgId: _asInt(j['spgId']),
        locationId: _asInt(j['locationId']),
        locationName: j['locationName'] as String,
        shiftName: j['shiftName'] as String?,
        startTime: j['startTime'] as String?,
        endTime: j['endTime'] as String?,
      );
}

class AttendanceRecord {
  AttendanceRecord({
    required this.id,
    required this.spgId,
    required this.brandId,
    required this.outlet,
    required this.date,
    required this.checkin,
    required this.checkout,
    required this.durationMinutes,
    required this.status,
    this.trainingSessionId,
    this.checkinSelfieUrl,
    this.checkoutSelfieUrl,
  });
  final int id;
  final int spgId;
  final int brandId;
  final String outlet;
  final String date;
  final String? checkin;
  final String? checkout;
  final int? durationMinutes;
  final String status;
  /// Set only when this check-in was at a training (full-day) instead of a store.
  final int? trainingSessionId;
  final String? checkinSelfieUrl;
  final String? checkoutSelfieUrl;

  bool get isTrainingDay => trainingSessionId != null;

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
        id: _asInt(j['id']),
        spgId: _asInt(j['spgId']),
        brandId: _asInt(j['brandId']),
        outlet: j['outlet'] as String,
        date: j['date'] as String,
        checkin: j['checkin'] as String?,
        checkout: j['checkout'] as String?,
        durationMinutes: _asIntOrNull(j['durationMinutes']),
        status: j['status'] as String,
        trainingSessionId: _asIntOrNull(j['trainingSessionId']),
        checkinSelfieUrl: j['checkinSelfieUrl'] as String?,
        checkoutSelfieUrl: j['checkoutSelfieUrl'] as String?,
      );
}

class ApprovalReport {
  ApprovalReport({
    required this.id,
    required this.spgId,
    required this.brandId,
    required this.outlet,
    required this.date,
    required this.time,
    required this.note,
    required this.status,
    required this.photoUrls,
  });
  final int id;
  final int spgId;
  final int brandId;
  final String outlet;
  final String date;
  final String time;
  final String note;
  final String status;
  final List<String>? photoUrls;

  factory ApprovalReport.fromJson(Map<String, dynamic> j) => ApprovalReport(
        id: _asInt(j['id']),
        spgId: _asInt(j['spgId']),
        brandId: _asInt(j['brandId']),
        outlet: j['outlet'] as String,
        date: j['date'] as String,
        time: j['time'] as String? ?? '',
        note: j['note'] as String? ?? '',
        status: j['status'] as String,
        photoUrls: j['photoUrls'] == null ? null : (j['photoUrls'] as List).cast<String>(),
      );
}

class ApprovalComment {
  ApprovalComment({required this.id, required this.authorName, required this.message, required this.createdAt});
  final int id;
  final String authorName;
  final String message;
  final DateTime createdAt;

  factory ApprovalComment.fromJson(Map<String, dynamic> j) => ApprovalComment(
        id: _asInt(j['id']),
        authorName: j['authorName'] as String,
        message: j['message'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class CompetitorActivity {
  CompetitorActivity({
    required this.id,
    required this.spgId,
    required this.brandId,
    required this.outlet,
    required this.date,
    required this.title,
    required this.description,
    required this.photoUrls,
  });
  final int id;
  final int spgId;
  final int brandId;
  final String outlet;
  final String date;
  final String title;
  final String description;
  final List<String>? photoUrls;

  factory CompetitorActivity.fromJson(Map<String, dynamic> j) => CompetitorActivity(
        id: _asInt(j['id']),
        spgId: _asInt(j['spgId']),
        brandId: _asInt(j['brandId']),
        outlet: j['outlet'] as String,
        date: j['date'] as String,
        title: j['title'] as String,
        description: j['description'] as String,
        photoUrls: j['photoUrls'] == null ? null : (j['photoUrls'] as List).cast<String>(),
      );
}

class DailySalesReportItem {
  DailySalesReportItem({required this.productId, required this.qty, required this.unitPrice, required this.lineTotal});
  final int productId;
  final int qty;
  final num unitPrice;
  final num lineTotal;

  factory DailySalesReportItem.fromJson(Map<String, dynamic> j) => DailySalesReportItem(
        productId: _asInt(j['productId']),
        qty: _asInt(j['qty']),
        unitPrice: (j['unitPrice'] as num?) ?? 0,
        lineTotal: j['lineTotal'] as num,
      );
}

class DailySalesReport {
  DailySalesReport({
    required this.id,
    required this.spgId,
    required this.outlet,
    required this.date,
    required this.createdAt,
    required this.photoUrl,
    required this.lat,
    required this.lng,
    this.items = const [],
  });
  final int id;
  final int spgId;
  final String outlet;
  final String date;
  final DateTime createdAt;
  final String? photoUrl;
  final double? lat;
  final double? lng;
  final List<DailySalesReportItem> items;

  num get total => items.fold<num>(0, (sum, i) => sum + i.lineTotal);

  factory DailySalesReport.fromJson(Map<String, dynamic> j) => DailySalesReport(
        id: _asInt(j['id']),
        spgId: _asInt(j['spgId']),
        outlet: j['outlet'] as String,
        date: j['date'] as String,
        createdAt: j['createdAt'] != null ? DateTime.parse(j['createdAt'] as String) : DateTime.parse(j['date'] as String),
        photoUrl: j['photoUrl'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        items: j['items'] == null ? const [] : (j['items'] as List).map((e) => DailySalesReportItem.fromJson(e)).toList(),
      );
}

/// One page of `GET /daily-sales-reports/search` — `{ data, total, totalAmount, page, pageSize }`.
class DailySalesReportPage {
  DailySalesReportPage({required this.items, required this.total, required this.totalAmount});
  final List<DailySalesReport> items;
  final int total;
  final num totalAmount;

  factory DailySalesReportPage.fromJson(Map<String, dynamic> j) => DailySalesReportPage(
        items: (j['data'] as List).map((e) => DailySalesReport.fromJson(e)).toList(),
        total: _asInt(j['total']),
        totalAmount: (j['totalAmount'] as num?) ?? 0,
      );
}

class ActivityLog {
  ActivityLog({
    required this.id,
    required this.spgId,
    required this.brandId,
    required this.outlet,
    required this.date,
    required this.reason,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
  });
  final int id;
  final int spgId;
  final int brandId;
  final String outlet;
  final String date;
  final String reason;
  final String startTime;
  final String? endTime;
  final int? durationMinutes;

  bool get isOngoing => endTime == null;

  factory ActivityLog.fromJson(Map<String, dynamic> j) => ActivityLog(
        id: _asInt(j['id']),
        spgId: _asInt(j['spgId']),
        brandId: _asInt(j['brandId']),
        outlet: j['outlet'] as String,
        date: j['date'] as String,
        reason: j['reason'] as String,
        startTime: j['startTime'] as String,
        endTime: j['endTime'] as String?,
        durationMinutes: _asIntOrNull(j['durationMinutes']),
      );
}

/// One outlet visit's Mulai/Akhiri Kunjungan session — distinct from the
/// once-a-day AttendanceRecord check-in/out and from ActivityLog breaks.
class VisitSession {
  VisitSession({
    required this.id,
    required this.spgId,
    required this.brandId,
    required this.outlet,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
  });
  final int id;
  final int spgId;
  final int brandId;
  final String outlet;
  final String date;
  final String startTime;
  final String? endTime;
  final int? durationMinutes;

  bool get isOngoing => endTime == null;

  factory VisitSession.fromJson(Map<String, dynamic> j) => VisitSession(
        id: _asInt(j['id']),
        spgId: _asInt(j['spgId']),
        brandId: _asInt(j['brandId']),
        outlet: j['outlet'] as String,
        date: j['date'] as String,
        startTime: j['startTime'] as String,
        endTime: j['endTime'] as String?,
        durationMinutes: _asIntOrNull(j['durationMinutes']),
      );
}

class StockCheck {
  StockCheck({
    required this.id,
    required this.spgId,
    required this.brandId,
    required this.outlet,
    required this.productId,
    required this.date,
    required this.stockOpen,
    required this.stockClose,
  });
  final int id;
  final int spgId;
  final int brandId;
  final String outlet;
  final int productId;
  final String date;
  final int? stockOpen;
  final int? stockClose;

  factory StockCheck.fromJson(Map<String, dynamic> j) => StockCheck(
        id: _asInt(j['id']),
        spgId: _asInt(j['spgId']),
        brandId: _asInt(j['brandId']),
        outlet: j['outlet'] as String,
        productId: _asInt(j['productId']),
        date: j['date'] as String,
        stockOpen: _asIntOrNull(j['stockOpen']),
        stockClose: _asIntOrNull(j['stockClose']),
      );
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.brandId,
    required this.entityType,
    required this.entityId,
    required this.readAt,
    required this.createdAt,
  });
  final int id;
  final String title;
  final String body;
  final String type;
  final int? brandId;
  final String? entityType;
  final int? entityId;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: _asInt(j['id']),
        title: j['title'] as String,
        body: j['body'] as String,
        type: j['type'] as String,
        brandId: _asIntOrNull(j['brandId']),
        entityType: j['entityType'] as String?,
        entityId: _asIntOrNull(j['entityId']),
        readAt: j['readAt'] == null ? null : DateTime.parse(j['readAt'] as String),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class LeaveRequest {
  LeaveRequest({
    required this.id,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.attachmentUrl,
    required this.status,
    required this.reviewedBy,
    required this.createdAt,
  });
  final int id;
  final String type;
  final String startDate;
  final String endDate;
  final String? reason;
  final String? attachmentUrl;
  final String status;
  final String? reviewedBy;
  final DateTime createdAt;

  factory LeaveRequest.fromJson(Map<String, dynamic> j) => LeaveRequest(
        id: _asInt(j['id']),
        type: j['type'] as String,
        startDate: j['startDate'] as String,
        endDate: j['endDate'] as String,
        reason: j['reason'] as String?,
        attachmentUrl: j['attachmentUrl'] as String?,
        status: j['status'] as String,
        reviewedBy: j['reviewedBy'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

/// "Sisa cuti tahunan" for one SPG in one calendar year — `used` is computed live from approved
/// requests server-side, not a stored counter (an approval can be reversed later).
class LeaveBalance {
  LeaveBalance({required this.year, required this.quota, required this.used, required this.remaining});
  final int year;
  final int quota;
  final int used;
  final int remaining;

  factory LeaveBalance.fromJson(Map<String, dynamic> j) => LeaveBalance(
        year: _asInt(j['year']),
        quota: _asInt(j['quota']),
        used: _asInt(j['used']),
        remaining: _asInt(j['remaining']),
      );
}

/// One month's payroll calculation for the signed-in SPG — a snapshot
/// generated by an admin's "Jalankan Payroll" run, not a live figure.
class Payslip {
  Payslip({
    required this.id,
    required this.period,
    required this.basicSalary,
    required this.scheduledDays,
    required this.presentDays,
    required this.approvedLeaveDays,
    required this.unpaidAbsenceDays,
    required this.attendanceDeduction,
    required this.bpjsKesehatanDeduction,
    required this.bpjsKetenagakerjaanDeduction,
    required this.incentiveTotal,
    required this.netSalary,
    required this.status,
    required this.paidAt,
  });
  final int id;
  final String period;
  final num basicSalary;
  final int scheduledDays;
  final int presentDays;
  final int approvedLeaveDays;
  final int unpaidAbsenceDays;
  final num attendanceDeduction;
  final num bpjsKesehatanDeduction;
  final num bpjsKetenagakerjaanDeduction;
  final num incentiveTotal;
  final num netSalary;
  final String status;
  final DateTime? paidAt;

  factory Payslip.fromJson(Map<String, dynamic> j) => Payslip(
        id: _asInt(j['id']),
        period: j['period'] as String,
        basicSalary: j['basicSalary'] as num,
        scheduledDays: _asInt(j['scheduledDays']),
        presentDays: _asInt(j['presentDays']),
        approvedLeaveDays: _asInt(j['approvedLeaveDays']),
        unpaidAbsenceDays: _asInt(j['unpaidAbsenceDays']),
        attendanceDeduction: j['attendanceDeduction'] as num,
        bpjsKesehatanDeduction: j['bpjsKesehatanDeduction'] as num,
        bpjsKetenagakerjaanDeduction: j['bpjsKetenagakerjaanDeduction'] as num,
        incentiveTotal: j['incentiveTotal'] as num,
        netSalary: j['netSalary'] as num,
        status: j['status'] as String,
        paidAt: j['paidAt'] == null ? null : DateTime.parse(j['paidAt'] as String),
      );
}

/// A store an SPG has proposed while prospecting in the field — `status` starts `pending` until
/// an admin reviews it; only once `approved` does it turn into a real assigned location with a
/// weekly visit schedule (see the mobile "Daftarkan Toko" flow and dashboard-api's
/// `LocationRegistrationRequest`).
class LocationRegistrationRequest {
  LocationRegistrationRequest({
    required this.id,
    required this.brandId,
    required this.name,
    required this.address,
    required this.category,
    required this.lat,
    required this.lng,
    required this.photoUrl,
    required this.status,
    required this.reviewNote,
    required this.reviewedAt,
    required this.createdAt,
  });
  final int id;
  final int brandId;
  final String name;
  final String? address;
  final String? category;
  final double lat;
  final double lng;
  final String? photoUrl;
  final String status;
  final String? reviewNote;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  factory LocationRegistrationRequest.fromJson(Map<String, dynamic> j) => LocationRegistrationRequest(
        id: _asInt(j['id']),
        brandId: _asInt(j['brandId']),
        name: j['name'] as String,
        address: j['address'] as String?,
        category: j['category'] as String?,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        photoUrl: j['photoUrl'] as String?,
        status: j['status'] as String,
        reviewNote: j['reviewNote'] as String?,
        reviewedAt: j['reviewedAt'] != null ? DateTime.parse(j['reviewedAt'] as String) : null,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

/// One page of `GET /location-registration-requests/mine` — `{ data, total, page, pageSize }`.
class LocationRegistrationPage {
  LocationRegistrationPage({required this.items, required this.total});
  final List<LocationRegistrationRequest> items;
  final int total;

  factory LocationRegistrationPage.fromJson(Map<String, dynamic> j) => LocationRegistrationPage(
        items: (j['data'] as List).map((e) => LocationRegistrationRequest.fromJson(e)).toList(),
        total: _asInt(j['total']),
      );
}
