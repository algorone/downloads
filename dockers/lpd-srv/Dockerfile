FROM ubuntu:noble
COPY --chmod=777 lpd-srv /lpd-srv
ENV LPD_PORT=515
ENV LPD_SPOOL_DIR=/dane/lpd-srv
CMD mkdir -p /dane/lpd-srv; /lpd-srv
