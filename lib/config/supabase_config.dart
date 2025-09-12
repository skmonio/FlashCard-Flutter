class SupabaseConfig {
  // TODO: Replace these with your actual Supabase project credentials
  // Get these from your Supabase project settings -> API
  static const String supabaseUrl = 'https://ohrkqrovgsshtoqhwoun.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9ocmtxcm92Z3NzaHRvcWh3b3VuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc1NzM3NTUsImV4cCI6MjA3MzE0OTc1NX0.sTsLi6I81al0mVxxvr7kzWHtzBgWxL5NTvfciwFc0gM';
  
  // For development, you can also use service role key for admin operations
  static const String supabaseServiceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9ocmtxcm92Z3NzaHRvcWh3b3VuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NzU3Mzc1NSwiZXhwIjoyMDczMTQ5NzU1fQ.CeMbWFgXLRjXt7I-7Bs5o-KG6U6oZSG2OdVxZ5Ys0Yc';
  
  // Validate configuration
  static bool get isConfigured {
    return supabaseUrl != 'YOUR_SUPABASE_URL_HERE' && 
           supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY_HERE';
  }
}
