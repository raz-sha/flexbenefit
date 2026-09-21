import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class UploadedFile {
  final String path;
  final String displayName;
  final DateTime? updatedAt;

  const UploadedFile({
    required this.path,
    required this.displayName,
    this.updatedAt,
  });
}

/// Handles per-user file uploads in the private "uploads" Storage bucket.
/// Objects live under "<user_id>/<timestamp>_<filename>"; RLS policies on
/// storage.objects restrict each user to their own folder (admins see all).
class StorageService {
  final SupabaseClient _client = Supabase.instance.client;
  static const _bucket = 'uploads';

  String get _ownFolder => _client.auth.currentUser!.id;

  Future<void> uploadFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final objectPath =
        '$_ownFolder/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await _client.storage.from(_bucket).uploadBinary(objectPath, bytes);
  }

  Future<List<UploadedFile>> listOwnFiles() async {
    final objects = await _client.storage.from(_bucket).list(
          path: _ownFolder,
          searchOptions: const SearchOptions(
            sortBy: SortBy(column: 'created_at', order: 'desc'),
          ),
        );
    return objects
        .map((object) => UploadedFile(
              path: '$_ownFolder/${object.name}',
              displayName: object.name.replaceFirst(RegExp(r'^\d+_'), ''),
              updatedAt: object.updatedAt != null
                  ? DateTime.tryParse(object.updatedAt!)
                  : null,
            ))
        .toList();
  }

  Future<String> createDownloadUrl(String path) {
    return _client.storage.from(_bucket).createSignedUrl(path, 60 * 10);
  }

  Future<void> deleteFile(String path) {
    return _client.storage.from(_bucket).remove([path]);
  }
}
