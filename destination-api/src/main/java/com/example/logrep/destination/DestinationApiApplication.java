package com.example.logrep.destination;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Côté abonné du PoC.
 *
 * <p>Cette application n'écrit jamais de clients : destination_db.customers est remplie et
 * tenue à jour par le processus d'application (apply worker) de la réplication logique de
 * Postgres, configuré dans la migration Flyway V2__subscribe_to_customers.sql. L'API se contente
 * de lire les données répliquées et d'exposer l'état de la souscription.
 */
@SpringBootApplication
public class DestinationApiApplication {

    public static void main(String[] args) {
        SpringApplication.run(DestinationApiApplication.class, args);
    }
}
