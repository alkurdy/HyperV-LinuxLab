# Track 1: Hands-On Linux Lab Curriculum

> **[Tutorials Hub](../README.md)** • **Linux Lab Track** • [Switch to Hyper-V Internals Track →](../hyperv/README.md)

Welcome to the **Hands-On Linux Lab** track of the HyperV-LinuxLab curriculum.

This track is built for developers, DevOps engineers, and students who want a fast, reproducible sandbox to master native Linux system administration without the bloat of slow ISO installers or the emulation limits of Docker/WSL2.

---

## 🧭 Tutorial Directory

| # | Tutorial Folder | What You Will Learn | Est. Time |
| :---: | :--- | :--- | :---: |
| **01** | [**01-deployment-and-ssh**](01-deployment-and-ssh/README.md) | Single-command provisioning, host storage Scream test, SSH key auto-discovery, generated passphrases, and dual-auth login. | 10 min |
| **02** | [**02-linux-mental-model-and-filesystems**](02-linux-mental-model-and-filesystems/README.md) | User space vs kernel space, "Everything is a file", pseudo-filesystems (`/proc`, `/sys`), user permissions, `sudo`, and `strace`. | 15 min |
| **03** | [**03-processes-systemd-and-networking**](03-processes-systemd-and-networking/README.md) | PID 1 ancestry (`pstree`), `htop`, managing services with `systemctl`, log streaming with `journalctl`, Unix pipes, and `iproute2` (`ip`, `ss`). | 20 min |
| **04** | [**04-snapshots-and-disaster-recovery**](04-snapshots-and-disaster-recovery/README.md) | Fearless failure: checkpoints (`Checkpoint-LabVM`), 2-second rollbacks (`Restore-LabVM`), catastrophic OS destruction, and 3-second differencing resets (`Reset-LabVM`). | 15 min |
| **05** | [**05-multi-distro-clusters**](05-multi-distro-clusters/README.md) | Running Ubuntu 24.04, Debian 12, and AlmaLinux 9 side-by-side, cross-distro sudo (`sudo` vs `wheel`), cluster validation, and credential recall (`Get-LabVM`). | 20 min |

---

### 🧭 Navigation
| [← Back to Master Tutorials Hub](../README.md) | [Start Lab 01: Deployment & SSH →](01-deployment-and-ssh/README.md) |
| :--- | ---: |
