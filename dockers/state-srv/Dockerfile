FROM ubuntu:noble
COPY state-srv /state-srv
RUN chmod +x /state-srv
ENV SIGMA_HTTP_PORT=8035
ENV SIGMA_DATA_DIR=/dane/state-srv
CMD mkdir -p /dane/state-srv;/state-srv