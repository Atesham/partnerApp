class SupabaseConstants {
  static const String projectId = String.fromEnvironment(
    'SUPABASE_PROJECT_ID',
    defaultValue: 'jdmwvxghimqiwpsbbeak',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpkbXd2eGdoaW1xaXdwc2JiZWFrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2NzU3MTAsImV4cCI6MjA5NjI1MTcxMH0.qSw2mhDyVjrpCAvwfxPMaWYyIncrrAYjOEzdJYuoxd8',
  );
}
