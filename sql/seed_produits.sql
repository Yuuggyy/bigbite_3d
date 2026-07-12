-- ── SEED PRODUITS : Big Bite ──────────────────────────────
INSERT INTO public.restaurants (nom, slug)
VALUES ('Big Bite', 'bigbite')
ON CONFLICT (slug) DO NOTHING;

DO $$
DECLARE rid UUID;
BEGIN
  SELECT id INTO rid FROM public.restaurants WHERE slug = 'bigbite';
  INSERT INTO public.produits (restaurant_id, nom, description, prix, categorie, disponible) VALUES
    (rid, 'Tacos Poulet Combo', 'Tacos poulet + boisson + frites', 13.77, 'Tacos', true),
    (rid, 'Tacos Viande Combo', 'Tacos viande + boisson + frites', 13.77, 'Tacos', true),
    (rid, 'Tacos Poulet Sandwich', 'Tacos poulet a la carte', 8.20, 'Tacos', true),
    (rid, 'Tacos Viande Sandwich', 'Tacos viande a la carte', 7.85, 'Tacos', true),
    (rid, 'Mexican Tacos Combo', 'Epices mexicaines + boisson + frites', 12.31, 'Tacos', true),
    (rid, 'Sweet Chilli Tacos Combo', 'Sauce sweet chilli + boisson + frites', 12.31, 'Tacos', true),
    (rid, 'Shawarma Viande Sandwich', 'Pain pita, viande, sauce maison', 5.27, 'Shawarma & Sandwich', true),
    (rid, 'Shawarma Poulet Sandwich', 'Pain pita, poulet, legumes', 5.27, 'Shawarma & Sandwich', true),
    (rid, 'Shawarma Viande Combo', 'Shawarma viande + boisson', 11.72, 'Shawarma & Sandwich', true),
    (rid, 'Shawarma Poulet Combo', 'Shawarma poulet + boisson', 11.72, 'Shawarma & Sandwich', true),
    (rid, 'Twister Combo', 'Rouleau poulet croustillant + boisson', 11.25, 'Shawarma & Sandwich', true),
    (rid, 'Shawarma Viande Plate', 'Assiette shawarma viande + garniture', 17.11, 'Shawarma & Sandwich', true),
    (rid, 'Margherita Tortilla Pizza', 'Tomate, mozzarella', 9.02, 'Pizza Tortilla', true),
    (rid, 'Pepperoni Tortilla Pizza', 'Pepperoni, fromage fondu', 9.96, 'Pizza Tortilla', true),
    (rid, 'Mortadelle Tortilla Pizza', 'Mortadelle, mozzarella', 9.96, 'Pizza Tortilla', true),
    (rid, 'Viande Tortilla Pizza', 'Viande hachee epicee, legumes', 10.55, 'Pizza Tortilla', true),
    (rid, 'Ailes Combo', '6 ailes croustillantes + boisson + frites', 13.13, 'Poulet Croustillant', true),
    (rid, 'Ailes 12 Combo', '12 ailes croustillantes + boisson + frites', 16.41, 'Poulet Croustillant', true),
    (rid, 'Crispy Burger Promo', 'Burger + coca + frites + 3pcs poulet', 10.43, 'Poulet Croustillant', true),
    (rid, 'Crispy Box Individuel', 'Crispy box + frites + boisson', 13.83, 'Poulet Croustillant', true),
    (rid, 'Bucket Meal Famille', 'Bucket poulet + accompagnements pour 4', 45.71, 'Menus Famille', true),
    (rid, 'Crispy Super Famille', 'Poulet croustillant x8 + frites + boissons', 47.47, 'Menus Famille', true),
    (rid, 'Mixata Bucket', 'Mix poulet varie pour la famille', 52.04, 'Menus Famille', true),
    (rid, 'Family Bite', 'Grand assortiment Big Bite pour 4-6', 57.19, 'Menus Famille', true),
    (rid, 'Mini Crispy Meal', 'Mini format crispy individuel', 9.14, 'Menus Individuels', true),
    (rid, 'Lunch Meal', 'Repas de midi complet', 13.13, 'Menus Individuels', true),
    (rid, 'BigBite Meal', 'Le repas signature Big Bite', 15.12, 'Menus Individuels', true),
    (rid, 'Promo Poulet Individuel', 'Poulet croustillant + frites + boisson', 14.42, 'Menus Individuels', true),
    (rid, 'Coca Cola 33cl', NULL, 2.34, 'Boissons', true),
    (rid, 'Fanta 33cl', NULL, 2.34, 'Boissons', true),
    (rid, 'Sprite 33cl', NULL, 2.34, 'Boissons', true),
    (rid, 'Eau Minerale', NULL, 0.88, 'Boissons', true),
    (rid, 'Jus Frisco', 'Jus de fruit frais', 2.11, 'Boissons', true)
  ON CONFLICT DO NOTHING;
END $$;
