const auraNativeApp = Boolean(window.Capacitor?.isNativePlatform?.());
window.AURA_ENVIRONMENTS = {
  test: {
    supabaseUrl: 'https://uhhjxjcshbeyzgdvqgra.supabase.co',
    supabasePublishableKey: 'sb_publishable_C0K-xGHy7kAzV3bD4BfeWg_Amc0ZBf1',
    // Homologação usa a origem atual: localhost no desenvolvimento e Vercel nos testes públicos.
    siteUrl: auraNativeApp ? 'https://aura-67-gamma.vercel.app' : window.location.origin
  },
  production: {
    supabaseUrl: 'COLE_AQUI_A_URL_DO_PROJETO_DE_PRODUCAO',
    supabasePublishableKey: 'COLE_AQUI_A_CHAVE_PUBLICA_DE_PRODUCAO',
    siteUrl: 'https://SEU-DOMINIO.com.br'
  }
};

const productionHosts = ['SEU-DOMINIO.com.br', 'www.SEU-DOMINIO.com.br'];
window.AURA_ENV = productionHosts.includes(window.location.hostname) ? 'production' : 'test';
