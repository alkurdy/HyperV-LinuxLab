# Profiles Directory: VM Hardware & Software Sizing

> **Directory:** `C:\Users\alkur\OneDrive\Documents\HyperV-LinuxLab\Profiles`  
> **Master Index:** 🧭 [INDEX.md](../INDEX.md)  
> **Workspace Rules:** 📋 [GEMINI.md](../GEMINI.md)  
> **Agent Directives:** 🤖 [AGENT.md](../AGENT.md)  
> **Skill:** 📁 [hyperv-lab-mentor](~/.gemini/config/skills/hyperv-lab-mentor/SKILL.md)  

---

## 🎛️ VM Hardware Profiles

| Profile | vCPUs | RAM (Static/Dynamic) | Target Workload |
| :--- | :---: | :---: | :--- |
| [**`Minimal.json`**](Minimal.json) | 1 vCPU | 1024 MB | Lightweight shell practice, basic utilities, tiny footprint. |
| [**`Container.json`**](Container.json) | 2 vCPUs | 2048 MB | Docker, containerd, Podman, small single-node services. |
| [**`Kubernetes.json`**](Kubernetes.json) | 2–4 vCPUs | 4096 MB | Control-plane nodes, etcd, heavier containerized workloads. |
