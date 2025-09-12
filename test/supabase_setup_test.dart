import 'package:flutter_test/flutter_test.dart';
import 'package:taal_trek_dutch/config/supabase_config.dart';

void main() {
  group('Supabase Setup Tests', () {
    test('Supabase configuration should be properly set up', () {
      // This test will fail until you update the config with real credentials
      expect(SupabaseConfig.supabaseUrl, isNotEmpty);
      expect(SupabaseConfig.supabaseAnonKey, isNotEmpty);
      expect(SupabaseConfig.isConfigured, isTrue);
    });
    
    test('Supabase URL should be a valid URL', () {
      expect(SupabaseConfig.supabaseUrl, startsWith('https://'));
      expect(SupabaseConfig.supabaseUrl, endsWith('.supabase.co'));
    });
    
    test('Supabase anon key should be a valid JWT', () {
      expect(SupabaseConfig.supabaseAnonKey, startsWith('eyJ'));
    });
  });
}
