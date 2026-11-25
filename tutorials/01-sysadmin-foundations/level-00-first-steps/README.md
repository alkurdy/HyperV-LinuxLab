# Level 00: Linux First Steps (Windows-to-Linux Orientation)

> **[Tier 1: Sysadmin Foundations](../README.md)** • Zero-Friction Orientation for First-Time Linux Users Coming from Windows.

---

## Objective
Remove the intimidation of a blinking Linux cursor. By the end of this lab, you will decode the terminal prompt, navigate the single Linux directory tree without `C:\` drives, create/move/delete files safely, edit text in `nano`, use `sudo` ("Run as Administrator"), install software via `apt`, and find help on your own—preparing you to explore kernel internals in [Level 01](../level-01-mental-model-and-architecture/README.md).

---

## 1. The Terminal & Prompt Rosetta Stone

In Windows, most tasks start on a graphical Desktop (`explorer.exe`). On Linux servers, there is no GUI—you connect over SSH directly into a **shell** (usually **Bash**).

### Decoding the Prompt
When you log in, you see:
```text
labadmin@sysadmin-node:~$
```

| Token | Meaning | Windows Equivalent |
| :--- | :--- | :--- |
| **`labadmin`** | Your logged-in username | `whoami` (`Contoso\alice`) |
| **`sysadmin-node`** | Hostname (computer name) | Computer Name (`hostname`) |
| **`~`** | Current working directory (`~` = your home folder) | `C:\Users\labadmin` |
| **`$`** vs **`#`** | `$` = Standard user; `#` = `root` (full admin) | Standard Prompt vs Elevated Admin Prompt |

### Three Day-1 Windows-to-Linux Traps
1. **Case Sensitivity**: On Windows NTFS, `Notes.txt` and `notes.txt` are the **same file**. On Linux, they are **two completely separate files**. Always match capitalization.
2. **`Ctrl+C` Means KILL, Not Copy**: In Windows, `Ctrl+C` copies text. In a Linux terminal, `Ctrl+C` **terminates the running program** immediately. Use `Ctrl+Shift+C` (or right-click / mouse select) to copy.
3. **No `.exe` Needed**: Windows decides if a file can run by its extension (`.exe`, `.bat`, `.ps1`). Linux ignores extensions for execution—whether a file runs depends on its **execute permission bit** (covered in Level 02) and file header.

### Terminal Keyboard Superpowers
- **`Tab`**: Auto-completes commands, filenames, and folder paths. Hit `Tab` twice to list all matches.
- **`↑` / `↓`**: Scroll through previous commands.
- **`Ctrl+L`** (or `clear`): Clears the screen.
- **`Ctrl+C`**: Cancels a frozen or mistyped command line.

---

## 2. No `C:\` Drive: Navigating the Single Tree (`/`)

Windows separates storage by drive letters (`C:\`, `D:\`, `E:\`) using backslashes (`\`).

Linux has **zero drive letters**. Everything lives inside one unified tree starting at **`/`** (called **root**), separated by forward slashes (`/`):

```text
/  (The Root of Everything — similar to "This PC")
├── home/
│   └── labadmin/     (~  Your personal folder, like C:\Users\labadmin)
├── etc/              (Configuration files — plain text instead of Windows Registry)
├── var/
│   └── log/          (System & app logs — like Windows Event Viewer)
├── bin/  &  usr/bin/ (Executable programs — like C:\Windows\System32 & Program Files)
└── tmp/              (Temporary scratch files — like C:\Windows\Temp)
```

### Core Navigation Commands
| Command | Action | Windows CMD / Explorer Equivalent |
| :--- | :--- | :--- |
| **`pwd`** | Print Working Directory ("Where am I?") | Looking at the Explorer address bar (`cd` with no args) |
| **`ls`** | List files in current folder | `dir` |
| **`ls -l`** | Long list (permissions, owner, size, date) | Explorer "Details" view |
| **`ls -a`** | Show hidden files (names starting with `.`) | Explorer "Show hidden items" |
| **`ls -lh`** | Long list with human-readable sizes (`K`, `M`, `G`) | Details view with KB/MB |
| **`cd /etc`** | Jump to exact **absolute** path (starts with `/`) | `cd C:\Windows\System32` |
| **`cd docs`** | Enter subfolder (**relative** to current folder) | Double-clicking a folder |
| **`cd ..`** | Go up one folder level | Clicking the "Up" arrow (`↑`) |
| **`cd ~`** (or `cd`) | Jump straight back to your home folder | Opening `C:\Users\labadmin` |
| **`cd -`** | Toggle back to the previous folder you visited | Explorer "Back" button |

> [!NOTE]
> **Hidden Files in Linux**: Windows hides files using a hidden file attribute bit. Linux hides any file or directory whose name starts with a dot (e.g., `.bashrc`, `.ssh`). Run `ls -la` to reveal them.

---

## 3. File & Folder Operations (CLI File Explorer)

| Command | Action | Example | Windows Equivalent |
| :--- | :--- | :--- | :--- |
| **`mkdir -p`** | Create folder (and missing parent folders) | `mkdir -p ~/sandbox/configs` | New Folder |
| **`touch`** | Create an empty file (or update timestamp) | `touch ~/sandbox/notes.txt` | Right-click -> New Text Document |
| **`cp`** | Copy a file (`cp -r` for folders) | `cp /etc/hostname ~/sandbox/` | `Ctrl+C` -> `Ctrl+V` |
| **`mv`** | Move a file OR rename it | `mv notes.txt done.txt` | `Ctrl+X` -> `Ctrl+V` or `F2` Rename |
| **`rm`** | Delete a file (`rm -r` for folders) | `rm ~/sandbox/old.txt` | `Shift+Delete` (Permanent!) |
| **`cat`** | Print entire short file to screen | `cat /etc/hostname` | Opening small file in Notepad |
| **`less`** | Scroll through long files safely (`q` to quit) | `less /etc/passwd` | Reading long log file with scrollbar |

> [!CAUTION]
> **No Recycle Bin**: `rm` permanently unlinks the file immediately. When learning, use `rm -i` (interactive confirmation prompt) and **never** run `rm -rf /` or `rm -rf *` blindly.

---

## 4. Editing Text Without Panicking (`nano`)

On Linux servers, configuration is stored in plain-text files inside `/etc/`. While veteran engineers often use `vim`, **`nano`** works just like Windows Notepad in the terminal.

```bash
nano ~/sandbox/notes.txt
```

### The Only 4 Shortcuts You Need in `nano`:
The bottom bar shows `^` which means the **`Ctrl`** key:
1. Type your text normally.
2. **`Ctrl+O`** then **`Enter`**: Save ("Write Out").
3. **`Ctrl+X`**: Exit `nano`.
4. **`Ctrl+W`**: Search ("Where Is") inside the file.

> [!TIP]
> **Emergency `vi` / `vim` Escape Hatch**: If you ever accidentally open `vi` or `vim` and typing does nothing (or beeps), do not close your SSH window! Press **`Esc`**, type **`:q!`**, and hit **`Enter`** to quit immediately without saving.

---

## 5. Admin Power (`sudo`), Packages (`apt`), & Self-Help

### Privilege Escalation (`sudo`)
By default, you work as standard user `labadmin` (`$`) so a typo cannot destroy the OS.
When you need Administrator rights (like modifying `/etc/` or installing software), prefix the command with **`sudo`** ("SuperUser DO"):
- **Windows Equivalent**: Right-click -> *Run as Administrator* (UAC elevation).

### Installing Software (`apt`)
Instead of browsing websites for `.exe` or `.msi` installers, Ubuntu pulls signed packages from central repositories (similar to `winget`):
```bash
# 1. Refresh the local package catalog (always run first)
sudo apt update

# 2. Install a package (-y skips the "Do you want to continue? [Y/n]" prompt)
sudo apt install -y tree
```

### Built-In Help (`--help` & `man`)
Never memorize every flag. Ask Linux directly:
- **Quick Cheat Sheet**: `ls --help` (prints all flags in seconds).
- **Full Manual Page**: `man ls` (opens documentation viewer; press **`/`** to search, **`n`** for next match, **`q`** to quit).

---

## Hands-On Lab: Your First 15 Minutes on `sysadmin-node`

Ensure your lab VM is running from host PowerShell:
```powershell
Import-Module .\HyperV-LinuxLab.psd1
Get-LabVM -Name "sysadmin-node"
```

Connect via SSH (use the IP and password shown by `Get-LabVM`):
```powershell
ssh labadmin@<VM_IP>
```

---

## Part A: Guided Orientation Drill (Action & Reaction)

### 1. Check Identity, Location & Tree Navigation
- **Action**:
  ```bash
  whoami
  pwd
  ls -la ~
  cd /etc
  pwd
  cd -
  ```
- **System Reaction**:
  - `whoami` prints `labadmin`. `pwd` confirms `/home/labadmin`.
  - `ls -la ~` reveals hidden dotfiles (`.bashrc`, `.profile`, `.ssh`).
  - `cd /etc` moves into the system configuration tree; `cd -` toggles right back to `/home/labadmin`.

### 2. Build a Safe Sandbox & Copy/Move Files
- **Action**:
  ```bash
  mkdir -p ~/sandbox/configs ~/sandbox/archive
  cp /etc/hostname ~/sandbox/configs/
  ls -l ~/sandbox/configs/
  ```
- **System Reaction**:
  - `mkdir -p` creates both `~/sandbox` and `configs` in one step without erroring on missing parents.
  - `cp` duplicates `/etc/hostname` (a read-only system file for normal users) into your home sandbox where you own it.

### 3. Edit Text with `nano` & Read Safely
- **Action**:
  ```bash
  nano ~/sandbox/notes.txt
  ```
  Type `First Linux lab note`, press **`Ctrl+O`**, press **`Enter`**, then press **`Ctrl+X`**.
  Now inspect and rename it:
  ```bash
  cat ~/sandbox/notes.txt
  mv ~/sandbox/notes.txt ~/sandbox/archive/done.txt
  ls -l ~/sandbox/archive/
  ```
- **System Reaction**:
  - `cat` outputs your saved text directly to the terminal.
  - `mv` simultaneously moved the file into `archive/` and renamed it from `notes.txt` to `done.txt`.

### 4. Use `sudo`, `apt`, and `man`
- **Action**:
  ```bash
  sudo apt update && sudo apt install -y tree
  tree ~/sandbox
  ```
- **System Reaction**:
  - `sudo` temporarily elevates your privilege to `root` to update APT's package index and install `tree`.
  - `tree ~/sandbox` renders a clean ASCII folder tree showing `archive/done.txt` and `configs/hostname`.

---

## Part B: Solo Orientation Drill (Unguided Practice)

Complete this clean-up and mini-challenge inside `~/sandbox` without copying commands:

1. **Acceptance Criteria**:
   - Create a directory `~/sandbox/system-info`.
   - Copy `/etc/os-release` into `~/sandbox/system-info/os.txt` (renaming it during or after the copy).
   - View `~/sandbox/system-info/os.txt` using `less` and quit cleanly (`q`).
   - Delete `~/sandbox/archive/done.txt` safely using `rm -i` (confirm with `y`).
   - Run `man tree` briefly, search for `-L`, and quit (`q`).
   - Clean up the entire practice workspace when done: `rm -r ~/sandbox` (double-check your path before pressing `Enter`!).

2. **Self-Verification** (run before deleting `~/sandbox`):
   ```bash
   test -f ~/sandbox/system-info/os.txt && ! test -e ~/sandbox/archive/done.txt && echo "[PASS] Orientation drill verified!" || echo "[FAIL] Check criteria above."
   ```

---

## What Comes Next?
You now know how to log in, navigate `/`, manage files, edit text, use `sudo`, and install packages.
In **[Level 01: The Sysadmin Mental Model Transition](../level-01-mental-model-and-architecture/README.md)**, we look **under the hood** at *how* those commands actually execute—Kernel vs. User space, `/proc` and `/sys` virtual filesystems, process memory, and I/O stream piping!

---

### Navigation
| [Tier 1: Sysadmin Foundations](../README.md) | [Tutorials Hub](../../INDEX.md) | [Next: Level 01: Mental Model & Architecture →](../level-01-mental-model-and-architecture/README.md) |
| :--- | :---: | ---: |
