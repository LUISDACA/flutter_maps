import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL']?.trim() ?? '';
  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
  static String get storageBucket =>
      dotenv.env['SUPABASE_STORAGE_BUCKET']?.trim() ?? 'danger-photos';

  static void assertLoaded() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Faltan variables en .env: SUPABASE_URL y/o SUPABASE_ANON_KEY',
      );
    }
  }
}
