package com.indra.telco.authserver.repository;

import java.sql.PreparedStatement;
import java.sql.Statement;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Repository;

import com.indra.telco.authserver.model.User;

import lombok.extern.slf4j.Slf4j;

@Repository
@Slf4j
public class UserRepository {

    private final JdbcTemplate jdbcTemplate;
    private final PasswordEncoder passwordEncoder;

    public UserRepository(JdbcTemplate jt, PasswordEncoder passwordEncoder){
        jdbcTemplate = jt;
        this.passwordEncoder = passwordEncoder;
    }

    public User findByUsername(String username){

        var users = jdbcTemplate.query("select id, username, password, fullname from users where username=?", 
        (row, i) -> {
                return new User(
                    row.getLong("id"), 
                    row.getString("username"), 
                    row.getString("password"),
                    row.getString("fullname")
                );
            },
        username
        );

        if(users.size() == 0) return null; else return users.get(0);
    }

    public User save(User user){
        String sql = "insert into users (username, password, fullname) VALUES (?, ?, ?)";

        KeyHolder keyHolder = new GeneratedKeyHolder();
        int rowsAffected = jdbcTemplate.update(conn -> {
            PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS);
            ps.setString(1, user.getUsername());
            ps.setString(2, passwordEncoder.encode(user.getPassword()));
            ps.setString(3, user.getFullname());
            return ps;
        }, keyHolder);

        var key = keyHolder.getKey();
        if(key == null){
            log.error("key was null " + rowsAffected);
            return null;
        } else {
            user.setId(key.intValue());
            return user;
        }
    }
}