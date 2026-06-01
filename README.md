# Brimot Facturation — Export autonome

Module de facturation Brimot extrait du dépôt principal swissbill.
Gère la création de factures (numérotées `BR-YYYY-NNNN`), leur visualisation PDF,
et leur envoi par e-mail via Brevo.

---

## Structure

```
brimot-facturation-export/
├── admin/brimot/
│   ├── facturation.html       # Interface principale de facturation
│   ├── facture-view.html      # Visualisation / impression d'une facture
│   ├── qrcode.min.js          # Génération QR code (dépendance locale)
│   └── send_mail.php          # Fallback mail PHP (optionnel)
├── js/
│   ├── auth.js                # Authentification Colixo (session + legacy code)
│   ├── config.js              # ⚠️  À configurer avant déploiement (voir ci-dessous)
│   └── invoices.js            # Logique métier : création / listing des factures
├── supabase/
│   ├── fix_facturation_rls.sql               # Politiques RLS tables factures
│   └── functions/send-brimot-invoice/
│       └── index.ts           # Edge Function Deno — envoi e-mail via Brevo
└── .gitignore
```

---

## Variables d'environnement

### `js/config.js` (frontend)

Remplacer les placeholders par les valeurs réelles de votre projet Supabase.
**Ne jamais committer les vraies valeurs.**

| Variable window             | Description                        |
|-----------------------------|------------------------------------|
| `COLIXO_SUPABASE_URL`       | URL du projet Supabase             |
| `COLIXO_SUPABASE_ANON_KEY`  | Clé publique anon (non secrète)    |

Exemple d'injection Netlify (`netlify.toml`) :

```toml
[build.environment]
  SUPABASE_URL      = "https://XXXX.supabase.co"
  SUPABASE_ANON_KEY = "eyJ..."
```

Avec remplacement via sed dans le pipeline :

```bash
sed -i "s|REMPLACER_PAR_VOTRE_URL_SUPABASE|$SUPABASE_URL|g" js/config.js
sed -i "s|REMPLACER_PAR_VOTRE_CLE_ANON_PUBLIQUE|$SUPABASE_ANON_KEY|g" js/config.js
```

### Edge Function `send-brimot-invoice` (Supabase)

Configurer dans **Supabase Dashboard → Edge Functions → Secrets** :

| Variable d'env                | Rôle                                      |
|-------------------------------|-------------------------------------------|
| `SUPABASE_URL`                | URL du projet (fourni automatiquement)    |
| `SUPABASE_SERVICE_ROLE_KEY`   | Clé service_role (fourni automatiquement) |
| `SUPABASE_ANON_KEY`           | Clé anon publique                         |
| `BREVO_API_KEY`               | Clé API Brevo (Sendinblue)                |
| `BRIMOT_FROM_EMAIL`           | Adresse expéditrice (ex: factures@colixo.ch) |
| `BRIMOT_REPLY_TO_EMAIL`       | Adresse de réponse                        |

Déploiement :

```bash
supabase functions deploy send-brimot-invoice --project-ref <ref>
supabase secrets set BREVO_API_KEY=... BRIMOT_FROM_EMAIL=... BRIMOT_REPLY_TO_EMAIL=...
```

---

## Tables Supabase requises

Le module suppose l'existence des tables suivantes dans `public` :

| Table           | Usage                                              |
|-----------------|----------------------------------------------------|
| `invoices`      | Factures (numérotées `BR-YYYY-NNNN`)               |
| `factures`      | Table alternative / legacy (voir fix_facturation_rls.sql) |
| `facture_lignes`| Lignes de détail des factures                      |
| `utilisateurs`  | Profils utilisateurs (role, email) — auth Brimot   |
| `clients`       | Clients facturés                                   |

Appliquer le script RLS avant la mise en production :

```bash
# Via Supabase CLI
supabase db push --file supabase/fix_facturation_rls.sql

# Ou coller le contenu dans Supabase → SQL Editor
```

> ⚠️  Lire SECURITY_NOTES.md avant d'appliquer ce script.

---

## Dépendances frontend

Chargées depuis CDN dans `facturation.html` / `facture-view.html` :

- [jsPDF 2.5.1](https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js) — génération PDF
- [html2canvas 1.4.1](https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js) — capture HTML → PDF
- [@supabase/supabase-js 2.x](https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js) — client Supabase
- `qrcode.min.js` (local) — QR code sur les factures

---

## Déploiement statique (Netlify / Vercel)

1. Injecter les variables dans `js/config.js` via votre pipeline CI.
2. Protéger `admin/brimot/` par authentification (nginx, Netlify `_headers`, etc.).
3. Déployer la Edge Function `send-brimot-invoice`.
4. Appliquer les scripts SQL RLS (après lecture de SECURITY_NOTES.md).
