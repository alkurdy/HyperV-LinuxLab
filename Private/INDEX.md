# Private Directory: Internal Helper Functions

> **Directory:** `C:\Users\alkur\OneDrive\Documents\HyperV-LinuxLab\Private`  
> **Master Index:** 🧭 [INDEX.md](../INDEX.md)  
> **Workspace Rules:** 📋 [GEMINI.md](../GEMINI.md)  
> **Agent Directives:** 🤖 [AGENT.md](../AGENT.md)  
> **Skill:** 📁 [hyperv-lab-mentor](~/.gemini/config/skills/hyperv-lab-mentor/SKILL.md)  

---

## 🔒 Internal Module Engine Functions

These functions provide underlying platform plumbing for the public module cmdlets:
- `Assert-Administrator.ps1` — Enforces elevated privileges before WMI/Hyper-V calls.
- `Assert-LabDiskSpace.ps1` — Validates host volume capacity before disk provisioning.
- `New-ISO9660Image.ps1` — Programmatic CD-ROM image creator for Cloud-Init metadata injection.
- `Get-LabDefaultSwitch.ps1` / `Get-LabVMIPAddress.ps1` — Network adapter and IP resolution.
- `Resolve-LabProfile.ps1` — Parses JSON configuration profiles into VM memory/CPU objects.
- `Get-LabVMMetadata.ps1` / `Set-LabVMMetadata.ps1` — Attaches lab tracking tags to Hyper-V VMs.
