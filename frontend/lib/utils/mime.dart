/// Best-effort MIME type for an uploaded file.
///
/// Evidence upload used to send a hardcoded `image/png` for every file. But
/// `image_picker` re-encodes to JPEG whenever `imageQuality`/`maxWidth` are set
/// (as they are here), so a gallery photo was stored and later served with the
/// wrong content type. Prefer what the platform reports, then fall back to the
/// extension, and only give up with a generic binary type.
String mimeTypeForFile(String pathOrName, {String? reported}) {
  final trimmed = reported?.trim();
  if (trimmed != null && trimmed.isNotEmpty && trimmed != 'application/octet-stream') {
    return trimmed;
  }

  // Only the basename matters: a dotted *directory* such as `/tmp/my.photos/x`
  // must not be read as the extension of the file.
  final base = pathOrName.split(RegExp(r'[/\\]')).last;
  final dot = base.lastIndexOf('.');
  final ext = dot <= 0 ? '' : base.substring(dot + 1).toLowerCase();

  switch (ext) {
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'bmp':
      return 'image/bmp';
    case 'heic':
      return 'image/heic';
    case 'pdf':
      return 'application/pdf';
    case 'mp4':
      return 'video/mp4';
    case 'mov':
      return 'video/quicktime';
    case 'webm':
      return 'video/webm';
    default:
      return 'application/octet-stream';
  }
}
