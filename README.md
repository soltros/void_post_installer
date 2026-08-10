# Modular Void Linux Desktop & Gaming Post-Installer

[![Void Linux](https://img.shields.io/badge/Void_Linux-474747?style=for-the-badge&logo=voidlinux&logoColor=white)](https://voidlinux.org/)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg?style=for-the-badge)](LICENSE)
[![voidPM Integrated](https://img.shields.io/badge/vpm-Integrated-success?style=for-the-badge)](https://github.com/soltros/voidPM)

An automated, modular, interactive post-installation setup script for **Void Linux**, powered by an interactive `dialog` menu and integrated with **voidPM (`vpm`)**.

Whether you are configuring a fresh Void Linux install, setting up a high-performance gaming rig, swapping desktop environments, or resetting back to a barebones base system, this installer handles graphics drivers, audio servers, microcode, desktop environments, flatpaks, and system optimizations with zero friction.

---

## 🌟 Key Features

- 🖥️ **Multi-DE Installation & Seamless Swapping**:
  - Full support for 10 Desktop Environments: **KDE Plasma 6**, **GNOME 48**, **XFCE 4.20**, **Cinnamon**, **MATE**, **LXQt 2.4**, **LXDE**, **Budgie**, **Sway (Wayland)**, and **Enlightenment (E25)**.
  - Dedicated **DE Swapper** modules that purge current desktop environments and clean up unneeded dependencies before installing the new session.
- 🎮 **Gaming & Performance Stack**:
  - Installs Steam, 32-bit Vulkan/Mesa libraries, Wine, Lutris, GameMode, MangoHud, ProtonTricks, and Winetricks.
  - Applies essential gaming kernel tweaks (`vm.max_map_count`, `fs.file-max`, elevated process limits).
- 🚀 **Hardware Acceleration & GPU Driver Auto-Detection**:
  - **AMD GPU**: Mesa VA-API, VDPAU, `vulkan-loader`, and `mesa-vulkan-radeon` (32-bit & 64-bit).
  - **Intel GPU**: Intel iHD driver (`intel-media-driver`), `intel-ucode` CPU microcode patches, and `dracut` initramfs hooks.
  - **NVIDIA GPU**: Proprietary NVIDIA drivers, DKMS, VA-API acceleration, `nvidia-drm.modeset=1` DRM KMS configuration, and dracut initramfs integration for Wayland & Sway compatibility.
- 🧹 **Fresh Start / Barebones Reset**:
  - Comprehensive reset module (`--barebones` / `--fresh-start`) to strip down all installed DEs, desktop applications, flatpaks, and extra services back to a clean Void Linux `base-system`.
- 🔊 **PipeWire Realtime Low-Latency Audio**:
  - Automated PipeWire and WirePlumber configuration with PulseAudio, ALSA, and JACK shims, realtime audio group privileges, and `rtkit` daemon setup.
- 🪵 **System Logging & Service Management**:
  - Installs and configures `socklog-void` (`socklog-unix`, `nanoklogd`) for native runit logging with user log permissions.
- 🎨 **Catppuccin Universal Theme Suite**:
  - System-wide Catppuccin theme suite (GTK themes, KDE Plasma themes, Kvantum, Konsole, Papirus icons, cursor themes, wallpapers) and Flatpak theme/font synchronization.
- 🐚 **Zsh & Starship Shell Suite**:
  - Zsh shell configuration with Oh My Zsh, `zsh-autosuggestions`, `zsh-syntax-highlighting`, Starship prompt, and convenient `vpm` aliases.

---

## 📋 Prerequisites

Running `run.sh` requires root privileges and the `dialog` package:

```bash
# Install dialog via xbps if not already present
sudo xbps-install -Sy dialog git
```

---

## 🚀 Quick Start

1. **Clone the repository**:
   ```bash
   git clone https://github.com/soltros/void_post_installer.git
   cd void_post_installer
   ```

2. **Make the script executable & run**:
   ```bash
   chmod +x run.sh
   sudo ./run.sh
   ```

By default, launching `./run.sh` without arguments opens an interactive TUI checklist menu powered by `dialog`.

---

## 💻 Command-Line Interface (CLI) Usage

You can automate specific tasks or run headless installations using CLI flags:

### Desktop Environment Installation
```bash
sudo ./run.sh --kde            # Install KDE Plasma 6 & SDDM
sudo ./run.sh --gnome          # Install GNOME 48 & GDM
sudo ./run.sh --xfce           # Install XFCE 4.20 & LightDM
sudo ./run.sh --cinnamon       # Install Cinnamon & LightDM
sudo ./run.sh --mate           # Install MATE & LightDM
sudo ./run.sh --lxqt           # Install LXQt & SDDM
sudo ./run.sh --sway           # Install Sway Wayland & LightDM
```

### Desktop Environment Swapping
```bash
sudo ./run.sh --swap-to-kde    # Purge current DEs & switch to KDE Plasma 6
sudo ./run.sh --swap-to-gnome  # Purge current DEs & switch to GNOME 48
sudo ./run.sh --swap-to-xfce   # Purge current DEs & switch to XFCE
```

### System Reset / Fresh Start
```bash
sudo ./run.sh --fresh-start    # Purge all DEs, apps, flatpaks down to base-system
```

### Hardware & Applications
```bash
sudo ./run.sh --gpu-amd        # Install AMD drivers & Mesa VA-API
sudo ./run.sh --gpu-intel      # Install Intel drivers & intel-ucode microcode
sudo ./run.sh --gpu-nvidia     # Install NVIDIA drivers & DRM modesetting
sudo ./run.sh --apps --gaming  # Install Core Desktop Apps & Gaming suite
sudo ./run.sh --catppuccin     # Install Catppuccin Theme Suite
sudo ./run.sh --maintenance    # One-touch system update, kernel purge (vkpurge), & orphan clean
```

---

## ⚙️ Module Reference

| Task ID | Description |
| :--- | :--- |
| `REPOS` | Enable Multilib & Non-Free repositories |
| `GPU_AMD` / `GPU_INTEL` / `GPU_NVIDIA` | GPU drivers, VA-API video acceleration, CPU microcode, and initramfs hooks |
| `PORTALS` | XDG Desktop Portals, D-Bus, elogind, NetworkManager, BlueZ, Avahi |
| `AUDIO` / `AUDIO_REALTIME` | PipeWire audio suite, WirePlumber, `rtkit` realtime permissions |
| `KDE`, `GNOME`, `XFCE`, `CINNAMON`, etc. | Complete Desktop Environment & Display Manager installation |
| `SWAP_*` | Purge active DEs and switch to chosen Desktop Environment |
| `PURGE_BAREBONES` | Fresh Start: Purge packages and DEs back to `base-system` |
| `APPS` | Core desktop applications (VLC, OBS, VSCode, LibreOffice, GIMP, Krita, etc.) |
| `GAMING` | Steam, Wine, Lutris, GameMode, MangoHud, ProtonTricks |
| `FLATPAKS` / `FLATPAK_THEMES` | Flatpak application suite and host theme/font synchronization |
| `CATPPUCCIN` | Universal Catppuccin GTK/Qt/KDE themes, icons, and wallpapers |
| `ZSH` | Zsh shell with Oh My Zsh, Starship prompt, and `vpm` aliases |
| `SERVICES` | Runit daemons setup, `socklog-void` logging, and user group assignments |

---

## 📄 License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
