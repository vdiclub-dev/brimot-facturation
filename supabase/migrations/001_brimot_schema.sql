-- ============================================================
-- 001_brimot_schema.sql — Brimot Facturation
--
-- Crée les 4 tables de l'application de facturation autonome.
-- Sûr à rejouer : CREATE TABLE IF NOT EXISTS, DROP TRIGGER IF EXISTS.
-- Ne supprime aucune donnée existante.
--
-- Ordre d'exécution : ce fichier AVANT 002_brimot_rls.sql
-- Exécuter dans : Supabase SQL Editor  ou  supabase db push
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- Fonction générique pour mettre à jour updated_at
-- Crée une seule fois, partagée entre les 4 tables.
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


-- ════════════════════════════════════════════════════════════
-- TABLE : brimot_clients
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.brimot_clients (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  nom             text,
  prenom          text,
  raison_sociale  text,
  email           text,
  telephone       text,
  adresse         text,
  npa             text,
  ville           text,
  pays            text        NOT NULL DEFAULT 'CH',
  notes           text,
  statut          text        NOT NULL DEFAULT 'actif',
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

-- Contrainte de valeurs autorisées pour statut
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'brimot_clients_statut_check'
      AND conrelid = 'public.brimot_clients'::regclass
  ) THEN
    ALTER TABLE public.brimot_clients
      ADD CONSTRAINT brimot_clients_statut_check
      CHECK (statut IN ('actif', 'inactif', 'archivé'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS brimot_clients_email_idx  ON public.brimot_clients (email);
CREATE INDEX IF NOT EXISTS brimot_clients_statut_idx ON public.brimot_clients (statut);

DROP TRIGGER IF EXISTS trg_brimot_clients_updated_at ON public.brimot_clients;
CREATE TRIGGER trg_brimot_clients_updated_at
  BEFORE UPDATE ON public.brimot_clients
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ════════════════════════════════════════════════════════════
-- TABLE : brimot_produits
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.brimot_produits (
  id          uuid           PRIMARY KEY DEFAULT gen_random_uuid(),
  nom         text           NOT NULL,
  description text,
  categorie   text,
  prix_ht     numeric(12, 2) NOT NULL DEFAULT 0,
  taux_tva    numeric(5, 2)  NOT NULL DEFAULT 8.1,
  unite       text,
  variantes   jsonb          NOT NULL DEFAULT '[]'::jsonb,
  actif       boolean        NOT NULL DEFAULT true,
  created_at  timestamptz    NOT NULL DEFAULT now(),
  updated_at  timestamptz    NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS brimot_produits_actif_idx     ON public.brimot_produits (actif);
CREATE INDEX IF NOT EXISTS brimot_produits_categorie_idx ON public.brimot_produits (categorie);

DROP TRIGGER IF EXISTS trg_brimot_produits_updated_at ON public.brimot_produits;
CREATE TRIGGER trg_brimot_produits_updated_at
  BEFORE UPDATE ON public.brimot_produits
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ════════════════════════════════════════════════════════════
-- TABLE : brimot_factures
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.brimot_factures (
  id                  uuid           PRIMARY KEY DEFAULT gen_random_uuid(),
  type_document       text           NOT NULL DEFAULT 'facture',
  numero              text           UNIQUE,
  client_id           uuid           REFERENCES public.brimot_clients(id) ON DELETE SET NULL,
  date_document       date           NOT NULL DEFAULT current_date,
  date_echeance       date,
  statut              text           NOT NULL DEFAULT 'brouillon',
  objet               text,
  notes               text,
  conditions_paiement text,
  total_ht            numeric(12, 2) NOT NULL DEFAULT 0,
  total_tva           numeric(12, 2) NOT NULL DEFAULT 0,
  total_ttc           numeric(12, 2) NOT NULL DEFAULT 0,
  paiement_echelonne  boolean        NOT NULL DEFAULT false,
  echeances           jsonb          NOT NULL DEFAULT '[]'::jsonb,
  pdf_data            jsonb,
  created_at          timestamptz    NOT NULL DEFAULT now(),
  updated_at          timestamptz    NOT NULL DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'brimot_factures_type_check'
      AND conrelid = 'public.brimot_factures'::regclass
  ) THEN
    ALTER TABLE public.brimot_factures
      ADD CONSTRAINT brimot_factures_type_check
      CHECK (type_document IN ('facture', 'devis'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'brimot_factures_statut_check'
      AND conrelid = 'public.brimot_factures'::regclass
  ) THEN
    ALTER TABLE public.brimot_factures
      ADD CONSTRAINT brimot_factures_statut_check
      CHECK (statut IN ('brouillon', 'envoyee', 'payee', 'annulee'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS brimot_factures_client_id_idx     ON public.brimot_factures (client_id);
CREATE INDEX IF NOT EXISTS brimot_factures_statut_idx        ON public.brimot_factures (statut);
CREATE INDEX IF NOT EXISTS brimot_factures_date_document_idx ON public.brimot_factures (date_document DESC);
CREATE INDEX IF NOT EXISTS brimot_factures_type_idx          ON public.brimot_factures (type_document);

DROP TRIGGER IF EXISTS trg_brimot_factures_updated_at ON public.brimot_factures;
CREATE TRIGGER trg_brimot_factures_updated_at
  BEFORE UPDATE ON public.brimot_factures
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ════════════════════════════════════════════════════════════
-- TABLE : brimot_lignes
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.brimot_lignes (
  id               uuid           PRIMARY KEY DEFAULT gen_random_uuid(),
  facture_id       uuid           NOT NULL REFERENCES public.brimot_factures(id) ON DELETE CASCADE,
  produit_id       uuid           REFERENCES public.brimot_produits(id)         ON DELETE SET NULL,
  description      text,
  quantite         numeric(10, 3) NOT NULL DEFAULT 1,
  unite            text,
  prix_unitaire_ht numeric(12, 2) NOT NULL DEFAULT 0,
  taux_tva         numeric(5, 2)  NOT NULL DEFAULT 8.1,
  total_ht         numeric(12, 2) NOT NULL DEFAULT 0,
  total_tva        numeric(12, 2) NOT NULL DEFAULT 0,
  total_ttc        numeric(12, 2) NOT NULL DEFAULT 0,
  ordre            integer        NOT NULL DEFAULT 0,
  created_at       timestamptz    NOT NULL DEFAULT now(),
  updated_at       timestamptz    NOT NULL DEFAULT now()
);

-- Index principal sur facture_id (accès par facture, ordre des lignes)
CREATE INDEX IF NOT EXISTS brimot_lignes_facture_id_idx       ON public.brimot_lignes (facture_id);
CREATE INDEX IF NOT EXISTS brimot_lignes_produit_id_idx       ON public.brimot_lignes (produit_id);
CREATE INDEX IF NOT EXISTS brimot_lignes_facture_ordre_idx    ON public.brimot_lignes (facture_id, ordre);

DROP TRIGGER IF EXISTS trg_brimot_lignes_updated_at ON public.brimot_lignes;
CREATE TRIGGER trg_brimot_lignes_updated_at
  BEFORE UPDATE ON public.brimot_lignes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ════════════════════════════════════════════════════════════
-- Commentaires de table (documentation inline Supabase)
-- ════════════════════════════════════════════════════════════
COMMENT ON TABLE public.brimot_clients  IS 'Clients Brimot Nettoyage';
COMMENT ON TABLE public.brimot_produits IS 'Catalogue produits / prestations Brimot';
COMMENT ON TABLE public.brimot_factures IS 'Factures et devis Brimot (type_document: facture | devis)';
COMMENT ON TABLE public.brimot_lignes   IS 'Lignes de détail des factures Brimot (ON DELETE CASCADE avec brimot_factures)';
