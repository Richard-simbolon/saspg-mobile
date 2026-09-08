import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/field_data_state.dart';
import '../theme/nocturne_theme.dart';
import '../widgets/nocturne_card.dart';

class TrainingDetailScreen extends StatefulWidget {
  const TrainingDetailScreen({super.key, required this.training});
  final TrainingSession training;

  @override
  State<TrainingDetailScreen> createState() => _TrainingDetailScreenState();
}

class _TrainingDetailScreenState extends State<TrainingDetailScreen> {
  bool _submitting = false;

  Future<void> _complete() async {
    setState(() => _submitting = true);
    try {
      await context.read<FieldDataState>().completeTraining(widget.training);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<FieldDataState>();
    final t = widget.training;
    final done = data.isTrainingCompleted(t);

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Training', style: TextStyle(fontSize: 16))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          NocturneCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    NocturneTag(t.brandName, variant: TagVariant.outline),
                    NocturneTag(done ? 'Selesai' : 'Terjadwal', variant: done ? TagVariant.accent : TagVariant.neutral),
                  ],
                ),
                const SizedBox(height: 6),
                Text(t.topik, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 12, color: NocturneColors.textMuted(0.5)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${t.tanggal} · ${t.waktu} · Trainer: ${t.trainer}',
                        style: TextStyle(fontSize: 11.5, color: NocturneColors.textMuted(0.5)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Materi Product Knowledge', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          NocturneCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: NocturneColors.textMuted(0.5)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Materi lengkap akan dibagikan oleh trainer secara langsung saat sesi berlangsung. Tandai selesai setelah Anda mengikuti training ini.',
                    style: TextStyle(fontSize: 12.5, color: NocturneColors.textMuted(0.75), height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (!done)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _submitting ? null : _complete,
                child: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Tandai Selesai Mengikuti'),
              ),
            )
          else
            NocturneCard(
              borderColor: NocturneColors.accent800,
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: NocturneColors.accent, size: 18),
                  const SizedBox(width: 10),
                  const Text('Anda sudah menyelesaikan training ini', style: TextStyle(fontSize: 12.5)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
