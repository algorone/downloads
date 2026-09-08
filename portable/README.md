# Wstęp

### Repozytorium przygotowane z użyciem nadzorowanego technicznego czatu AI, z późniejszymi zmianami #AL-280

Zbiorcza dystrybucja otwartoźórdłowgo oprogramowania i skryptów potrzebnych do uruchomienia komponentów AlgorOne bzezpośrednio w Windows. 
- **PostgreSQL**: Wersja [Postgres 17](https://www.postgresql.org/) portable, odchudzona redystrybucja binarek z [EDB Postgres](https://www.enterprisedb.com/download-postgresql-binaries) z przygotowanym rozszerzeniem [http](https://github.com/pramsey/pgsql-http), binaria z [Postgres OnLine Journal](https://www.postgresonline.com/journal/archives/371-http-extension.html)
- **Python**: Wersja [Python 3.14](https://www.python.org/) portable, redystrubucja binarek (dot) z [WinPython](https://winpython.github.io/), z doinstalowanymi pakietami `asyncpg`, `dotenv`, `requests`
- **Redis**: Wersja [Redis 7](https://redis.io/) portable, redystrybucja binarek z [redis-windows](https://github.com/redis-windows/redis-windows) 
### TOTHINK:
- ~~**Valkey**: Aktywnie rozwijany [link](https://valkey.io/) na przyjaznej licencji fork [Redis](https://redis.io/), kompatyblilny z API Redis, redystrybucja binarek z [valkey-windows](https://github.com/valkey-windows/valkey-windows)~~
