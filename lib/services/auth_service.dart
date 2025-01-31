import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  User? _currentUser;
  bool _loading = false;

  User? get currentUser => _currentUser;
  bool get loading => _loading;

  AuthService() {
    _init();
  }

  void _init() {
    _currentUser = _supabase.auth.currentUser;
    _supabase.auth.onAuthStateChange.listen((event) {
      _currentUser = event.session?.user;
      notifyListeners();
    });
  }

  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      _loading = true;
      notifyListeners();

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );

      if (response.user == null) {
        return 'Signup failed';
      }

      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _loading = true;
      notifyListeners();

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        return 'Login failed';
      }

      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
