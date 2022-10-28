package com.indra.telco.myapp;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.cloud.openfeign.EnableFeignClients;


@SpringBootApplication
@ComponentScan(basePackages = "com.indra.telco")
@EnableFeignClients(basePackages = "com.indra.telco.product")
public class MyappApplication {
	public static void main(String[] args) {
		SpringApplication.run(MyappApplication.class, args);
	}
}
