import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/auth_state.dart';
import '../services/field_data_state.dart';
import '../services/location_service.dart';
import '../theme/nocturne_theme.dart';
import '../widgets/location_error_card.dart';
import '../widgets/nocturne_card.dart';

/// Free-roam check-in for `penjualan_keliling` SPGs — no fixed store, so unlike
/// [CheckinScreen] there's no geofence/WiFi card at all, just live GPS + selfie.
class CheckinKelilingScreen extends StatefulWidget {
  const CheckinKelilingScreen({super.key, required this.brandId});
  final int brandId;

  @override
  State<CheckinKelilingScreen> createState() => _CheckinKelilingScreenState();
}

class _CheckinKelilingScreenState extends State<CheckinKelilingScreen> {
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
      if (mounted) setState(() => _position = pos);
    } on LocationFailure catch (e) {
      if (mounted) setState(() => _locError = e);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
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

  Future<void> _checkin() async {
    final selfieUrl = _selfieUrl;
    if (_position == null || selfieUrl == null) return;
    final auth = context.read<AuthState>();
    final data = context.read<FieldDataState>();
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final record = await data.api.checkin(
        spgId: auth.user!.spgId!,
        brandId: widget.brandId,
        lat: _position!.latitude,
        lng: _position!.longitude,
        selfieUrl: selfieUrl,
      );
      if (mounted) setState(() => _result = record);
    } catch (e) {
      if (mounted) setState(() => _submitError = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Absen Masuk (Keliling)', style: TextStyle(fontSize: 16))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
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
              borderColor: NocturneColors.accent800,
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: NocturneColors.accent, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Absen keliling tidak terikat lokasi tertentu — titik GPS Anda saat ini akan dicatat.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          if (_result == null) ...[
            const Text('Selfie verifikasi (wajib)', style: TextStyle(fontSize: 12, color: Color(0x99E9E9ED))),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _takeSelfie,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(NocturneRadius.md),
                  border: Border.all(color: NocturneColors.divider),
                  image: _selfieUrl == null ? null : DecorationImage(image: NetworkImage(_selfieUrl!), fit: BoxFit.cover),
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
                onPressed: (_position != null && _selfieUrl != null && !_submitting) ? _checkin : null,
                child: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_selfieUrl == null ? 'Ambil Selfie untuk Absen Masuk' : 'Absen Masuk Sekarang'),
              ),
            ),
          ] else
            NocturneCard(
              borderColor: NocturneColors.accent800,
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: NocturneColors.accent, size: 18),
                  const SizedBox(width: 10),
                  Text('Berhasil absen masuk pukul ${_result!.checkin}', style: const TextStyle(fontSize: 12.5)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
