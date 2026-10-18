-- =============================================================================
-- V2 : des lignes qui existent AVANT la mise en place de la publication et de
-- la souscription.
--
-- Elles ne passeront pas par le flux du WAL. À la place, quand la souscription
-- est créée avec copy_data = true (le défaut), un processus de synchronisation
-- de table effectue une copie initiale (COPY) de la table, en appliquant le
-- même filtre de lignes et la même liste de colonnes.
-- Attendu sur la destination après le démarrage : Alice et Chloé seulement
-- (EU), sans internal_notes / credit_card_number.
-- =============================================================================
INSERT INTO customers (first_name, last_name, email, region, loyalty_points, internal_notes, credit_card_number)
VALUES ('Alice', 'Martin', 'alice@example.com', 'EU',  120, 'VIP, prefers email',  '4111-1111-1111-1111'),
       ('Bob',   'Smith',  'bob@example.com',   'US',   40, 'Late payer',          '5500-0000-0000-0004'),
       ('Chloé', 'Durand', 'chloe@example.com', 'EU',    0, NULL,                  NULL),
       ('Kenji', 'Sato',   'kenji@example.com', 'APAC', 75, 'Asked for a refund',  '3400-0000-0000-009');
