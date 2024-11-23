#!/bin/bash

# Function to print info logs in green
info() {
    echo -e "\033[0;32m==> INFO: $1\033[0m"
}

# Function to print error logs in red
error() {
    echo -e "\033[0;31m==> ERROR: $1\033[0m"
    exit 1
}

# Update package list and upgrade
info "Updating package list and upgrading existing packages..."
sudo apt-get update && sudo apt-get upgrade || error "Failed to update and upgrade packages"

# Install Docker
info "Installing Docker..."
sudo apt install docker.io || error "Failed to install Docker"

# Enable and start Docker service
info "Enabling and starting Docker service..."
sudo systemctl enable docker && sudo systemctl start docker || error "Failed to start Docker"

# Disable swap
info "Disabling swap..."
sudo swapoff -a || error "Failed to disable swap"
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab || error "Failed to comment swap in /etc/fstab"

# Load necessary kernel modules
info "Loading necessary kernel modules for Kubernetes..."
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
sudo modprobe overlay && sudo modprobe br_netfilter || error "Failed to load kernel modules"

# Apply sysctl settings for Kubernetes
info "Applying sysctl settings for Kubernetes..."
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system || error "Failed to apply sysctl settings"

# Install dependencies for Docker repository
info "Installing Docker repository dependencies..."
sudo apt-get install apt-transport-https ca-certificates curl software-properties-common || error "Failed to install dependencies"

# Add Docker repository
info "Adding Docker repository..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg || error "Failed to add Docker GPG key"
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" || error "Failed to add Docker repository"

# Install Containerd
info "Installing containerd..."
sudo apt update && sudo apt install containerd.io || error "Failed to install containerd"

# Configure containerd
info "Configuring containerd..."
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null || error "Failed to configure containerd"
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml || error "Failed to modify containerd config"

# Restart and enable containerd
info "Restarting and enabling containerd..."
sudo systemctl restart containerd && sudo systemctl enable containerd || error "Failed to restart and enable containerd"

# Add Kubernetes APT repository
info "Adding Kubernetes APT repository..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg || error "Failed to add Kubernetes GPG key"
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list || error "Failed to add Kubernetes repository"

# Install Kubernetes components
info "Installing kubelet, kubeadm, and kubectl..."
sudo apt-get update && sudo apt-get install kubelet kubeadm kubectl || error "Failed to install Kubernetes components"

# Mark Kubernetes components to prevent accidental upgrades
info "Marking kubelet, kubeadm, kubectl to hold versions..."
sudo apt-mark hold kubelet kubeadm kubectl || error "Failed to hold Kubernetes components"

# Enable and start kubelet
info "Enabling and starting kubelet..."
sudo systemctl enable --now kubelet || error "Failed to enable kubelet"

# Initialize Kubernetes cluster
info "Initializing Kubernetes cluster..."
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=172.17.0.1 --kubernetes-version=1.30.1 --ignore-preflight-errors=NumCPU || error "Failed to initialize Kubernetes cluster"

# Set up kubeconfig
info "Setting up kubeconfig..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config || error "Failed to copy kubeconfig"
sudo chown $(id -u):$(id -g) $HOME/.kube/config || error "Failed to set ownership of kubeconfig"

# Apply Calico network plugin
info "Applying Calico network plugin..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml || error "Failed to apply Calico network plugin"

info "Kubernetes setup completed successfully!"
