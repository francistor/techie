package com.indra.telco.myapp;

import javax.servlet.http.HttpSession;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

import com.indra.telco.product.Product;
import com.indra.telco.product.ProductError;
import com.indra.telco.product.ProductProxy;
import com.indra.telco.product.ProductService;
import com.indra.telco.psba.Client;
import com.indra.telco.psba.PSBARepository;

@Controller
public class AppController {

    private static Logger logger = LoggerFactory.getLogger(AppController.class);

    private ProductService productService;
    private ProductProxy productProxy;
    private PSBARepository psba;

    public AppController(ProductService ps, ProductProxy pp, PSBARepository psba){
        this.productService = ps;
        this.productProxy = pp;
        this.psba = psba;
    }

    // Simple request for static page
    @RequestMapping("/staticHome")
    public String staticHome(){
        return "home.html";
    }

    // Returns a template (in resources/templates directory)
    // Ilustrates getting parameters from the URL (PathVariable) or from the querystring
    // The 'Model' will hold values that are usable in the template
    @RequestMapping("/templateHome/{user}")
    public String templateHome(@RequestParam(required = true) String color, @PathVariable String user, Model params){
        params.addAttribute("color", color);
        params.addAttribute("username", user);
        return "home.html";
    }

    // Gets the products and presents them on the products page
    // Ilustrates invoking a service internally
    @GetMapping("/products")
    public String viewProducts(Model model, HttpSession session){
        model.addAttribute("products", productService.findAll());

        return "products.html";
    }

    // Adds a new product to the list
    // Illustrates retreiving parameters from a POST form, using @RequestParam
    @PostMapping("/products")
    public String addProduct(@RequestParam String name, @RequestParam double price, Model model){
        logger.info("add product");

        // Build the new product
        Product p = new Product(name, price);

        // Add it 
        productService.addProduct(p);

        // Make products available for the view
        model.addAttribute("products", productService.findAll());

        // Return template
        return "products.html";
    }

    // Rest archetype
    // The input is marked with @RequestBody, and the object will be unserialized from JSON
    // The answer is serialized to JSON, as signalled by the @ResponseBody annotation
    @ResponseBody
    @PostMapping("/echoProduct")
    public Product restGetProduct(@RequestBody Product inputProduct){
        logger.info("executing /echoProduct");
        return new Product(inputProduct.getName() + "_echo", inputProduct.getPrice());
    }

    // Simiar to the above, but the answer is customized with a ResponseEntity, which allows
    // to set the response code and headers
    @ResponseBody
    @PostMapping("/echoProductWithEntity")
    public ResponseEntity<Product> restGetProductWithEntity(@RequestBody Product inputProduct){
        var p = new Product(inputProduct.getName() + "_echo", inputProduct.getPrice());

        return ResponseEntity.
          status(HttpStatus.ACCEPTED).
          header("customheader", "customvalue").
          body(p);
    }

    // Similar to the above, but the answer is customized with a generic ResponseEntity, which
    // may contain a custom error
    @ResponseBody
    @PostMapping("/echoProductWithError")
    public ResponseEntity<?> restGetProductWithError(@RequestBody Product inputProduct){

        return ResponseEntity.
            badRequest().
            header("custom header", "custom value").
            body(new ProductError("custom message"));
    }

    // Invocation of custom error handler
    @ResponseBody
    @PostMapping("/echoProductWithManagedError")
    public ResponseEntity<?> restGetProductWithManagedError(@RequestBody Product inputProduct){

        throw new RuntimeException("there was a managed error");
    }

    @ResponseBody
    @PostMapping("/echoWithRestProxy")
    public Product restProxyGetProduct(@RequestBody Product inputProduct){
        logger.info("executing /echoWithRestProxy");
        return productProxy.getProduct("fake request Id", inputProduct);
    }

    @ResponseBody
    @PostMapping("/clients")
    public ResponseEntity<?> createClient(@RequestBody Client client){

        var clientId = psba.createClientWithId(client);

        return ResponseEntity.
            status(HttpStatus.CREATED).
            header("custom header", "custom value").
            body(clientId);
    }

    @ResponseBody
    @GetMapping("/clients/{clientId}")
    public ResponseEntity<Client> findClientById(@PathVariable int clientId){
        logger.info("1");
         var clientOpt = psba.findClientById(clientId);
         logger.info("2");
         logger.info(clientOpt.toString());

         if (clientOpt.isEmpty()) {
            logger.info("3");
            return ResponseEntity.
            status(HttpStatus.NOT_FOUND).
            body(null);
         } else {
            logger.info("4");
            return ResponseEntity.
            status(HttpStatus.FOUND).
            body(clientOpt.get());
         }
    }


}
