insert into oauth2_registered_client (
    id, 
    client_id, 
    client_id_issued_at, 
    client_secret, 
    client_secret_expires_at,
    client_name,
    client_authentication_methods,
    authorization_grant_types,
    redirect_uris,
    scopes,
    client_settings,
    token_settings) 
    
    values (
    'a5e1d365-ff1b-4796-8b6f-e962b7aac483',
    'myclient',
    CURRENT_TIMESTAMP(),
    '{noop}secret',
    NULL,
    'a5e1d365-ff1b-4796-8b6f-e962b7aac483',
    'client_secret_basic',
    'refresh_token,client_credentials,authorization_code',
    'http://127.0.0.1:9090/login/oauth2/code/taco-admin-client',
    'WriteScope,ReadScope,openid,profile',
    '{"@class":"java.util.Collections$UnmodifiableMap","settings.client.require-proof-key":false,"settings.client.require-authorization-consent":true}',
    '{"@class":"java.util.Collections$UnmodifiableMap","settings.token.reuse-refresh-tokens":true,"settings.token.id-token-signature-algorithm":["org.springframework.security.oauth2.jose.jws.SignatureAlgorithm","RS256"],"settings.token.access-token-time-to-live":["java.time.Duration",300.000000000],"settings.token.access-token-format":{"@class":"org.springframework.security.oauth2.server.authorization.settings.OAuth2TokenFormat","value":"self-contained"},"settings.token.refresh-token-time-to-live":["java.time.Duration",3600.000000000],"settings.token.authorization-code-time-to-live":["java.time.Duration",300.000000000]}'
    );

/*
insert into users (
    username,
    password,
    fullname
) values (
    'theuser',
    'thepassword',
    'Francisco Rodrigez'
);
*/
