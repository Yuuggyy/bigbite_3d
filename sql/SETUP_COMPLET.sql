-- ============================================================
-- O POETA — SETUP COMPLET (UN SEUL SCRIPT, UNE SEULE FOIS)
-- Copier-coller en entier dans Supabase > SQL Editor
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 1 : PURGE TOTALE
-- ────────────────────────────────────────────────────────────
SET session_replication_role = replica;

DO $$ DECLARE r RECORD;
BEGIN
  FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public')
  LOOP
    EXECUTE 'DROP TABLE IF EXISTS public.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END $$;

DO $$ DECLARE r RECORD;
BEGIN
  FOR r IN (
    SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
  )
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS public.' || quote_ident(r.proname) || '(' || r.args || ') CASCADE';
  END LOOP;
END $$;

SET session_replication_role = DEFAULT;

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 2 : EXTENSIONS
-- ────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 3 : TABLES
-- ────────────────────────────────────────────────────────────

CREATE TABLE public.categories (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nom         TEXT NOT NULL,
  description TEXT,
  emoji       TEXT DEFAULT '🍽️',
  ordre       INTEGER DEFAULT 0,
  actif       BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.produits (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  categorie_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
  nom          TEXT NOT NULL,
  description  TEXT,
  prix         NUMERIC(10,2) NOT NULL DEFAULT 0,
  image_url    TEXT,
  disponible   BOOLEAN DEFAULT true,
  ordre        INTEGER DEFAULT 0,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.commandes (
  id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  numero_table       TEXT NOT NULL,
  statut             TEXT NOT NULL DEFAULT 'recue'
                       CHECK (statut IN ('recue', 'en_cours', 'terminee', 'annulee')),
  demandes_speciales TEXT,
  montant_total      NUMERIC(10,2) DEFAULT 0,
  created_at         TIMESTAMPTZ DEFAULT NOW(),
  updated_at         TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.commande_items (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  commande_id UUID NOT NULL REFERENCES public.commandes(id) ON DELETE CASCADE,
  produit_id  UUID REFERENCES public.produits(id) ON DELETE SET NULL,
  nom_produit TEXT NOT NULL,
  prix_unit   NUMERIC(10,2) NOT NULL,
  quantite    INTEGER NOT NULL DEFAULT 1,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.appels_serveur (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  numero_table TEXT NOT NULL,
  message      TEXT DEFAULT 'Un client demande le serveur',
  traite       BOOLEAN DEFAULT false,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.admin_profiles (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email      TEXT NOT NULL,
  nom        TEXT,
  role       TEXT DEFAULT 'admin',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.parametres (
  id             INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  nom_restaurant TEXT DEFAULT 'Big Bite',
  logo_url       TEXT,
  adresse        TEXT DEFAULT 'Kinshasa Mall, Avenue 24 Novembre, Kinshasa',
  telephone      TEXT DEFAULT '+243 900 000 720',
  whatsapp       TEXT DEFAULT '243900000720',
  horaires       TEXT DEFAULT 'Tous les jours 10h00 - 22h00',
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 4 : FONCTIONS ET TRIGGERS
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_produits_updated_at
  BEFORE UPDATE ON public.produits
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_commandes_updated_at
  BEFORE UPDATE ON public.commandes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_parametres_updated_at
  BEFORE UPDATE ON public.parametres
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Trigger : crée automatiquement un profil admin quand un user s'inscrit
CREATE OR REPLACE FUNCTION public.handle_new_admin()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.admin_profiles (id, email, nom)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'nom', 'Admin'))
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_admin();

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 5 : RLS (UN SEUL BLOC, SANS AMBIGUÏTÉ)
-- ────────────────────────────────────────────────────────────

ALTER TABLE public.categories      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.produits        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commandes       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commande_items  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appels_serveur  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_profiles  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parametres      ENABLE ROW LEVEL SECURITY;

-- CATÉGORIES : lecture publique, écriture admin
CREATE POLICY "cat_select"  ON public.categories FOR SELECT USING (true);
CREATE POLICY "cat_insert"  ON public.categories FOR INSERT WITH CHECK (auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "cat_update"  ON public.categories FOR UPDATE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "cat_delete"  ON public.categories FOR DELETE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));

-- PRODUITS : lecture publique, écriture admin
CREATE POLICY "prod_select" ON public.produits FOR SELECT USING (true);
CREATE POLICY "prod_insert" ON public.produits FOR INSERT WITH CHECK (auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "prod_update" ON public.produits FOR UPDATE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "prod_delete" ON public.produits FOR DELETE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));

-- COMMANDES : insertion SANS connexion, gestion admin
CREATE POLICY "cmd_insert"  ON public.commandes FOR INSERT WITH CHECK (true);
CREATE POLICY "cmd_select"  ON public.commandes FOR SELECT USING (auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "cmd_update"  ON public.commandes FOR UPDATE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "cmd_delete"  ON public.commandes FOR DELETE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));

-- COMMANDE ITEMS : insertion SANS connexion, lecture admin
CREATE POLICY "item_insert" ON public.commande_items FOR INSERT WITH CHECK (true);
CREATE POLICY "item_select" ON public.commande_items FOR SELECT USING (auth.uid() IN (SELECT id FROM public.admin_profiles));

-- APPELS SERVEUR : insertion SANS connexion, gestion admin
CREATE POLICY "appel_insert" ON public.appels_serveur FOR INSERT WITH CHECK (true);
CREATE POLICY "appel_select" ON public.appels_serveur FOR SELECT USING (auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "appel_update" ON public.appels_serveur FOR UPDATE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));

-- PARAMÈTRES : lecture publique, écriture admin
CREATE POLICY "param_select" ON public.parametres FOR SELECT USING (true);
CREATE POLICY "param_update" ON public.parametres FOR UPDATE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));

-- ADMIN PROFILES : accès propre uniquement
CREATE POLICY "ap_select" ON public.admin_profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "ap_update" ON public.admin_profiles FOR UPDATE USING (auth.uid() = id);

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 6 : STORAGE BUCKET
-- ────────────────────────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public)
VALUES ('menu-images', 'menu-images', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "img_select" ON storage.objects;
DROP POLICY IF EXISTS "img_insert" ON storage.objects;
DROP POLICY IF EXISTS "img_update" ON storage.objects;
DROP POLICY IF EXISTS "img_delete" ON storage.objects;
DROP POLICY IF EXISTS "lecture_publique_images" ON storage.objects;
DROP POLICY IF EXISTS "upload_admin_images" ON storage.objects;
DROP POLICY IF EXISTS "update_admin_images" ON storage.objects;
DROP POLICY IF EXISTS "delete_admin_images" ON storage.objects;
DROP POLICY IF EXISTS "menu_images_select_all" ON storage.objects;
DROP POLICY IF EXISTS "menu_images_insert_admin" ON storage.objects;
DROP POLICY IF EXISTS "menu_images_update_admin" ON storage.objects;
DROP POLICY IF EXISTS "menu_images_delete_admin" ON storage.objects;

CREATE POLICY "img_select" ON storage.objects FOR SELECT USING (bucket_id = 'menu-images');
CREATE POLICY "img_insert" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'menu-images' AND auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "img_update" ON storage.objects FOR UPDATE USING (bucket_id = 'menu-images' AND auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "img_delete" ON storage.objects FOR DELETE USING (bucket_id = 'menu-images' AND auth.uid() IN (SELECT id FROM public.admin_profiles));

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 7 : DONNÉES PAR DÉFAUT
-- ────────────────────────────────────────────────────────────

INSERT INTO public.parametres (id, nom_restaurant, adresse, telephone, whatsapp, horaires)
VALUES (1, 'Big Bite', 'Kinshasa Mall, Avenue 24 Novembre, Kinshasa', '+243 900 000 720', '243900000720', 'Tous les jours 10h00 - 22h00')
ON CONFLICT (id) DO NOTHING;

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 8 : BACKFILL ADMIN (pour compte existant avant le trigger)
-- ────────────────────────────────────────────────────────────

INSERT INTO public.admin_profiles (id, email, nom)
SELECT id, email, COALESCE(raw_user_meta_data->>'nom', 'Admin')
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 9 : MENU BIG BITE (tacos, shawarma, pizza tortilla)
INSERT INTO public.categories (nom, description, emoji, ordre, actif) VALUES
('Tacos',              'Tacos poulet et viande',            '🌮', 1, true),
('Shawarma & Sandwich','Shawarma et sandwichs',             '🥙', 2, true),
('Pizza Tortilla',     'Pizzas sur tortilla croustillante', '🍕', 3, true),
('Poulet Croustillant','Ailes, crispy box, combos',         '🍗', 4, true),
('Menus Famille',      'Grands formats pour partager',      '👨‍👩‍👧', 5, true),
('Menus Individuels',  'Repas complets individuels',        '🍱', 6, true),
('Boissons',           'Sodas, jus, boissons fraiches',     '🥤', 7, true)
ON CONFLICT DO NOTHING;

INSERT INTO public.produits (nom, description, prix, categorie_id, disponible, ordre) VALUES
('Tacos Poulet Combo',        'Tacos poulet + boisson + frites',              13.77, (SELECT id FROM categories WHERE nom='Tacos'), true, 1),
('Tacos Viande Combo',        'Tacos viande + boisson + frites',              13.77, (SELECT id FROM categories WHERE nom='Tacos'), true, 2),
('Tacos Poulet Sandwich',     'Tacos poulet a la carte',                       8.20, (SELECT id FROM categories WHERE nom='Tacos'), true, 3),
('Tacos Viande Sandwich',     'Tacos viande a la carte',                       7.85, (SELECT id FROM categories WHERE nom='Tacos'), true, 4),
('Mexican Tacos Combo',       'Epices mexicaines + boisson + frites',         12.31, (SELECT id FROM categories WHERE nom='Tacos'), true, 5),
('Sweet Chilli Tacos Combo',  'Sauce sweet chilli + boisson + frites',        12.31, (SELECT id FROM categories WHERE nom='Tacos'), true, 6),
('Shawarma Viande Sandwich',  'Pain pita, viande, sauce maison',               5.27, (SELECT id FROM categories WHERE nom='Shawarma & Sandwich'), true, 1),
('Shawarma Poulet Sandwich',  'Pain pita, poulet, legumes',                    5.27, (SELECT id FROM categories WHERE nom='Shawarma & Sandwich'), true, 2),
('Shawarma Viande Combo',     'Shawarma viande + boisson',                    11.72, (SELECT id FROM categories WHERE nom='Shawarma & Sandwich'), true, 3),
('Shawarma Poulet Combo',     'Shawarma poulet + boisson',                    11.72, (SELECT id FROM categories WHERE nom='Shawarma & Sandwich'), true, 4),
('Twister Combo',             'Rouleau poulet croustillant + boisson',        11.25, (SELECT id FROM categories WHERE nom='Shawarma & Sandwich'), true, 5),
('Shawarma Viande Plate',     'Assiette shawarma viande + garniture',         17.11, (SELECT id FROM categories WHERE nom='Shawarma & Sandwich'), true, 6),
('Margherita Tortilla Pizza', 'Tomate, mozzarella',                            9.02, (SELECT id FROM categories WHERE nom='Pizza Tortilla'), true, 1),
('Pepperoni Tortilla Pizza',  'Pepperoni, fromage fondu',                      9.96, (SELECT id FROM categories WHERE nom='Pizza Tortilla'), true, 2),
('Mortadelle Tortilla Pizza', 'Mortadelle, mozzarella',                        9.96, (SELECT id FROM categories WHERE nom='Pizza Tortilla'), true, 3),
('Viande Tortilla Pizza',     'Viande hachee epicee, legumes',                10.55, (SELECT id FROM categories WHERE nom='Pizza Tortilla'), true, 4),
('Ailes Combo',               '6 ailes croustillantes + boisson + frites',   13.13, (SELECT id FROM categories WHERE nom='Poulet Croustillant'), true, 1),
('Ailes 12 Combo',            '12 ailes croustillantes + boisson + frites',  16.41, (SELECT id FROM categories WHERE nom='Poulet Croustillant'), true, 2),
('Crispy Burger Promo',       'Burger + coca + frites + 3pcs poulet',         10.43, (SELECT id FROM categories WHERE nom='Poulet Croustillant'), true, 3),
('Crispy Box Individuel',     'Crispy box + frites + boisson',                13.83, (SELECT id FROM categories WHERE nom='Poulet Croustillant'), true, 4),
('Bucket Meal Famille',       'Bucket poulet + accompagnements pour 4',       45.71, (SELECT id FROM categories WHERE nom='Menus Famille'), true, 1),
('Crispy Super Famille',      'Poulet croustillant x8 + frites + boissons',  47.47, (SELECT id FROM categories WHERE nom='Menus Famille'), true, 2),
('Mixata Bucket',             'Mix poulet varie pour la famille',              52.04, (SELECT id FROM categories WHERE nom='Menus Famille'), true, 3),
('Family Bite',               'Grand assortiment Big Bite pour 4-6',          57.19, (SELECT id FROM categories WHERE nom='Menus Famille'), true, 4),
('Mini Crispy Meal',          'Mini format crispy individuel',                  9.14, (SELECT id FROM categories WHERE nom='Menus Individuels'), true, 1),
('Lunch Meal',                'Repas de midi complet',                         13.13, (SELECT id FROM categories WHERE nom='Menus Individuels'), true, 2),
('BigBite Meal',              'Le repas signature Big Bite',                   15.12, (SELECT id FROM categories WHERE nom='Menus Individuels'), true, 3),
('Promo Poulet Individuel',   'Poulet croustillant + frites + boisson',        14.42, (SELECT id FROM categories WHERE nom='Menus Individuels'), true, 4),
('Coca Cola 33cl',            NULL,                                              2.34, (SELECT id FROM categories WHERE nom='Boissons'), true, 1),
('Fanta 33cl',                NULL,                                              2.34, (SELECT id FROM categories WHERE nom='Boissons'), true, 2),
('Sprite 33cl',               NULL,                                              2.34, (SELECT id FROM categories WHERE nom='Boissons'), true, 3),
('Eau Minerale',              NULL,                                              0.88, (SELECT id FROM categories WHERE nom='Boissons'), true, 4),
('Jus Frisco',                'Jus de fruit frais',                             2.11, (SELECT id FROM categories WHERE nom='Boissons'), true, 5)
ON CONFLICT DO NOTHING;


-- ────────────────────────────────────────────────────────────
-- VÉRIFICATION FINALE
-- ────────────────────────────────────────────────────────────
SELECT
  (SELECT count(*) FROM public.categories) AS nb_categories,
  (SELECT count(*) FROM public.produits)   AS nb_produits,
  (SELECT count(*) FROM public.admin_profiles) AS nb_admins,
  'Setup terminé OK' AS status;
