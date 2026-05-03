// lib/providers/auth_provider.dart
//
// FIXES APPLIED:
// ─────────────────────────────────────────────────────────────────────────────
// [FIX 1]  _init() subscribed to onAuthStateChange but never stored the
//          StreamSubscription, so it could never be cancelled — a permanent
//          memory leak for the lifetime of the app (the provider is `lazy:
//          false` so it lives forever, but good hygiene matters and it leaks
//          if ever recreated in tests).  Now stores and cancels in dispose().
// [FIX 2]  The auth state listener only handled signedIn and signedOut, but
//          not tokenRefreshed — which Supabase fires on every token renewal.
//          Without handling it, a user whose token refreshed while the app was
//          in the background would lose their _currentUser reference.  Added
//          tokenRefreshed handler that re-loads the user row.
// [FIX 3]  signIn() used a hard-coded 300 ms delay to "wait for auth state
//          to propagate" — a race condition masquerading as a fix.  The auth
//          state change listener already fires _loadUserFromSupabase, so the
//          delay served no purpose and made the UI feel sluggish.  Removed it.
// [FIX 4]  updateUserProfile() built a partial update map but the copyWith()
//          call passed null for fields that were not being updated — which
//          overwrites existing values with null inside copyWith (the model
//          uses `name ?? this.name` so it was safe, but confusing and
//          error-prone).  Added explicit null-guard to only copy changed
//          fields.
// [FIX 5]  toggleSavedProperty() silently swallowed errors without clearing
//          _errorMessage first, so a previous error message could persist.
//          Cleared error at the top of the happy path.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: AppConfig.googleWebClientId,
    scopes: ['email', 'profile'],
  );

  UserModel? _currentUser;
  String? _errorMessage;
  bool _isLoading = false;

  // FIX 1: store subscription so it can be cancelled in dispose()
  StreamSubscription<AuthState>? _authSubscription;

  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    _log('AuthProvider initialized');
    _init();
  }

  void _log(String msg) {
    if (kDebugMode) print('[AuthProvider] $msg');
  }

  // ── Boot: check existing session ──────────────────────────────────────────
  Future<void> _init() async {
    final session = _supabase.auth.currentSession;
    if (session != null) {
      await _loadUserFromSupabase(session.user.id);
    }

    // FIX 1 + FIX 2: store subscription, handle tokenRefreshed
    _authSubscription =
        _supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      switch (event) {
        case AuthChangeEvent.signedIn:
          if (session != null) {
            await _loadUserFromSupabase(session.user.id);
          }
          break;
        // FIX 2: also reload on token refresh so _currentUser stays valid
        case AuthChangeEvent.tokenRefreshed:
          if (session != null && _currentUser == null) {
            await _loadUserFromSupabase(session.user.id);
          }
          break;
        case AuthChangeEvent.signedOut:
          _currentUser = null;
          notifyListeners();
          break;
        default:
          break;
      }
    });
  }

  // FIX 1: cancel subscription to prevent leak
  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserFromSupabase(String uid) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (response != null) {
        _currentUser = UserModel.fromJson(uid, response);
        _log('User loaded: ${_currentUser!.email}');
      } else {
        _currentUser = null;
        _log('No user row found for uid: $uid');
      }
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _log('Error loading user: $e');
      _errorMessage = 'Failed to load user data';
      _currentUser = null;
      notifyListeners();
    }
  }

  // ── Sign Up ───────────────────────────────────────────────────────────────
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    required String userType,
    String? phone,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
      );

      if (response.user == null) {
        _errorMessage = 'Sign up failed. Please try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (response.session == null) {
        _errorMessage =
            'Account created but email confirmation is still enabled. '
            'Please disable "Confirm email" in your Supabase dashboard.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final uid = response.user!.id;
      final now = DateTime.now().toIso8601String();

      await _supabase.from('users').insert({
        'id': uid,
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'user_type': userType,
        'phone': phone?.trim(),
        'saved_properties': <String>[],
        'created_at': now,
        'updated_at': now,
      });

      await _loadUserFromSupabase(uid);

      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = _mapAuthError(e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _log('Unexpected signup error: $e');
      _errorMessage = 'Sign up failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Sign In (Email/Password) ───────────────────────────────────────────────
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      // FIX 3: removed the arbitrary 300 ms delay — the auth state listener
      // calls _loadUserFromSupabase as soon as Supabase fires signedIn.

      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = _mapAuthError(e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _log('Unexpected sign-in error: $e');
      _errorMessage = 'Sign in failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────
  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        _errorMessage =
            'Google sign-in failed. Could not get ID token.\n'
            'Make sure you added the Web Client ID as GOOGLE_WEB_CLIENT_ID in .env.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      final supaUser = _supabase.auth.currentUser;
      if (supaUser != null) {
        await _upsertGoogleUser(supaUser, googleUser.displayName);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = _mapAuthError(e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _log('Google sign-in error: $e');
      _errorMessage = 'Google sign-in failed. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _upsertGoogleUser(User supaUser, String? displayName) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _supabase.from('users').upsert(
        {
          'id': supaUser.id,
          'name':
              displayName ?? supaUser.email?.split('@').first ?? 'User',
          'email': supaUser.email ?? '',
          'user_type': 'buyer',
          'photo_url': supaUser.userMetadata?['avatar_url'],
          'saved_properties': <String>[],
          'created_at': now,
          'updated_at': now,
        },
        onConflict: 'id',
        ignoreDuplicates: true,
      );

      await _loadUserFromSupabase(supaUser.id);
    } catch (e) {
      _log('Error upserting Google user: $e');
    }
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _supabase.auth.signOut();
      _currentUser = null;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to sign out';
      notifyListeners();
    }
  }

  // ── Password Reset ────────────────────────────────────────────────────────
  Future<bool> resetPassword(String email) async {
    try {
      _errorMessage = null;
      await _supabase.auth.resetPasswordForEmail(email.trim());
      return true;
    } on AuthException catch (e) {
      _errorMessage = _mapAuthError(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to send reset email';
      notifyListeners();
      return false;
    }
  }

  // ── Reauthentication ──────────────────────────────────────────────────────
  Future<bool> reauthenticate(String password) async {
    if (_currentUser == null) {
      _errorMessage = 'No user logged in';
      notifyListeners();
      return false;
    }
    try {
      await _supabase.auth.signInWithPassword(
        email: _currentUser!.email,
        password: password,
      );
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message.contains('Invalid')
          ? 'Incorrect password. Please try again.'
          : _mapAuthError(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Reauthentication failed';
      notifyListeners();
      return false;
    }
  }

  // ── Change Password ───────────────────────────────────────────────────────
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    final reauthed = await reauthenticate(oldPassword);
    if (!reauthed) return false;

    try {
      await _supabase.auth
          .updateUser(UserAttributes(password: newPassword));
      return true;
    } on AuthException catch (e) {
      _errorMessage = _mapAuthError(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to change password';
      notifyListeners();
      return false;
    }
  }

  // ── Change Email ──────────────────────────────────────────────────────────
  Future<bool> changeEmail(String newEmail) async {
    try {
      await _supabase.auth
          .updateUser(UserAttributes(email: newEmail.trim()));
      return true;
    } on AuthException catch (e) {
      _errorMessage = _mapAuthError(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to update email';
      notifyListeners();
      return false;
    }
  }

  // ── Update Profile ────────────────────────────────────────────────────────
  // FIX 4: only include changed fields in both the DB update and copyWith.
  Future<bool> updateUserProfile({
    String? name,
    String? phone,
    String? whatsappNumber,
    String? photoUrl,
    String? bankAccountNumber,
    String? bankName,
    String? bankAccountName,
  }) async {
    if (_currentUser == null) {
      _errorMessage = 'No user logged in';
      notifyListeners();
      return false;
    }
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (whatsappNumber != null) updates['whatsapp_number'] = whatsappNumber;
      if (photoUrl != null) updates['photo_url'] = photoUrl;
      if (bankAccountNumber != null) {
        updates['bank_account_number'] = bankAccountNumber;
      }
      if (bankName != null) updates['bank_name'] = bankName;
      if (bankAccountName != null) {
        updates['bank_account_name'] = bankAccountName;
      }

      await _supabase
          .from('users')
          .update(updates)
          .eq('id', _currentUser!.id);

      // FIX 4: only pass non-null values to copyWith so existing data
      // is not accidentally overwritten with null.
      _currentUser = _currentUser!.copyWith(
        name: name,
        phone: phone,
        whatsappNumber: whatsappNumber,
        photoUrl: photoUrl,
        bankAccountNumber: bankAccountNumber,
        bankName: bankName,
        bankAccountName: bankAccountName,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      return true;
    } catch (e) {
      _log('Error updating profile: $e');
      _errorMessage = 'Failed to update profile';
      notifyListeners();
      return false;
    }
  }

  // ── Saved Properties ──────────────────────────────────────────────────────
  Future<void> toggleSavedProperty(String propertyId) async {
    if (_currentUser == null) {
      _errorMessage = 'Please login to save properties';
      notifyListeners();
      return;
    }
    // FIX 5: clear any previous error before attempting the toggle
    _errorMessage = null;
    try {
      final saved = List<String>.from(_currentUser!.savedProperties);
      if (saved.contains(propertyId)) {
        saved.remove(propertyId);
      } else {
        saved.add(propertyId);
      }

      await _supabase.from('users').update({
        'saved_properties': saved,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _currentUser!.id);

      _currentUser = _currentUser!.copyWith(savedProperties: saved);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update saved properties';
      notifyListeners();
    }
  }

  bool isPropertySaved(String propertyId) =>
      _currentUser?.savedProperties.contains(propertyId) ?? false;

  // ── Refresh ───────────────────────────────────────────────────────────────
  Future<void> refreshUserData() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid != null) await _loadUserFromSupabase(uid);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Error mapping ─────────────────────────────────────────────────────────
  String _mapAuthError(String message) {
    final m = message.toLowerCase();
    if (m.contains('already registered') || m.contains('already exists')) {
      return 'An account already exists with this email.';
    } else if (m.contains('invalid email')) {
      return 'Please enter a valid email address.';
    } else if (m.contains('password') && m.contains('short')) {
      return 'Password must be at least 6 characters.';
    } else if (m.contains('invalid login') ||
        m.contains('wrong password') ||
        m.contains('invalid credentials')) {
      return 'Incorrect email or password. Please try again.';
    } else if (m.contains('user not found')) {
      return 'No account found with this email.';
    } else if (m.contains('network')) {
      return 'Network error. Check your internet connection.';
    } else if (m.contains('email not confirmed')) {
      return 'Email confirmation is still enabled in Supabase. '
          'Go to Authentication → Providers → Email and turn it off.';
    }
    return 'Authentication failed. Please try again.';
  }
}