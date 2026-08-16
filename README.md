# void_post_installer

A modular post-installation and desktop management suite for Void Linux, featuring an interactive `dialog` menu, extensive CLI flags, and seamless integration with [`voidPM`](https://github.com/soltros/voidPM) (`vpm`).

## Features

- **Desktop Environments**: Install or swap between 10 DEs (KDE Plasma 6, GNOME, XFCE 4, Cinnamon, MATE, LXQt, LXDE, Budgie, Sway, Enlightenment).
- **Desktop Swapping**: Automatically purges current DE packages and unneeded dependencies before installing the new environment.
- **Barebones Reset**: Purge installed DEs, desktop applications, Flatpaks, extra daemons, and orphaned dependencies back to a minimal Void `base-system`.
- **GPU Drivers & Acceleration**: Auto-detects hardware and installs drivers for AMD, Intel (with `intel-ucode` microcode), and NVIDIA (with DRM modesetting and dracut hooks).
- **Audio Setup**: PipeWire and WirePlumber with PulseAudio, ALSA, and JACK compatibility plus realtime audio privileges (`rtkit`).
- **Void Power-User Suite**: Optional installation of `xtools`, `vsv`, `octoxbps`, `btop`, `fzf`, `ripgrep`, `fd`, `bat`, `eza`, `duf`, `tldr`, and `jq`.
- **Package Manager Helper**: Automatic download, verification, and installation of the latest `voidPM` (`vpm` / `voidpm`) binary directly from GitHub.
- **System Daemons & Services**:
  - **ZRAM Compressed Swap**: Automated swap configuration via `zramen` runit daemon and kernel module loading.
  - **NTP Time Sync**: Reliable time synchronization with `openntpd` configured for `pool.ntp.org`.
  - **Power Management**: `power-profiles-daemon` for adaptive performance/battery profiles on laptops and desktops.
  - **SSD TRIM**: Weekly automated `fstrim` maintenance cron job.
  - **Firmware Updates**: `fwupd` daemon integration for LVFS hardware firmware updates.
  - **Locale Generation**: System-wide `en_US.UTF-8` locale configuration in `libc-locales` and `locale.conf`.
  - **System Logging**: `socklog-void` (`socklog-unix`, `nanoklogd`) for clean runit system logging and user group permissions.
- **Gaming Stack**: Steam, Wine, Lutris, GameMode, MangoHud, ProtonTricks, and kernel sysctl/limit performance tweaks.
- **Flatpak Integration**: Batch installs Flatpaks and synchronizes host GTK/Qt themes and system fonts.
- **Shell & Theming**: Zsh configuration with Oh My Zsh, Starship prompt, modern tool aliases, and system-wide Catppuccin theme suite.

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

Running `./run.sh` without flags launches the interactive `dialog` checklist menu.

## Command-Line Usage

### View Available Flags & Help
```bash
./run.sh --help
```

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

### Full Recommended Setup
```bash
sudo ./run.sh --all
```

### System Reset / Fresh Start
```bash
sudo ./run.sh --fresh-start
```

### Specific Modules & System Tweaks
```bash
sudo ./run.sh --repos --vpm
sudo ./run.sh --gpu-amd
sudo ./run.sh --gpu-intel
sudo ./run.sh --gpu-nvidia
sudo ./run.sh --audio --realtime-audio
sudo ./run.sh --zram --time-sync --power --trim --fwupd --locale
sudo ./run.sh --void-tools
sudo ./run.sh --apps --gaming --flatpaks --flatpak-themes
sudo ./run.sh --zsh --catppuccin
sudo ./run.sh --maintenance
```

## Module Reference

| Task ID | CLI Flag | Description |
| :--- | :--- | :--- |
| `REPOS` | `--repos` | Enable Multilib & Non-Free repositories |
| `VPM` | `--vpm` | Install or force-update `voidPM` (`vpm` / `voidpm`) helper binary |
| `GPU_AMD` | `--gpu-amd` | AMD GPU drivers, Mesa VA-API, and AMD firmware |
| `GPU_INTEL` | `--gpu-intel` | Intel GPU drivers, iHD VA-API, and CPU microcode |
| `GPU_NVIDIA` | `--gpu-nvidia` | NVIDIA proprietary drivers, DKMS, and DRM modesetting |
| `PORTALS` | `--portals` | XDG Desktop Portals, D-Bus, elogind, NetworkManager, BlueZ, Avahi |
| `AUDIO` | `--audio` | PipeWire audio suite, WirePlumber, ALSA, PulseAudio & JACK wrappers |
| `AUDIO_REALTIME`| `--realtime-audio` | Realtime audio priority (`rtkit`) and low-latency audio group permissions |
| `KDE` / `GNOME` / `XFCE` etc. | `--kde`, `--gnome`, etc. | Complete Desktop Environment & Display Manager installation |
| `SWAP_*` | `--swap-to-<de>` | Purge active DEs and switch to chosen Desktop Environment |
| `PURGE_BAREBONES` | `--barebones`, `--fresh-start` | Reset system back to minimal Void `base-system` |
| `VOID_TOOLS` | `--void-tools` | Void Linux power-user suite (`xtools`, `vsv`, `octoxbps`, `btop`, `fzf`, etc.) |
| `APPS` | `--apps` | Core desktop applications (VLC, OBS, VSCode, LibreOffice, GIMP, Krita, etc.) |
| `GAMING` | `--gaming` | Steam, Wine, Lutris, GameMode, MangoHud, ProtonTricks, sysctl tweaks |
| `FLATPAKS` | `--flatpaks` | Curated Flatpak applications (Discord, Bitwarden, Obsidian, etc.) |
| `FLATPAK_THEMES` | `--flatpak-themes` | Synchronize host GTK/Qt themes and system fonts to Flatpaks |
| `TAILSCALE` | `--tailscale` | Tailscale Mesh VPN daemon and client |
| `TIME_SYNC` | `--time-sync` | NTP time synchronization (`openntpd`) configured for `pool.ntp.org` |
| `POWER` | `--power` | Power profiles daemon (`power-profiles-daemon`) |
| `TRIM` | `--trim` | Periodic weekly SSD TRIM maintenance cron job (`fstrim`) |
| `FWUPD` | `--fwupd` | Firmware update daemon (`fwupd`) for LVFS firmware management |
| `LOCALE` | `--locale` | Generate and set system locale (`en_US.UTF-8`) |
| `ZRAM` | `--zram` | ZRAM compressed swap management via `zramen` runit service |
| `FONTS` | `--fonts` | System TrueType font collection (Noto & Liberation) |
| `ZSH` | `--zsh` | Zsh shell setup with Oh My Zsh, Starship prompt, and aliases |
| `CATPPUCCIN` | `--catppuccin` | Universal Catppuccin GTK/Qt/KDE themes, icons, and wallpapers |
| `SESSION_CONFIG`| `--session-config` | Auto-configure default user session presets |
| `MAINTENANCE` | `--maintenance` | One-touch maintenance (`vpm update`, `clean`, `vkpurge`, Flatpak update) |
| `SERVICES` | `--services` | Enable runit system daemons, `socklog-void` logging, and user group setup |

## License

GNU General Public License v3.0 ([LICENSE](LICENSE)).
