package com.salesmanager.shop.store.security;

import java.io.IOException;

import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.springframework.beans.factory.InitializingBean;
import org.springframework.core.Ordered;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

@Component("restAuthenticationEntryPoint")
public class RestAuthenticationEntryPoint implements AuthenticationEntryPoint, InitializingBean, Ordered {
	
	private String realmName = "rest-realm";

	@Override
	public void commence(HttpServletRequest request, HttpServletResponse response,
			AuthenticationException authException) throws IOException, ServletException {
		
		
		response.sendError( HttpServletResponse.SC_UNAUTHORIZED, "Unauthorized" );

	}

	@Override
	public int getOrder() {
		return 1;
	}

	@Override
	public void afterPropertiesSet() throws Exception {
		if ((realmName == null) || "".equals(realmName)) {
			throw new IllegalArgumentException("realmName must be specified");
		}
	}

}
