import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Uploads waste photo evidence to Firebase Storage and returns its
/// download URL. When [useFake] is true (preview build or demo login,
/// where there's no real Firebase project behind this session) it skips
/// the network call entirely and returns a placeholder marker instead —
/// callers should treat any non-null return as "a photo was attached."
Future<String?> uploadSubmissionPhoto({
  required String uid,
  required List<int> bytes,
  required bool useFake,
}) async {
  if (useFake) {
    return 'preview://foto-bukti-${DateTime.now().millisecondsSinceEpoch}';
  }
  final ref = FirebaseStorage.instance.ref(
    'submission_photos/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg',
  );
  await ref.putData(
    Uint8List.fromList(bytes),
    SettableMetadata(contentType: 'image/jpeg'),
  );
  return ref.getDownloadURL();
}
