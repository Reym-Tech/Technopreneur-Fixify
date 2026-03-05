// lib/core/constants/supabase_config.dart

class SupabaseConfig {
  // Replace these with your actual Supabase project credentials
  static const String supabaseUrl = 'https://jkoxjgibtkosefcumxhm.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imprb3hqZ2lidGtvc2VmY3VteGhtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2OTUyNjQsImV4cCI6MjA4ODI3MTI2NH0.4QnBgx45zJxi2x6m7NOeNcwM8cCkw9mWgXmPT3PojtA';

  // Table names
  static const String usersTable = 'users';
  static const String professionalsTable = 'professionals';
  static const String bookingsTable = 'bookings';
  static const String reviewsTable = 'reviews';

  // Storage buckets
  static const String avatarsBucket = 'avatars';
  static const String documentsBucket = 'documents';
}
