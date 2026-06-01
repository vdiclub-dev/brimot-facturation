# Notes de sécurité — Brimot Facturation Export

---

## 🔴 CRITIQUE — Credentials hardcodés dans le dépôt source

Le fichier original `js/config.js` du dépôt `swissbill` contient en clair :

- L'URL Supabase de production : `https://iubbsnntcreneakbdkmv.supabase.co`
- La clé `anon` Supabase complète (JWT signé)

**Ces valeurs ont été retirées de cette copie export.**
Le `config.js` inclus ici contient uniquement des placeholders.

### Actions recommandées

1. **Rotation de la clé anon** si elle a été exposée dans un dépôt public ou partagé.
   → Supabase Dashboard → Settings → API → Regenerate anon key
2. **Ne jamais committer** les vraies valeurs dans ce dépôt export.
3. Injecter les valeurs via des secrets CI/CD ou des variables d'environnement serveur.

---

## 🟠 AVERTISSEMENT — RLS trop permissif dans `fix_facturation_rls.sql`

Le script `supabase/fix_facturation_rls.sql` crée des politiques qui accordent
**ALL (lecture + écriture) au rôle `anon`** sur `factures` et `facture_lignes` :

```sql
CREATE POLICY "anon_all_factures" ON public.factures
  FOR ALL TO anon USING (true) WITH CHECK (true);
```

Ce paramétrage a probablement été utilisé pour débloquer un accès en urgence.
**Il ne doit pas être utilisé tel quel en production.**

### Actions recommandées avant de l'appliquer

- Remplacer les policies `anon` par des policies `authenticated` uniquement.
- Ajouter des conditions `USING` basées sur `auth.uid()` pour limiter la visibilité
  par entreprise ou par utilisateur.
- Exemple de policy restrictive :

```sql
CREATE POLICY "admin_only_factures" ON public.factures
  FOR ALL TO authenticated
  USING (public.colixo_is_admin())
  WITH CHECK (public.colixo_is_admin());
```

---

## 🟡 INFORMATION — Clé `anon` côté frontend

La clé `anon` Supabase est une clé **publique par conception** — elle est visible
dans le HTML/JS chargé par le navigateur. Ce n'est pas un secret.
Sa sécurité repose entièrement sur les politiques RLS activées côté Supabase.

Vérifier que RLS est activé (`ALTER TABLE ... ENABLE ROW LEVEL SECURITY`)
sur toutes les tables accessibles via cette clé.

---

## 🟡 INFORMATION — `send_mail.php` (fallback PHP)

Le fichier `admin/brimot/send_mail.php` est un fallback d'envoi d'e-mail PHP.
- Il ne contient pas de secrets dans cette copie.
- Si déployé sur un serveur PHP, s'assurer qu'il est protégé par authentification
  (via `.htaccess` ou équivalent) — voir `admin/brimot/.htaccess`.
- Privilégier la Edge Function `send-brimot-invoice` (Brevo API) plutôt que ce fallback.

---

## 🟢 OK — Edge Function `send-brimot-invoice`

- N'expose aucun secret : toutes les valeurs sensibles sont lues via `Deno.env.get()`.
- Vérifie le JWT appelant avant toute action (rôle dans `utilisateurs`).
- Les secrets Supabase (`SUPABASE_SERVICE_ROLE_KEY`, etc.) ne transitent jamais vers le browser.
