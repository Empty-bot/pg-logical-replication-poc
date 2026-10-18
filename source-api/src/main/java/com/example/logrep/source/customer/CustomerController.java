package com.example.logrep.source.customer;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

/**
 * API CRUD sur la source de vérité. Remarquez qu'il n'y a aucun code de réplication ici :
 * chaque transaction validée est récupérée dans le WAL par Postgres et, si elle correspond à la
 * publication, appliquée sur destination_db de façon asynchrone (en général en quelques
 * millisecondes).
 */
@RestController
@RequestMapping("/customers")
public class CustomerController {

    private final CustomerRepository repository;

    public CustomerController(CustomerRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public List<Customer> findAll() {
        return repository.findAll();
    }

    @GetMapping("/{id}")
    public Customer findById(@PathVariable Long id) {
        return repository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND));
    }

    /** INSERT : répliqué uniquement si region = 'EU'. */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Customer create(@RequestBody CustomerRequest request) {
        Customer customer = new Customer(
                request.firstName(),
                request.lastName(),
                request.email(),
                request.region(),
                request.loyaltyPoints() == null ? 0 : request.loyaltyPoints(),
                request.internalNotes(),
                request.creditCardNumber());
        return repository.save(customer);
    }

    /**
     * UPDATE : répliqué selon la matrice ancienne/nouvelle ligne du filtre décrite en V3. Modifier
     * uniquement une colonne privée (internal_notes, credit_card_number) d'un client EU émet quand
     * même un UPDATE sur la destination, mais avec des valeurs publiées identiques.
     */
    @PutMapping("/{id}")
    @Transactional
    public Customer update(@PathVariable Long id, @RequestBody CustomerRequest request) {
        Customer customer = findById(id);
        if (request.firstName() != null) customer.setFirstName(request.firstName());
        if (request.lastName() != null) customer.setLastName(request.lastName());
        if (request.email() != null) customer.setEmail(request.email());
        if (request.region() != null) customer.setRegion(request.region());
        if (request.loyaltyPoints() != null) customer.setLoyaltyPoints(request.loyaltyPoints());
        if (request.internalNotes() != null) customer.setInternalNotes(request.internalNotes());
        if (request.creditCardNumber() != null) customer.setCreditCardNumber(request.creditCardNumber());
        // Dirty checking : Hibernate émet l'UPDATE au commit, ce qui l'écrit dans le WAL.
        return customer;
    }

    /**
     * DELETE : répliqué uniquement si la ligne supprimée a region = 'EU' (publish inclut 'delete'
     * depuis la migration V5). Supprimer un client hors EU n'envoie rien, puisqu'il n'a jamais été
     * sur la destination.
     */
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        repository.deleteById(id);
    }
}
