# Wstęp

### Repozytorium przygotowane z użyciem nadzorowanego technicznego czatu AI, z późniejszymi zmianami #AL-279

Algorek-2.0 to dystrybucja Windows Subsytem Linux [WSL](https://learn.microsoft.com/en-us/windows/wsl/) oprata na dystrybucji [Ubuntu](https://ubuntu.com/wsl), z dodakowo zainstalowanymi komponentami.
- **Baza OS**: `Ubuntu 24.04 LTS (Noble Numbat)`
- **Kubernetes CLI & Node (`kubeadm`, `kubectl`, `kubelet`)**
- **Środowisko uruchomieniowe (CRI)**: `CRI-O ${{ github.event.inputs.k8s_version }}` oraz `containerd`
- **Zarządzanie kontenerami**: `Podman` (skonfigurowany w trybie rootful z dostępem grupowym)
- **Docker API Emulator Gateway**: `DOCKER_HOST` przekierowany globalnie do `/run/podman/podman.sock`
- **Docker Narzędzia**: Oficjalne `docker-ce-cli` oraz `docker-compose-plugin` (v2)
- **Pakiety dodatkowe**: `cups-ipp-utils`, `python3-asyncpg`, `python3-dotenv`


Uruchomienie WSL jako konto systemowe (zablokowane na twardo dla SYSTEM), czy start jako “Network Account“ nie działa poprawnie, lub nie spełnia kluczowego warunku pełnego dostepu do WSL po zalogowaniu się opiekuna robota na komputerze gospodarza. Jako rozwiązanie stabilne i zrozumiałe pozostaje opcja “autologon“ dedykowanego użytkonika `algorek`.

Wzorcowa sytuacja:

1. Domenowy użytkownik 'algorek' jest w lokalnej grupie administratów gospodarza Windows (potrzebne np do uruchomienia proxy na 80 i 443, oraz zarządzania uprawnieniami do zasobów lokalnych)
2. Robot Algorek-2.0 działa w sesji użytkownika 'algorek' 
3. Autologowanie użytkownika 'algorek' przy starcie systemu
4. Skrypt inicjalizacjy instację Algorek-2.0 podpięty pod zdarzenie logowania użytkownika 'algorek'
5. Opiekun robota loguje się do maszyny gospodarza z poświadczeniami użytkownika 'algorek', 
6. Hasło użytkonika ‘algorek’ widoczne tylko dla opiekuna i administratorów, lub przechowywane na urządzeniu zewnętrznym typu 'Rohos logon key'.
 - rozwiązanie z modyfikacją rejestru przechowuje hasło czystym tekstem w rejestrze 
 - rozwiązanie autologin z sysyinternals przenosi samo hasło do magazynu chronionego  https://learn.microsoft.com/pl-pl/windows/win32/secauthn/protecting-the-automatic-logon-password ale obowiązuje ostrzeżenie:`
```
[! OSTRZEŻENIE] Chociaż hasło jest szyfrowane w rejestrze jako klucz tajny LSA, 
użytkownik z uprawnieniami administracyjnymi może łatwo pobrać i odszyfrować. 
(Aby uzyskać więcej informacji, zobacz Ochrona hasła logowania automatycznego )
```
- rozwiązanie z przechowywaniem hasła logowanie poza systemem gospodarza np z 'Rohos logon key' mogą wymagać zaawansowanej konfiguracji sieciowej i konfiguracji hipervisora


# Instalacja
1. Pobierz plik dystrybucyjny z [repozutorium](https://github.com/algorone/downloads/releases) lub ([zbuduj](#jak-zbudować-algorka)) instancję Algore2-wsl
2. **Kliknij dwukrotnie pobrany plik** w Eksploratorze plików systemu Windows, aby uruchomić automatyczny kreator instalacji graficznej.
3. Po zakończeniu instalacji uruchom dystrybucję bezpośrednio z menu Start (Algorek-2.0) lub wpisując w terminalu:
```powershell
wsl -d Algorek-2.0
```

# Jak zbudować Algorka
Poostepuj zgodnie z intrukacjami z oficjalnej dokumentacji:
- [Build a Custom Linux Distribution for WSL](https://learn.microsoft.com/en-us/windows/wsl/build-custom-distro)
- [Customise an Ubuntu distro for WSL](https://ubuntu.com/wsl/docs/stable/howto/custom-ubuntu-distro/)

Pobierz bazowy obraz z Ubuntu WSL `ubuntu-24.04.4-wsl-amd64.tar` (link w dokumentacji), dalsze kroki wykanaj w domyślnej instancji WSL lub na fizycznaj lub wirtualnej maszynie z zainstalowanym Ubuntu 24.
1. upewanij się, że masz dostep do zasobów i internetu
2. skopiuj lub udestepnij katalog wsl do katalogu roboczego
3. skopiuj lub udostpenij obraz z Ubuntu WSL `ubuntu-24.04.4-wsl-amd64.tar` do katalogu roboczgo 
4. w sesji bash wykonaj:
```
mkdir algorek-wsl

sudo tar -xpf ubuntu-24.04.4-wsl-amd64.tar -C algorek-wsl --numeric-owner --absolute-names

cp -f wsl/wsl-distribution.conf algorek-wsl/etc/wsl-distribution.conf 
cp -f wsl/algorek.ico algorek-wsl/usr/share/wsl/algorek.ico
cp -f wsl/90_sudoers algorek-wsl/etc/sudoers.d/
cp -f wsl/build_script.sh algorek-wsl/tmp/build_script.sh
chmod +x algorek-wsl/tmp/build_script.sh

sudo mount -t proc /proc algorek-wsl/proc
sudo mount --rbind --make-rslave /sys algorek-wsl/sys
sudo mount --rbind --make-rslave /dev algorek-wsl/dev
sudo mount --rbind --make-rslave /run algorek-wsl/run

export K8S_VERSION="v1.37"

sudo chroot algorek-wsl /bin/bash /tmp/build_script.sh "$K8S_VERSION"
sudo rm -f algorek-wsl/tmp/build_script.sh

sudo umount -R algorek-wsl/run
sudo umount -R algorek-wsl/dev
sudo umount -R algorek-wsl/sys
sudo umount algorek-wsl/proc

cd ~/algorek-wsl

sudo tar --numeric-owner --absolute-names --one-file-system -czvf ../algorek-2.0-wsl.wsl
```
