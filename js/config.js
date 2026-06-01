// ⚠️  CONFIGURATION — ne jamais committer les vraies valeurs
// Injectez ces variables via votre hébergeur (Netlify, Vercel, nginx, etc.)
// avant de servir ce fichier, ou via un pipeline de build.

window.COLIXO_SUPABASE_URL      = window.__ENV_SUPABASE_URL__      || "REMPLACER_PAR_VOTRE_URL_SUPABASE";
window.COLIXO_SUPABASE_ANON_KEY = window.__ENV_SUPABASE_ANON_KEY__ || "REMPLACER_PAR_VOTRE_CLE_ANON_PUBLIQUE";

// Configuration applicative (pas de secrets ici)
window.COLIXO_APP = {
  companyName:        "Colixo",
  companyEmail:       "info@colixo.ch",
  companyWebsite:     "https://colixo.ch",
  tvaRate:            8.1,
  cgvFallbackVersion: "v1.0_colixo_2026"
};
