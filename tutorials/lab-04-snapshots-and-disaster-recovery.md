# Lab Tutorial 04: Snapshots, Break-Fix Drills & Instant Disaster Recovery

> **[HyperV-LinuxLab Tutorials Hub](README.md)** • **Track 1: Hands-On Linux Lab** • [← Previous: Processes & Networking](lab-03-processes-systemd-and-networking.md) • [📑 Index](README.md) • [Next: Multi-Distro Clusters →](lab-05-multi-distro-clusters.md)

---

Now that we've got our Linux system running and mastered the basics, **let's break things on purpose.**

In physical environments or slow clouds, breaking an operating system means a 30-minute reinstallation ordeal. In `HyperV-LinuxLab`, because every VM runs on a child differencing VHDX attached to a read-only golden master, you can execute catastrophic commands fearlessly and recover in **2 to 3 seconds**.

---

## 🧭 In This Tutorial:
1. [The Fearless Experimentation Mental Model](#1-the-fearless-experimentation-mental-model)
2. [Drill 1: Taking a Checkpoint (`Checkpoint-LabVM`)](#drill-1-taking-a-checkpoint)
3. [Drill 2: Simulating Accidental Data Loss](#drill-2-simulating-accidental-data-loss)
4. [Drill 3: The 2-Second Snapshot Restore (`Restore-LabVM`)](#drill-3-the-2-second-snapshot-restore)
5. [Drill 4: Catastrophic OS Destruction](#drill-4-catastrophic-os-destruction)
6. [Drill 5: The 3-Second Factory Wipe (`Reset-LabVM`)](#drill-5-the-3-second-factory-wipe)
7. [Drill 6: Clean Lab Teardown (`Remove-LabVM`)](#drill-6-clean-lab-teardown)

---

## 1. The Fearless Experimentation Mental Model

So you want to test risky kernel tunings, broken system configurations, or destructive scripts without fear?

```text
[ Golden Base Image: ubuntu-24.04.vhdx ] (LOCKED READ-ONLY)
                   ▲
                   │ Read pointer
[ Child Differencing Disk: linux-sandbox.vhdx ] (All writes stay here: < 50MB)
```

Because all writes go exclusively to the small child differencing disk, the master base image can never be corrupted. You can rollback or discard the child disk anytime.

---

## Drill 1: Taking a Checkpoint

First, let's create a sample project inside your running Linux VM:

```powershell
ssh labadmin@<Your-VM-IP>
```
```bash
# Inside Linux:
mkdir -p ~/production-app && echo "Mission-Critical Database Data v1.0" > ~/production-app/db.data
exit
```

Now, switch back to your elevated Windows PowerShell window and freeze this exact point in time:

```powershell
Checkpoint-LabVM -Name "linux-sandbox" -SnapshotName "pre-incident"
```
Hyper-V pauses the guest memory state, forks the differencing chain, and completes the snapshot in less than 2 seconds.

---

## Drill 2: Simulating Accidental Data Loss

Now that our snapshot is taken, let's simulate an accidental deletion incident:

```powershell
ssh labadmin@<Your-VM-IP>
```
```bash
# Accurately simulate an accidental rm -rf:
rm -rf ~/production-app
ls ~/production-app
# Output: ls: cannot access '/home/labadmin/production-app': No such file or directory
exit
```

Your data is gone, and in a traditional environment, you would be looking for backups.

---

## Drill 3: The 2-Second Snapshot Restore

Now watch how fast you can roll back the clock. In your Windows PowerShell prompt:

```powershell
Restore-LabVM -Name "linux-sandbox" -Force
```

Hyper-V reverts the differencing pointer back to the `pre-incident` branch.

### Verify Data Restored:
```powershell
ssh labadmin@<Your-VM-IP>
```
```bash
cat ~/production-app/db.data
# Output: Mission-Critical Database Data v1.0
exit
```
Your entire filesystem state is restored exactly as it was.

---

## Drill 4: Catastrophic OS Destruction

Now, let's push things to the extreme. What happens if you accidentally run a command that nukes critical OS plumbing like networking and `systemd`?

```powershell
ssh labadmin@<Your-VM-IP>
```
```bash
# Obliterate systemd and networking configuration:
sudo rm -rf /etc/systemd /etc/netplan /etc/network
# Force an immediate kernel crash / reboot:
sudo reboot -f
```

Your SSH connection drops instantly. The VM will fail to boot or boot into a completely broken, unmanageable state.

---

## Drill 5: The 3-Second Factory Wipe

Instead of downloading an ISO and waiting 20 minutes to reinstall Ubuntu:

```powershell
Reset-LabVM -Name "linux-sandbox" -Force
```

### What Happens Behind the Scenes:
1. `Stop-VM -TurnOff` terminates the broken VM process immediately.
2. The corrupt child differencing VHDX is unlinked and deleted.
3. A brand new, pristine child differencing VHDX (< 4 MB) is spawned from the golden master image.
4. The VM is booted up clean with fresh Cloud-Init credentials.

In **under 3 seconds**, you have a fresh out-of-the-box Ubuntu 24.04 server ready for login.

---

## Drill 6: Clean Lab Teardown

When you are done experimenting for the day, clean up all hypervisor registrations and reclaimed disk space:

```powershell
Remove-LabVM -Name "linux-sandbox" -Force
```

All differencing disks, metadata logs, and temporary virtual ISOs are completely erased. Your host storage is restored to zero overhead.

---

### 🧭 Navigation
| [← Previous: Processes & Networking](lab-03-processes-systemd-and-networking.md) | [📑 All Tutorials](README.md) | [Next: Lab Tutorial 05 - Multi-Distro Clusters →](lab-05-multi-distro-clusters.md) |
| :--- | :---: | ---: |

*(Under the hood: Want to see the VHDX block allocation tables and parent-child pointer chains? Read [Hyper-V Tutorial 04: Storage & Differencing Disks](hyperv-04-storage-and-differencing-disks.md)).*
