# 🚀 HA Kubernetes Cluster — Full Automation

### GCP + Ansible + Kubespray + ArgoCD + K8s Dashboard + Cloudflare DNS

---

## 📐 Architecture & Pipeline

```
Your Local Machine (Ansible Controller)
│
├─ STAGE 1+2 ──► GCP API (service account)
│                  Create VPC + Subnet + Firewall rules
│                  Provision 5 VMs (Ubuntu 22.04, e2-standard-2)
│                  ┌─────────────────────────────────────────┐
│                  │  us-central1-a (masters zone)           │
│                  │   ha-k8s-master-1  10.10.0.x  ◄─ kube-vip (10.10.0.100)
│                  │   ha-k8s-master-2  10.10.0.x            │
│                  │   ha-k8s-master-3  10.10.0.x            │
│                  │                                         │
│                  │  us-central1-b (workers zone)           │
│                  │   ha-k8s-worker-1  10.10.0.x            │
│                  │   ha-k8s-worker-2  10.10.0.x            │
│                  └─────────────────────────────────────────┘
│                  Write → inventory/hosts.ini (dynamic, from real IPs)
│                  Write → inventory/kubespray-hosts.yaml
│
├─ STAGE 3 ─────► All 5 VMs (parallel)
│                  Disable swap, sysctl, kernel modules
│                  Install packages, set /etc/hosts, NTP
│
├─ STAGE 4 ─────► master1 only
│                  Clone Kubespray v2.24.0
│                  Push inventory + group_vars
│                  master1 → ansible-playbook cluster.yml
│                       → installs K8s on all 5 via internal IPs
│
├─ STAGE 5 ─────► master1 → local
│                  Fetch /etc/kubernetes/admin.conf
│                  Patch server: to master1 external IP
│                  Install kubectl + helm on local if missing
│
├─ STAGE 6 ─────► local → K8s cluster
│                  Deploy ArgoCD (+ ingress + patch password)
│                  Deploy K8s Dashboard (helm + admin token)
│
└─ STAGE 7 ─────► Cloudflare API
                   k8s-dashboard.example.com → worker-1 external IP
                   argocd.example.com        → worker-1 external IP
```

---

## ⚡ Quick Start

### 1. Prerequisites

```bash
# Install Python dependencies
pip3 install -r requirements.txt

# Install Ansible Galaxy collections (GCP + extras)
ansible-galaxy collection install -r requirements.yml
```

### 2. GCP Service Account

```bash
# In GCP Console → IAM → Service Accounts → Create
# Grant these roles:
#   Compute Admin
#   Service Account User
#   DNS Admin (if managing GCP DNS — we use Cloudflare here)

# Download JSON key → save as:
cp ~/Downloads/your-sa-key.json files/sa-key.json
```

### 3. Configure Variables

Edit **`group_vars/all.yml`** — minimum required changes:

```yaml
gcp_project_id: "your-actual-gcp-project-id"
service_account_file: "files/sa-key.json"
gcp_region: "us-central1" # change if needed
gcp_zone_masters: "us-central1-a"
gcp_zone_workers: "us-central1-b"

cluster_name: "ha-k8s" # used as VM name prefix

cloudflare_zone: "yourdomain.com"
cloudflare_api_token: "your-cf-token"
argocd_admin_password: "YourSecurePassword!"
```

### 4. Cloudflare API Token

Go to https://dash.cloudflare.com/profile/api-tokens → Create Token

Permissions needed:

- `Zone → DNS → Edit`
- `Zone → Zone → Read`
- Include: your specific zone

### 5. Run Everything 🎯

```bash
# Full pipeline — one command, ~35-45 minutes total
ansible-playbook site.yml
```

---

## 🎛️ Run Individual Stages

```bash
# Stage 1+2: Provision GCP VMs only
ansible-playbook site.yml --tags provision

# Stage 3: Prepare nodes only (VMs must exist)
ansible-playbook site.yml --tags prepare

# Stage 4+5: Kubespray + fetch kubeconfig
ansible-playbook site.yml --tags kubespray

# Stage 6: Deploy apps only (cluster must be running)
ansible-playbook site.yml --tags apps

# Stage 6a: ArgoCD only
ansible-playbook site.yml --tags argocd

# Stage 6b: Dashboard only
ansible-playbook site.yml --tags dashboard

# Stage 7: DNS only
ansible-playbook site.yml --tags dns

# Skip provisioning if VMs already exist
ansible-playbook site.yml --skip-tags provision
```

---

## 📁 Project Structure

```
k8s-gcp-automation/
│
├── README.md                       ← 📝 Project overview / instructions
├── ansible.cfg                     ← ⚙️ Ansible configuration
├── auto_push.sh                     ← 🔄 Helper script to push changes or run plays
├── Justfile                         ← 🛠 Automation helper via just
├── requirements.txt                 ← 🐍 Python deps (pip install)
├── requirements.yml                 ← 📦 Ansible collections
│
├── credentials/                     ← 🔑 Secrets for GCP + SSH
│   ├── service-account.json         ← 🗝 GCP service account key
│   ├── k8s-ssh-key                  ← 🔐 SSH private key (auto-generated)
│   └── k8s-ssh-key.pub              ← 📬 SSH public key (auto-generated)
│
├── inventory/                       ← 📋 Auto-generated inventory, do not edit manually
│   ├── inventory.ini                 ← 🖥 Nodes & IPs (dynamic hosts)
│   ├── kubespray-hosts.yaml          ← 🏗 Kubespray inventory YAML
│   └── node_info.json                ← 🌐 Node info (internal/external IPs, roles)
│
├── playbooks/                        ← 📜 Main playbooks
│   ├── main.yml                      ← ▶️ Entry point (run Kubespray deploy / orchestration)
│   └── tasks/
│       ├── create-gcp.yml            ← ☁️ GCP VM provisioning
│       └── destroy-gcp.yml           ← ❌ Tear down all GCP infrastructure
│
├── templates/                        ← 📄 Templates for dynamic files
│   ├── dynamic-hosts.ini.j2          ← 🖥 Jinja template for dynamic inventory.ini
│   ├── kubespray-hosts.yaml.j2       ← 🏗 Jinja template for Kubespray hosts.yaml
│   └── startup-script.sh.j2          ← ⚡ Startup script run on VM boot
│
├── roles/                            ← 🎛 Ansible roles
│   ├── kubespray-deploy/             ← 🏗 Master1 runs Kubespray cluster deployment
│   │   ├── tasks/
│   │   │   └── main.yml              ← ▶️ Role tasks
│   │   └── templates/
│   │       ├── Justfile.j2           ← 🛠 Justfile template for Kubespray
│   │       ├── addons.yml.j2         ← ➕ Optional addons manifest
│   │       ├── etcd.yml.j2           ← 🗄 ETCD manifest template
│   │       ├── inventory.ini.j2      ← 🖥 Dynamic inventory template
│   │       └── k8s-cluster.yml.j2    ← 🏗 Cluster YAML template
│   ├── prepare-nodes/                ← 🖥 Prepare OS / dependencies on all nodes
│   │   └── tasks/
│   │       └── main.yml
│   ├── argocd/                       ← 🚀 Install ArgoCD
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   └── templates/
│   │       ├── argocd-ingress.yaml.j2
│   │       └── argocd-nodeport.yaml.j2
│   ├── k8s-dashboard/                ← 🖥 Install Kubernetes Dashboard
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   └── templates/
│   │       ├── dashboard-admin.yaml.j2
│   │       └── dashboard-ingress.yaml.j2
│   └── cloudflare-dns/               ← 🌐 Create DNS records via Cloudflare
│       └── tasks/
│           └── main.yml
│
├── secrets/                          ← 🔒 Vault / become password storage
│   ├── vault_pass.txt                ← 🗝 Vault password
│   └── become_pass.yml               ← 🛡 Sudo password for remote hosts
│
└── vars/                             ← ✏️ Variables for all roles / environments
    ├── all.yml                        ← 🏷 Global vars
    ├── cloudflare_vars.yml            ← 🌐 Cloudflare DNS vars
    └── secrets.yml                    ← 🔑 Vaulted secrets variables
```

---

## 🌐 Accessing Your Cluster

```bash
# After site.yml completes:
export KUBECONFIG=$(pwd)/kubeconfig/admin.conf

kubectl get nodes -o wide
kubectl get pods -A
kubectl get svc -A
```

| App               | URL                                 | Login                                        |
| ----------------- | ----------------------------------- | -------------------------------------------- |
| **K8s Dashboard** | `https://k8s-dashboard.example.com` | Token from `kubeconfig/dashboard-token.txt`  |
| **ArgoCD**        | `https://argocd.example.com`        | `admin` / value from `argocd_admin_password` |

---

## 🔍 Troubleshooting

```bash
# Check all nodes reachable
ansible all -m ping -i inventory/hosts.ini

# Verbose run
ansible-playbook site.yml -vvv

# Check Kubespray log on master1
ssh -i files/k8s-ssh-key ubuntu@<master1-ip> \
  "tail -100 ~/kubespray-install.log"

# Check cluster events
kubectl get events -A --sort-by='.lastTimestamp'

# Check ingress controller
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

# Check ArgoCD pods
kubectl get pods -n argocd

# Re-run only failed stage
ansible-playbook site.yml --tags apps
```

## 💣 Teardown

```bash
# Destroys all GCP VMs, network, firewall rules
ansible-playbook teardown.yml
```

---

## ⏱️ Expected Timeline

| Stage                 | Duration       |
| --------------------- | -------------- |
| GCP VM provisioning   | 3–5 min        |
| Node preparation      | 3–5 min        |
| Kubespray K8s install | 20–30 min      |
| Kubeconfig fetch      | < 1 min        |
| ArgoCD + Dashboard    | 3–5 min        |
| Cloudflare DNS        | < 1 min        |
| **Total**             | **~30–45 min** |

---

## 🔒 GCP Firewall Summary

| Rule             | Ports       | Source         | Target    |
| ---------------- | ----------- | -------------- | --------- |
| allow-internal   | ALL         | `10.10.0.0/24` | all nodes |
| allow-ssh        | 22          | `0.0.0.0/0`    | all nodes |
| allow-k8s-api    | 6443        | `0.0.0.0/0`    | masters   |
| allow-http-https | 80, 443     | `0.0.0.0/0`    | workers   |
| allow-nodeport   | 30000-32767 | `0.0.0.0/0`    | all nodes |
