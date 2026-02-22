#!/bin/bash
# preflight-check-ha-external.sh
# Automated Kubernetes HA preflight check using external IPs or via bastion

# === NODE INVENTORY (external IPs) ===
NODES=(
  "34.50.49.13"   # ha-k8s-master-1
  "34.50.11.74"   # ha-k8s-master-2
  "34.64.232.84"  # ha-k8s-master-3
  "34.104.180.231" # ha-k8s-worker-1
  "136.110.101.118" # ha-k8s-worker-2
)
SSH_USER="k8s-cluster-key"   # node SSH user
VIP_IP="10.10.0.100"         # internal VIP, may not be reachable externally

# Optional: if using a bastion, define it here
USE_BASTION=false
BASTION_USER="bastion-user"
BASTION_HOST="your-bastion-ip"

echo "🚀 Starting HA Kubernetes preflight check from local (external IPs)..."

for NODE in "${NODES[@]}"; do
  echo -e "\n==== Checking node: $NODE ===="

  # If using a bastion host, use ProxyJump
  SSH_CMD="ssh -o StrictHostKeyChecking=no"
  if [ "$USE_BASTION" = true ]; then
    SSH_CMD="$SSH_CMD -J $BASTION_USER@$BASTION_HOST"
  fi
  SSH_CMD="$SSH_CMD $SSH_USER@$NODE"

  $SSH_CMD bash <<'EOF'
    echo "[1] OS & Swap"
    uname -r
    cat /etc/os-release
    if swapon --summary | grep -q '^'; then
        echo "❌ Swap is ON! Kubernetes requires swap OFF."
    else
        echo "✅ Swap is OFF."
    fi

    echo "[2] Hostname & /etc/hosts"
    hostname
    grep -v '^#' /etc/hosts | grep -v '^$'

    echo "[3] Container runtime"
    command -v docker >/dev/null && docker version --format '{{.Server.Version}}' || echo "Docker not installed"
    command -v containerd >/dev/null && containerd --version || echo "containerd not installed"
    systemctl is-active --quiet docker && echo "✅ Docker active" || echo "❌ Docker inactive"
    systemctl is-active --quiet containerd && echo "✅ containerd active" || echo "❌ containerd inactive"

    echo "[4] Kubernetes binaries"
    command -v kubeadm >/dev/null && kubeadm version -o short || echo "kubeadm not installed"
    command -v kubelet >/dev/null && kubelet --version || echo "kubelet not installed"
    command -v kubectl >/dev/null && kubectl version --client --short || echo "kubectl not installed"

    echo "[5] Node resources"
    free -h
    nproc
    df -h / | awk '{if(NR>1) print $1,$2,$3,$4,$5}'

    echo "[6] Kubelet health"
    systemctl is-active --quiet kubelet && echo "✅ kubelet active" || echo "❌ kubelet inactive"
EOF

  echo "[7] Networking check"
  ping -c 2 -W 2 $NODE >/dev/null && echo "✅ Node reachable" || echo "❌ Node unreachable"
  nc -z -w 3 $NODE 22 && echo "✅ SSH port open" || echo "❌ SSH port closed"

  # VIP check (optional, may fail externally)
  nc -z -w 3 $VIP_IP 6443 && echo "✅ VIP/API port 6443 reachable" || echo "⚠ VIP/API port unreachable externally"
done

echo -e "\n✅ Preflight check finished!"