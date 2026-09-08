import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/field_data_state.dart';
import '../services/location_service.dart';
import '../theme/nocturne_theme.dart';
import '../utils/image_provider.dart';
import '../widgets/location_error_card.dart';
import '../widgets/nocturne_card.dart';

/// Check-out for a full-day training — mirrors `CheckoutScreen`'s GPS/selfie
/// flow, validated against the training's own venue geofence.
class TrainingCheckoutScreen extends StatefulWidget {
  const TrainingCheckoutScreen({super.key, required this.training, required this.attendance});
  final TrainingSession training;
  final AttendanceRecord attendance;

  @override
  State<TrainingCheckoutScreen> createState() => _TrainingCheckoutScreenState();
}

class _TrainingCheckoutScreenState extends State<TrainingCheckoutScreen> {
  Position? _position;
  LocationFailure? _locError;
  bool _locating = true;
  String? _selfieUrl;
  bool _uploadingSelfie = false;
  bool _submitting = false;
  AttendanceRecord? _result;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locError = null;
    });
    try {
      final pos = await LocationService.getPosition();
      if (!mounted) return;
      setState(() => _position = pos);
    } on LocationFailure catch (e) {
      if (mounted) setState(() => _locError = e);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  double? get _distance {
    final t = widget.training;
    if (_position == null || t.lat == null || t.lng == null) return null;
    return Geolocator.distanceBetween(_position!.latitude, _position!.longitude, t.lat!, t.lng!);
  }

  bool get _withinRadius {
    final d = _distance;
    if (d == null) return true;
    return d <= (widget.training.radiusMeters ?? 100);
  }

  Future<void> _takeSelfie() async {
    final api = context.read<FieldDataState>().api;
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 480,
        imageQuality: 70,
      );
      if (file == null) return;
      setState(() => _uploadingSelfie = true);
      final url = await api.uploadFile(File(file.path));
      if (mounted) setState(() => _selfieUrl = url);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengambil foto: $e')));
    } finally {
      if (mounted) setState(() => _uploadingSelfie = false);
    }
  }

  Future<void> _checkout() async {
    if (_position == null) return;
    final data = context.read<FieldDataState>();
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final record = await data.api.checkout(
        attendanceId: widget.attendance.id,
        trainingSessionId: widget.training.id,
        lat: _position!.latitude,
        lng: _position!.longitude,
        selfieUrl: _selfieUrl,
      );
      if (mounted) setState(() => _result = record);
    } catch (e) {
      if (mounted) setState(() => _submitError = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  ImageProvider? _selfieImage(String? url) => resolveImageProvider(url);

  @override
  Widget build(BuildContext context) {
    final venue = widget.training.venueName?.trim().isNotEmpty == true ? widget.training.venueName! : widget.training.topik;
    return Scaffold(
      appBar: AppBar(title: const Text('Check-out Training', style: TextStyle(fontSize: 16))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          NocturneCard(
            borderColor: NocturneColors.divider,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NocturneColors.bg,
                    image: _selfieImage(widget.attendance.checkinSelfieUrl) == null
                        ? null
                        : DecorationImage(image: _selfieImage(widget.attendance.checkinSelfieUrl)!, fit: BoxFit.cover),
                  ),
                  child: _selfieImage(widget.attendance.checkinSelfieUrl) == null
                      ? Icon(Icons.person_outline, size: 18, color: NocturneColors.textMuted(0.4))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Anda check-in training pukul ${widget.attendance.checkin} di $venue',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_locating)
            const NocturneCard(
              child: Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('Mencari lokasi GPS…', style: TextStyle(fontSize: 13)),
                ],
              ),
            )
          else if (_locError != null)
            LocationErrorCard(failure: _locError!, onRetry: _locate)
          else if (_result == null)
            NocturneCard(
              borderColor: _withinRadius ? NocturneColors.accent800 : NocturneColors.dangerBorder,
              child: Row(
                children: [
                  Icon(
                    _withinRadius ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: _withinRadius ? NocturneColors.accent : NocturneColors.danger,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _withinRadius
                          ? 'Anda berada dalam radius ${widget.training.radiusMeters ?? 100}m dari $venue. Check-out diizinkan.'
                          : 'Lokasi di luar radius training (jarak ${_distance!.round()}m). Check-out diblokir.',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          if (_result == null) ...[
            const Text('Selfie verifikasi check-out', style: TextStyle(fontSize: 12, color: Color(0x99E9E9ED))),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _takeSelfie,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(NocturneRadius.md),
                  border: Border.all(color: NocturneColors.divider),
                  image: _selfieUrl == null
                      ? null
                      : DecorationImage(image: NetworkImage(_selfieUrl!), fit: BoxFit.cover),
                ),
                child: _uploadingSelfie
                    ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                    : _selfieUrl == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt_outlined, color: NocturneColors.textMuted(0.5)),
                              const SizedBox(height: 4),
                              Text('Ambil foto selfie', style: TextStyle(fontSize: 10, color: NocturneColors.textMuted(0.5))),
                            ],
                          )
                        : null,
              ),
            ),
            const SizedBox(height: 14),
            NocturneCard(
              borderColor: NocturneColors.divider,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Koordinat: ${_position != null ? '${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}' : '-'}',
                    style: TextStyle(fontSize: 12, color: NocturneColors.textMuted(0.6)),
                  ),
                  const SizedBox(height: 4),
                  Text('Waktu: ${TimeOfDay.now().format(context)}', style: TextStyle(fontSize: 12, color: NocturneColors.textMuted(0.6))),
                ],
              ),
            ),
            if (_submitError != null) ...[
              const SizedBox(height: 10),
              Text(_submitError!, style: TextStyle(color: NocturneColors.danger, fontSize: 12.5)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: (_position != null && _withinRadius && !_submitting) ? _checkout : null,
                child: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Check-out Sekarang'),
              ),
            ),
          ] else ...[
            NocturneCard(
              borderColor: NocturneColors.accent800,
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: NocturneColors.accent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Berhasil check-out pukul ${_result!.checkout} (${_result!.durationMinutes} menit di training)',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kembali ke Beranda'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
