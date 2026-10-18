package com.example.logrep.source.customer;

/**
 * Corps de requête pour POST (création) et PUT (mise à jour partielle) sur /customers.
 * Pour un PUT, les champs null ne sont pas modifiés.
 */
public record CustomerRequest(
        String firstName,
        String lastName,
        String email,
        String region,
        Integer loyaltyPoints,
        String internalNotes,
        String creditCardNumber) {
}
