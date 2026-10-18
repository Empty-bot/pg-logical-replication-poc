# Build multi-étapes : compilation avec Maven sur JDK 25, exécution sur un JRE 25.
FROM maven:3.9-eclipse-temurin-25 AS build
WORKDIR /app
COPY pom.xml .
# Met les dépendances en cache dans leur propre couche, pour qu'une modification
# du code ne les re-télécharge pas.
RUN mvn -q -B dependency:go-offline
COPY src ./src
RUN mvn -q -B package -DskipTests

FROM eclipse-temurin:25-jre
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
