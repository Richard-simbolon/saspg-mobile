import 'dart:convert';
import 'package:flutter/widgets.dart';

/// Resolves a stored photo/document field to the right [ImageProvider].
///
/// Records created before the file-upload migration still hold a base64
/// `data:` URI; anything uploaded since holds a real URL from `POST /uploads`.
/// Returns null for null/empty input or a malformed data URI.
ImageProvider? resolveImageProvider(String? value) {
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('data:')) {
    final comma = value.indexOf(',');
    if (comma == -1) return null;
    try {
      return MemoryImage(base64Decode(value.substring(comma + 1)));
    } catch (_) {
      return null;
    }
  }
  return NetworkImage(value);
}
