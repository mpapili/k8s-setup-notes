sudo bash -s <<'EOF'
set -euo pipefail

echo "[*] Checking for br_netfilter kernel module..."
if ! modinfo br_netfilter &>/dev/null; then
  echo "[!] br_netfilter module is not available in this kernel."
  echo "    You may need a different kernel or to enable BRIDGE_NETFILTER in the kernel config."
  exit 1
fi

echo "[*] Loading br_netfilter module..."
modprobe br_netfilter || {
  echo "[!] Failed to load br_netfilter. Check dmesg/journalctl for details."
  exit 1
}

echo "[*] Ensuring br_netfilter loads on boot..."
mkdir -p /etc/modules-load.d
cat <<'EOM' >/etc/modules-load.d/k8s.conf
br_netfilter
EOM

echo "[*] Writing Kubernetes networking sysctls..."
mkdir -p /etc/sysctl.d
cat <<'EOM' >/etc/sysctl.d/99-kubernetes-net.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOM

echo "[*] Applying sysctl settings..."
sysctl --system >/dev/null

echo "[*] Verifying /proc/sys/net/bridge/bridge-nf-call-iptables exists..."
if [ -f /proc/sys/net/bridge/bridge-nf-call-iptables ]; then
  cat /proc/sys/net/bridge/bridge-nf-call-iptables
else
  echo "[!] /proc/sys/net/bridge/bridge-nf-call-iptables still missing."
  echo "    Something is off with the kernel/bridge setup; double-check your kernel and modules."
  exit 1
fi

# Optional but helpful: restart container runtime + kubelet if present
for svc in crio containerd docker kubelet; do
  if systemctl list-unit-files | grep -q "^${svc}.service"; then
    echo "[*] Restarting ${svc}..."
    systemctl restart "${svc}" || echo "[!] Failed to restart ${svc}, continuing..."
  fi
done

echo
echo "[✓] br_netfilter and sysctls configured on this node."
echo "    Now run on ALL other Kubernetes nodes (control-plane and workers)."
echo "    After you’ve done that cluster-wide, run:"
echo "      kubectl delete pod -n kube-flannel -l app=flannel"
echo "    to force the flannel DaemonSet pods to restart and pick up the new settings."
EOF

