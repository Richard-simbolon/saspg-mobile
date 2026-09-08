import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/auth_state.dart';
import '../services/field_data_state.dart';
import '../theme/nocturne_theme.dart';
import 'nocturne_card.dart';

const _lunchReason = 'Istirahat Makan Siang';

/// Lets an SPG log time away from duty during a visit — sholat, toilet, or
/// anything else via free text, plus a one-tap Lunch Break shortcut — each
/// with a real start time and (once closed) end time.
class ActivityLogSection extends StatefulWidget {
  const ActivityLogSection({super.key, required this.brandId, required this.outlet});
  final int brandId;
  final String outlet;

  @override
  State<ActivityLogSection> createState() => _ActivityLogSectionState();
}

class _ActivityLogSectionState extends State<ActivityLogSection> {
  List<ActivityLog> _activities = [];
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthState>();
    final api = context.read<FieldDataState>().api;
    try {
      final activities = await api.listActivityLogs(spgId: auth.user!.spgId!, brandId: widget.brandId, outlet: widget.outlet);
      if (mounted) setState(() => _activities = activities);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ActivityLog? get _ongoing {
    for (final a in _activities) {
      if (a.isOngoing) return a;
    }
    return null;
  }

  bool get _lunchOngoing => _ongoing?.reason == _lunchReason;

  Future<void> _start(String reason) async {
    setState(() => _busy = true);
    final auth = context.read<AuthState>();
    final api = context.read<FieldDataState>().api;
    try {
      await api.startActivity(spgId: auth.user!.spgId!, brandId: widget.brandId, outlet: widget.outlet, reason: reason);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _end(ActivityLog activity) async {
    setState(() => _busy = true);
    final api = context.read<FieldDataState>().api;
    try {
      await api.endActivity(activity.id);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAddDialog() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NocturneColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NocturneRadius.lg)),
        title: const Text('Tambah Aktivitas', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'mis. Sholat, Ke toilet, ...'),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(ctrl.text), child: const Text('Mulai')),
        ],
      ),
    );
    if (reason != null && reason.trim().isNotEmpty) {
      await _start(reason.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Aktivitas Lapangan', style: TextStyle(fontSize: 12, letterSpacing: 0.5, color: NocturneColors.accent)),
        const SizedBox(height: 8),
        NocturneCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy || (_ongoing != null && !_lunchOngoing) ? null : () => _start(_lunchReason),
                      icon: const Icon(Icons.lunch_dining_outlined, size: 15),
                      label: const Text('Mulai Lunch Break', style: TextStyle(fontSize: 12.5)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy || !_lunchOngoing ? null : () => _end(_ongoing!),
                      icon: const Icon(Icons.check, size: 15),
                      label: const Text('Selesai Lunch Break', style: TextStyle(fontSize: 12.5)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _busy || (_ongoing != null && !_lunchOngoing) ? null : _openAddDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Tambah Aktivitas Lain (Sholat, Toilet, dll.)', style: TextStyle(fontSize: 12.5)),
                ),
              ),
              if (_loading) ...[
                const SizedBox(height: 8),
                const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
              ] else if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: NocturneColors.danger, fontSize: 12)),
              ] else if (_activities.isNotEmpty) ...[
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: NocturneDivider()),
                ..._activities.map((a) => _ActivityRow(activity: a, busy: _busy, onEnd: () => _end(a))),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity, required this.busy, required this.onEnd});
  final ActivityLog activity;
  final bool busy;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.reason, style: const TextStyle(fontSize: 13)),
                Text(
                  activity.isOngoing
                      ? '${activity.startTime} — berlangsung…'
                      : '${activity.startTime} – ${activity.endTime} (${activity.durationMinutes} mnt)',
                  style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.5)),
                ),
              ],
            ),
          ),
          if (activity.isOngoing)
            TextButton(
              onPressed: busy ? null : onEnd,
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
              child: const Text('Selesai', style: TextStyle(fontSize: 12)),
            )
          else
            const NocturneTag('Selesai', variant: TagVariant.neutral),
        ],
      ),
    );
  }
}
