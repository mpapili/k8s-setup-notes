# 🐳 Getting Started: Setting Up a Docker Build Server

This guide will walk you through setting up a Docker-based build server on a Debian 13 VM, enabling remote builds and image deployment.

## 🔧 Prerequisites

- A Debian 13 VM installed via **virt-manager**
- Static IP configured
- SSH access enabled
- No desktop environment (lightweight setup preferred)

---

## 🖥️ Step-by-Step Setup

### 1. Install Required Packages & Docker

Log in to your Debian VM and run:

```bash
su -
apt update && apt install -y vim curl htop
curl -fsSL https://get.docker.com | sh
usermod -aG docker $USER   # or if running as root: usermod -aG docker mike
systemctl enable --now docker
```

### 2. Start Local Docker Registry

Run a local registry container with auto-restart:

```bash
docker run -d \
  --restart=always \
  --name registry \
  -p 5000:5000 \
  registry:2
```

> Reboot the VM to confirm Docker and the registry are running.

---

## 🧪 Test Local Image Push/Pull

Pull an image, tag it, and push it to your local registry:

```bash
docker pull rockylinux:9.3
docker tag rockylinux:9.3 localhost:5000/rockylinux:9.3
```

Now, make sure you can pull from the host machine:

```bash
docker pull builder-1:5000/rockylinux:9.3
```

> ✅ You should see `it works` when pulling and running the image locally.

---

## 🌐 Configure Host Access

### 1. Add Host Alias to `/etc/hosts`

Edit `/etc/hosts`:

```bash
sudo vim /etc/hosts
# Add:
192.xxx.xxx.x builder-1
```

### 2. Allow Insecure Registry Access

Create and configure the Docker daemon for insecure registry access:

```bash
sudo mkdir -p /etc/docker
sudo vim /etc/docker/daemon.json
```

Add this content (update port if needed):

```json
{
  "insecure-registries": ["builder-1:5000"]
}
```

Then restart Docker:

```bash
systemctl restart docker
```

Test again:

```bash
docker pull builder-1:5000/rockylinux:9.3
```

---

## 🛠️ Set Up Remote Build Context

To allow building images on the remote VM from your host, we'll use Docker contexts.

### 1. Generate SSH Key (on Host Machine)

```bash
ssh-keygen -t ed25519 -C "buildbox-key"
```

### 2. Copy Public Key to Builder VM

```bash
ssh-copy-id mike@builder-1
```

### 3. Create Docker Context

On your **host machine**, create a new Docker context:

```bash
docker context create buildbox --docker "host=ssh://mike@builder-1"
```

### 4. Build and Push an Image Remotely

Create a sample `test.Dockerfile`:

```Dockerfile
FROM alpine:latest
RUN echo "it works" > /hello.txt
CMD cat /hello.txt
```

Build and push the image using the remote context:

```bash
docker --context buildbox build . -f test.Dockerfile -t testbuild
docker --context buildbox images

# Tag and push to local registry
docker --context buildbox tag testbuild localhost:5000/testbuild
docker --context buildbox push localhost:5000/testbuild

# Pull locally and run
docker pull builder-1:5000/testbuild
docker run builder-1:5000/testbuild
```

> ✅ You should see `it works` printed after running the container.

---

## 🧠 Use With Kubernetes (CRI-O)

If you're using **Kubernetes with CRI-O**, configure your worker nodes to trust your private registry:

### 1. Create Drop-in Configuration File

On each **worker node**:

```bash
su -
mkdir -p /etc/containers/registries.conf.d
tee /etc/containers/registries.conf.d/100-builder1.conf >/dev/null <<'EOF'
[[registry]]
location = "builder-1:5000"
insecure = true
blocked = false
EOF
```

### 2. Restart CRI-O

```bash
systemctl restart crio
```

### 3. Test With Kubernetes Pod

Deploy a pod using your image from the build server:

```bash
kubectl run testpod --image builder-1:5000/testbuild
kubectl logs testpod
```

> You should see `it works`.

---

## ✅ Summary

You now have:

- A fully functional Docker registry inside a Debian 13 VM
- A secure remote build context using SSH
- The ability to pull and push images across your lab
- Kubernetes integration via CRI-O for seamless deployments

---

## 🧩 Next Steps

- Automate builds with CI/CD pipelines (e.g., GitHub Actions)
- Secure the registry with TLS certificates
- Use Docker Compose or Swarm for multi-container setups
- Explore advanced Docker build features like buildkit and multi-stage builds

---

> 💡 Tip: Always ensure your `builder-1` static IP is consistent across reboots.

--- 

**Happy Building!** 🚀  
