import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Lets a tab (e.g. Home's "Lihat semua") switch the bottom-nav tab it's
/// hosted in, without the tab widgets needing to know about ShellScreen.
class ShellNavigation {
  ShellNavigation(this._setIndex);
  final void Function(int) _setIndex;

  static void goToTab(BuildContext context, int index) {
    context.read<ShellNavigation>()._setIndex(index);
  }
}
