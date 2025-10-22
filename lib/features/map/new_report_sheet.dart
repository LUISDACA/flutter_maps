import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/danger_zone.dart';
import '../../services/storage_service.dart';

class NewReportSheet extends StatefulWidget {
  const NewReportSheet({super.key, required this.initialPoint});
  final LatLng initialPoint;

  @override
  State<NewReportSheet> createState() => _NewReportSheetState();
}

class _NewReportSheetState extends State<NewReportSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  String _dangerType = 'asalto';
  int _severity = 2;
  Uint8List? _imageBytes;
  bool _saving = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Cámara'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo),
            title: const Text('Galería'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (src == null) return;
    final file = await picker.pickImage(
      source: src,
      maxWidth: 1440,
      imageQuality: 82,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _imageBytes = bytes);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser!;
      String? photoUrl;

      if (_imageBytes != null) {
        try {
          final storage = StorageService(client);
          final id = const Uuid().v4();
          photoUrl = await storage.uploadPublicBytes(
            bytes: _imageBytes!,
            path: '${user.id}/$id.jpg',
            contentType: 'image/jpeg',
          );
        } on StorageException catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No se pudo subir la foto (${e.statusCode}: ${e.message}). '
                  'Se creará el reporte sin imagen.',
                ),
              ),
            );
          }
          photoUrl = null;
        }
      }

      final dz = DangerZone(
        userId: user.id,
        lat: widget.initialPoint.latitude,
        lng: widget.initialPoint.longitude,
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        dangerType: _dangerType,
        severity: _severity,
        photoUrl: photoUrl,
        reporterEmail: user.email, // 👈 guardamos el email del reportante
      );

      Navigator.pop(context, dz);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear el reporte: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final point = widget.initialPoint;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 12,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: controller,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Nuevo reporte',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('Lat: ${point.latitude.toStringAsFixed(6)}  '
                        'Lng: ${point.longitude.toStringAsFixed(6)}'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _dangerType,
                      items: const [
                        DropdownMenuItem(
                            value: 'asalto', child: Text('Asalto / robo')),
                        DropdownMenuItem(
                            value: 'calle_sin_luz',
                            child: Text('Calle sin iluminación')),
                        DropdownMenuItem(
                            value: 'accidente_vial',
                            child: Text('Accidente vial')),
                        DropdownMenuItem(value: 'otro', child: Text('Otro')),
                      ],
                      onChanged: (v) =>
                          setState(() => _dangerType = v ?? 'asalto'),
                      decoration:
                          const InputDecoration(labelText: 'Tipo de peligro'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                        hintText:
                            'Ej: Zona con asaltos frecuentes por la noche',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Gravedad'),
                        Expanded(
                          child: Slider(
                            min: 0,
                            max: 5,
                            divisions: 5,
                            value: _severity.toDouble(),
                            label: _severity.toString(),
                            onChanged: (v) =>
                                setState(() => _severity = v.toInt()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Adjuntar foto'),
                        ),
                        const SizedBox(width: 12),
                        if (_imageBytes != null)
                          const Icon(Icons.check_circle, color: Colors.green),
                      ],
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: const Icon(Icons.send),
                      label: Text(_saving ? 'Enviando...' : 'Enviar reporte'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
