@echo off
SETLOCAL Enabledelayedexpansion
TITLE Windows Portable Environment Launcher

:: Pobranie bezwzględnej ścieżki do głównego katalogu dystrybucji (katalog wyżej niż portable/scripts)
SET "SCRIPT_DIR=%~dp0"
CD /D "%SCRIPT_DIR%\..\.."
SET "BASE_DIR=%CD%"

:: Konfiguracja zmiennych środowiskowych PATH dla binariów komponentów
SET "PATH=%BASE_DIR%\python;%BASE_DIR%\python\Scripts;%BASE_DIR%\postgres\bin;%BASE_DIR%\redis;%PATH%"

:: Konfiguracja izolacji dla Pythona (zapobiega konfliktom z lokalnym środowiskiem użytkownika)
SET "PYTHONNOUSERSITE=1"
SET "PIP_CONFIG_FILE=%BASE_DIR%\python\pip.ini"

echo =======================================================================
echo  Portable Environment Ready (Postgres 17, Python 3.14, Redis 7)
echo =======================================================================
echo.
echo Dostepne narzedzia w sesji konsoli:
echo  - Python:   python --version
echo  - Postgres: psql --version
echo  - Redis:    redis-cli --version
echo.
echo Aby zainicjalizowac baze danych (pierwsze uruchomienie):
echo   initdb -D "%%BASE_DIR%%\data\postgres" -U postgres --auth=trust
echo.
echo Aby uruchomic serwer bazy danych:
echo   pg_ctl -D "%%BASE_DIR%%\data\postgres" -l "%%BASE_DIR%%\data\postgres\server.log" start
echo.
echo Aby uruchomic serwer Redis:
echo   redis-server
echo.
echo =======================================================================
cmd /k
