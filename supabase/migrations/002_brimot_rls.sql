-- ============================================================
-- 002_brimot_rls.sql — Brimot Facturation
--
-- Active RLS sur les 4 tables Brimot.
-- Aucun accès anon. Accès authentifié réservé aux admin / super_admin.
-- DELETE autorisé pour super_admin seulement.
--
-- Dépendance : exécuter APRÈS 001_brimot_schema.sql
-- Dépendance : requiert la table public.utilisateurs avec colonne role
-- Exécuter dans : Supabase SQL Editor  ou  supabase db push
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- Révoquer tout accès anon sur les tables Brimot
-- (défense en profondeur : même sans policy, anon ne peut rien faire)
-- ────────────────────────────────────────────────────────────
REVOKE ALL ON public.brimot_clients  FROM anon;
REVOKE ALL ON public.brimot_produits FROM anon;
REVOKE ALL ON public.brimot_factures FROM anon;
REVOKE ALL ON public.brimot_lignes   FROM anon;


-- ────────────────────────────────────────────────────────────
-- Fonctions helper — SECURITY DEFINER pour lire utilisateurs
-- même si cette table a son propre RLS actif.
-- search_path figé à public pour éviter toute escalade de privilèges.
-- ────────────────────────────────────────────────────────────

-- brimot_is_admin() : retourne TRUE pour admin ET super_admin
CREATE OR REPLACE FUNCTION public.brimot_is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM   public.utilisateurs
    WHERE  id   = auth.uid()
      AND  role IN ('admin', 'super_admin')
      AND  (actif IS NULL OR actif = true)
  );
$$;

-- brimot_is_super_admin() : retourne TRUE pour super_admin uniquement
-- Utilisé pour les policies DELETE (droit de suppression renforcé).
CREATE OR REPLACE FUNCTION public.brimot_is_super_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM   public.utilisateurs
    WHERE  id   = auth.uid()
      AND  role = 'super_admin'
      AND  (actif IS NULL OR actif = true)
  );
$$;

-- Permissions d'exécution : uniquement authenticated et service_role
-- (service_role contourne RLS de toute façon — le GRANT est ici pour clarté)
REVOKE EXECUTE ON FUNCTION public.brimot_is_admin()        FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.brimot_is_super_admin()  FROM PUBLIC;

GRANT  EXECUTE ON FUNCTION public.brimot_is_admin()        TO authenticated;
GRANT  EXECUTE ON FUNCTION public.brimot_is_admin()        TO service_role;
GRANT  EXECUTE ON FUNCTION public.brimot_is_super_admin()  TO authenticated;
GRANT  EXECUTE ON FUNCTION public.brimot_is_super_admin()  TO service_role;


-- ────────────────────────────────────────────────────────────
-- Activer RLS sur les 4 tables
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.brimot_clients   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.brimot_produits  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.brimot_factures  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.brimot_lignes    ENABLE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════
-- POLICIES — brimot_clients
-- ════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "brimot_clients_admin_select" ON public.brimot_clients;
DROP POLICY IF EXISTS "brimot_clients_admin_insert" ON public.brimot_clients;
DROP POLICY IF EXISTS "brimot_clients_admin_update" ON public.brimot_clients;
DROP POLICY IF EXISTS "brimot_clients_admin_delete" ON public.brimot_clients;

-- Lecture : admin + super_admin
CREATE POLICY "brimot_clients_admin_select"
  ON public.brimot_clients
  FOR SELECT
  TO authenticated
  USING (public.brimot_is_admin());

-- Création : admin + super_admin
CREATE POLICY "brimot_clients_admin_insert"
  ON public.brimot_clients
  FOR INSERT
  TO authenticated
  WITH CHECK (public.brimot_is_admin());

-- Modification : admin + super_admin
CREATE POLICY "brimot_clients_admin_update"
  ON public.brimot_clients
  FOR UPDATE
  TO authenticated
  USING     (public.brimot_is_admin())
  WITH CHECK (public.brimot_is_admin());

-- Suppression : super_admin uniquement
-- Un admin peut archiver (statut = 'archivé') mais seul super_admin peut détruire la ligne.
CREATE POLICY "brimot_clients_admin_delete"
  ON public.brimot_clients
  FOR DELETE
  TO authenticated
  USING (public.brimot_is_super_admin());


-- ════════════════════════════════════════════════════════════
-- POLICIES — brimot_produits
-- ════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "brimot_produits_admin_select" ON public.brimot_produits;
DROP POLICY IF EXISTS "brimot_produits_admin_insert" ON public.brimot_produits;
DROP POLICY IF EXISTS "brimot_produits_admin_update" ON public.brimot_produits;
DROP POLICY IF EXISTS "brimot_produits_admin_delete" ON public.brimot_produits;

CREATE POLICY "brimot_produits_admin_select"
  ON public.brimot_produits
  FOR SELECT
  TO authenticated
  USING (public.brimot_is_admin());

CREATE POLICY "brimot_produits_admin_insert"
  ON public.brimot_produits
  FOR INSERT
  TO authenticated
  WITH CHECK (public.brimot_is_admin());

CREATE POLICY "brimot_produits_admin_update"
  ON public.brimot_produits
  FOR UPDATE
  TO authenticated
  USING     (public.brimot_is_admin())
  WITH CHECK (public.brimot_is_admin());

-- Suppression : super_admin uniquement
-- Un admin peut désactiver (actif = false) mais seul super_admin peut supprimer le produit.
CREATE POLICY "brimot_produits_admin_delete"
  ON public.brimot_produits
  FOR DELETE
  TO authenticated
  USING (public.brimot_is_super_admin());


-- ════════════════════════════════════════════════════════════
-- POLICIES — brimot_factures
-- ════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "brimot_factures_admin_select" ON public.brimot_factures;
DROP POLICY IF EXISTS "brimot_factures_admin_insert" ON public.brimot_factures;
DROP POLICY IF EXISTS "brimot_factures_admin_update" ON public.brimot_factures;
DROP POLICY IF EXISTS "brimot_factures_admin_delete" ON public.brimot_factures;

CREATE POLICY "brimot_factures_admin_select"
  ON public.brimot_factures
  FOR SELECT
  TO authenticated
  USING (public.brimot_is_admin());

CREATE POLICY "brimot_factures_admin_insert"
  ON public.brimot_factures
  FOR INSERT
  TO authenticated
  WITH CHECK (public.brimot_is_admin());

CREATE POLICY "brimot_factures_admin_update"
  ON public.brimot_factures
  FOR UPDATE
  TO authenticated
  USING     (public.brimot_is_admin())
  WITH CHECK (public.brimot_is_admin());

-- Suppression : super_admin uniquement
-- Un admin peut annuler (statut = 'annulee') mais seul super_admin peut détruire l'enregistrement.
CREATE POLICY "brimot_factures_admin_delete"
  ON public.brimot_factures
  FOR DELETE
  TO authenticated
  USING (public.brimot_is_super_admin());


-- ════════════════════════════════════════════════════════════
-- POLICIES — brimot_lignes
-- ════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "brimot_lignes_admin_select" ON public.brimot_lignes;
DROP POLICY IF EXISTS "brimot_lignes_admin_insert" ON public.brimot_lignes;
DROP POLICY IF EXISTS "brimot_lignes_admin_update" ON public.brimot_lignes;
DROP POLICY IF EXISTS "brimot_lignes_admin_delete" ON public.brimot_lignes;

CREATE POLICY "brimot_lignes_admin_select"
  ON public.brimot_lignes
  FOR SELECT
  TO authenticated
  USING (public.brimot_is_admin());

CREATE POLICY "brimot_lignes_admin_insert"
  ON public.brimot_lignes
  FOR INSERT
  TO authenticated
  WITH CHECK (public.brimot_is_admin());

CREATE POLICY "brimot_lignes_admin_update"
  ON public.brimot_lignes
  FOR UPDATE
  TO authenticated
  USING     (public.brimot_is_admin())
  WITH CHECK (public.brimot_is_admin());

-- Suppression des lignes : admin + super_admin (cas normal : supprimer une ligne de facture en cours d'édition)
-- NOTE : si la facture entière est supprimée, les lignes sont effacées automatiquement par ON DELETE CASCADE.
CREATE POLICY "brimot_lignes_admin_delete"
  ON public.brimot_lignes
  FOR DELETE
  TO authenticated
  USING (public.brimot_is_admin());
