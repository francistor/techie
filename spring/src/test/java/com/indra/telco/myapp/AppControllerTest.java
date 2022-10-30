package com.indra.telco.myapp;

import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.ui.Model;

import com.indra.telco.product.Product;
import com.indra.telco.product.ProductService;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.BDDMockito.*;

@ExtendWith(MockitoExtension.class)
public class AppControllerTest {

    // Inject a mock model
    @Mock
    private Model model;

    // Inject a mock service
    @Mock
    private ProductService productService;

    // Inject a controller with the above mocks
    @InjectMocks
    private AppController appController;

    @Test
    public void addProductTest(){
        // Products to return
       List<Product> products = new ArrayList<>();
       products.add(new Product("my product", 10.1));

       given(productService.findAll()).willReturn(products);

       String result = appController.addProduct("my product", 10.1, model);
       assertEquals("products.html", result);

       // The findAll method was called
       verify(productService).findAll();

       // The model was added the right attribute
       verify(model).addAttribute("products", products);

    }
}
