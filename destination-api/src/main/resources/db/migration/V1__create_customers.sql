-- =============================================================================
-- V1 : la table CIBLE de la souscription.
--
-- La réplication logique ne réplique PAS le DDL : la table doit exister sur
-- l'abonné avant la création de la souscription, et les changements de schéma
-- sur la source doivent être appliqués ici à la main (ou par une migration de
-- cette application).
--
-- Comment l'abonné fait correspondre tables et colonnes :
--   - Les tables sont associées par nom qualifié par le schéma
--     (public.customers) : le nom doit donc être le même que sur le publieur.
--   - Les colonnes sont associées PAR NOM, pas par position. Les types peuvent
--     différer tant que la représentation texte se convertit (par défaut, les
--     valeurs arrivent sous forme de texte).
--   - Chaque colonne publiée doit exister ici (sinon : erreur
--     « logical replication target relation ... is missing replicated
--     column »).
--   - L'abonné PEUT avoir des colonnes en plus. Elles reçoivent leur DEFAULT
--     lors des INSERT répliqués et ne sont pas touchées par les UPDATE (voir
--     first_seen_at).
--   - Les colonnes privées de la source (internal_notes, credit_card_number)
--     sont simplement absentes : elles ne sont jamais envoyées.
-- =============================================================================
CREATE TABLE customers (
    -- Clé primaire = moyen pour le processus d'application (apply worker) de
    -- retrouver la ligne à mettre à jour. Ses colonnes doivent être un
    -- sous-ensemble de la replica identity du publieur (id, region) :
    -- l'identité (id) ici est « plus stricte » que (id, region) là-bas, ce qui
    -- convient.
    id             BIGINT       PRIMARY KEY,
    first_name     VARCHAR(100) NOT NULL,
    last_name      VARCHAR(100) NOT NULL,
    -- Volontairement AUCUNE contrainte d'unicité sur email. Toute contrainte
    -- que la source n'applique pas à l'identique peut faire échouer un
    -- changement entrant sur l'abonné. En cas d'erreur, l'apply worker
    -- s'arrête et réessaie la même transaction en boucle : la réplication est
    -- bloquée jusqu'à ce que quelqu'un corrige le problème.
    -- Tant que les DELETE n'étaient pas répliqués (avant la V5 de la source),
    -- les anciennes lignes s'accumulaient ici, et l'unicité de l'email n'était
    -- donc pas garantie.
    email          VARCHAR(255) NOT NULL,
    region         VARCHAR(10)  NOT NULL,
    loyalty_points INTEGER      NOT NULL,
    -- Colonne propre à l'abonné : montre que la cible peut porter des données
    -- locales. Renseignée une seule fois, à l'arrivée de la ligne (copie
    -- initiale ou INSERT répliqué).
    first_seen_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
