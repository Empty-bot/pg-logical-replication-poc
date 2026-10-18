-- =============================================================================
-- V2 : CONFIGURATION DE LA RÉPLICATION CÔTÉ ABONNÉ
--
-- Une SOUSCRIPTION (SUBSCRIPTION) relie cette base à une publication d'une
-- autre base (ici : customers_pub dans source_db, dans la même instance
-- Postgres). Une fois créée, Postgres démarre des processus d'arrière-plan
-- qui :
--   1. table-sync worker : copient les lignes qui correspondent actuellement à
--      la publication (filtre de lignes + liste de colonnes appliqués sur le
--      publieur), puis
--   2. apply worker : lisent en continu chaque changement validé ensuite
--      depuis le slot de réplication et l'appliquent ici, dans l'ordre des
--      commits.
-- Aucun code applicatif n'intervient dans l'une ou l'autre étape.
--
-- S'exécute avec executeInTransaction=false (voir le fichier .conf à côté de
-- ce script) : CREATE SUBSCRIPTION ne peut pas s'exécuter dans un bloc de
-- transaction quand elle se connecte au publieur.
--
-- Les valeurs publisher_host / publisher_port / ... de la chaîne CONNECTION
-- sont des placeholders Flyway, résolus depuis spring.flyway.placeholders.*
-- dans application.yml. (Attention : Flyway substitue aussi les placeholders
-- dans les commentaires SQL, donc un motif de placeholder sans valeur casse
-- la migration, même dans un commentaire.)
-- =============================================================================
CREATE SUBSCRIPTION customers_sub

    -- -------------------------------------------------------------------------
    -- CONNECTION : chaîne de connexion libpq utilisée par le serveur Postgres
    -- lui-même (l'apply worker dans le conteneur postgres), PAS par cette
    -- application Spring.
    --   host     : 'postgres' (nom du service compose) plutôt que localhost,
    --              pour que le serveur demande un mot de passe. Un
    --              propriétaire de souscription non-superutilisateur
    --              (destination_app) n'a droit qu'aux connexions authentifiées
    --              par mot de passe (password_required = true).
    --   user     : 'replicator', un rôle avec l'attribut REPLICATION et
    --              SELECT sur la table publiée uniquement.
    -- Remarque : cette chaîne, mot de passe compris, est stockée dans
    -- pg_subscription (lisible uniquement par les superutilisateurs). Pour un
    -- propriétaire non-superutilisateur comme destination_app, le mot de passe
    -- DOIT figurer dans la chaîne elle-même : un fichier .pgpass ou un
    -- certificat client ne sont acceptés que pour une souscription appartenant
    -- à un superutilisateur. D'où un rôle replicator aux droits minimaux, TLS
    -- en production et une rotation régulière du mot de passe.
    -- -------------------------------------------------------------------------
    CONNECTION 'host=${publisher_host} port=${publisher_port} dbname=${publisher_db} user=${publisher_user} password=${publisher_password}'

    -- Une ou plusieurs publications du publieur. Les filtres et listes de
    -- colonnes sont définis LÀ-BAS (V3 de la source), pas ici : l'abonné reçoit
    -- ce qu'on lui donne.
    PUBLICATION customers_pub

    WITH (
        -- ---------------------------------------------------------------------
        -- create_slot = false + slot_name : utiliser le slot créé par la V4 de
        -- la source au lieu d'en créer un ici. OBLIGATOIRE quand publieur et
        -- abonné sont dans la même instance : avec create_slot = true (le
        -- défaut), cette instruction se bloquerait indéfiniment (expliqué dans
        -- la V4 de la source).
        -- ---------------------------------------------------------------------
        create_slot = false,
        slot_name   = 'customers_slot',

        -- copy_data = true (défaut) : effectuer la synchronisation initiale,
        -- c'est-à-dire copier les lignes EU qui existent déjà sur la source
        -- (insérées par la V2 de la source). Avec false, seuls les changements
        -- faits après ce point arriveraient.
        copy_data   = true,

        -- enabled = true (défaut) : démarrer la réplication immédiatement.
        -- Avec false, il faudrait plus tard un
        -- ALTER SUBSCRIPTION customers_sub ENABLE.
        enabled     = true

        -- Autres options utiles à connaître (laissées à leur défaut ici) :
        --   binary            = false : valeurs envoyées en texte (fonctionne
        --                               même si les types de colonnes
        --                               diffèrent).
        --   streaming         = off   : les grosses transactions en cours ne
        --                               sont envoyées qu'au commit
        --                               ('on'/'parallel' pour les diffuser
        --                               au fil de l'eau).
        --   disable_on_error  = false : en cas d'erreur d'application, nouvel
        --                               essai en boucle. 'true' désactive
        --                               plutôt la souscription.
        --   synchronous_commit= off   : l'apply worker n'attend pas le vidage
        --                               du WAL local (sans risque : il peut
        --                               redemander les données).
        --   origin            = any   : 'none' évite les boucles dans les
        --                               configurations bidirectionnelles.
        --   failover          = false : (PG17) synchronise le slot vers les
        --                               standbys physiques.
    );
