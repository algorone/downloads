FROM ubuntu:noble
COPY store-srv /store-srv
RUN chmod +x /store-srv
ENV STORE_HTTP_PORT=8034
ENV STORE_DATA_DIR=/dane/store-srv
CMD mkdir -p /dane/store-srv; /store-srv