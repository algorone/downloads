FROM eclipse-temurin:25
COPY pki-fat.jar /pki-fat.jar
ENV PKI_HTTP_PORT=8036
ENV OBJECT_STORE_URL=http://localhost:8033
RUN mkdir -p /usr/share/fonts/truetype/liberation2/
COPY LiberationSans-Italic.ttf /usr/share/fonts/truetype/liberation2/LiberationSans-Italic.ttf
WORKDIR /
CMD ["java", "-jar", "pki-fat.jar"]
