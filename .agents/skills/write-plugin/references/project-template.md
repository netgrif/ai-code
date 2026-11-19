# Plugin project template

A complete plugin `hello-plugin` (registration name `helloPlugin`, entry point
`greetings`, method `hello`). It builds with `mvn clean package` on Java 21
and Maven 3.9. Copy it into `plugins/<artifactId>/` and replace:

| Placeholder in the template       | Replace with                         |
|-----------------------------------|--------------------------------------|
| `hello-plugin`                    | your `artifactId` (folder, service)  |
| `helloPlugin`                     | your `registrationName`              |
| `com.example` / `com.example.hello` | your `groupId` / Java package      |
| `Hello plugin`, description, `url`, `licenses`, `scm` | your project's values |
| `8701` / `9701`                   | your REST / gRPC ports               |

Layout:

```
plugins/hello-plugin/
├── pom.xml
├── Dockerfile
├── .dockerignore
├── compose.yaml
├── README.md
└── src/
    ├── main/java/com/example/hello/
    │   ├── HelloPluginApplication.java
    │   ├── GreetingsEntryPoint.java
    │   └── GreetingService.java
    ├── main/resources/application.properties
    └── test/java/com/example/hello/GreetingServiceTest.java
```

Do not change the `<build>` section except the registration name property:
the `process-classes` binding and the second compiler execution are what make
`nae-plugin-maven-plugin` find the entry points on a clean build and compile
the registration it generates (`PluginRegistrationConfigurationImpl` and a
Spring auto-configuration import).

## `pom.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>4.1.0</version>
        <relativePath/>
    </parent>

    <groupId>com.example</groupId>
    <artifactId>hello-plugin</artifactId>
    <version>0.1.0-SNAPSHOT</version>
    <name>Hello plugin</name>
    <description>Greets a name; callable from Petriflow actions</description>
    <!-- The generated plugin registration copies url, scm and licenses into its metadata;
         without them it inherits the Spring Boot parent's values. -->
    <url>https://example.com/hello-plugin</url>
    <licenses>
        <license>
            <name>Proprietary</name>
        </license>
    </licenses>
    <scm>
        <url>https://example.com/hello-plugin</url>
    </scm>

    <properties>
        <java.version>21</java.version>
        <nae.plugin-sdk.version>1.1.0</nae.plugin-sdk.version>
        <plugin.registration-name>helloPlugin</plugin.registration-name>
    </properties>

    <repositories>
        <repository>
            <id>netgrif-nexus-releases</id>
            <url>https://nexus.netgrif.com/repository/maven-public</url>
            <snapshots><enabled>false</enabled></snapshots>
        </repository>
    </repositories>
    <pluginRepositories>
        <pluginRepository>
            <id>netgrif-nexus-releases</id>
            <url>https://nexus.netgrif.com/repository/maven-public</url>
            <snapshots><enabled>false</enabled></snapshots>
        </pluginRepository>
    </pluginRepositories>

    <dependencies>
        <dependency>
            <groupId>com.netgrif</groupId>
            <artifactId>plugin-client</artifactId>
            <version>${nae.plugin-sdk.version}</version>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <resources>
            <resource>
                <directory>src/main/resources</directory>
                <filtering>true</filtering>
            </resource>
        </resources>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <configuration>
                    <classifier>exec</classifier>
                </configuration>
            </plugin>
            <plugin>
                <groupId>com.netgrif</groupId>
                <artifactId>nae-plugin-maven-plugin</artifactId>
                <version>1.0.2</version>
                <configuration>
                    <registrationName>${plugin.registration-name}</registrationName>
                    <apiVersion>1.0.0</apiVersion>
                </configuration>
                <executions>
                    <execution>
                        <id>generate-plugin-registration</id>
                        <phase>process-classes</phase>
                        <goals>
                            <goal>generate-plugin-registration</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <executions>
                    <execution>
                        <id>compile-plugin-registration</id>
                        <phase>process-classes</phase>
                        <goals>
                            <goal>compile</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>
</project>
```

## `src/main/java/com/example/hello/HelloPluginApplication.java`

```java
package com.example.hello;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication(scanBasePackages = {"com.netgrif", "com.example.hello"})
@ConfigurationPropertiesScan("com.netgrif.plugin.core.properties")
public class HelloPluginApplication {

    public static void main(String[] args) {
        SpringApplication.run(HelloPluginApplication.class, args);
    }
}
```

## `src/main/java/com/example/hello/GreetingsEntryPoint.java`

```java
package com.example.hello;

import com.netgrif.application.engine.adapter.spring.plugin.annotations.EntryPoint;
import com.netgrif.application.engine.adapter.spring.plugin.annotations.EntryPointMethod;

@EntryPoint("greetings")
public class GreetingsEntryPoint {

    private final GreetingService greetingService;

    public GreetingsEntryPoint(GreetingService greetingService) {
        this.greetingService = greetingService;
    }

    @EntryPointMethod(name = "hello")
    public String hello(String name) {
        return greetingService.greet(name);
    }
}
```

## `src/main/java/com/example/hello/GreetingService.java`

```java
package com.example.hello;

import org.springframework.stereotype.Service;

@Service
public class GreetingService {

    public String greet(String name) {
        if (name == null || name.isBlank()) {
            return "Hello!";
        }
        return "Hello " + name.trim() + "!";
    }
}
```

## `src/main/resources/application.properties`

```properties
spring.application.name=@project.artifactId@
spring.profiles.active=service
server.port=${SERVER_PORT:8701}
netgrif.plugin.service.grpc.port=${NETGRIF_PLUGIN_SERVICE_GRPC_PORT:9701}
netgrif.plugin.service.search.default-zone=${NETGRIF_PLUGIN_SERVICE_SEARCH_DEFAULT_ZONE:z1}
```

`spring.profiles.active=service` is required: the registration, the gRPC server and `ActionApiImpl` in `plugin-client` exist only in the `service` profile, and the client's own `application.yaml` defaults to the `module` profile. The other plugin keys (`netgrif.plugin.service.host`, `admin-node.*`) come from the `application.yaml` inside `plugin-client` and are set by env variables in `compose.yaml`. `@project.artifactId@` works because the pom filters resources.

## `src/test/java/com/example/hello/GreetingServiceTest.java`

```java
package com.example.hello;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class GreetingServiceTest {

    private final GreetingService service = new GreetingService();

    @Test
    void greetsByName() {
        assertEquals("Hello John!", service.greet(" John "));
    }

    @Test
    void greetsWithoutName() {
        assertEquals("Hello!", service.greet(null));
    }
}
```

## `Dockerfile`

```dockerfile
FROM eclipse-temurin:21-jre
WORKDIR /opt/netgrif/plugin
COPY target/*-exec.jar app.jar
ENTRYPOINT ["java", "-Dfile.encoding=UTF-8", "-jar", "app.jar"]
```

## `.dockerignore`

```
*
!target/*-exec.jar
```

The build context is only the runnable jar, so the image does not copy sources or `target/` leftovers.

## `compose.yaml`

```yaml
services:
  hello-plugin:
    build: .
    image: netgrif-starter/hello-plugin:local
    restart: unless-stopped
    environment:
      SERVER_PORT: 8701
      NETGRIF_PLUGIN_SERVICE_HOST: hello-plugin
      NETGRIF_PLUGIN_SERVICE_GRPC_PORT: 9701
      NETGRIF_PLUGIN_SERVICE_ADMIN_NODE_HOST: nae-admin
      NETGRIF_PLUGIN_SERVICE_ADMIN_NODE_GRPC_PORT: 9999
      NETGRIF_PLUGIN_SERVICE_SEARCH_DEFAULT_ZONE: z1
    ports:
      - "127.0.0.1:8701:8701"
    healthcheck:
      test: [ "CMD", "sh", "-c", "curl -sf http://127.0.0.1:8701/manage/health | grep UP" ]
      interval: 30s
      timeout: 5s
      retries: 5
      start_period: 30s
    depends_on:
      nae-admin:
        condition: service_healthy
      nae-engine:
        condition: service_healthy
    networks:
      - netgrif-platformnet

networks:
  netgrif-platformnet:
    name: netgrif-platformnet
```

The network is declared by name only, so it merges with the root file's `netgrif-platformnet` when included. `depends_on` refers to services of the root file: always run `docker compose` from the repository root. gRPC is not published to the host; the cluster reaches it on the Docker network.

## `README.md`

````markdown
# Hello plugin

Greets a name. Registered as `helloPlugin`.

## Entry points

| Call from an action                              | Returns  |
|--------------------------------------------------|----------|
| `Plugin.helloPlugin.greetings.hello(String name)` | `String` |

## Build and run

```bash
mvn -f plugins/hello-plugin/pom.xml clean package
docker compose up -d --build hello-plugin
```

Ports: REST 8701 (this machine only), gRPC 9701 (cluster network only).
````

## Example: a file generated into the case

When the plugin produces a file for a file field, it can store it itself:

```java
@EntryPointMethod(name = "generateInto")
public String generateInto(String caseId, String fileFieldId) {
    byte[] pdf = renderer.render(actionApi.findCase(caseId));
    actionApi.saveFile(caseId, fileFieldId, ActionFileHolder.builder()
            .fileName("document.pdf")
            .fileContent(pdf)
            .build());
    return "document.pdf";
}
```

`ActionFileHolder` is `com.netgrif.application.engine.adapter.spring.actions.ActionFileHolder`;
`actionApi` is an injected `PluginActionApi`. The action calls
`Plugin.<registrationName>.<entryPoint>.generateInto(useCase.stringId, "<file_field_id>")`.
