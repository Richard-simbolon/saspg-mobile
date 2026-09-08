import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/profile_screen.dart';
import '../services/auth_state.dart';
import '../theme/nocturne_theme.dart';
import '../utils/image_provider.dart';

const _bubbleSize = 52.0;
/// Below this much total movement, a gesture counts as a tap (open profile) rather than a drag.
const _dragThreshold = 6.0;
const _prefsDxKey = 'sigraforce_bubble_dx_frac';
const _prefsDyKey = 'sigraforce_bubble_dy_frac';

/// A Messenger-style draggable chat-head that opens the SPG's own profile.
/// Lives above [MaterialApp]'s `builder`, so it persists across every pushed
/// screen app-wide, not just the bottom-nav tabs — pass [navigatorKey] (the
/// same one given to `MaterialApp(navigatorKey: ...)`) since this widget
/// sits outside the Navigator's own context and can't use `Navigator.of()`.
class FloatingProfileBubble extends StatefulWidget {
  const FloatingProfileBubble({super.key, required this.navigatorKey});
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<FloatingProfileBubble> createState() => _FloatingProfileBubbleState();
}

class _FloatingProfileBubbleState extends State<FloatingProfileBubble> {
  Offset? _position; // top-left, logical pixels
  Offset? _pendingFraction; // loaded from prefs, resolved to pixels once we know screen size
  Offset _dragAccum = Offset.zero;

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final dxFrac = prefs.getDouble(_prefsDxKey);
    final dyFrac = prefs.getDouble(_prefsDyKey);
    if (mounted && dxFrac != null && dyFrac != null) {
      setState(() => _pendingFraction = Offset(dxFrac, dyFrac));
    }
  }

  Future<void> _savePosition(Size screenSize) async {
    if (_position == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsDxKey, _position!.dx / screenSize.width);
    await prefs.setDouble(_prefsDyKey, _position!.dy / screenSize.height);
  }

  void _openProfile() {
    widget.navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    if (!auth.isLoggedIn) return const SizedBox.shrink();

    final mq = MediaQuery.of(context);
    final screenSize = mq.size;
    final safeTop = mq.padding.top + 8;
    final safeBottom = mq.padding.bottom + 8;

    // Default: bottom-right corner, just above the bottom nav bar's rightmost
    // tab (Kinerja) — only used until the SPG drags it somewhere else, after
    // which their chosen spot is remembered instead.
    final navBarClearance = safeBottom + kBottomNavigationBarHeight + 8;
    _position ??= _pendingFraction != null
        ? Offset(_pendingFraction!.dx * screenSize.width, _pendingFraction!.dy * screenSize.height)
        : Offset(screenSize.width - _bubbleSize - 8, screenSize.height - _bubbleSize - navBarClearance);

    final clamped = Offset(
      _position!.dx.clamp(4.0, screenSize.width - _bubbleSize - 4.0),
      _position!.dy.clamp(safeTop, screenSize.height - _bubbleSize - safeBottom),
    );

    final spg = auth.spgProfile;
    final photo = resolveImageProvider(spg?.photoUrl);

    return Positioned(
      left: clamped.dx,
      top: clamped.dy,
      child: GestureDetector(
        onPanStart: (_) => _dragAccum = Offset.zero,
        onPanUpdate: (details) {
          setState(() {
            _position = _position! + details.delta;
            _dragAccum += details.delta;
          });
        },
        onPanEnd: (_) {
          if (_dragAccum.distance < _dragThreshold) {
            _openProfile();
          } else {
            _savePosition(screenSize);
          }
        },
        child: Container(
          width: _bubbleSize,
          height: _bubbleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: NocturneColors.surface,
            border: Border.all(color: NocturneColors.accent, width: 2),
            image: photo != null ? DecorationImage(image: photo, fit: BoxFit.cover) : null,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: photo == null ? Icon(Icons.person, color: NocturneColors.accent, size: 26) : null,
        ),
      ),
    );
  }
}
