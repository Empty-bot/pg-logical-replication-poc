# Démonstration avec curl

Commandes à lancer une par une pour vérifier que la réplication fonctionne.

- **source-api** : `http://localhost:8081`, en lecture et écriture.
- **destination-api** : `http://localhost:8082`, en lecture seule. Tout ce qui y apparaît a été copié par Postgres.

Rappel des règles de la publication :
- **Lignes** : seuls les clients avec `region = "EU"` sont répliqués.
- **Colonnes** : `internalNotes` et `creditCardNumber` ne quittent jamais la source.
- **Opérations** : INSERT, UPDATE et DELETE.

## Préparation

Partez d'une base neuve, pour que les identifiants correspondent à ceux de ce document :

```bash
docker compose down -v
docker compose up -d --build
```

Attendez que `curl -s localhost:8082/customers` réponde, une vingtaine de secondes. `| jq` est facultatif et sert seulement à rendre le JSON lisible.

> La réplication est asynchrone, avec un délai de quelques millisecondes. En tapant les commandes à la main, le changement est déjà arrivé quand vous lancez le GET suivant.

## 1. État initial

```bash
curl -s localhost:8081/customers | jq     # source
```

La source contient quatre clients : Alice (EU), Bob (US), Chloé (EU) et Kenji (APAC). Chacun a ses `internalNotes` et son `creditCardNumber`.

```bash
curl -s localhost:8082/customers | jq     # destination
```

La destination ne contient qu'**Alice (id 1) et Chloé (id 3)**, les deux clients EU, **sans** `internalNotes` ni `creditCardNumber`. Ces lignes existaient avant la création de la souscription : elles ont été copiées par la synchronisation initiale.

## 2. INSERT

```bash
curl -s -X POST localhost:8081/customers -H 'Content-Type: application/json' \
  -d '{"firstName":"David","lastName":"Leroy","email":"david@example.com","region":"EU","loyaltyPoints":10,"internalNotes":"secret","creditCardNumber":"4000-0000-0000-0002"}' | jq
```

La source répond avec le nouveau client, d'**id 5**.

```bash
curl -s localhost:8082/customers/5 | jq
```

David est présent sur la destination avec 10 points, sans ses notes ni sa carte.

## 3. Deux UPDATE

**PUT qui satisfait le filtre** : David est un client EU.

```bash
curl -s -X PUT localhost:8081/customers/5 -H 'Content-Type: application/json' -d '{"loyaltyPoints":500}' | jq
```

**PUT qui ne satisfait pas le filtre** : Kenji (id 4) est un client APAC.

```bash
curl -s -X PUT localhost:8081/customers/4 -H 'Content-Type: application/json' -d '{"loyaltyPoints":999}' | jq
```

Vérification sur la destination :

```bash
curl -s localhost:8082/customers/5 | jq    # David a maintenant 500 points : l'UPDATE est répliqué
curl -s localhost:8082/customers/4 | jq    # 404 : Kenji n'est pas EU, rien n'est répliqué
```

## 4. DELETE

```bash
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE localhost:8081/customers/5    # 204
```

```bash
curl -s localhost:8082/customers/5 | jq    # 404 : David a aussi été supprimé de la destination
```

## Pour aller plus loin

- `curl -s localhost:8082/replication/status | jq` affiche l'état de la souscription : workers, état de chaque table (`r` = prête) et compteurs d'erreurs.
- Un UPDATE qui change la région fait entrer ou sortir un client de la destination :
  - `PUT /customers/2` avec `{"region":"EU"}` : Bob apparaît sur la destination.
  - `PUT /customers/3` avec `{"region":"APAC"}` : Chloé en disparaît.
