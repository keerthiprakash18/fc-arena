import 'package:flutter_test/flutter_test.dart';

import 'package:fc_arena/utils/mime.dart';

void main() {
  group('mimeTypeForFile', () {
    test('falls back to the extension when nothing is reported', () {
      expect(mimeTypeForFile('evidence.jpg'), 'image/jpeg');
      expect(mimeTypeForFile('evidence.jpeg'), 'image/jpeg');
      expect(mimeTypeForFile('evidence.png'), 'image/png');
      expect(mimeTypeForFile('evidence.webp'), 'image/webp');
      expect(mimeTypeForFile('report.pdf'), 'application/pdf');
    });

    test('is case-insensitive about the extension', () {
      expect(mimeTypeForFile('EVIDENCE.JPG'), 'image/jpeg');
      expect(mimeTypeForFile('Evidence.PnG'), 'image/png');
    });

    test('prefers the type the platform reported', () {
      expect(
        mimeTypeForFile('evidence.jpg', reported: 'image/heic'),
        'image/heic',
        reason: 'the picker knows better than the extension',
      );
    });

    test('ignores a blank or generic reported type', () {
      expect(mimeTypeForFile('evidence.jpg', reported: ''), 'image/jpeg');
      expect(mimeTypeForFile('evidence.jpg', reported: '   '), 'image/jpeg');
      expect(
        mimeTypeForFile('evidence.png', reported: 'application/octet-stream'),
        'image/png',
        reason: 'a generic type carries no information',
      );
    });

    test('handles a full path and a name with no extension', () {
      expect(mimeTypeForFile('/tmp/uploads/a/b/photo.jpeg'), 'image/jpeg');
      expect(mimeTypeForFile('noextension'), 'application/octet-stream');
    });

    test('does not mistake a dotted directory for an extension', () {
      expect(
        mimeTypeForFile('/tmp/my.photos/evidence'),
        'application/octet-stream',
        reason: 'the last dot is inside a directory, not the file name',
      );
    });
  });
}
