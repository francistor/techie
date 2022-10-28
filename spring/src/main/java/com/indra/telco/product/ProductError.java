package com.indra.telco.product;

public class ProductError {
    private String message;

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public ProductError(String message){
        this.message = message;
    }
}
