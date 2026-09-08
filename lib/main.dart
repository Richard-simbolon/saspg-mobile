import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'services/auth_state.dart';
import 'services/field_data_state.dart';
import 'services/theme_controller.dart';
import 'theme/nocturne_theme.dart';
import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';
import 'widgets/floating_profile_bubble.dart';

/// Shared with [FloatingProfileBubble], which sits above [MaterialApp]'s
/// `builder` (outside the Navigator's own BuildContext) and so can't reach
/// it via `Navigator.of(context)`.
final rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  ThemeController.instance.load();
  runApp(const SigraForceApp());
}

class SigraForceApp extends StatelessWidget {
  const SigraForceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthState()..restore(),
      child: const _AppShell(),
    );
  }
}

/// Provides [FieldDataState] above [MaterialApp] (i.e. above its Navigator),
/// so screens pushed via `Navigator.push` from anywhere in the app — not
/// just widgets inside ShellScreen's own subtree — can still read it. A
/// provider declared *inside* a route's content is invisible to sibling
/// routes pushed on the same Navigator, which is why it lives here instead
/// of inside ShellScreen. Keyed by spgId so a different SPG logging in
/// (or logging out) gets a fresh instance instead of stale cached data.
class _AppShell extends StatelessWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final spgId = auth.user?.spgId;

    return ChangeNotifierProvider<FieldDataState>(
      key: ValueKey(spgId),
      create: (_) {
        final state = FieldDataState(api: auth.api, spgId: spgId ?? -1);
        if (spgId != null) state.loadAll();
        return state;
      },
      child: ListenableBuilder(
        listenable: ThemeController.instance,
        builder: (context, _) => MaterialApp(
          title: 'One Big Circle (OBC)',
          debugShowCheckedModeBanner: false,
          theme: buildNocturneTheme(),
          navigatorKey: rootNavigatorKey,
          home: const _Gate(),
          builder: (context, child) => Stack(
            children: [
              if (child != null) child,
              FloatingProfileBubble(navigatorKey: rootNavigatorKey),
            ],
          ),
        ),
      ),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    if (auth.restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return auth.isLoggedIn ? const ShellScreen() : const LoginScreen();
  }
}
