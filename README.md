# PoC : réplication logique native de PostgreSQL 17

Deux API Spring Boot 4.1.1 / Java 25 (Hibernate et Flyway), chacune propriétaire de sa propre
base dans une seule instance Postgres 17. `source_db.customers` publie **une partie de ses
colonnes** pour **une partie de ses lignes**, et `destination_db.customers` est maintenue
synchronisée sur les **INSERT, UPDATE et DELETE**. Aucune des deux applications ne contient de
code de réplication : tout se trouve dans des migrations Flyway et s'exécute dans Postgres.

```
source-api :8081 ──▶ source_db.customers ── PUBLICATION customers_pub ── slot customers_slot
                                                         │ pgoutput (décodage du WAL)
destination-api :8082 ──▶ destination_db.customers ◀── SUBSCRIPTION customers_sub (apply worker)
```

| Règle | Valeur |
|---|---|
| Colonnes publiées | `id, first_name, last_name, email, region, loyalty_points` |
| Colonnes privées | `internal_notes, credit_card_number` (ne quittent jamais source_db) |
| Filtre de lignes | `region = 'EU'` |
| Opérations | `insert, update` (V3), puis `delete` (V5). TRUNCATE n'est pas répliqué |

## Lancer

```bash
docker compose up -d --build   # postgres, puis source-api, puis destination-api
docker compose down -v         # tout réinitialiser
```

## Démonstration

Les commandes curl pour vérifier la réplication (INSERT, UPDATE dans et hors filtre, DELETE) sont dans [`DEMO.md`](DEMO.md).

## Où se trouve la configuration de la réplication

À lire dans cet ordre :

1. `docker-compose.yml` : `wal_level=logical` et les paramètres de connexion de la souscription.
2. `postgres/init.sql` : les rôles (`source_app`, `replicator`, `destination_app`) et les privilèges dont la réplication a besoin.
3. `source-api/.../db/migration/V3__publish_customers.sql` : replica identity, publication, filtre de lignes et liste de colonnes. **C'est le fichier principal.**
4. `source-api/.../db/migration/V4__create_replication_slot.sql` : le slot créé à la main.
5. `source-api/.../db/migration/V5__publish_deletes.sql` : ajoute DELETE aux opérations publiées.
6. `destination-api/.../db/migration/V1__create_customers.sql` : la table cible et la correspondance des colonnes.
7. `destination-api/.../db/migration/V2__subscribe_to_customers.sql` : la souscription.

## Pièges rencontrés par ce PoC (et comment il les gère)

- **Filtre de lignes + UPDATE/DELETE** : la colonne du filtre doit faire partie de la REPLICA IDENTITY. **Liste de colonnes + UPDATE/DELETE** : la liste doit inclure la replica identity. `REPLICA IDENTITY FULL` n'est donc pas une option (il obligerait à publier toutes les colonnes). La solution : `REPLICA IDENTITY USING INDEX` sur un index unique `(id, region)`.
- **Même instance** : `CREATE SUBSCRIPTION` se bloque indéfiniment s'il crée lui-même son slot. Le slot est créé côté publieur, et la souscription utilise `create_slot = false`.
- **Transactions** : `CREATE SUBSCRIPTION` et `pg_create_logical_replication_slot()` ne doivent pas s'exécuter dans la transaction de Flyway. Les deux ont un fichier `*.sql.conf` avec `executeInTransaction=false`.
- **Propriétaire de souscription non-superutilisateur (PG16+ `pg_create_subscription`)** : il doit s'authentifier par mot de passe. La connexion utilise l'hôte `postgres` et non `localhost`, car le loopback est en `trust` dans l'image officielle.
- **Les placeholders Flyway** sont substitués aussi dans les commentaires.
- **Un UPDATE qui fait sortir une ligne du filtre est appliqué comme un DELETE** sur la destination, même quand les DELETE ne sont pas publiés (comme avant la V5).
- **Le DDL n'est pas répliqué.** Un changement de schéma doit être appliqué aux deux bases, d'abord sur l'abonné quand on ajoute une colonne publiée.
- **Un slot abandonné conserve le WAL indéfiniment.** Supprimez la souscription ou le slot lors du démontage.
- **Flyway calcule une somme de contrôle sur tout le fichier de migration, commentaires compris.** Modifier une migration déjà appliquée (même un commentaire) fait échouer la validation au démarrage suivant. Dans ce PoC, on repart d'une base vide avec `docker compose down -v` ; sur une vraie base, il faudrait ajouter une nouvelle migration (comme la V5) ou lancer `flyway repair`.

## Inspecter directement

```bash
docker exec -it pg-logrep-postgres psql -U postgres -d source_db \
  -c "SELECT * FROM pg_publication_tables" -c "SELECT slot_name, active, confirmed_flush_lsn FROM pg_replication_slots"
docker exec -it pg-logrep-postgres psql -U postgres -d destination_db \
  -c "SELECT * FROM pg_stat_subscription" -c "TABLE customers"
curl -s localhost:8082/replication/status | jq
```
