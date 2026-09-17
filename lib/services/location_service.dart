import 'package:geolocator/geolocator.dart';

/// Why a location request failed — lets the UI offer the right shortcut
/// (open Location settings vs. open the app's own permission settings)
/// instead of just showing text and leaving the SPG to hunt for it.
enum LocationFailureReason { serviceDisabled, permissionDenied, permissionDeniedForever, mockLocationDetected }

class LocationFailure implements Exception {
  LocationFailure(this.message, this.reason);
  final String message;
  final LocationFailureReason reason;
  @override
  String toString() => message;
}

class LocationService {
  /// Best-effort current position — returns null instead of throwing, for
  /// screens where GPS is a nice-to-have (distance labels) rather than a
  /// hard requirement.
  static Future<Position?> tryGetPosition() async {
    try {
      return await getPosition();
    } catch (_) {
      return null;
    }
  }

  /// Strict current position — throws [LocationFailure] with a user-facing
  /// message, for flows where GPS is required (check-in).
  static Future<Position> getPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationFailure(
        'Layanan lokasi (GPS) tidak aktif. Aktifkan GPS terlebih dahulu.',
        LocationFailureReason.serviceDisabled,
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationFailure(
          'Izin lokasi ditolak. Aplikasi memerlukan akses lokasi untuk melanjutkan.',
          LocationFailureReason.permissionDenied,
        );
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationFailure(
        'Izin lokasi diblokir permanen. Aktifkan dari pengaturan aplikasi.',
        LocationFailureReason.permissionDeniedForever,
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    // isMocked comes from the OS itself (Android's isFromMockProvider / iOS 15+'s
    // isSimulatedBySoftware) — this is what catches the standard "fake GPS" app
    // cheating method, which the geofence/WiFi checks alone can't tell apart from a real visit.
    if (position.isMocked) {
      throw LocationFailure(
        'Lokasi GPS terdeteksi palsu (mock/fake GPS). Nonaktifkan aplikasi fake GPS lalu coba lagi.',
        LocationFailureReason.mockLocationDetected,
      );
    }
    return position;
  }
}
