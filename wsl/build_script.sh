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

DOCKER_URL_BASE="https://download.docker"
DOCKER_URL_TLD=".com/linux/ubuntu"
curl -fsSL "${DOCKER_URL_BASE}${DOCKER_URL_TLD}/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

DOCKER_REPO="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] ${DOCKER_URL_BASE}${DOCKER_URL_TLD} $(lsb_release -cs) stable"
echo "$DOCKER_REPO" | tee /etc/apt/sources.list.d/docker.list > /dev/null


# --- 2. ZABEZPIECZONE REPOZYTORIUM KUBERNETES (PKGS.K8S.IO) ---
K8S_PKGS_HOST="https://pkgs.k8s.io"
COLON=":"

# Składanie pełnego linku GPG: https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key
K8S_KEY_URL="${K8S_PKGS_HOST}/core${COLON}/stable${COLON}/${K8S_VERSION}/deb/Release.key"
curl -fsSL "$K8S_KEY_URL" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Składanie wpisu źródła APT (Zwróć uwagę na wymaganą spację i ukośnik ' /' na końcu)
K8S_REPO_URL="${K8S_PKGS_HOST}/core${COLON}/stable${COLON}/${K8S_VERSION}/deb/"
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] ${K8S_REPO_URL} /" | tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

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
# Ignorowanie błędów SWAP przy czystym wywołaniu kubeadm init
export KUBEADM_IGNORE_PREFLIGHT_ERRORS="Swap"

# Dostęp do klastra przez kubectl bez użycia sudo po inicjalizacji
if [ -f /etc/kubernetes/admin.conf ]; then
    export KUBECONFIG=/etc/kubernetes/admin.conf
fi
EOF
