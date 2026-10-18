package com.example.logrep.source;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Côté publieur du PoC.
 *
 * <p>Cette application est un service CRUD JPA/Hibernate tout à fait ordinaire : elle ne sait
 * rien de la réplication. Chaque INSERT/UPDATE/DELETE émis par Hibernate est écrit dans le WAL,
 * et c'est Postgres lui-même qui décide (via la publication définie dans les migrations Flyway
 * V3 et V5) de ce qui est diffusé vers destination_db. Cette transparence est le principal
 * avantage de la réplication logique native par rapport à une synchronisation applicative
 * (outbox, double écriture, ...).
 */
@SpringBootApplication
public class SourceApiApplication {

    public static void main(String[] args) {
        SpringApplication.run(SourceApiApplication.class, args);
    }
}
