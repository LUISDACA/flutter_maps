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

  /// Elimina un objeto a partir de su URL pública de Supabase Storage.
  /// Soporta URLs del tipo:
  /// https://<project>.supabase.co/storage/v1/object/public/<bucket>/<path>
  Future<void> deleteByPublicUrl(String publicUrl) async {
    try {
      final uri = Uri.parse(publicUrl);
      final seg = uri
          .pathSegments; // e.g. ['storage','v1','object','public','bucket','a','b.jpg']
      final i = seg.indexOf('object');
      if (i == -1 || i + 2 >= seg.length) return;
      if (seg[i + 1] != 'public') return;
      final bucket = seg[i + 2];
      final pathSegments = seg.sublist(i + 3);
      if (pathSegments.isEmpty) return;
      final path = pathSegments.join('/');
      await _client.storage.from(bucket).remove([path]);
    } catch (_) {
      // Ignorar errores de parse/borrado para no bloquear el flujo
    }
  }
}
