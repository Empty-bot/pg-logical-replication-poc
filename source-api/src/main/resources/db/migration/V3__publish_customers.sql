-- =============================================================================
-- V3 : CONFIGURATION DE LA RÉPLICATION CÔTÉ PUBLIEUR  (le cœur du PoC)
--
-- Une PUBLICATION est un ensemble nommé de tables (et, depuis PG15, de lignes
-- et de colonnes) dont les changements sont décodés depuis le WAL et envoyés
-- aux abonnés. Elle ne stocke aucune donnée et ne démarre rien par elle-même :
-- la diffusion ne commence que lorsqu'un abonné se connecte via un slot de
-- réplication (V4).
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Étape 1 - REPLICA IDENTITY : choisir les colonnes qui identifient une ligne
-- dans le WAL.
--
-- Pour un UPDATE (et un DELETE), le WAL enregistre l'« ancienne » version de
-- la ligne en ne gardant que les colonnes de la replica identity. Par défaut,
-- il s'agit de la clé primaire, c'est-à-dire seulement « id ».
--
-- Ce défaut ne suffit pas ici, à cause de deux règles de Postgres :
--
--   Règle A (filtres de lignes) : si une publication publie les UPDATE/DELETE,
--          sa clause WHERE ne peut référencer que des colonnes de la REPLICA
--          IDENTITY.
--          Raison : pour un UPDATE, Postgres évalue le filtre sur l'ancienne
--          ET la nouvelle ligne, et seules les colonnes de la replica identity
--          de l'ancienne ligne sont disponibles dans le WAL. Notre filtre
--          utilise « region », donc « region » doit faire partie de la
--          replica identity.
--
--   Règle B (listes de colonnes) : si une publication publie les
--          UPDATE/DELETE, sa liste de colonnes doit inclure toutes les
--          colonnes de la REPLICA IDENTITY, sinon l'abonné ne pourrait pas
--          retrouver la ligne à mettre à jour.
--
-- La solution tentante, REPLICA IDENTITY FULL (la ligne entière sert
-- d'identité), satisfait la règle A mais casse la règle B : la liste de
-- colonnes devrait alors contenir TOUTES les colonnes, et on ne pourrait plus
-- masquer internal_notes / credit_card_number.
--
-- La solution qui satisfait les deux : un index UNIQUE sur (id, region),
-- utilisé comme replica identity. Exigences pour un tel index : unique, non
-- partiel, non différable, et uniquement sur des colonnes NOT NULL (d'où le
-- region NOT NULL en V1). Il est trivialement unique puisque « id » l'est
-- déjà seul.
-- -----------------------------------------------------------------------------
CREATE UNIQUE INDEX customers_replica_identity_idx ON customers (id, region);

ALTER TABLE customers REPLICA IDENTITY USING INDEX customers_replica_identity_idx;


-- -----------------------------------------------------------------------------
-- Étape 2 - la PUBLICATION elle-même.
--
--   FOR TABLE customers (col, col, ...)
--       Liste de colonnes (PG15+). Seules ces colonnes sont envoyées, par la
--       copie initiale comme par le flux de changements. internal_notes et
--       credit_card_number ne sont jamais transmises. Doit inclure les
--       colonnes de la replica identity (id, region), voir règle B.
--
--   WHERE (region = 'EU')
--       Filtre de lignes (PG15+). Évalué sur le publieur, pour chaque
--       changement : les lignes qui ne correspondent pas ne quittent jamais
--       source_db. Restrictions : expressions simples uniquement
--       (fonctions/opérateurs intégrés immuables, pas de fonctions définies
--       par l'utilisateur, pas de sous-requêtes) et, voir règle A, uniquement
--       des colonnes de la replica identity.
--
--       Traitement d'un UPDATE avec un filtre de lignes (ancienne ligne vs
--       nouvelle ligne) :
--         ancienne OK,  nouvelle OK  -> envoyé comme UPDATE
--         ancienne non, nouvelle OK  -> envoyé comme INSERT (la ligne « entre »
--                                       dans l'ensemble)
--         ancienne OK,  nouvelle non -> envoyé comme DELETE (la ligne « sort »
--                                       de l'ensemble)
--         ancienne non, nouvelle non -> rien n'est envoyé
--       L'avant-dernier cas signifie que la destination PERD bien une ligne
--       quand un client quitte l'EU, même si les DELETE ne sont pas publiés
--       (voir « Pour aller plus loin » dans DEMO.md). La destination reste
--       ainsi égale à « SELECT ... WHERE region = 'EU' » sur la source.
--
--   WITH (publish = 'insert, update')
--       Opérations à diffuser. Le défaut est 'insert, update, delete,
--       truncate'. Le besoin initial étant INSERT + UPDATE uniquement, un
--       DELETE sur la source n'était PAS propagé et la ligne survivait sur la
--       destination (comportement de type archive). Idem pour TRUNCATE.
--       (V5 ajoute ensuite 'delete' à cette liste.)
-- -----------------------------------------------------------------------------
CREATE PUBLICATION customers_pub
    FOR TABLE customers (id, first_name, last_name, email, region, loyalty_points)
    WHERE (region = 'EU')
    WITH (publish = 'insert, update');


-- -----------------------------------------------------------------------------
-- Étape 3 - autoriser le rôle de réplication à lire la table.
--
-- La synchronisation initiale de l'abonné exécute
-- « COPY customers (...) TO STDOUT » sur le publieur, avec le rôle indiqué
-- dans la chaîne de connexion de la souscription (replicator). Sans SELECT, la
-- synchronisation de la table échoue avec « permission denied ».
-- Le flux du WAL lui-même n'a pas besoin de ce privilège, seule la copie.
-- -----------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO replicator;
GRANT SELECT ON customers TO replicator;
