# Wstęp

### Repozytorium przygotowane z użyciem nadzorowanego technicznego czatu AI, z późniejszymi zmianami #AL-281

Obsługa tworzenia i publikacji obrazów docker w [repozytorium pakietów algorone](https://github.com/orgs/algorone/packages). Obrazy dla architektur `amd64` i `arm64` tworzone są przez dedykowane akcje github.
 - **[devel](https://github.com/orgs/algorone/packages/container/package/devel)**: obraz z preinstalowanym bogatym środowiskiem: liberoffice, tesseract-ocr, poppler-utils, uv python 

Na potrzeby sprwnego zarządzania budową obrazów przgotowano wzorcowe szablony:
 - `.github/workflows/build_docker_graalvm_template.yml`
 - `.github/workflows/build_docker_nextjs_template.yml`
 - `.github/workflows/build_docker_simple_template.yml`

### UWAGA Repozytorium wymaga jawnie nadanych uprawnień do publikowania artefaktow bezpośrednio w przestrzeni organizacji
1. **Jednorazowe przygotowanie (Zarezerwowanie nazwy w GHCR)**
Musimy pokazać GitHubowi, że pakiet `aplikacjaA` istnieje i jest powiązany z repozytorium.
- Użyj GitHub Personal Access Token (classic) z uprawnieniem write:packages.
- Zaloguj się w konsoli swojego komputera do GHCR:
```bash 
echo "TWÓJ_PAT" | docker login ghcr.io -u Publikator --password-stdin
```

- Stwórz pusty lub minimalistyczny obraz i wypchnij go, aby utworzyć encję pakietu:
```bash
docker pull alpine:latest
docker tag alpine:latest ghcr.io/algorone/aplikacjaA:latest
docker push ghcr.io/algorone/aplikacjaA:latest
```

2. **Kluczowe nadanie uprawnień w GitHub UI**:
Na stronie organizacji [algorone](https://github.com/algorone) na GitHubie:
- przejdź do zakładki Packages i kliknij `aplikacjaA`. 
- po prawej stronie na dole kliknij Package settings.
- przewiń do sekcji Manage Actions access
- kliknij Add repository.Wyszukaj i dodaj swoje repozytorium (algorone/downloads).
- zmień uprawnienia dla tego repozytorium na Write lub Admin.
- w sekcji `Danger Zone` zmień ustawienia na `public`

Od tej chwili GitHub Actions ma prawo zarządzać pakietem `aplikacjaA`.
