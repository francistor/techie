package com.indra.telco.authserver;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.core.io.ClassPathResource;

@SpringBootApplication
public class AuthserverApplication {

	public static void main(String[] args) throws Exception{
		
		var resource = new ClassPathResource("org/springframework/security/oauth2/server/authorization/client/oauth2-registered-client-schema.sql");
		System.out.println(new String(resource.getInputStream().readAllBytes()));

		resource = new ClassPathResource("org/springframework/security/oauth2/server/authorization/oauth2-authorization-consent-schema.sql");
		System.out.println(new String(resource.getInputStream().readAllBytes()));

		resource = new ClassPathResource("org/springframework/security/oauth2/server/authorization/oauth2-authorization-schema.sql");
		System.out.println(new String(resource.getInputStream().readAllBytes()));
		
		SpringApplication.run(AuthserverApplication.class, args);
	}

}

