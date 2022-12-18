package com.indra.telco.authserver;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class AuthserverApplicationTests {

	@Test
	void contextLoads() {
	}

}


/*
 
http://localhost:9000/oauth2/authorize?response_type=code&client_id=myclient&redirect_uri=http://127.0.0.1:9090/login/oauth2/code/taco-admin-client&scope=ReadScope+WriteScope

export code=B-Ep6qPy0WV6Ap8s0caGaWRjxMUG2nwJY5wl9fZ3-f3M6vHEeXsdHaspnekBAEWsxSJjIaOegPCPYadhuec5RWwz_kkbVlOC1ru2-3oHNIhyu09IofT2QnkMPcyn3Edg

curl localhost:9000/oauth2/token \
-H"Content-type: application/x-www-form-urlencoded" \
-d"grant_type=authorization_code" \
-d"redirect_uri=http://127.0.0.1:9090/login/oauth2/code/taco-admin-client" \
-d"code=$code" \
-u myclient:secret

*/
