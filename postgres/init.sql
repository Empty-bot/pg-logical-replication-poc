-- =============================================================================
-- Script d'amorçage, exécuté UNE SEULE FOIS par l'image postgres, en tant que
-- superutilisateur, au premier démarrage.
--
-- Il ne fait que ce qui exige réellement les droits superutilisateur (rôles +
-- bases de données). Tout le reste (tables, publication, slot, souscription)
-- appartient aux applications et vit dans leurs migrations Flyway : c'est
-- l'intérêt de ce PoC, la configuration de la réplication est versionnée avec
-- le code qui la possède.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. source_app : propriétaire de source_db et de la table publiée.
--
--    Attribut REPLICATION : nécessaire car la migration source V4 appelle
--    pg_create_logical_replication_slot(), qui l'exige (voir ce fichier pour
--    comprendre pourquoi le slot est créé à la main). En production, ce serait
--    plutôt un DBA qui créerait le slot, et le rôle applicatif n'aurait pas
--    cet attribut.
-- -----------------------------------------------------------------------------
CREATE ROLE source_app WITH LOGIN PASSWORD 'source_app' REPLICATION;
CREATE DATABASE source_db OWNER source_app;

-- -----------------------------------------------------------------------------
-- 2. replicator : le rôle avec lequel la SOUSCRIPTION se connecte côté
--    publieur.
--
--    - REPLICATION lui permet d'ouvrir une connexion walsender (protocole de
--      réplication) et de lire un slot de réplication.
--    - Il a aussi besoin de SELECT sur les tables publiées : la copie initiale
--      de la table (copy_data = true) est un simple COPY ... TO STDOUT exécuté
--      avec ce rôle. Ce GRANT est fait dans la migration source, à côté de la
--      table.
--    - Il n'a besoin de rien d'autre : il ne peut écrire nulle part.
-- -----------------------------------------------------------------------------
CREATE ROLE replicator WITH LOGIN PASSWORD 'replicator' REPLICATION;
GRANT CONNECT ON DATABASE source_db TO replicator;

-- -----------------------------------------------------------------------------
-- 3. destination_app : propriétaire de destination_db et de la table
--    répliquée.
--
--    pg_create_subscription (Postgres 16+) : rôle prédéfini qui permet à un
--    NON-superutilisateur d'exécuter CREATE SUBSCRIPTION (avec le privilège
--    CREATE sur la base, qu'il possède en tant que propriétaire). Avant PG16,
--    seuls les superutilisateurs le pouvaient.
--    Conséquence pour un propriétaire non-superutilisateur : la connexion de
--    la souscription DOIT s'authentifier par mot de passe (voir PUBLISHER_HOST
--    dans docker-compose.yml).
-- -----------------------------------------------------------------------------
CREATE ROLE destination_app WITH LOGIN PASSWORD 'destination_app';
GRANT pg_create_subscription TO destination_app;
CREATE DATABASE destination_db OWNER destination_app;
