import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_state.dart';
import '../services/field_data_state.dart';
import '../services/theme_controller.dart';
import '../theme/nocturne_theme.dart';
import 'home_tab.dart';
import 'jadwal_tab.dart';
import 'training_tab.dart';
import 'chat_tab.dart';
import 'kinerja_tab.dart';
import 'cuti_screen.dart';
import 'payroll_screen.dart';
import 'notifications_screen.dart';
import 'shell_navigation.dart';

const _tabTitles = ['Beranda', 'Jadwal Kunjungan', 'Training Saya', 'Pesan', 'Kinerja Saya'];

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthState>();
    if (auth.user?.spgId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Akun ini bukan akun SPG. Aplikasi ini khusus untuk field app SPG.')),
        );
        auth.logout();
      });
    }
  }

  void _openDisplaySettings() {
    showDialog(
      context: context,
      builder: (dialogContext) => const _DisplaySettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // FieldDataState is provided above MaterialApp (see main.dart's _AppShell)
    // so that screens pushed via Navigator.push can read it too.
    final data = context.watch<FieldDataState>();

    return Provider<ShellNavigation>(
      create: (_) => ShellNavigation((i) => setState(() => _index = i)),
      child: Scaffold(
        backgroundColor: NocturneColors.bg,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 18,
          title: _AppBarTitle(title: _tabTitles[_index]),
          actions: [
            _NotificationBell(data: data),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.airplane_ticket_outlined, size: 18),
              tooltip: 'Cuti Saya',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CutiScreen())),
            ),
            IconButton(
              icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
              tooltip: 'Slip Gaji',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PayrollScreen())),
            ),
            IconButton(
              icon: const Icon(Icons.palette_outlined, size: 18),
              tooltip: 'Tampilan',
              onPressed: _openDisplaySettings,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: IconButton(
                icon: const Icon(Icons.logout, size: 18),
                tooltip: 'Keluar',
                onPressed: () => context.read<AuthState>().logout(),
              ),
            ),
          ],
        ),
        body: IndexedStack(
          index: _index,
          children: const [
            HomeTab(),
            JadwalTab(),
            TrainingTab(),
            ChatTab(),
            KinerjaTab(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Beranda'),
            BottomNavigationBarItem(icon: Icon(Icons.event_available_outlined), activeIcon: Icon(Icons.event_available), label: 'Jadwal'),
            BottomNavigationBarItem(icon: Icon(Icons.school_outlined), activeIcon: Icon(Icons.school), label: 'Training'),
            BottomNavigationBarItem(icon: Icon(Icons.forum_outlined), activeIcon: Icon(Icons.forum), label: 'Chat'),
            BottomNavigationBarItem(icon: Icon(Icons.emoji_events_outlined), activeIcon: Icon(Icons.emoji_events), label: 'Kinerja'),
          ],
        ),
      ),
    );
  }
}

class _DisplaySettingsDialog extends StatelessWidget {
  const _DisplaySettingsDialog();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final isDark = ThemeController.instance.isDark;
        return AlertDialog(
          backgroundColor: NocturneColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NocturneRadius.lg)),
          title: const Text('Tampilan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DisplayOption(
                icon: Icons.dark_mode_outlined,
                label: 'Nocturnal',
                description: 'Tampilan gelap — bawaan aplikasi',
                selected: isDark,
                onTap: () => ThemeController.instance.setDark(true),
              ),
              const SizedBox(height: 8),
              _DisplayOption(
                icon: Icons.light_mode_outlined,
                label: 'Light',
                description: 'Tampilan terang',
                selected: !isDark,
                onTap: () => ThemeController.instance.setDark(false),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Tutup')),
          ],
        );
      },
    );
  }
}

class _DisplayOption extends StatelessWidget {
  const _DisplayOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NocturneRadius.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? NocturneColors.accent : NocturneColors.divider),
          borderRadius: BorderRadius.circular(NocturneRadius.md),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? NocturneColors.accent : NocturneColors.textMuted(0.6)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                  Text(description, style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.55))),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle, size: 18, color: NocturneColors.accent),
          ],
        ),
      ),
    );
  }
}

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({required this.title});
  final String title;

  static String get _today {
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_today, style: TextStyle(fontSize: 11, color: NocturneColors.textMuted(0.5))),
        Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.data});
  final FieldDataState data;

  Future<void> _open(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    if (context.mounted) data.refreshNotificationCount();
  }

  @override
  Widget build(BuildContext context) {
    final unread = data.unreadNotificationCount;
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(NocturneRadius.md),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          border: Border.all(color: NocturneColors.divider),
          borderRadius: BorderRadius.circular(NocturneRadius.md),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            const Icon(Icons.notifications_none, size: 18),
            if (unread > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 15,
                  height: 15,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: NocturneColors.accent, shape: BoxShape.circle),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: NocturneColors.bg),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
