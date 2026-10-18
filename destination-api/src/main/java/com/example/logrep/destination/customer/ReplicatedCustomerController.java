package com.example.logrep.destination.customer;

import java.util.List;

import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

/** API en lecture seule sur les données répliquées. Aucun endpoint d'écriture, volontairement. */
@RestController
@RequestMapping("/customers")
public class ReplicatedCustomerController {

    private final ReplicatedCustomerRepository repository;

    public ReplicatedCustomerController(ReplicatedCustomerRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public List<ReplicatedCustomer> findAll() {
        return repository.findAll(Sort.by("id"));
    }

    @GetMapping("/{id}")
    public ReplicatedCustomer findById(@PathVariable Long id) {
        return repository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND));
    }
}
