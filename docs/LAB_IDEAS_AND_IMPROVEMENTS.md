# HyperV-LinuxLab: Curriculum Feedback & Lab Expansion Backlog

This living backlog captures real-world friction, edge cases, and ideas for new hands-on labs discovered while running paired sessions with the **`hyperv-lab-mentor`**.

---

## 1. Active Lab Improvements & Clarifications Log

| Date | Target Tutorial | Observation / Friction Point | Action Taken |
| :--- | :--- | :--- | :--- |
| *Auto-logged* | `level-01-mental-model` | Learner clarified Monolithic vs Microkernel drivers | Added `modinfo hv_vmbus` driver inspection note |
| *Auto-logged* | `04-storage-and-differencing` | Child differencing disk parent-locator corruption risk | Added alert callout warning on parent VHDX read-only lock |

---

## 2. Proposed Future Labs & Scenarios

### Idea Backlog:
- [ ] **Lab Scenario: Simulated Split-Brain NAT Network Partition**
  - *Context*: Create an exercise where two lab VMs lose default gateway routing via an internal virtual switch, forcing the learner to diagnose route tables and ARP tables without hypervisor host connectivity.
- [ ] **Lab Scenario: Inode Starvation Without Disk Saturation**
  - *Context*: Script creating 1,000,000 0-byte files in `/var/spool` to trigger `No space left on device` while `df -h` shows 90% free space (`df -i` triage).
- [ ] **Lab Scenario: Systemd Unit Ordering Deadlock**
  - *Context*: Two custom services with circular `After=` and `Requires=` dependencies causing systemd startup stall.

---

## 3. How the Mentor Logs Here
When pairing:
1. If the learner asks a question that reveals a gap in the tutorial $\to$ update tutorial directly, then log in Section 1.
2. If an edge case or advanced question suggests a great new lab $\to$ append an actionable specification item to Section 2.
