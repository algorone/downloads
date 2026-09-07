#!/bin/bash
set -e

# Odebranie wersji K8s przekazanej jako pierwszy argument z GitHub Actions
TARGET_VERSION=$1

if [ -z "$TARGET_VERSION" ]; then
    echo "Błąd: Nie podano wersji docelowej jako argumentu skryptu!"
    exit 1
fi

if [ -f /etc/sudoers.d/90_sudoers ]; then
  chown root:root /etc/sudoers.d/90_sudoers
  chmod 0440 /etc/sudoers.d/90_sudoers
fi

export DEBIAN_FRONTEND=noninteractive
K8S_VERSION="$TARGET_VERSION"

# Podstawowe pakiety systemowe
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https cups-ipp-utils python3-asyncpg python3-dotenv

# --- 1. ZABEZPIECZONE REPOZYTORIUM DOCKER (DLA SILNIKA DOCKER-CE I CONTAINERD) ---
mkdir -p /etc/apt/keyrings

# --- DOCKER & CONTAINERD ---
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# --- KUBERNETES ---
curl -fsSL https://pkgs.k8s.io/core:/stable:/$K8S_VERSION/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$K8S_VERSION/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

# --- INSTALACJA PAKIETÓW ---
apt-get update
# Instalujemy pełny silnik Dockera (docker-ce) wraz z klientem oraz Kubernetes
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin kubeadm kubectl kubelet
apt-mark hold kubelet kubeadm kubectl

# --- AUTOMATYZACJA UPRAWNIEŃ UŻYTKOWNIKA ---
# Wymuszenie dodawania nowych użytkowników WSL do grupy sudo oraz grupy docker (w pełni natywnej)
sed -i 's/#EXTRA_GROUPS=.*/EXTRA_GROUPS="sudo docker"/' /etc/adduser.conf
sed -i 's/#ADD_EXTRA_GROUPS=.*/ADD_EXTRA_GROUPS=1/' /etc/adduser.conf

# Przygotowanie uprawnień do pliku admin.conf klastra dla grupy sudo (użytkownik nie-root)
mkdir -p /etc/kubernetes
touch /etc/kubernetes/admin.conf
chmod 0640 /etc/kubernetes/admin.conf
chown root:sudo /etc/kubernetes/admin.conf

# --- KONFIGURACJA KUBERNETES & SWAP ---
# Domyślna tolerancja SWAP dla usługi Kubelet
mkdir -p /etc/systemd/system/kubelet.service.d
cat <<EOF > /etc/systemd/system/kubelet.service.d/20-allow-swap.conf
[Service]
Environment="KUBELET_EXTRA_ARGS=--fail-swap-on=false"
EOF

# Szablon pliku konfiguracyjnego Kubelet
mkdir -p /var/lib/kubelet
cat <<EOF > /var/lib/kubelet/config.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
failSwapOn: false
EOF

# --- KLUCZOWE WSPÓŁDZIELENIE DOCKER + KUBERNETES ---
# Generujemy domyślną konfigurację dla systemowego Containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
# Wymuszenie poprawnego sterownika cgroup dla Kubernetes w WSL
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# Konfiguracja oficjalnego demona Dockera (daemon.json), aby zapisywał dane w przestrzeni klastra K8s (k8s.io)
sudo mkdir -p /etc/docker
cat <<EOF | sudo tee /etc/docker/daemon.json > /dev/null
{
  "features": {
    "containerd-snapshotter": true
  },
  "containerd-namespace": "k8s.io"
}
EOF

# Włączenie usług systemowych
systemctl enable containerd
systemctl enable docker

# --- GLOBALNE ZMIENNE ŚRODOWISKOWE ---
mkdir -p /etc/profile.d
cat <<'EOF' > /etc/profile.d/algorek-env.sh
# 1. Inteligentne mapowanie interfejsów sieciowych
# Domyślny interfejs NAT w WSL to zawsze pierwsza karta (zwykle eth0)
DEFAULT_NAT_IFACE=$(ip route | grep default | awk '{print $5; exit}')

# Szukamy DEDYKOWANEGO interfejsu dla klastra. 
# Filtrujemy tylko rzeczywiste karty Hyper-V, odrzucając domyślny NAT, pętle i tunele.
K8S_BRIDGE_IFACE=$(ip -br link | awk -v nat="$DEFAULT_NAT_IFACE" '$1 !~ /lo|sit|tunnel|veth|cni/ && $1 != nat {print $1; exit}')

if [ ! -z "$K8S_BRIDGE_IFACE" ]; then
    # SCENARIUSZ A: Znaleziono fizyczny, dedykowany mostek klastra (niezależnie od innych kart w systemie)
    sudo ip link set dev $K8S_BRIDGE_IFACE up 2>/dev/null || true
    
    # Czyszczenie starych śmieciowych adresów, jeśli karta wstała z domyślnym IP
    sudo ip addr flush dev $K8S_BRIDGE_IFACE 2>/dev/null || true
    
    # Przypisanie dedykowanego, bezpiecznego adresu IP dla klastra
    sudo ip addr add 10.88.0.10/24 dev $K8S_BRIDGE_IFACE 2>/dev/null || true
    export K8S_NODE_IP="10.88.0.10"
    
elif [ ! -z "$DEFAULT_NAT_IFACE" ]; then
    # SCENARIUSZ B: Brak dedykowanego mostka (Deweloper ma 100 innych kart na Windowsie, ale w WSL tylko domyślny NAT)
    NAT_IP=$(ip -4 addr show "$DEFAULT_NAT_IFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
    export K8S_NODE_IP="$NAT_IP"
    echo -e "\e[33m[Algorek Info]: Dedykowany mostek klastra niedostępny. Używam lokalnego NAT ($NAT_IP).\e[0m"
else
    # SCENARIUSZ C: Całkowity brak sieci wewnątrz WSL
    export K8S_NODE_IP="127.0.0.1"
fi

# 2. Stałe i bezpieczne zmienne dla Dockera i Kubeadm
export KUBEADM_IGNORE_PREFLIGHT_ERRORS="Swap"

if [ -f /etc/kubernetes/admin.conf ]; then
    export KUBECONFIG=/etc/kubernetes/admin.conf
fi
EOF


# --- CZYSZCZENIE SYSTEMU I OPTYMALIZACJA ROZMIARU IMAGE ---
# 1. Usunięcie pobranych archiwów pakietów .deb z pamięci podręcznej APT
apt-get clean
apt-get autoclean

# 2. Usunięcie list pakietów i metadanych repozytoriów (zostaną pobrane na nowo przy pierwszym 'apt update' u użytkownika)
rm -rf /var/lib/apt/lists/*

# 3. Czyszczenie katalogów tymczasowych
rm -rf /tmp/*
rm -rf /var/tmp/*

# 4. Czyszczenie logów systemowych, aby nie powielały się w dystrybucji
find /var/log -type f -exec truncate -s 0 {} \;

# 5. Usunięcie pamięci podręcznej kluczy i certyfikatów pobierania (jeśli powstały)
rm -rf /root/.cache

