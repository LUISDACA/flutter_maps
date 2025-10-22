import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/danger_zone.dart';

class DangerZoneRepository {
  final SupabaseClient _client;
  DangerZoneRepository(this._client);

  Future<List<DangerZone>> fetchAll({int limit = 500}) async {
    final res = await _client
        .from('danger_zones')
        .select('*')
        .order('created_at', ascending: false)
        .limit(limit);
    return (res as List<dynamic>)
        .map((e) => DangerZone.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<DangerZone>> fetchInBounds({
    required double south,
    required double west,
    required double north,
    required double east,
    int limit = 1000,
  }) async {
    final res = await _client
        .from('danger_zones')
        .select('*')
        .gte('lat', south)
        .lte('lat', north)
        .gte('lng', west)
        .lte('lng', east)
        .order('created_at', ascending: false)
        .limit(limit);
    return (res as List<dynamic>)
        .map((e) => DangerZone.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> create(DangerZone zone) async {
    await _client.from('danger_zones').insert(zone.toInsertMap());
  }
}
