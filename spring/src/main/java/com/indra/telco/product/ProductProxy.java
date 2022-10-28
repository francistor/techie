package com.indra.telco.product;

import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;

@FeignClient(name = "products", url = "${product.service.url}")
public interface ProductProxy {
    @PostMapping
    public Product getProduct(@RequestHeader String requestId, @RequestBody Product product);
}
