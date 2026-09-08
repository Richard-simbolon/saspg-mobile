import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// Fallback base URL, only used the very first time the app runs (before the SPG has ever set
/// a server address from the login screen). Override at build time with
/// `--dart-define=API_BASE_URL=http://10.0.2.2:3000/api` (Android emulator) or your machine's
/// LAN IP (physical device) — but since the LAN IP changes, [ApiClient.baseUrl] is the real,
/// day-to-day way to point the app at a server: it's mutable at runtime and persisted by
/// [ServerConfig], so switching servers never requires a rebuild.
const String defaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000/api',
);

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({this.token, String? baseUrl})
    : baseUrl = baseUrl ?? defaultApiBaseUrl;
  String? token;

  /// Mutable — [ServerConfig]/[AuthState.setServerUrl] update this at runtime when the SPG
  /// changes the server address, no rebuild needed.
  String baseUrl;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v != null && v != '') q[k] = v.toString();
    });
    return Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: q.isEmpty ? null : q);
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    String message = 'Terjadi kesalahan (${res.statusCode})';
    try {
      final body = jsonDecode(res.body);
      final m = body['message'];
      message = m is List ? m.join(', ') : (m?.toString() ?? message);
    } catch (_) {}
    throw ApiException(res.statusCode, message);
  }

  Future<dynamic> get(String path, [Map<String, dynamic>? query]) async {
    final res = await http.get(_uri(path, query), headers: _headers);
    return _decode(res);
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final res = await http.post(
      _uri(path),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async {
    final res = await http.patch(
      _uri(path),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) async {
    final res = await http.put(
      _uri(path),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  // ── Uploads ───────────────────────────────────────────────────────────
  /// Uploads [file] and returns its public URL — every photo/document field downstream
  /// (selfieUrl, photoUrls, attachmentUrl) is this URL, never an embedded base64 blob.
  Future<String> uploadFile(File file) async {
    final request = http.MultipartRequest('POST', _uri('/uploads'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    final body = _decode(res) as Map<String, dynamic>;
    return body['url'] as String;
  }

  // ── Auth ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await post('/auth/login', {
      'username': username,
      'password': password,
    });
    return res as Map<String, dynamic>;
  }

  // ── SPG ───────────────────────────────────────────────────────────────
  Future<Spg> getSpg(int id) async => Spg.fromJson(await get('/spg/$id'));

  /// WhatsApp-style "about" text on the SPG's own profile — null/empty clears it.
  Future<Spg> updateStatusNote(int spgId, String? statusNote) async =>
      Spg.fromJson(
        await patch('/spg/$spgId/status-note', {'statusNote': statusNote}),
      );
  Future<List<Spg>> listSpg() async =>
      (await get('/spg') as List).map((e) => Spg.fromJson(e)).toList();

  // ── Brands ────────────────────────────────────────────────────────────
  Future<List<Brand>> listBrands() async =>
      (await get('/brands') as List).map((e) => Brand.fromJson(e)).toList();
  Future<Brand> getBrand(int id) async =>
      Brand.fromJson(await get('/brands/$id'));

  Future<List<OutletLocation>> listLocations(
    int brandId, {
    String brandName = '',
  }) async => (await get('/brands/$brandId/locations') as List)
      .map((e) => OutletLocation.fromJson(e, brandName: brandName))
      .toList();

  /// Resolved shift schedule for every day in [from, to] — the source of truth for the Jadwal
  /// calendar's arbitrary-date lookups. Keyed by "YYYY-MM-DD".
  Future<Map<String, List<BrandScheduleEntry>>> getBrandSchedule(
    int brandId,
    String from,
    String to,
  ) async {
    final raw =
        await get('/brands/$brandId/schedule', {'from': from, 'to': to})
            as List;
    return {
      for (final d in raw)
        (d as Map<String, dynamic>)['date']
            as String: ((d['entries'] as List?) ?? [])
            .map((e) => BrandScheduleEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
    };
  }

  // ── Attendance ────────────────────────────────────────────────────────
  Future<List<AttendanceRecord>> attendanceToday(int spgId) async =>
      (await get('/attendance/today/$spgId') as List)
          .map((e) => AttendanceRecord.fromJson(e))
          .toList();

  /// Full attendance history for this SPG (not just today) — used to build the Activity feed.
  Future<List<AttendanceRecord>> listAttendanceForSpg(int spgId) async =>
      (await get('/attendance', {'spgId': spgId}) as List)
          .map((e) => AttendanceRecord.fromJson(e))
          .toList();

  /// Exactly one of [locationId] / [trainingSessionId] — a store check-in or a
  /// full-day training check-in.
  /// [selfieUrl] is required — the backend rejects a check-in without one, so callers must
  /// have a captured/uploaded selfie in hand before ever reaching this method.
  Future<AttendanceRecord> checkin({
    required int spgId,
    required int brandId,
    int? locationId,
    int? trainingSessionId,
    required double lat,
    required double lng,
    required String selfieUrl,
    String? wifiSsid,
  }) async {
    final res = await post('/attendance/checkin', {
      'spgId': spgId,
      'brandId': brandId,
      if (locationId != null) 'locationId': locationId,
      if (trainingSessionId != null) 'trainingSessionId': trainingSessionId,
      'lat': lat,
      'lng': lng,
      'selfieUrl': selfieUrl,
      if (wifiSsid != null) 'wifiSsid': wifiSsid,
    });
    return AttendanceRecord.fromJson(res);
  }

  /// Wherever the SPG is checking out FROM right now — on a multi-store day this
  /// may be a different outlet than the one they checked in at, so it's validated
  /// separately, not inferred from the original check-in record. Exactly one of
  /// [locationId] / [trainingSessionId].
  Future<AttendanceRecord> checkout({
    required int attendanceId,
    int? locationId,
    int? trainingSessionId,
    required double lat,
    required double lng,
    String? selfieUrl,
    String? wifiSsid,
  }) async {
    final res = await post('/attendance/checkout', {
      'attendanceId': attendanceId,
      if (locationId != null) 'locationId': locationId,
      if (trainingSessionId != null) 'trainingSessionId': trainingSessionId,
      'lat': lat,
      'lng': lng,
      if (selfieUrl != null) 'selfieUrl': selfieUrl,
      if (wifiSsid != null) 'wifiSsid': wifiSsid,
    });
    return AttendanceRecord.fromJson(res);
  }

  // ── Tracking ──────────────────────────────────────────────────────────
  Future<void> upsertTracking({
    required int spgId,
    required String outlet,
    required double lat,
    required double lng,
    required bool online,
  }) => post('/tracking', {
    'spgId': spgId,
    'outlet': outlet,
    'lat': lat,
    'lng': lng,
    'online': online,
  });

  // ── Approvals (Laporan Kunjungan + Foto Bukti) ──────────────────────────
  Future<ApprovalReport> createApproval({
    required int spgId,
    required int brandId,
    required String outlet,
    required String note,
    required double lat,
    required double lng,
    String? wifiSsid,
  }) async => ApprovalReport.fromJson(
    await post('/approvals', {
      'spgId': spgId,
      'brandId': brandId,
      'outlet': outlet,
      'note': note,
      'lat': lat,
      'lng': lng,
      if (wifiSsid != null) 'wifiSsid': wifiSsid,
    }),
  );

  Future<ApprovalReport> addApprovalPhotos(
    int id,
    List<String> photoUrls, {
    required double lat,
    required double lng,
    String? wifiSsid,
  }) async => ApprovalReport.fromJson(
    await patch('/approvals/$id/photos', {
      'photoUrls': photoUrls,
      'lat': lat,
      'lng': lng,
      if (wifiSsid != null) 'wifiSsid': wifiSsid,
    }),
  );

  Future<List<ApprovalReport>> listApprovals({
    int? spgId,
    String? date,
  }) async => (await get('/approvals', {'spgId': spgId, 'date': date}) as List)
      .map((e) => ApprovalReport.fromJson(e))
      .toList();

  Future<ApprovalReport> getApproval(int id) async =>
      ApprovalReport.fromJson(await get('/approvals/$id'));

  Future<List<ApprovalComment>> listApprovalComments(int approvalId) async =>
      (await get('/approvals/$approvalId/comments') as List)
          .map((e) => ApprovalComment.fromJson(e))
          .toList();

  // ── Competitor activities (Aktivitas Kompetitor) ────────────────────
  Future<CompetitorActivity> createCompetitorActivity({
    required int spgId,
    required int brandId,
    required String outlet,
    required String title,
    required String description,
    List<String>? photoUrls,
    required double lat,
    required double lng,
    String? wifiSsid,
  }) async => CompetitorActivity.fromJson(
    await post('/competitor-activities', {
      'spgId': spgId,
      'brandId': brandId,
      'outlet': outlet,
      'title': title,
      'description': description,
      if (photoUrls != null && photoUrls.isNotEmpty) 'photoUrls': photoUrls,
      'lat': lat,
      'lng': lng,
      if (wifiSsid != null) 'wifiSsid': wifiSsid,
    }),
  );

  Future<List<CompetitorActivity>> listCompetitorActivities({
    int? spgId,
    String? date,
  }) async =>
      (await get('/competitor-activities', {'spgId': spgId, 'date': date})
              as List)
          .map((e) => CompetitorActivity.fromJson(e))
          .toList();

  // ── Stock checks (buka/tutup, per produk) ───────────────────────────
  Future<List<StockCheck>> listStockChecks({
    required int spgId,
    required int brandId,
    required String outlet,
  }) async =>
      (await get('/stock-checks', {
                'spgId': spgId,
                'brandId': brandId,
                'outlet': outlet,
              })
              as List)
          .map((e) => StockCheck.fromJson(e))
          .toList();

  Future<StockCheck> upsertStockCheck({
    required int spgId,
    required int brandId,
    required String outlet,
    required int productId,
    int? stockOpen,
    int? stockClose,
  }) async {
    final res = await put('/stock-checks', {
      'spgId': spgId,
      'brandId': brandId,
      'outlet': outlet,
      'productId': productId,
      if (stockOpen != null) 'stockOpen': stockOpen,
      if (stockClose != null) 'stockClose': stockClose,
    });
    return StockCheck.fromJson(res);
  }

  // ── Daily sales reports ──────────────────────────────────────────────
  Future<DailySalesReport> createDailySalesReport({
    required int spgId,
    required int brandId,
    required String outlet,
    required String date,
    required List<Map<String, int>> items,
    required double lat,
    required double lng,
    String? wifiSsid,
  }) async => DailySalesReport.fromJson(
    await post('/daily-sales-reports', {
      'spgId': spgId,
      'brandId': brandId,
      'outlet': outlet,
      'date': date,
      'items': items,
      'lat': lat,
      'lng': lng,
      if (wifiSsid != null) 'wifiSsid': wifiSsid,
    }),
  );

  Future<List<DailySalesReport>> listDailySalesReports({int? spgId}) async =>
      (await get('/daily-sales-reports', {'spgId': spgId}) as List)
          .map((e) => DailySalesReport.fromJson(e))
          .toList();

  // ── Training completions ────────────────────────────────────────────
  Future<List<int>> listTrainingCompletions(
    int brandId,
    int trainingId,
  ) async =>
      (await get('/brands/$brandId/training/$trainingId/completions') as List)
          .map((e) => e as int)
          .toList();

  Future<void> markTrainingCompletion(int brandId, int trainingId, int spgId) =>
      post('/brands/$brandId/training/$trainingId/completions', {
        'spgId': spgId,
      });

  // ── Field reports supporting data ───────────────────────────────────
  Future<List<Map<String, dynamic>>> listAttendance({int? brandId}) async =>
      (await get('/attendance', {'brandId': brandId}) as List)
          .cast<Map<String, dynamic>>();

  // ── Activity logs (sholat, toilet, lunch break, dll.) ───────────────
  Future<List<ActivityLog>> listActivityLogs({
    required int spgId,
    required int brandId,
    required String outlet,
  }) async =>
      (await get('/activity-logs', {
                'spgId': spgId,
                'brandId': brandId,
                'outlet': outlet,
              })
              as List)
          .map((e) => ActivityLog.fromJson(e))
          .toList();

  Future<ActivityLog> startActivity({
    required int spgId,
    required int brandId,
    required String outlet,
    required String reason,
  }) async => ActivityLog.fromJson(
    await post('/activity-logs', {
      'spgId': spgId,
      'brandId': brandId,
      'outlet': outlet,
      'reason': reason,
    }),
  );

  Future<ActivityLog> endActivity(int id) async =>
      ActivityLog.fromJson(await patch('/activity-logs/$id/end'));

  // ── Visit sessions (Mulai/Akhiri Kunjungan) ──────────────────────────
  Future<List<VisitSession>> listVisitSessions({
    int? spgId,
    int? brandId,
    String? outlet,
    String? date,
  }) async =>
      (await get('/visit-sessions', {
                'spgId': spgId,
                'brandId': brandId,
                'outlet': outlet,
                'date': date,
              })
              as List)
          .map((e) => VisitSession.fromJson(e))
          .toList();

  Future<VisitSession> startVisitSession({
    required int spgId,
    required int brandId,
    required String outlet,
  }) async => VisitSession.fromJson(
    await post('/visit-sessions', {
      'spgId': spgId,
      'brandId': brandId,
      'outlet': outlet,
    }),
  );

  Future<VisitSession> endVisitSession(int id) async =>
      VisitSession.fromJson(await patch('/visit-sessions/$id/end'));

  // ── Notifications ────────────────────────────────────────────────────
  Future<List<AppNotification>> listNotifications() async =>
      (await get('/notifications') as List)
          .map((e) => AppNotification.fromJson(e))
          .toList();

  Future<int> unreadNotificationCount() async {
    final count = (await get('/notifications/unread-count'))['count'];
    return count is int ? count : (count as num).toInt();
  }

  Future<AppNotification> markNotificationRead(int id) async =>
      AppNotification.fromJson(await patch('/notifications/$id/read'));

  // ── Cuti (leave requests) ────────────────────────────────────────────
  Future<List<LeaveRequest>> listMyLeaveRequests(int spgId) async =>
      (await get('/leave-requests', {'spgId': spgId}) as List)
          .map((e) => LeaveRequest.fromJson(e))
          .toList();

  Future<LeaveRequest> requestLeave({
    required String type,
    required String startDate,
    required String endDate,
    String? reason,
    String? attachmentUrl,
  }) async => LeaveRequest.fromJson(
    await post('/leave-requests', {
      'type': type,
      'startDate': startDate,
      'endDate': endDate,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
    }),
  );

  /// "Sisa cuti tahunan" for the signed-in SPG — defaults to the current year.
  Future<LeaveBalance> getLeaveBalance(int spgId, {int? year}) async =>
      LeaveBalance.fromJson(
        await get('/leave-requests/balance', {
          'spgId': spgId,
          if (year != null) 'year': year,
        }),
      );

  // ── Payroll (slip gaji) ──────────────────────────────────────────────
  Future<List<Payslip>> listMyPayslips() async =>
      (await get('/payroll/me') as List)
          .map((e) => Payslip.fromJson(e))
          .toList();

  void log(String message) {
    if (kDebugMode) debugPrint('[ApiClient] $message');
  }
}
