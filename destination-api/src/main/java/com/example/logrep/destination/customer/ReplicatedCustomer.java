package com.example.logrep.destination.customer;

import java.time.OffsetDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import org.hibernate.annotations.Immutable;

/**
 * Projection en lecture seule d'un client de la source, mappée sur destination_db.customers.
 *
 * <p>{@link Immutable} : Hibernate n'émettra jamais d'INSERT/UPDATE/DELETE pour cette entité.
 * L'apply worker de la réplication est le seul à écrire dans cette table. Y écrire localement
 * n'échouerait pas, mais la ferait diverger de la source, et pourrait plus tard faire entrer en
 * conflit un changement répliqué (par exemple une clé dupliquée sur un INSERT), ce qui bloque la
 * réplication.
 *
 * <p>Remarquez ce qui n'est PAS ici : internalNotes et creditCardNumber. Ils sont exclus par la
 * liste de colonnes de la publication et n'atteignent jamais cette base.
 */
@Entity
@Immutable
@Table(name = "customers")
public class ReplicatedCustomer {

    /** Même valeur que sur la source : la réplication la copie, il n'y a pas de générateur ici. */
    @Id
    private Long id;

    @Column(name = "first_name")
    private String firstName;

    @Column(name = "last_name")
    private String lastName;

    private String email;

    /** Toujours 'EU', à cause du filtre de lignes de la publication. */
    private String region;

    @Column(name = "loyalty_points")
    private int loyaltyPoints;

    /** Colonne propre à l'abonné, remplie par son DEFAULT now() à la première arrivée de la ligne. */
    @Column(name = "first_seen_at")
    private OffsetDateTime firstSeenAt;

    protected ReplicatedCustomer() {
        // pour Hibernate
    }

    public Long getId() { return id; }
    public String getFirstName() { return firstName; }
    public String getLastName() { return lastName; }
    public String getEmail() { return email; }
    public String getRegion() { return region; }
    public int getLoyaltyPoints() { return loyaltyPoints; }
    public OffsetDateTime getFirstSeenAt() { return firstSeenAt; }
}
