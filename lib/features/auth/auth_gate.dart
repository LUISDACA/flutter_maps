import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../map/map_page.dart';
import 'login_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final SupabaseClient _client;
  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
    _client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _client.auth.currentSession;
    if (session == null) return const LoginPage();
    return const MapPage();
  }
}
