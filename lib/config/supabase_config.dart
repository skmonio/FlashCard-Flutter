class SupabaseConfig {
  static const String supabaseUrl = 'https://ohrkqrovgsshtoqhwoun.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9ocmtxcm92Z3NzaHRvcWh3b3VuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc1NzM3NTUsImV4cCI6MjA3MzE0OTc1NX0.sTsLi6I81al0mVxxvr7kzWHtzBgWxL5NTvfciwFc0gM';

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
