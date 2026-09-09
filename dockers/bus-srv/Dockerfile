FROM ubuntu:noble
COPY --chmod=777 bus-srv /bus-srv
ENV BUS_HTTP_PORT=8033
ENV BUS_DATA_DIR=/dane/bus-srv
CMD mkdir -p /dane/bus-srv; /bus-srv