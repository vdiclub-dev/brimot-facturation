# Brimot Facturation — Application autonome

Application de facturation interne pour **Brimot Nettoyage**.
Frontend statique (HTML / JS vanilla), backend Supabase (auth, base de données, Edge Function).

> **Dépôt privé** — ne pas rendre public. Voir [SECURITY_NOTES.md](SECURITY_NOTES.md).

---

## Structure du projet

```
brimot-facturation-export/
│
├── index.html                  → Redirige automatiquement vers login/
├── favicon.svg
├── _headers                    → En-têtes HTTP Cloudflare Pages
│
├── login/
│   └── index.html              → Page de connexion (email + mot de passe)
│
├── app/
│   └── index.html              → Application de facturation (SPA)
│
├── facture-view.html           → Vue client d'une facture (lecture seule, lien partageable)
│
├── js/
│   ├── supabase.min.js         → SDK Supabase (UMD, pas de CDN externe)
│   ├── config.js               → SUPABASE_CONFIG + BRIMOT_CONFIG (pas de secrets)
│   ├── auth.js                 → Helpers auth Colixo (colixoRequireRoute, colixoLogout…)
│   └── qrcode.min.js           → Génération QR Code SIX Swiss Payment (local, pas de CDN)
│
└── supabase/
    ├── migrations/
    │   ├── 001_brimot_schema.sql   → Schéma des 4 tables (clients, produits, factures, lignes)
    │   └── 002_brimot_rls.sql      → RLS : accès admin/super_admin uniquement, aucun anon
    └── functions/
        └── send-brimot-invoice/
            └── index.ts            → Edge Function Deno — envoi email via Brevo API
```

---

## Flux de navigation

```
/                   → login/
login/              → (après auth admin) → app/
app/                → (sans auth)        → login/
facture-view.html   → lecture seule, données passées via ?data=base64 (pas d'auth requise)
```

---

## Installation locale (test sans déploiement)

Un serveur HTTP local est nécessaire (les requêtes Supabase nécessitent un contexte HTTP —
`file://` ne fonctionne pas).

```bash
# Option 1 — Python
cd brimot-facturation-export
python3 -m http.server 8080
# Ouvrir http://localhost:8080

# Option 2 — Node.js
npx serve .

# Option 3 — VS Code Live Server
# Clic droit sur index.html → Open with Live Server
```

---

## Configuration Supabase

### 1. Créer les tables (migrations SQL)

Dans Supabase Dashboard → SQL Editor, exécuter dans l'ordre :

```sql
-- Coller le contenu de :
supabase/migrations/001_brimot_schema.sql
-- puis :
supabase/migrations/002_brimot_rls.sql
```

Ou via la CLI Supabase :

```bash
supabase db push
```

Tables créées : `brimot_clients`, `brimot_produits`, `brimot_factures`, `brimot_lignes`.

### 2. Configurer `js/config.js`

Remplacer les deux placeholders par les vraies valeurs du projet Supabase :

```js
window.SUPABASE_CONFIG = {
    url:     '...',   // Dashboard → Settings → API → Project URL
    anonKey: '...',   // Dashboard → Settings → API → anon public
};
```

La clé `anon` est **publique par conception** — elle apparaît dans le HTML chargé par le
navigateur. Sa sécurité repose sur les politiques RLS activées sur toutes les tables.

### 3. Créer un utilisateur admin

Dans Supabase Dashboard → Authentication → Users, créer le compte puis dans SQL Editor :

```sql
INSERT INTO public.utilisateurs (id, email, prenom, nom, role, actif)
VALUES (
  '<uuid-de-l-utilisateur-auth>',
  'admin@brimot.ch',
  'Prénom',
  'Nom',
  'admin',   -- ou 'super_admin' pour droits de suppression
  true
);
```

---

## Edge Function — send-brimot-invoice

### Secrets requis (Supabase Dashboard → Edge Functions → Secrets)

| Variable | Description |
|---|---|
| `SUPABASE_URL` | URL du projet Supabase (injecté automatiquement) |
| `SUPABASE_ANON_KEY` | Clé anon (injectée automatiquement) |
| `SUPABASE_SERVICE_ROLE_KEY` | Clé service_role — **jamais dans le frontend** |
| `BREVO_API_KEY` | Clé API Brevo (Transactional emails) |
| `BRIMOT_FROM_EMAIL` | Adresse expéditrice vérifiée chez Brevo (ex. `noreply@brimot.ch`) |
| `BRIMOT_REPLY_TO_EMAIL` | *(optionnel)* Adresse de réponse (ex. `info@brimot.ch`) |

### Déployer la fonction

```bash
# Depuis la racine du projet (requiert Supabase CLI installée)
supabase functions deploy send-brimot-invoice --no-verify-jwt
```

> `--no-verify-jwt` : la passerelle Supabase ne vérifie pas le JWT avant d'appeler la
> fonction. L'authentification est faite dans le code : lecture du Bearer token +
> lookup `utilisateurs.role`.

---

## Déploiement Cloudflare Pages

### Paramètres

| Paramètre | Valeur |
|---|---|
| **Framework preset** | None |
| **Build command** | *(vide — pas de build)* |
| **Output directory** | `/` |
| **Root directory** | *(racine du dépôt)* |

### Variables d'environnement Cloudflare Pages

Cloudflare Pages ne peut pas injecter de variables dans des fichiers HTML statiques au
runtime. Deux options :

**Option A — Injection à la construction (CI/CD)** :
Utiliser une GitHub Action qui remplace les placeholders avant déploiement :

```bash
sed -i "s|REMPLACER_PAR_VOTRE_URL_SUPABASE|$SUPABASE_URL|g" js/config.js
sed -i "s|REMPLACER_PAR_VOTRE_CLE_ANON_PUBLIQUE|$SUPABASE_ANON_KEY|g" js/config.js
```

**Option B — Modifier `js/config.js` directement** :
Renseigner les vraies valeurs dans `config.js` avant de committer/déployer.
Acceptable car la clé `anon` est publique — voir [SECURITY_NOTES.md](SECURITY_NOTES.md).

### Fichier `_headers`

Le fichier `_headers` à la racine configure les en-têtes HTTP de sécurité pour Cloudflare
Pages. Il est inclus dans ce dépôt.

---

## Tests à effectuer après déploiement

- [ ] `https://votre-domaine/` redirige vers `/login/`
- [ ] La page de login s'affiche (thème sombre, formulaire email/mot de passe)
- [ ] Connexion avec un compte non-admin → refus avec message d'erreur
- [ ] Connexion avec un compte admin → redirection vers `/app/`
- [ ] L'application charge la liste des factures sans erreur console
- [ ] Création d'un client, d'un produit, d'une facture avec lignes
- [ ] Génération du PDF (jsPDF + html2canvas)
- [ ] Génération du bulletin de versement QR (SIX Swiss Payment Standard)
- [ ] Envoi email via Edge Function (vérifier réception + PDF joint)
- [ ] `https://votre-domaine/facture-view.html?data=...` affiche la facture correctement
- [ ] Déconnexion → retour sur `/login/` avec session effacée
- [ ] Accès direct à `/app/` sans session → redirection automatique vers `/login/`

---

## Dépendances frontend

| Fichier / Source | Hébergement | Usage |
|---|---|---|
| `js/supabase.min.js` | Local (bundle UMD) | Client Supabase (auth + DB) |
| `js/qrcode.min.js` | Local | QR Code SIX Swiss Payment |
| Google Fonts (Outfit + Bebas Neue) | CDN Google | Typographies |
| Font Awesome 6 | CDN cdnjs | Icônes |
| jsPDF 2.5.1 | CDN jsDelivr | Génération PDF client-side |
| html2canvas 1.4.1 | CDN jsDelivr | Capture HTML → image pour PDF |
