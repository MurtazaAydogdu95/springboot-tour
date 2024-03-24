FROM openjdk:17

WORKDIR /app

COPY target/springboot-tour-0.0.1.jar /app/app.jar

EXPOSE 8080

CMD ["java", "-jar", "app.jar"]
