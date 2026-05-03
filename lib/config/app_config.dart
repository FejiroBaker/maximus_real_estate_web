// lib/config/app_config.dart
// ─────────────────────────────────────────────────────────────────────────────
// Central config — all secrets come from the .env file (never hardcoded).
// Add .env to .gitignore so keys are never committed to version control.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // ── Supabase ────────────────────────────────────────────────────────────────
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? _missing('SUPABASE_URL');

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? _missing('SUPABASE_ANON_KEY');

  // ── Gemini AI ───────────────────────────────────────────────────────────────
  static String get geminiApiKey =>
      dotenv.env['GEMINI_API_KEY'] ?? _missing('GEMINI_API_KEY');

  // ── Google Sign-In ──────────────────────────────────────────────────────────
  static String get googleWebClientId =>
      dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? _missing('GOOGLE_WEB_CLIENT_ID');

  // ── Flutterwave (PUBLIC key only — secret key is in Supabase Edge Secrets) ──
  // Store in Supabase Edge Function Secrets:
  //   FLW_SECRET_KEY    = FLWSECK-1e193a825ce4a311347f3afa624c0e00-19db9dfc5c9vt-X
  //   FLW_ENCRYPTION_KEY = 1e193a825ce4a906a6fcb5ca
  static String get flutterwavePublicKey =>
      dotenv.env['FLUTTERWAVE_PUBLIC_KEY'] ?? _missing('FLUTTERWAVE_PUBLIC_KEY');

  static String get flutterwaveCallbackUrl =>
      dotenv.env['FLUTTERWAVE_CALLBACK_URL'] ??
      'https://maximusrealestate.ng/payment/callback';

  // ── Admin ───────────────────────────────────────────────────────────────────
  static String get adminEmail =>
      dotenv.env['ADMIN_EMAIL'] ?? _missing('ADMIN_EMAIL');

  // ── App Owner Contact (optional, used in service layer) ─────────────────────
  static String get appOwnerPhone =>
      dotenv.env['APP_OWNER_PHONE'] ?? '';

  static String get appOwnerWhatsapp =>
      dotenv.env['APP_OWNER_WHATSAPP'] ?? '';

  // ── Helpers ─────────────────────────────────────────────────────────────────
  static String _missing(String key) {
    throw Exception(
      '❌ Missing environment variable: $key\n'
      'Make sure your .env file exists and contains this key.\n'
      'See .env.example for the required keys.',
    );
  }

  /// Validate all required config keys are present at startup.
  static void validate() {
    // Accessing each getter will throw _missing() if the key is absent.
    final _ = [
      supabaseUrl,
      supabaseAnonKey,
      geminiApiKey,
      googleWebClientId,
      flutterwavePublicKey,
      adminEmail,
    ];
  }
}