# Examples Directory: Provisioning Scripts & Cluster Manifests

> **Directory:** `C:\Users\alkur\OneDrive\Documents\HyperV-LinuxLab\examples`  
> **Master Index:** 🧭 [INDEX.md](../INDEX.md)  
> **Workspace Rules:** 📋 [GEMINI.md](../GEMINI.md)  
> **Agent Directives:** 🤖 [AGENT.md](../AGENT.md)  
> **Skill:** 📁 [hyperv-lab-mentor](~/.gemini/config/skills/hyperv-lab-mentor/SKILL.md)  

---

## 🚀 Provisioning Examples

| File | Type | Purpose |
| :--- | :---: | :--- |
| [**`01-Single-Linux-Node.ps1`**](01-Single-Linux-Node.ps1) | PowerShell | Quick start: Spawns a single Ubuntu 24.04 VM with Cloud-Init in ~10 seconds. |
| [**`02-K8s-3Node-Cluster.ps1`**](02-K8s-3Node-Cluster.ps1) | PowerShell | Automated deployment of a 1 control-plane + 2 worker node Kubernetes cluster. |
| [**`k8s-3node-cluster.json`**](k8s-3node-cluster.json) | JSON Manifest | Cluster declarative definition consumed by `New-LabCluster`. |
| [**`multi-distro-cluster.json`**](multi-distro-cluster.json) | JSON Manifest | Heterogeneous lab manifest testing Ubuntu, Debian, and AlmaLinux nodes simultaneously. |
