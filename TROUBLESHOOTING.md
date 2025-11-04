# Troubleshooting Guide

## Maven Build Failures

### Issue: "Could not find artifact com.shopizer:sm-core:jar" error

**Error Message:**
```
[ERROR] Could not resolve dependencies for project com.shopizer:sm-shop:jar:3.2.5:
The following artifacts could not be resolved: com.shopizer:sm-core:jar:3.2.5,
com.shopizer:sm-core-model:jar:3.2.5, com.shopizer:sm-shop-model:jar:3.2.5
```

**Root Cause:**
This is a multi-module Maven project. The internal modules (sm-core, sm-core-model, sm-shop-model) need to be built and installed to your local Maven repository before the main application (sm-shop) can run.

**Fix:**
Always build all modules first before running the application:

**Windows (CMD):**
```cmd
mvnw.cmd clean install -DskipTests
cd sm-shop
..\mvnw.cmd spring-boot:run -DskipTests
```

**Windows (PowerShell):**
```powershell
.\mvnw.cmd clean install -DskipTests
cd sm-shop
..\mvnw.cmd spring-boot:run -DskipTests
```

**Mac/Linux:**
```bash
./mvnw clean install -DskipTests
cd sm-shop
../mvnw spring-boot:run -DskipTests
```

**Note:** The startup scripts now handle this automatically by building all modules before starting the server.

### Issue: "Not authorized" error when downloading dependencies

**Error Message:**
```
[ERROR] Failed to execute goal on project sm-shop: Could not resolve dependencies
Failed to transfer artifact from/to spring-releases (https://repo.spring.io/libs-release): Not authorized
```

**Root Cause:**
Spring has deprecated their old `repo.spring.io/libs-release` repository. All Spring release artifacts are now hosted on Maven Central.

**Fix Applied:**
The project's `pom.xml` has been updated to remove references to the deprecated Spring repository. Maven now uses Maven Central by default for all Spring dependencies.

### Solutions (if issue persists):

#### 1. Clear Maven Cache and Retry

Delete the Maven local repository cache and try again:

```cmd
rmdir /s /q %USERPROFILE%\.m2\repository
```

Then run the start script again.

#### 2. Check Network/Proxy Configuration

If you're behind a corporate firewall or proxy, configure Maven proxy settings.

Create or edit `%USERPROFILE%\.m2\settings.xml`:

```xml
<settings>
  <proxies>
    <proxy>
      <id>corporate-proxy</id>
      <active>true</active>
      <protocol>http</protocol>
      <host>your.proxy.host</host>
      <port>8080</port>
      <!-- Add if authentication is required -->
      <username>proxyuser</username>
      <password>proxypass</password>
    </proxy>
  </proxies>
</settings>
```

#### 3. Use Maven Central Mirror

If Spring repository is blocked, configure Maven to use Maven Central as a mirror.

Create or edit `%USERPROFILE%\.m2\settings.xml`:

```xml
<settings>
  <mirrors>
    <mirror>
      <id>central</id>
      <mirrorOf>*</mirrorOf>
      <name>Maven Central</name>
      <url>https://repo.maven.apache.org/maven2</url>
    </mirror>
  </mirrors>
</settings>
```

#### 4. Update Repository URLs in pom.xml

Check if the project's `pom.xml` files have outdated repository URLs. The Spring repositories have been reorganized:

Old URL (may not work):
```
https://repo.spring.io/libs-release
```

New URLs:
```
https://repo.spring.io/release
https://repo.maven.apache.org/maven2
```

#### 5. Run with Verbose Output

To get more details about the error:

```cmd
cd sm-shop
..\mvnw.cmd clean install -e -X
```

This will show detailed error messages and stack traces.

#### 6. Check Internet Connectivity

Verify the machine can access Maven repositories:

```cmd
curl https://repo.maven.apache.org/maven2/
curl https://repo.spring.io/release/
```

If these fail, there's a network connectivity issue.

#### 7. Try Offline Build (if dependencies were previously downloaded)

If you have all dependencies cached:

```cmd
cd sm-shop
..\mvnw.cmd spring-boot:run -DskipTests -o
```

The `-o` flag enables offline mode.

## Port 8080 Already in Use

If you get "Address already in use" error:

### Windows:

Find the process using port 8080:
```cmd
netstat -ano | findstr :8080
```

Kill the process (replace PID with the actual process ID):
```cmd
taskkill /PID <PID> /F
```

Or use the stop script:
```cmd
stop-backend.bat
```

## Java Version Issues

Verify Java version:
```cmd
java -version
```

Should show Java 11 or higher (Java 21 recommended).

If wrong version, update `JAVA_HOME` environment variable to point to correct Java installation.

## Database Connection Issues

If using MySQL and getting connection errors:

1. Verify MySQL is running
2. Check credentials in `sm-shop/src/main/resources/database.properties`
3. Ensure database exists: `CREATE DATABASE SALESMANAGER;`

Default configuration uses **H2 in-memory database** which doesn't require any external database setup.

## General Build Issues

### Clean and rebuild:
```cmd
cd sm-shop
..\mvnw.cmd clean install -DskipTests
```

### Update Maven wrapper:
```cmd
mvnw.cmd wrapper:wrapper
```

## Getting Help

- Check logs in: `sm-shop/logs/`
- View application.properties: `sm-shop/src/main/resources/application.properties`
- API documentation: http://localhost:8080/swagger-ui.html (when server is running)
