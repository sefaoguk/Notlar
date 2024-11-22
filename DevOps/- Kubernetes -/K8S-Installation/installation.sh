#!/bin/bash

# Script Configuration
CONTAINERD_VERSION="1.7.23-1"
KUBERNETES_VERSION="1.30.7-1.1"
DOCKERCE_VERSION="27.3.1"
NETWORK_CIDR="192.168.0.0/16"

# Log functions for colored output with decorations
info() {
    echo -e "\033[1;32m[INFO] ==> $1 <==\033[0m"
}

warn() {
    echo -e "\033[1;33m[WARN] ==> $1 <==\033[0m"
}

error() {
    echo -e "\033[1;31m[ERR!] !!! $1 !!!\033[0m"
    exit 1
}

# # Version information display
info "Starting Kubernetes setup script"
info "Versions being installed:"
info " - containerd: $CONTAINERD_VERSION"
info " - Kubernetes: $KUBERNETES_VERSION"
info " - Docker CE: $DOCKERCE_VERSION"

# # Checking and installing required modules
info "Adding required modules to /etc/modules-load.d/containerd.conf"
if ! grep -q 'overlay' /etc/modules-load.d/containerd.conf; then
    echo "overlay" | sudo tee -a /etc/modules-load.d/containerd.conf || error "Failed to add 'overlay' to modules"
else
    warn "Module 'overlay' already exists in configuration. Skipping..."
fi

if ! grep -q 'br_netfilter' /etc/modules-load.d/containerd.conf; then
    echo "br_netfilter" | sudo tee -a /etc/modules-load.d/containerd.conf || error "Failed to add 'br_netfilter' to modules"
else
    warn "Module 'br_netfilter' already exists in configuration. Skipping..."
fi

# # Load modules
info "Loading required kernel modules"
sudo modprobe overlay || error "Failed to load module: overlay"
sudo modprobe br_netfilter || error "Failed to load module: br_netfilter"

# # Setup sysctl configuration
info "Setting sysctl configuration for Kubernetes"
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
EOF

# # Apply sysctl settings
 info "Applying sysctl settings"
 sudo sysctl --system || error "Failed to apply sysctl settings"

# # Update apt and install necessary packages
info "Updating package list"
sudo apt update || error "Failed to update package list"

# # Install curl if not already installed
info "Installing curl"
if ! dpkg -l | grep -q curl; then
    sudo apt install curl -y || error "Failed to install curl"
else
    warn "curl is already installed. Skipping..."
fi

# # Install ntp if not already installed
info "Installing ntp"
if ! dpkg -l | grep -q ntp; then
    sudo apt install ntp -y || error "Failed to install ntp"
else
    warn "ntp is already installed. Skipping..."
fi

# # Install ca-certificates and gnupg
info "Installing ca-certificates and gnupg"
sudo apt install ca-certificates gnupg -y || error "Failed to install ca-certificates or gnupg"

# # Docker GPG key and repository setup
info "Setting up Docker repository"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg || error "Failed to download Docker GPG key"
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# # Update apt and install containerd
info "Updating apt and installing containerd version $CONTAINERD_VERSION"
sudo apt update || error "Failed to update apt"
if ! dpkg -l | grep -q containerd; then
    sudo apt install containerd.io=$CONTAINERD_VERSION -y || error "Failed to install containerd"
else
    warn "containerd $CONTAINERD_VERSION is already installed. Skipping..."
fi

# # Kubernetes GPG key and repository setup
info "Setting up Kubernetes repository"
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg || error "Failed to download Kubernetes GPG key"
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update apt and install Kubernetes packages
info "Updating apt and installing Kubernetes version $KUBERNETES_VERSION"
sudo apt update || error "Failed to update apt"
if ! dpkg -l | grep -q kubelet; then
    sudo apt install kubelet=$KUBERNETES_VERSION kubeadm=$KUBERNETES_VERSION kubectl=$KUBERNETES_VERSION -y || error "Failed to install Kubernetes packages"
else
    warn "Kubernetes packages $KUBERNETES_VERSION are already installed. Skipping..."
fi

# # Mark Kubernetes packages to hold
info "Marking Kubernetes packages to hold"
sudo apt-mark hold kubelet kubeadm kubectl || error "Failed to hold Kubernetes packages"

# Initialize Kubernetes
info "Initializing Kubernetes cluster with kubeadm $NETWORK_CIDR"
sudo rm /etc/containerd/config.toml
sudo systemctl restart containerd
sudo kubeadm init --pod-network-cidr=$NETWORK_CIDR || error "Failed to initialize Kubernetes"

# Configure kubectl
info "Configuring kubectl"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config || error "Failed to copy Kubernetes admin.conf"
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Apply Calico network plugin
info "Applying Calico network plugin"
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml || error "Failed to apply Calico network plugin"

info "Kubernetes setup completed successfully!"

kubectl get pods -A
