package com.indra.telco.myapp;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import com.indra.telco.product.ProductError;

// Custom error handler
@RestControllerAdvice
public class ExceptionHandler {

    @org.springframework.web.bind.annotation.ExceptionHandler(RuntimeException.class)
    public ResponseEntity<ProductError> productErrorHandler(RuntimeException e){
        return ResponseEntity.
        badRequest().
        header("custom header", "custom value").
        body(new ProductError(e.getMessage()));
    }
}
