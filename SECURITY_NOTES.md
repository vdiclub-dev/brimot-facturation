# Notes de sécurité — Brimot Facturation

---

## Recommandation générale

**Conserver ce dépôt en privé.** Même si `js/config.js` ne contient pas de secrets,
un dépôt public exposerait la structure de l'application à des tiers non autorisés.

---

## Ce qui est dans ce dépôt (sans secrets)

### `js/config.js` — informations publiques uniquement

Le fichier `config.js` contient uniquement :

- L'**URL du projet Supabase** et la **clé `anon`** — deux valeurs visibles dans le HTML
  chargé par n'importe quel navigateur. Ce ne sont pas des secrets : leur sécurité repose
  entièrement sur les politiques RLS activées côté Supabase.
- Les **constantes métier Brimot** (nom, adresse, IBAN, téléphone, email) — données
  figurant déjà sur les factures imprimées, non sensibles.

**Ne jamais ajouter dans `config.js` :**
- `service_role` key Supabase
- Clé API Brevo / Resend
- Tout token ou mot de passe

### `js/auth.js`

Helpers d'authentification (lecture session, vérification rôle via table `utilisateurs`).
Aucun secret. Fonctionne uniquement avec la clé `anon`.

---

## Ce qui n'est PAS dans ce dépôt (secrets serveur)

Les secrets suivants vivent **uniquement dans les variables d'environnement Supabase**
(Dashboard → Edge Functions → Secrets) :

| Secret | Usage |
|---|---|
| `SUPABASE_SERVICE_ROLE_KEY` | Accès admin base de données depuis l'Edge Function |
| `BREVO_API_KEY` | Envoi d'emails via l'API Brevo |
| `BRIMOT_FROM_EMAIL` | Adresse expéditrice vérifiée chez Brevo |
| `BRIMOT_REPLY_TO_EMAIL` | Adresse de réponse (optionnel) |

Ces valeurs ne transitent **jamais vers le navigateur**.

---

## RLS — Row Level Security

### Statut

RLS est activé sur les 4 tables de facturation :
`brimot_clients`, `brimot_produits`, `brimot_factures`, `brimot_lignes`.

### Politique appliquée (migration `002_brimot_rls.sql`)

| Opération | Rôle autorisé |
|---|---|
| SELECT | `admin`, `super_admin` |
| INSERT | `admin`, `super_admin` |
| UPDATE | `admin`, `super_admin` |
| DELETE (clients, produits, factures) | `super_admin` uniquement |
| DELETE (lignes) | `admin`, `super_admin` |

**Aucune policy `anon`.** En plus du RLS, `REVOKE ALL … FROM anon` est appliqué sur les
4 tables — défense en profondeur.

La vérification du rôle passe par la fonction `public.brimot_is_admin()` /
`public.brimot_is_super_admin()` — `SECURITY DEFINER`, `search_path = public`,
peut lire `utilisateurs` même si cette table a son propre RLS.

### À vérifier avant mise en production

```sql
-- RLS activé sur toutes les tables brimot ?
SELECT relname, relrowsecurity
FROM pg_class
WHERE relname LIKE 'brimot_%' AND relkind = 'r';
-- Toutes les lignes doivent avoir relrowsecurity = true

-- Aucune policy anon ?
SELECT tablename, policyname, roles
FROM pg_policies
WHERE schemaname = 'public' AND tablename LIKE 'brimot_%';
-- La colonne roles ne doit contenir que {authenticated}
```

---

## Edge Function — send-brimot-invoice

- Déployée avec `--no-verify-jwt` : la passerelle Supabase ne pré-vérifie pas le JWT,
  mais **la fonction le vérifie elle-même** via `supabase.auth.getUser()` +
  lookup `utilisateurs.role`.
- Seuls les comptes `admin` / `super_admin` peuvent envoyer des emails.
- Le `SUPABASE_SERVICE_ROLE_KEY` est lu via `Deno.env.get()` — jamais exposé.
- La clé Brevo est lue via `Deno.env.get("BREVO_API_KEY")` — jamais exposée.

---

## Clé `anon` Supabase — rappel

La clé `anon` est une clé **publique par conception** (SIX Swiss Payment Standard pour
les bulletins de versement QR, jsPDF, html2canvas sont tous côté client).

Elle est visible dans tout navigateur via les DevTools. Sa sécurité repose sur :
1. Le RLS activé sur toutes les tables accessibles via cette clé.
2. L'absence totale de policy permissive pour le rôle `anon`.

Si la clé a été exposée dans un dépôt public par erreur → faire une rotation :
Supabase Dashboard → Settings → API → Regenerate anon key.

---

## Rotation recommandée

Si ce dépôt a été rendu public accidentellement ou partagé en dehors de l'équipe :

1. Régénérer la clé `anon` Supabase (Settings → API).
2. Mettre à jour `js/config.js` avec la nouvelle clé.
3. Vérifier les logs Supabase pour détecter tout accès non autorisé.
