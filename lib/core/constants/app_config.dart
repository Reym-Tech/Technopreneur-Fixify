// lib/core/constants/app_config.dart
//
// Reads all sensitive config from the .env file at runtime.
// Never hardcode keys here.
//
// Setup:
//   1. Add flutter_dotenv to pubspec.yaml (see README / SETUP.md)
//   2. Create a .env file at your project root (copy from .env.example)
//   3. Add .env to your .gitignore
//   4. Add .env to flutter assets in pubspec.yaml:
//        flutter:
//          assets:
//            - .env

import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // ── Supabase ────────────────────────────────────────────
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? _missing('SUPABASE_URL');

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? _missing('SUPABASE_ANON_KEY');

  // ── Google Maps ─────────────────────────────────────────
  static String get googleMapsApiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? _missing('GOOGLE_MAPS_API_KEY');

  // ── Table names (not secret, but kept here for consistency) ──
  static const String usersTable = 'users';
  static const String professionalsTable = 'professionals';
  static const String bookingsTable = 'bookings';
  static const String reviewsTable = 'reviews';
  static const String servicesTable = 'service_offers';

  // ── Storage buckets ─────────────────────────────────────
  static const String avatarsBucket = 'avatars';
  static const String documentsBucket = 'documents';
  static const String bookingPhotosBucket = 'booking_photos';

  static String _missing(String key) {
    throw Exception(
      '[$key] is missing from your .env file. '
      'Copy .env.example → .env and fill in your real values.',
    );
  }
}
