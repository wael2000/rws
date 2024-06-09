./mvnw clean package -Dquarkus.container-image.build=true -DskipTests
oc tag mc:1.0 mc:latest