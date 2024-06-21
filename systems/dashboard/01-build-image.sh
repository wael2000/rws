./mvnw clean package -Dquarkus.container-image.build=true -DskipTests
oc tag dashboard:1.0 dashboard:latest