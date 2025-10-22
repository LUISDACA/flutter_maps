class DangerZone {
  final int? id;
  final String userId;
  final double lat;
  final double lng;
  final String? description;
  final String dangerType;
  final int severity;
  final String? photoUrl;
  final String? reporterEmail; // 👈 nuevo
  final DateTime? createdAt;

  DangerZone({
    this.id,
    required this.userId,
    required this.lat,
    required this.lng,
    this.description,
    required this.dangerType,
    this.severity = 0,
    this.photoUrl,
    this.reporterEmail, // 👈 nuevo
    this.createdAt,
  });

  factory DangerZone.fromMap(Map<String, dynamic> m) {
    return DangerZone(
      id: m['id'] as int?,
      userId: m['user_id'] as String,
      lat: (m['lat'] as num).toDouble(),
      lng: (m['lng'] as num).toDouble(),
      description: m['description'] as String?,
      dangerType: m['danger_type'] as String,
      severity: (m['severity'] as num?)?.toInt() ?? 0,
      photoUrl: m['photo_url'] as String?,
      reporterEmail: m['reporter_email'] as String?, // 👈 nuevo
      createdAt:
          m['created_at'] != null ? DateTime.parse(m['created_at']) : null,
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'user_id': userId,
        'lat': lat,
        'lng': lng,
        'description': description,
        'danger_type': dangerType,
        'severity': severity,
        'photo_url': photoUrl,
        'reporter_email': reporterEmail, // 👈 nuevo
      };
}
