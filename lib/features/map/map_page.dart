import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/danger_zone.dart';
import '../../data/repositories/danger_zone_repository.dart';
import '../../services/location_service.dart';
import '../../services/storage_service.dart';
import '../auth/login_page.dart';
import 'new_report_sheet.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _mapController = MapController();
  late final SupabaseClient _client;
  late final DangerZoneRepository _repo;
  List<DangerZone> _zones = [];
  bool _loading = false;
  LatLng _center = const LatLng(4.60971, -74.08175); // Bogotá por defecto

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
    _repo = DangerZoneRepository(_client);
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    try {
      await _moveToUserIfPossible();
    } catch (_) {}
    await _reloadZones();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _moveToUserIfPossible() async {
    try {
      final pos = await LocationService.getCurrentPosition();
      _center = LatLng(pos.latitude, pos.longitude);
      _mapController.move(_center, 14);
    } catch (_) {
      _mapController.move(_center, 12);
    }
  }

  Future<void> _reloadZones() async {
    _zones = await _repo.fetchAll();
    if (mounted) setState(() {});
  }

  Future<void> _onTapMap(TapPosition tapPosition, LatLng point) async {
    final session = _client.auth.currentSession;
    if (session == null) {
      if (!mounted) return;
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const LoginPage()));
      return;
    }
    final created = await showModalBottomSheet<DangerZone?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => NewReportSheet(initialPoint: point),
    );
    if (created != null) {
      await _repo.create(created);
      await _reloadZones();
    }
  }

  List<Marker> _markers() {
    return _zones.map<Marker>((z) {
      return Marker(
        point: LatLng(z.lat, z.lng),
        width: 48,
        height: 48,
        child: GestureDetector(
          onTap: () => _showReportDetail(z),
          child: _DangerMarker(
            color: _colorForType(z.dangerType),
            icon: Icons.warning_amber_rounded,
          ),
        ),
      );
    }).toList();
  }

  void _showReportDetail(DangerZone z) {
    final f = DateFormat('yyyy-MM-dd HH:mm');
    final created =
        z.createdAt != null ? f.format(z.createdAt!.toLocal()) : '-';
    final myId = _client.auth.currentUser?.id;
    final canDelete = z.id != null && z.userId == myId;
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: ListView(
              shrinkWrap: true,
              children: [
                Row(
                  children: [
                    Icon(Icons.report, color: _colorForType(z.dangerType)),
                    const SizedBox(width: 8),
                    Text(z.dangerType.toUpperCase(),
                        style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    Chip(
                      label: Text('Sev ${z.severity}'),
                      avatar: const Icon(Icons.trending_up, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (z.photoUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        z.photoUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: cs.surfaceVariant.withOpacity(.4),
                            child: const Center(
                                child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          height: 160,
                          color: cs.surfaceVariant.withOpacity(.4),
                          alignment: Alignment.center,
                          child: const Text('No se pudo cargar la imagen'),
                        ),
                      ),
                    ),
                  ),
                if (z.photoUrl != null) const SizedBox(height: 12),
                if (z.description != null && z.description!.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.notes_rounded, color: cs.primary),
                          const SizedBox(width: 10),
                          Expanded(child: Text(z.description!)),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InfoChip(
                        icon: Icons.person,
                        label: z.reporterEmail ?? 'Anónimo'),
                    _InfoChip(icon: Icons.calendar_today, label: created),
                    _InfoChip(
                        icon: Icons.location_on,
                        label:
                            'Lat ${z.lat.toStringAsFixed(5)} • Lng ${z.lng.toStringAsFixed(5)}'),
                  ],
                ),
                const SizedBox(height: 10),
                if (canDelete)
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Eliminar reporte'),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: sheetCtx,
                          builder: (dCtx) => AlertDialog(
                            title: const Text('Eliminar reporte'),
                            content: const Text(
                                'Esta acción no se puede deshacer. ¿Deseas continuar?'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(dCtx, false),
                                  child: const Text('Cancelar')),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red),
                                onPressed: () => Navigator.pop(dCtx, true),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                        if (ok != true) return;

                        try {
                          if (z.photoUrl != null && z.photoUrl!.isNotEmpty) {
                            await StorageService(_client)
                                .deleteByPublicUrl(z.photoUrl!);
                          }
                          await _repo.deleteById(z.id!);

                          if (!mounted) return;
                          Navigator.pop(sheetCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Reporte eliminado')));
                          await _reloadZones();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al eliminar: $e')));
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _colorForType(String t) {
    final s = t.toLowerCase();
    if (s.contains('asalto')) return const Color(0xFFE53935);
    if (s.contains('luz') || s.contains('ilumin'))
      return const Color(0xFFFBC02D);
    if (s.contains('accidente')) return const Color(0xFF8E24AA);
    return const Color(0xFF6D4C41);
  }

  Future<void> _reportFromCurrentLocation() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      if (!mounted) return;
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const LoginPage()));
      return;
    }
    try {
      final pos = await LocationService.getCurrentPosition();
      final created = await showModalBottomSheet<DangerZone?>(
        context: context,
        isScrollControlled: true,
        builder: (_) =>
            NewReportSheet(initialPoint: LatLng(pos.latitude, pos.longitude)),
      );
      if (created != null) {
        await _repo.create(created);
        await _reloadZones();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo obtener la ubicación: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _client.auth.currentSession;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zonas de Peligro'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _reloadZones,
            icon: const Icon(Icons.refresh),
          ),
          if (session != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.logout, size: 18),
                label: const Text('Salir'),
                onPressed: () async {
                  await _client.auth.signOut();
                  if (mounted) setState(() {});
                },
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 12,
              onTap: _onTapMap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.zonas_peligro_app',
              ),
              MarkerLayer(markers: _markers()),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    '© OpenStreetMap contributors',
                    onTap: () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Tarjeta de leyenda
          Positioned(
            left: 12,
            top: 12,
            child: Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _LegendDot(color: _colorForType('asalto'), label: 'Asalto'),
                  const SizedBox(width: 8),
                  _LegendDot(color: _colorForType('luz'), label: 'Sin luz'),
                  const SizedBox(width: 8),
                  _LegendDot(
                      color: _colorForType('accidente'), label: 'Accidente'),
                ]),
              ),
            ),
          ),
          // Cargador elegante
          Positioned(
            right: 12,
            top: 12,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _loading
                  ? Card(
                      key: const ValueKey('loading'),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(children: const [
                          SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Cargando...'),
                        ]),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('idle')),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: const Uuid().v4(),
            onPressed: _reportFromCurrentLocation,
            icon: const Icon(Icons.add_location_alt),
            label: const Text('Reportar aquí'),
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: const Uuid().v4(),
            onPressed: _moveToUserIfPossible,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12)),
    ]);
  }
}

class _DangerMarker extends StatelessWidget {
  const _DangerMarker({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(.45), blurRadius: 14, spreadRadius: 1),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 28, color: Colors.white),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
