import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../theme/nocturne_theme.dart';
import 'nocturne_card.dart';

/// Shown whenever a GPS/location request fails — explains why, and gives a
/// direct shortcut into the device's Location (or app permission) settings
/// instead of leaving the SPG to go hunt for it themselves.
class LocationErrorCard extends StatelessWidget {
  const LocationErrorCard({super.key, required this.failure, required this.onRetry});
  final LocationFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return NocturneCard(
      borderColor: NocturneColors.dangerBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: NocturneColors.danger, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(failure.message, style: const TextStyle(fontSize: 12.5))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (failure.reason != LocationFailureReason.permissionDenied &&
                  failure.reason != LocationFailureReason.mockLocationDetected) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: failure.reason == LocationFailureReason.serviceDisabled
                        ? Geolocator.openLocationSettings
                        : Geolocator.openAppSettings,
                    child: Text(
                      failure.reason == LocationFailureReason.serviceDisabled ? 'Aktifkan GPS' : 'Buka Pengaturan Aplikasi',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Coba Lagi', style: TextStyle(fontSize: 12.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
