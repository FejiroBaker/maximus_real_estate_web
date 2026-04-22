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
  // Use the WEB client ID from Google Cloud Console as the serverClientId.
  // The Android client ID is registered via SHA-1 — NOT stored here.
  static String get googleWebClientId =>
      dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? _missing('GOOGLE_WEB_CLIENT_ID');

  // ── Cloudinary (kept for legacy compatibility) ──────────────────────────────
  static String get cloudinaryCloudName =>
      dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';

  static String get cloudinaryApiKey =>
      dotenv.env['CLOUDINARY_API_KEY'] ?? '';

  static String get cloudinaryApiSecret =>
      dotenv.env['CLOUDINARY_API_SECRET'] ?? '';

  static String get cloudinaryUploadPreset =>
      dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? 'ml_default';

  // ── Paystack (PUBLIC key only — secret key is server-side) ──────────────────
  static String get paystackPublicKey =>
      dotenv.env['PAYSTACK_PUBLIC_KEY'] ?? _missing('PAYSTACK_PUBLIC_KEY');

  // ⚠️  paystackSecretKey is intentionally REMOVED from the Flutter client.
  //     All secret-key Paystack calls go through Supabase Edge Functions.
  //     See: supabase/functions/paystack/index.ts

  static String get paystackCallbackUrl =>
      dotenv.env['PAYSTACK_CALLBACK_URL'] ??
      'https://maximusrealestate.ng/payment/callback';

  // ── Admin ───────────────────────────────────────────────────────────────────
  static String get adminEmail =>
      dotenv.env['ADMIN_EMAIL'] ?? _missing('ADMIN_EMAIL');

  // ── App Owner Contact (used in Paystack service) ────────────────────────────
  // Store these in .env so they are never hardcoded in the binary.
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
    final _ = [
      supabaseUrl,
      supabaseAnonKey,
      geminiApiKey,
      googleWebClientId,
      paystackPublicKey,
      adminEmail,
    ];
  }
}