import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/field_data_state.dart';
import '../theme/nocturne_theme.dart';
import '../widgets/async_state.dart';
import '../widgets/nocturne_card.dart';
import 'training_detail_screen.dart';

class TrainingTab extends StatelessWidget {
  const TrainingTab({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<FieldDataState>();
    if (data.loading) return const LoadingState();
    if (data.error != null) return ErrorState(message: data.error!, onRetry: data.loadAll);
    final trainings = data.myTrainings;
    if (trainings.isEmpty) return const EmptyState(label: 'Belum ada training terjadwal.');

    return RefreshIndicator(
      onRefresh: data.loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        itemCount: trainings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final t = trainings[i];
          final done = data.isTrainingCompleted(t);
          return NocturneCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrainingDetailScreen(training: t))),
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
                Text(t.topik, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 11, color: NocturneColors.textMuted(0.5)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${t.tanggal} · ${t.waktu} · ${t.trainer}',
                        style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.5)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
