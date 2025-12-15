package com.salesmanager.shop.store.security;

import org.springframework.beans.factory.InitializingBean;
import org.springframework.core.Ordered;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;

public class ServicesAuthenticationEntryPoint implements AuthenticationEntryPoint, InitializingBean, Ordered {

	
	private String realmName = "services-realm";
	
	@Override
	public void commence( HttpServletRequest request, HttpServletResponse response, 
			AuthenticationException authException ) throws IOException{
		response.sendError( HttpServletResponse.SC_UNAUTHORIZED, "Unauthorized" );
	}

	@Override
	public int getOrder() {
		return 0;
	}

	@Override
	public void afterPropertiesSet() throws Exception {
		if ((realmName == null) || "".equals(realmName)) {
			throw new IllegalArgumentException("realmName must be specified");
		}
		
	}

}