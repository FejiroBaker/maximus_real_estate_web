// lib/providers/admin_auth_provider.dart
// Admin login via Supabase Auth — checks user_type = 'admin' in users table.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../config/app_config.dart';

class AdminAuthProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Admin ID is stored here after login for ownerId on admin-added properties.
  static String _adminId = '';
  static String get ADMIN_ID => _adminId;

  static const String _adminSessionKey = 'admin_session';

  bool _isAdmin = false;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isAdmin => _isAdmin;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get adminEmail => AppConfig.adminEmail;

  AdminAuthProvider() {
    _checkAdminSession();
  }

  // ── Session persistence ───────────────────────────────────────────────────
  Future<void> _checkAdminSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString(_adminSessionKey);
      if (sessionJson != null) {
        final sessionData = json.decode(sessionJson);
        final expiresAt = DateTime.parse(sessionData['expiresAt']);
        if (DateTime.now().isBefore(expiresAt)) {
          // Also verify Supabase session is still active
          final session = _supabase.auth.currentSession;
          if (session != null &&
              session.user.email?.toLowerCase() ==
                  AppConfig.adminEmail.toLowerCase()) {
            _isAdmin = true;
            _adminId = session.user.id;
            notifyListeners();
            return;
          }
        }
        await logoutAdmin();
      }
    } catch (e) {
      debugPrint('Error checking admin session: $e');
      _isAdmin = false;
    }
  }

  Future<void> _createAdminSession(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionData = {
        'adminUid': uid,
        'email': AppConfig.adminEmail,
        'createdAt': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now()
            .add(const Duration(days: 7))
            .toIso8601String(),
      };
      await prefs.setString(_adminSessionKey, json.encode(sessionData));
    } catch (e) {
      debugPrint('Error creating admin session: $e');
    }
  }

  // ── Admin Login ───────────────────────────────────────────────────────────
  Future<bool> loginAsAdmin(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (email.trim().toLowerCase() != AppConfig.adminEmail.toLowerCase()) {
        _errorMessage = 'Invalid admin credentials';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (response.user == null) {
        _errorMessage = 'Invalid admin credentials';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final uid = response.user!.id;

      // Ensure admin row exists in users table
      final existing = await _supabase
          .from('users')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('users').insert({
          'id': uid,
          'name': 'Administrator',
          'email': AppConfig.adminEmail,
          'user_type': 'admin',
          'saved_properties': <String>[],
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        await _supabase.from('users').update({
          'user_type': 'admin',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', uid);
      }

      await _createAdminSession(uid);
      _adminId = uid;
      _isAdmin = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message.contains('Invalid')
          ? 'Invalid admin credentials'
          : 'Login failed: ${e.message}';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Login failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  bool isAdminEmail(String? email) =>
      email?.toLowerCase() == AppConfig.adminEmail.toLowerCase();

  Future<void> logoutAdmin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_adminSessionKey);
      await _supabase.auth.signOut();
      _isAdmin = false;
      _adminId = '';
      notifyListeners();
    } catch (e) {
      debugPrint('Error logging out admin: $e');
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> checkAdminStatus() async => _checkAdminSession();
}
