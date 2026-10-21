class SupabaseConstants {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kjsxbrbtpcizgaxypctv.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_cD7z3HTcDWlUHOZwzf1vyw_q1mGtQPr',
  );
  static const String mediaBucket = 'chat-media';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
