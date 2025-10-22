import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config.dart';

class StorageService {
  final SupabaseClient _client;
  StorageService(this._client);

  Future<String> uploadPublicBytes({
    required Uint8List bytes,
    required String path, // "<userId>/<uuid>.jpg"
    String contentType = 'image/jpeg',
  }) async {
    final storage = _client.storage.from(AppConfig.storageBucket);
    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: true,
      ),
    );
    return storage.getPublicUrl(path);
  }
}
