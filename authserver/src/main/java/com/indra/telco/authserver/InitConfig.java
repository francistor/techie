package com.indra.telco.authserver;

import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.indra.telco.authserver.model.User;
import com.indra.telco.authserver.repository.UserRepository;

@Configuration
public class InitConfig {
    
    @Bean
    public CommandLineRunner dataLoader(UserRepository repo) {
        return args -> {
            repo.save(new User(0, "theuser", "thepassword", "Francisco Rodriguez"));
        };
    }
    
}
