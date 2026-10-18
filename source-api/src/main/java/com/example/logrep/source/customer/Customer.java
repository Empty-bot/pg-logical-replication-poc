package com.example.logrep.source.customer;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Fiche client complète, mappée sur source_db.customers (voir V1__create_customers.sql).
 *
 * <p>Points liés à la réplication (règles définies dans V3__publish_customers.sql) :
 * <ul>
 *   <li>Seuls {@code id, firstName, lastName, email, region, loyaltyPoints} sont publiés.</li>
 *   <li>{@code internalNotes} et {@code creditCardNumber} ne quittent jamais source_db.</li>
 *   <li>Seules les lignes avec {@code region = 'EU'} sont publiées. Modifier {@code region}
 *       fait entrer ou sortir une ligne de l'ensemble répliqué (un INSERT ou un DELETE sur la
 *       destination).</li>
 * </ul>
 */
@Entity
@Table(name = "customers")
public class Customer {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "first_name", nullable = false)
    private String firstName;

    @Column(name = "last_name", nullable = false)
    private String lastName;

    @Column(nullable = false, unique = true)
    private String email;

    /** Colonne du filtre de lignes de la publication, et membre de l'index de REPLICA IDENTITY. */
    @Column(nullable = false)
    private String region;

    @Column(name = "loyalty_points", nullable = false)
    private int loyaltyPoints;

    /** Colonne privée : exclue de la liste de colonnes de la publication. */
    @Column(name = "internal_notes")
    private String internalNotes;

    /** Colonne privée : exclue de la liste de colonnes de la publication. */
    @Column(name = "credit_card_number")
    private String creditCardNumber;

    protected Customer() {
        // pour Hibernate
    }

    public Customer(String firstName, String lastName, String email, String region,
                    int loyaltyPoints, String internalNotes, String creditCardNumber) {
        this.firstName = firstName;
        this.lastName = lastName;
        this.email = email;
        this.region = region;
        this.loyaltyPoints = loyaltyPoints;
        this.internalNotes = internalNotes;
        this.creditCardNumber = creditCardNumber;
    }

    public Long getId() { return id; }
    public String getFirstName() { return firstName; }
    public String getLastName() { return lastName; }
    public String getEmail() { return email; }
    public String getRegion() { return region; }
    public int getLoyaltyPoints() { return loyaltyPoints; }
    public String getInternalNotes() { return internalNotes; }
    public String getCreditCardNumber() { return creditCardNumber; }

    public void setFirstName(String firstName) { this.firstName = firstName; }
    public void setLastName(String lastName) { this.lastName = lastName; }
    public void setEmail(String email) { this.email = email; }
    public void setRegion(String region) { this.region = region; }
    public void setLoyaltyPoints(int loyaltyPoints) { this.loyaltyPoints = loyaltyPoints; }
    public void setInternalNotes(String internalNotes) { this.internalNotes = internalNotes; }
    public void setCreditCardNumber(String creditCardNumber) { this.creditCardNumber = creditCardNumber; }
}
