# Kubernetes Lab Setup on Debian 13 (VM Environment)

This guide walks you through setting up a Kubernetes cluster using three Debian 13 VMs with static IPs, CRI-O as the container runtime, and Flannel for networking. The setup is ideal for learning, testing, or development purposes.

---

## 🖥️ Prerequisites

- Host machine running a hypervisor (e.g., `libvirt`, `virt-manager`)
- Three Debian 13 VMs (minimal install, no GUI, SSH enabled)
- Static IP configuration via `virsh net-edit default`
- Root access on all VMs

---

## 🌐 Step 1: Configure Static IPs in Virtual Network

Edit the virtual network to assign static IPs to your VMs:

```bash
sudo virsh net-edit default
```

Update the `<network>` XML to include static IP assignments for your VMs (example below). Replace MAC addresses and IPs as needed.

```xml
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
      <!-- Replace with your VM MAC addresses and desired IPs -->
      <host mac='youriphere' name='control-plane-1' ip='youriphere'/>
      .....
    </dhcp>
```

Save the file and reboot your hypervisor host to apply changes.

---

## 📝 Step 2: Configure `/etc/hosts` on All VMs

On each VM, add entries for easy SSH access:

```bash
echo "192.168.122.91 control-plane-1" | sudo tee -a /etc/hosts
echo "192.168.122.83 worker-1" | sudo tee -a /etc/hosts
echo "192.168.122.53 worker-2" | sudo tee -a /etc/hosts
```

---

## 💾 Step 3: Disable Swap

Run on **all VMs**:

```bash
sudo swapoff -a
sudo sed -i '/\sswap\s/s/^[^#]/#&/' /etc/fstab
sudo systemctl disable --now zramswap.service 2>/dev/null || true
swapon --show  # Verify no swap is active
```

---

## 🐳 Step 4: Install CRI-O (Container Runtime)

Become root (`su -`) and run the following on **all VMs**:

```bash
apt update -y
apt install -y sudo curl gpg apt-transport-https ca-certificates

KUBERNETES_VERSION=v1.34
CRIO_VERSION=v1.34
```

### Add Kubernetes Repository

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key |
    gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" |
    tee /etc/apt/sources.list.d/kubernetes.list
```

### Add CRI-O Repository

```bash
curl -fsSL https://download.opensuse.org/repositories/isv:/cri-o:/stable:/$CRIO_VERSION/deb/Release.key |
    gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://download.opensuse.org/repositories/isv:/cri-o:/stable:/$CRIO_VERSION/deb/ /" |
    tee /etc/apt/sources.list.d/cri-o.list
```

### Install CRI-O and Kubernetes Tools

```bash
apt-get install -y cri-o kubelet kubeadm kubectl
systemctl enable --now crio
```

---

## 🔒 Step 5: Freeze Kubernetes Component Versions

Prevent automatic upgrades:

```bash
sudo apt-mark hold kubelet kubeadm kubectl
```

---

## ⚙️ Step 6: Enable and Configure Kubelet

Ensure `kubelet` is running:

```bash
sudo systemctl enable --now kubelet
```

### Configure CRI-O to Use `systemd` cgroup driver

```bash
sudo mkdir -p /etc/crio/crio.conf.d
printf '[crio.runtime]\ncgroup_manager = "systemd"\n' | \
  sudo tee /etc/crio/crio.conf.d/02-cgroup-manager.conf

sudo systemctl restart crio
```

---

## 📄 Step 7: Create `kubeadm.yaml` Configuration File

On the **control-plane-1** VM, create the configuration file:

```bash
cat > kubeadm.yaml <<'EOF'
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
networking:
  podSubnet: 10.244.0.0/16
  serviceSubnet: 10.96.0.0/12
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
nodeRegistration:
  criSocket: unix:///var/run/crio/crio.sock
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
EOF
```

---

## 🚀 Step 8: Initialize the Control Plane

Run on **control-plane-1**:

```bash
sudo kubeadm init --config=kubeadm.yaml
```

After initialization, set up the local user kube config:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

---

## 🔄 Step 9: Join Worker Nodes

On each **worker node**, run the join command provided by `kubeadm init` (example below — replace with your actual token and CA hash):

```bash
kubeadm join <address> --token <token> \
    --discovery-token-ca-cert-hash sha256:<hash>
```

> ⚠️ **Note**: The token and CA hash will be unique to your cluster. Use the output from `kubeadm init`.

---

## 🌐 Step 10: Set Up Networking (Flannel)

On the **control-plane-1**, apply Flannel:

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

Wait for all pods to be ready:

```bash
kubectl get pods -A
```

---

## ✅ Final Checks

Ensure all nodes are in `Ready` state:

```bash
kubectl get nodes
```

You should see:

```
control-plane-1:~$ kubectl get nodes
NAME              STATUS   ROLES           AGE   VERSION
control-plane-1   Ready    control-plane   15m   v1.34.1
worker-1          Ready    <none>          13m   v1.34.1
worker-2          Ready    <none>          13m   v1.34.1
```

---

## 📌 Notes

- **Security**: In production, use secure tokens and certificates.
- **Updates**: The `apt-mark hold` prevents accidental upgrades — remove only if you intend to update.
- **CRI-O vs Docker**: CRI-O is lightweight and Kubernetes-native; ideal for learning or resource-constrained environments.

---

## 📚 Resources Used

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [CRI-O GitHub](https://github.com/cri-o/cri-o)
- [Flannel Docs](https://github.com/flannel-io/flannel)
- [Qwen3 VL 32B](https://huggingface.co/Qwen/Qwen3-VL-32B-Instruct) (turned scratchpad notes into this markdown)

---

> *This setup is for educational purposes only. Not suitable for production without additional hardening.*
