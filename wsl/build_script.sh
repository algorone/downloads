#!/bin/bash
set -e

# Odbranie wersji K8s/CRI-O przekazanej jako pierwszy argument z GitHub Actions
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
CRIO_VERSION="$TARGET_VERSION"

apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release podman containerd apt-transport-https cups-ipp-utils python3-asyncpg python3-dotenv

mkdir -p /etc/apt/keyrings

# Maskowanie domeny i pobieranie klucza
DOCKER_URL_BASE="https://download.docker"
DOCKER_URL_TLD=".com/linux/ubuntu"
curl -fsSL "${DOCKER_URL_BASE}${DOCKER_URL_TLD}/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Składanie repozytorium APT
DOCKER_REPO="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] ${DOCKER_URL_BASE}${DOCKER_URL_TLD} $(lsb_release -cs) stable"
echo "$DOCKER_REPO" | tee /etc/apt/sources.list.d/docker.list > /dev/null


# Definicja tokenów i domen, które normalnie podlegają obcinaniu
K8S_PKGS_HOST="https://k8s.io"
COLON=":"

# --- REPOZYTORIUM CRI-O ---
# Budowanie pełnego URL: https://k8s.io/addons:/cri-o:/stable:/v1.31/deb/Release.key
CRIO_KEY_URL="${K8S_PKGS_HOST}/addons${COLON}/cri-o${COLON}/stable${COLON}/${CRIO_VERSION}/deb/Release.key"
curl -fsSL "$CRIO_KEY_URL" | gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

# Budowanie wpisu APT (Pamiętaj o spacji i slashu na końcu!)
CRIO_REPO_URL="${K8S_PKGS_HOST}/addons${COLON}/cri-o${COLON}/stable${COLON}/${CRIO_VERSION}/deb/"
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] ${CRIO_REPO_URL} /" | tee /etc/apt/sources.list.d/cri-o.list > /dev/null


# --- REPOZYTORIUM KUBERNETES ---
# Budowanie pełnego URL: https://k8s.io/core:/stable:/v1.31/deb/Release.key
K8S_KEY_URL="${K8S_PKGS_HOST}/core${COLON}/stable${COLON}/${K8S_VERSION}/deb/Release.key"
curl -fsSL "$K8S_KEY_URL" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Budowanie wpisu APT (Również ze spacją i slashem na końcu!)
K8S_REPO_URL="${K8S_PKGS_HOST}/core${COLON}/stable${COLON}/${K8S_VERSION}/deb/"
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] ${K8S_REPO_URL} /" | tee /etc/apt/sources.list.d/kubernetes.list > /dev/null


apt-get update
apt-get install -y docker-ce-cli docker-compose-plugin cri-o kubeadm kubectl kubelet
apt-mark hold kubelet kubeadm kubectl

# --- NOWE: Automatyzacja uprawnień użytkownika WSL ---
groupadd -f podman
groupadd -f docker

# Wymuszenie dodawania nowych użytkowników do grup systemowych i kontenerowych
sed -i 's/#EXTRA_GROUPS=.*/EXTRA_GROUPS="sudo podman docker"/' /etc/adduser.conf
sed -i 's/#ADD_EXTRA_GROUPS=.*/ADD_EXTRA_GROUPS=1/' /etc/adduser.conf

# Przygotowanie pliku uprawnień dla kubeadm, aby grupa sudo (użytkownik WSL) mogła go czytać bez roota
mkdir -p /etc/kubernetes
touch /etc/kubernetes/admin.conf
chmod 0640 /etc/kubernetes/admin.conf
chown root:sudo /etc/kubernetes/admin.conf
# ----------------------------------------------------

mkdir -p /etc/systemd/system/podman.socket.d
cat <<EOF > /etc/systemd/system/podman.socket.d/override.conf
[Socket]
SocketGroup=podman
SocketMode=0660
EOF

mkdir -p /etc/systemd/system/kubelet.service.d
cat <<EOF > /etc/systemd/system/kubelet.service.d/20-allow-swap.conf
[Service]
Environment="KUBELET_EXTRA_ARGS=--fail-swap-on=false"
EOF

mkdir -p /var/lib/kubelet
cat <<EOF > /var/lib/kubelet/config.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
failSwapOn: false
EOF

systemctl enable podman.socket
systemctl enable crio
systemctl enable containerd

# --- NOWE: Połączone zmienne środowiskowe i KUBECONFIG ---
mkdir -p /etc/profile.d
cat <<'EOF' > /etc/profile.d/algorek-env.sh
export CONTAINER_HOST="unix:///run/podman/podman.sock"
export DOCKER_HOST="unix:///run/podman/podman.sock"
export KUBEADM_IGNORE_PREFLIGHT_ERRORS="Swap"

# Dostęp do klastra dla nie-roota po wykonaniu kubeadm init
if [ -f /etc/kubernetes/admin.conf ]; then
    export KUBECONFIG=/etc/kubernetes/admin.conf
fi
EOF
