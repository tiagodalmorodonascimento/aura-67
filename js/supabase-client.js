(function initializeSupabase() {
  const environmentName = window.AURA_ENV || 'test';
  const config = window.AURA_ENVIRONMENTS?.[environmentName];
  const configured = config && config.supabaseUrl.startsWith('https://') && !config.supabaseUrl.includes('COLE_AQUI') && !config.supabasePublishableKey.includes('COLE_AQUI');

  window.AURA_SUPABASE_CONFIGURED = Boolean(configured);
  window.AURA_CURRENT_CONFIG = config;
  window.auraSupabase = configured && window.supabase
    ? window.supabase.createClient(config.supabaseUrl, config.supabasePublishableKey, {
        auth: { autoRefreshToken: true, persistSession: true, detectSessionInUrl: true }
      })
    : null;
})();
