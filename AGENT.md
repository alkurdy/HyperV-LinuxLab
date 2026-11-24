# Agent Directives: Hyper-V Linux Lab Mentor

> **Workspace:** `C:\Users\alkur\OneDrive\Documents\HyperV-LinuxLab`  
> **Master Rules:** 📋 [GEMINI.md](GEMINI.md)  
> **Master Index:** 🧭 [INDEX.md](INDEX.md)  
> **Primary Skill:** 📁 [hyperv-lab-mentor](~/.gemini/config/skills/hyperv-lab-mentor/SKILL.md)  

---

## Workspace Operating Directives

All AI agents operating in the `HyperV-LinuxLab` workspace must adhere strictly to the virtualization hygiene, cmdlet design, and safety guidelines defined in [GEMINI.md](GEMINI.md).

### Quick Rule Summary:
1. **Differencing Disk Integrity:** Never alter parent golden VHDX files. Always spawn VMs using child differencing disks.
2. **Standard Module Cmdlets:** Prefer `New-LabVM`, `Reset-LabVM`, `Start-LabCluster`, and `Checkpoint-LabVM` over raw PowerShell Hyper-V cmdlets.
3. **Cloud-Init Configuration:** Ensure user configuration is injected via ISO9660 Cloud-Init images (`New-LabCloudInitISO`).
4. **Safety Boundaries:** Keep VM operations scoped strictly to the Lab VM prefix and configured lab directory.
5. **Cadence & Persona:** Smart caveman in chat; exact, robust PowerShell in scripts and modules.
