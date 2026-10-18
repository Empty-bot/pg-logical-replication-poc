package com.example.logrep.destination.customer;

import org.springframework.data.jpa.repository.JpaRepository;

/** Seules les méthodes de lecture sont utilisées ; l'entité est de toute façon @Immutable. */
public interface ReplicatedCustomerRepository extends JpaRepository<ReplicatedCustomer, Long> {
}
