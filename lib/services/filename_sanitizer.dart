/// Filename sanitisation shared by the camera API (download naming) and the
/// platform file savers (save boundary, defense in depth).
library;

/// Return a filename safe to append to a local directory, stripping any
/// path separators, `..`, NUL bytes, control and reserved characters. Used
/// to defend against path traversal via a hostile/corrupt camera response.
String sanitizeFilename(String raw) {
  // Keep only the last path segment; reject any separator chars.
  final base = raw.split(RegExp(r'[/\\]')).last;
  final cleaned = base
      .replaceAll('\u0000', '')
      .replaceAll(RegExp(r'[\x00-\x1F]'), '')
      .replaceAll(RegExp(r'[<>:"|?*]'), '_')
      .trim();
  // Reject traversal and empty/dot-only names.
  if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
    return 'file_${DateTime.now().millisecondsSinceEpoch}';
  }
  // Cap length to something sane.
  return cleaned.length > 180 ? cleaned.substring(0, 180) : cleaned;
}
