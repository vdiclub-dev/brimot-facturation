// ============================================================
// config.js — Brimot Facturation
//
// Variables publiques (non sensibles) injectées côté navigateur.
// Ne jamais mettre ici : service_role, clé Brevo, token Resend.
//
// Pour déployer, remplacer les placeholders ci-dessous ou
// injecter via le pipeline CI (sed, Netlify/Cloudflare env, etc.)
// ============================================================

// ── Timeout auth (ms) ────────────────────────────────────────
window.AUTH_TIMEOUT_MS = 8000;

// ── Supabase ─────────────────────────────────────────────────
// Injecter ces valeurs via votre hébergeur — ne jamais committer les vraies clés.
window.SUPABASE_CONFIG = {
    url:    'https://iubbsnntcreneakbdkmv.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml1YmJzbm50Y3JlbmVha2Jka212Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI1NzI1MDYsImV4cCI6MjA4ODE0ODUwNn0.FzMgCZxNIej1skSIc8UAGiODcZEZW1GCWZwBfonm_1Y',
    // Alias utilisé par facturation.html pour l'appel à l'Edge Function
    get key() { return this.anonKey; }
};

// ── Initialisation du client Supabase ────────────────────────
try {
    if (typeof window.supabase === 'undefined' || !window.supabase.createClient) {
        throw new Error('SDK Supabase non chargé — vérifiez js/supabase.min.js');
    }
    window.SUPABASE_CLIENT = window.supabase.createClient(
        window.SUPABASE_CONFIG.url,
        window.SUPABASE_CONFIG.anonKey,
        {
            auth: {
                persistSession:    true,
                storageKey:        'Brimot-auth',
                autoRefreshToken:  true,
                detectSessionInUrl: true
            }
        }
    );
} catch (e) {
    console.warn('[Brimot] Supabase init error:', e && e.message);
    window.SUPABASE_CLIENT = null;
}

// ── Constantes Brimot (non sensibles) ────────────────────────
// Ces valeurs apparaissent dans les factures et bulletins de versement QR.
// Elles ne sont pas des secrets.
window.BRIMOT_CONFIG = {
    companyName:  'Brimot Nettoyage',
    address:      'Impasse des Griottes 3',
    postalCity:   '1462 Yvonand',
    email:        'info@brimot.ch',
    phone:        '+41 79 646 74 42',
    // IBAN affiché sur les factures (pas un secret, imprimé sur les BVR)
    iban:         'CH95 3000 5291 1478 8940 K',
    // URL du logo Brimot — remplacer par un chemin local si possible
    // (Google Drive n'est pas fiable en production)
    logoUrl:      '',
    // TVA par défaut
    tvaRate:      8.1
};

// ── Envoi e-mail factures ─────────────────────────────────────
// Laisser vide = mode Edge Function Supabase (send-brimot-invoice).
// Remplir avec l'URL absolue de send_mail.php si mode PHP.
if (typeof window.BRIMOT_SEND_MAIL_URL === 'undefined') {
    window.BRIMOT_SEND_MAIL_URL = '';
}

// ── Application Colixo (compatibilité auth.js) ────────────────
window.COLIXO_APP = {
    companyName:        'Brimot Nettoyage',
    companyEmail:       'info@brimot.ch',
    companyWebsite:     'https://brimot.ch',
    tvaRate:            8.1,
    cgvFallbackVersion: 'v1.0_brimot_2026'
};
