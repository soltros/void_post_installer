# void_post_installer

A modular post-installation and desktop management script for Void Linux, featuring an interactive `dialog` menu, CLI flags, and integration with `voidPM` (`vpm`).

## Features

- **Desktop Environments**: Install or swap between 10 DEs (KDE Plasma, GNOME, XFCE, Cinnamon, MATE, LXQt, LXDE, Budgie, Sway, Enlightenment).
- **Desktop Swapping**: Automatically purges current DE packages and unneeded dependencies before installing the new environment.
- **Barebones Reset**: Purge installed DEs, desktop applications, flatpaks, and extra services back to a minimal Void `base-system`.
- **GPU Drivers & Acceleration**: Auto-detects hardware and installs drivers for AMD, Intel (with `intel-ucode` microcode), and NVIDIA (with DRM modesetting and dracut hooks).
- **Audio Setup**: PipeWire and WirePlumber with PulseAudio, ALSA, and JACK compatibility plus realtime audio privileges.
- **Void Power-User Tools**: Optional installation of `xtools`, `vsv`, `octoxbps`, `btop`, `fzf`, `ripgrep`, `fd`, `bat`, `eza`, `duf`, `tldr`, and `jq`.
- **Gaming Stack**: Steam, Wine, Lutris, GameMode, MangoHud, ProtonTricks, and kernel sysctl/limit tweaks.
- **Flatpak Integration**: Batch installs Flatpaks and syncs host GTK/Qt themes and system fonts.
- **Shell & Theming**: Zsh configuration with Oh My Zsh, Starship prompt, custom aliases, and system-wide Catppuccin theme suite.
- **System Logging**: Configures `socklog-void` (`socklog-unix`, `nanoklogd`) for runit system logging.

## Prerequisites

Requires `dialog` and `git`:

```bash
sudo xbps-install -Sy dialog git
```

## Quick Start

```bash
git clone https://github.com/soltros/void_post_installer.git
cd void_post_installer
chmod +x run.sh
sudo ./run.sh
```

Running `./run.sh` without flags launches the interactive `dialog` menu.

## Command-Line Usage

### Install a Desktop Environment
```bash
sudo ./run.sh --kde
sudo ./run.sh --gnome
sudo ./run.sh --xfce
sudo ./run.sh --cinnamon
sudo ./run.sh --mate
sudo ./run.sh --lxqt
sudo ./run.sh --sway
```

### Swap Desktop Environments
```bash
sudo ./run.sh --swap-to-kde
sudo ./run.sh --swap-to-gnome
sudo ./run.sh --swap-to-xfce
```

### System Reset / Fresh Start
```bash
sudo ./run.sh --fresh-start
```

### Modules & Tweaks
```bash
sudo ./run.sh --gpu-amd
sudo ./run.sh --gpu-intel
sudo ./run.sh --gpu-nvidia
sudo ./run.sh --void-tools
sudo ./run.sh --apps --gaming
sudo ./run.sh --catppuccin
sudo ./run.sh --maintenance
```

## Module Reference

| Task ID | Description |
| :--- | :--- |
| `REPOS` | Enable Multilib & Non-Free repositories |
| `GPU_AMD` / `GPU_INTEL` / `GPU_NVIDIA` | GPU drivers, VA-API video acceleration, CPU microcode, and initramfs hooks |
| `PORTALS` | XDG Desktop Portals, D-Bus, elogind, NetworkManager, BlueZ, Avahi |
| `AUDIO` / `AUDIO_REALTIME` | PipeWire audio suite, WirePlumber, `rtkit` realtime permissions |
| `KDE`, `GNOME`, `XFCE`, `CINNAMON`, etc. | Complete Desktop Environment & Display Manager installation |
| `SWAP_*` | Purge active DEs and switch to chosen Desktop Environment |
| `PURGE_BAREBONES` | Reset system back to minimal `base-system` |
| `VOID_TOOLS` | Void Linux power-user tools (`xtools`, `vsv`, `octoxbps`, `btop`, `fzf`, etc.) |
| `APPS` | Core desktop applications (VLC, OBS, VSCode, LibreOffice, GIMP, Krita, etc.) |
| `GAMING` | Steam, Wine, Lutris, GameMode, MangoHud, ProtonTricks |
| `FLATPAKS` / `FLATPAK_THEMES` | Flatpak application suite and theme/font sync |
| `CATPPUCCIN` | Universal Catppuccin GTK/Qt/KDE themes, icons, and wallpapers |
| `ZSH` | Zsh shell setup with Oh My Zsh, Starship prompt, and aliases |
| `SERVICES` | Runit daemons setup, `socklog-void` logging, and user groups |

## License

GNU General Public License v3.0 ([LICENSE](LICENSE)).
