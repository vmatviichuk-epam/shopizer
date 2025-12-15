package com.salesmanager.shop.filter;

import java.io.IOException;

import jakarta.servlet.Filter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.FilterConfig;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.http.HttpServletRequest;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;


@Component
@Order(0)
public class XssFilter implements Filter {

	 /**
	  * Description: Log
	  */
	 private static final Logger LOGGER = LoggerFactory.getLogger(XssFilter.class);

	 @Override
	 public void init(FilterConfig filterConfig) throws ServletException {
	  LOGGER.debug("(XssFilter) initialize");
	 }

	 
	 @Override
	 public void doFilter(ServletRequest srequest, ServletResponse response, FilterChain filterChain) throws IOException, ServletException {

	 		HttpServletRequest request = (HttpServletRequest) srequest;
	 		filterChain.doFilter(new XssHttpServletRequestWrapper(request) {}, response);

	 }



	 @Override
	 public void destroy() {
	  LOGGER.debug("(XssFilter) destroy");
	 }

}
