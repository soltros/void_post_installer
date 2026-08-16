#!/usr/bin/env bash
set -eo pipefail

echo "========================================================"
echo " Modular Void Linux Desktop & Gaming Installer (dialog)"
echo " Integrated with voidPM (vpm) - Multi-DE Support"
echo "========================================================"

# Allow viewing usage without root privileges
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    print_usage() {
        cat << 'EOF'
Modular Void Linux Desktop & Gaming Installer (dialog & CLI)
Integrated with voidPM (vpm) - Multi-DE Support

Usage: run.sh [OPTIONS]

Options:
  --all                     Install recommended suite (repos, vpm, portals, audio, GNOME, void-tools,
                            apps, gaming, flatpaks, tailscale, time-sync, power, trim, fwupd, locale,
                            fonts, services)
  --gui, --dialog           Launch interactive dialog checklist menu (default when run without flags)
  --repos                   Enable Multilib & Non-Free repositories
  --vpm                     Download & install/update voidPM (vpm) binary to /usr/bin/vpm
  --gpu-amd                 Install AMD GPU drivers, Mesa VA-API, and firmware
  --gpu-intel               Install Intel GPU drivers, iHD VA-API, and microcode
  --gpu-nvidia              Install NVIDIA GPU proprietary drivers, DKMS, and DRM modesetting
  --portals                 Install XDG Desktop Portals & core daemons (D-Bus, elogind, NetworkManager)
  --audio                   Configure PipeWire audio suite & WirePlumber
  --realtime-audio          Configure PipeWire low-latency & rtkit realtime permissions
  --kde                     Install KDE Plasma 6 & SDDM
  --kde-tools               Install KDE CLI tools & XDG handlers
  --gnome                   Install GNOME Shell & GDM
  --xfce                    Install XFCE 4 & LightDM
  --cinnamon                Install Cinnamon Desktop & LightDM
  --mate                    Install MATE Desktop & LightDM
  --lxqt                    Install LXQt Desktop & SDDM
  --lxde                    Install LXDE Desktop & LightDM
  --budgie                  Install Budgie Desktop & LightDM
  --sway                    Install Sway Wayland & LightDM
  --enlightenment           Install Enlightenment (E25) & LightDM
  --hyprland                Install Hyprland Wayland Compositor & LightDM
  --swap-to-kde             Purge active DE and switch to KDE Plasma 6
  --swap-to-gnome           Purge active DE and switch to GNOME
  --swap-to-xfce            Purge active DE and switch to XFCE 4
  --swap-to-cinnamon        Purge active DE and switch to Cinnamon
  --swap-to-mate            Purge active DE and switch to MATE
  --swap-to-lxqt            Purge active DE and switch to LXQt
  --swap-to-lxde            Purge active DE and switch to LXDE
  --swap-to-budgie          Purge active DE and switch to Budgie
  --swap-to-sway            Purge active DE and switch to Sway
  --swap-to-enlightenment   Purge active DE and switch to Enlightenment
  --swap-to-hyprland        Purge active DE and switch to Hyprland
  --barebones, --fresh-start, --purge-to-barebones
                            Purge all packages and DEs down to base-system
  --void-tools, --community-tools
                            Install Void Linux community power-user suite (xtools, vsv, btop, fzf, etc.)
  --apps                    Install core desktop applications (VLC, OBS, VSCode, LibreOffice, GIMP, etc.)
  --gaming                  Install Steam, Wine, Lutris, GameMode, MangoHud & gaming sysctl tweaks
  --flatpaks                Install curated Flatpak application suite
  --flatpak-themes          Synchronize host GTK/Qt themes to Flatpaks
  --tailscale               Install Tailscale VPN
  --time-sync               Configure openntpd NTP time synchronization
  --power                   Configure power-profiles-daemon
  --trim                    Configure weekly periodic SSD TRIM cron job
  --fwupd                   Install fwupd firmware update daemon (LVFS)
  --locale                  Configure system locale (en_US.UTF-8)
  --zram                    Configure ZRAM compressed swap (zramen)
  --fonts                   Install TrueType fonts (Noto & Liberation)
  --zsh                     Configure Zsh with Oh My Zsh, Starship prompt & aliases
  --catppuccin              Install Catppuccin universal theme suite system-wide
  --hyprland-themes         Install popular Hyprland dotfile theme suite into user's ~/.config
  --hyprland-theme=<theme>  Specify theme: catppuccin, tokyo-night, nord, gruvbox, cyberpunk, all
  --user=<username>         Specify target non-root user homedir for configuration files
  --session-config          Auto-configure default session presets
  --maintenance             Run one-touch system maintenance (vpm update & clean)
  --services                Configure Runit system daemons, socklog logging & user groups
  -h, --help                Show this help message and exit
EOF
    }
    print_usage
    exit 0
fi

# Check root privilege
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root (or via sudo)." >&2
    exit 1
fi

# Ensure dialog is installed
if ! command -v dialog >/dev/null 2>&1; then
    echo "Installing dialog..."
    if command -v vpm >/dev/null 2>&1; then
        echo y | vpm install dialog 2>/dev/null || xbps-install -Sy dialog
    else
        xbps-install -Sy dialog
    fi
fi

# Helper functions leveraging voidPM (vpm)
pkg_install() {
    if command -v vpm >/dev/null 2>&1; then
        echo y | vpm install "$@" 2>/dev/null || xbps-install -y "$@"
    else
        xbps-install -y "$@"
    fi
}

pkg_update() {
    if command -v vpm >/dev/null 2>&1; then
        echo y | vpm update 2>/dev/null || xbps-install -Syu
    else
        xbps-install -Syu
    fi
}

pkg_remove() {
    if command -v vpm >/dev/null 2>&1; then
        echo y | vpm remove "$@" 2>/dev/null || xbps-remove -RFy "$@" 2>/dev/null || true
    else
        xbps-remove -RFy "$@" 2>/dev/null || true
    fi
}

service_enable() {
    local sname="$1"
    if command -v vpm >/dev/null 2>&1; then
        vpm sv enable "$sname" 2>/dev/null || true
    fi
    if [ -d "/etc/sv/$sname" ]; then
        ln -sfn "/etc/sv/$sname" "/var/service/$sname"
    fi
}

service_disable() {
    local sname="$1"
    if command -v vpm >/dev/null 2>&1; then
        vpm sv disable "$sname" 2>/dev/null || true
    fi
    rm -f "/var/service/$sname" 2>/dev/null || true
}

stop_all_display_managers() {
    service_disable sddm
    service_disable gdm
    service_disable lightdm
    pkill -f sddm 2>/dev/null || true
    pkill -f gdm 2>/dev/null || true
    pkill -f lightdm 2>/dev/null || true
}

# Detect non-root target user for group assignments
TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "$USER")}"
if [ "$TARGET_USER" = "root" ] || [ -z "$TARGET_USER" ]; then
    TARGET_USER="$(awk -F: '$3 >= 1000 && $3 < 60000 {print $1; exit}' /etc/passwd)"
fi

# Detect GPU hardware automatically
GPU_TYPE="UNKNOWN"
VGA_LINES="$(lspci 2>/dev/null | tr '[:upper:]' '[:lower:]' | grep -E "vga|display|3d" || echo "")"
if echo "$VGA_LINES" | grep -E -q "nvidia|geforce|quadro|rtx|gtx"; then
    GPU_TYPE="NVIDIA"
elif echo "$VGA_LINES" | grep -E -q "intel"; then
    GPU_TYPE="INTEL"
elif echo "$VGA_LINES" | grep -E -q "amd|radeon|ati|advanced micro devices"; then
    GPU_TYPE="AMD"
fi

# Detect available repository versions
KDE_VERSION="$(xbps-query -R plasma-desktop 2>/dev/null | awk -F'[-_]' '/^pkgver:/ {print $3}' || echo "6.x")"
GNOME_VERSION="$(xbps-query -R gnome-shell 2>/dev/null | awk -F'[-_]' '/^pkgver:/ {print $3}' || echo "48.x")"

# Selected Hyprland themes array
SELECTED_HYPRLAND_THEMES=()

# Module definitions
mod_repos() {
    echo "=== Enabling Repositories (non-free & multilib) ==="
    pkg_install void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree
    pkg_update
}

mod_gpu_amd() {
    echo "=== Installing AMD GPU Drivers & Video Acceleration ==="
    pkg_install \
        xorg-minimal \
        xf86-input-libinput \
        xf86-video-amdgpu \
        mesa-dri \
        mesa-vulkan-radeon \
        mesa-vulkan-radeon-32bit \
        mesa-vaapi \
        vulkan-loader \
        vulkan-loader-32bit \
        libvdpau-va-gl \
        linux-firmware-amd \
        libva-utils

    if ! grep -q "LIBVA_DRIVER_NAME=radeonsi" /etc/environment 2>/dev/null; then
        cat << 'EOF' >> /etc/environment
# AMD GPU VA-API & VDPAU Video Acceleration
LIBVA_DRIVER_NAME=radeonsi
VDPAU_DRIVER=va_gl
EOF
    fi

    echo "Reconfiguring kernel initramfs for AMD firmware..."
    xbps-reconfigure -fa 2>/dev/null || true
}

mod_gpu_intel() {
    echo "=== Installing Intel GPU Drivers, CPU Microcode & Video Acceleration ==="
    pkg_install \
        xorg-minimal \
        xf86-input-libinput \
        intel-ucode \
        mesa-dri \
        mesa-vulkan-intel \
        mesa-vulkan-intel-32bit \
        mesa-vaapi \
        vulkan-loader \
        vulkan-loader-32bit \
        intel-video-accel \
        intel-media-driver \
        libva-intel-driver \
        libvdpau-va-gl \
        linux-firmware-intel \
        libva-utils

    if ! grep -q "LIBVA_DRIVER_NAME=iHD" /etc/environment 2>/dev/null; then
        cat << 'EOF' >> /etc/environment
# Intel GPU VA-API & VDPAU Video Acceleration
LIBVA_DRIVER_NAME=iHD
VDPAU_DRIVER=va_gl
EOF
    fi

    echo "Reconfiguring kernel initramfs for Intel microcode..."
    xbps-reconfigure -fa 2>/dev/null || true
}

mod_gpu_nvidia() {
    echo "=== Installing NVIDIA GPU Proprietary Drivers & Acceleration ==="
    pkg_install \
        xorg-minimal \
        xf86-input-libinput \
        nvidia \
        nvidia-libs-32bit \
        nvidia-dkms \
        nvidia-vaapi-driver \
        libva-utils

    if ! grep -q "LIBVA_DRIVER_NAME=nvidia" /etc/environment 2>/dev/null; then
        cat << 'EOF' >> /etc/environment
# NVIDIA GPU VA-API Acceleration
LIBVA_DRIVER_NAME=nvidia
NVD_BACKEND=direct
__GLX_VENDOR_LIBRARY_NAME=nvidia
EOF
    fi

    mkdir -p /etc/modprobe.d /etc/dracut.conf.d
    cat << 'EOF' > /etc/modprobe.d/nvidia.conf
# Enable DRM KMS modesetting for Wayland & Sway compatibility
options nvidia-drm modeset=1
EOF

    cat << 'EOF' > /etc/dracut.conf.d/nvidia.conf
# Include NVIDIA kernel modules in initramfs for early modesetting
add_drivers+=" nvidia nvidia_modeset nvidia_uvm nvidia_drm "
EOF

    echo "Reconfiguring kernel initramfs for NVIDIA DRM modesetting..."
    xbps-reconfigure -fa 2>/dev/null || true
}

mod_portals() {
    echo "=== Installing XDG Desktop Portals & Core Daemons ==="
    pkg_install \
        dbus \
        elogind \
        NetworkManager \
        bluez \
        avahi \
        xdg-desktop-portal \
        xdg-desktop-portal-gtk \
        xdg-utils
}

mod_audio() {
    echo "=== Configuring PipeWire Audio (WirePlumber, ALSA, Pulse, JACK) ==="
    pkg_install \
        pipewire \
        wireplumber \
        wireplumber-elogind \
        alsa-pipewire \
        libspa-bluetooth \
        pulseaudio-utils \
        pavucontrol \
        libjack-pipewire

    mkdir -p /etc/pipewire/pipewire.conf.d
    if [ -f /usr/share/examples/wireplumber/10-wireplumber.conf ]; then
        ln -sf /usr/share/examples/wireplumber/10-wireplumber.conf /etc/pipewire/pipewire.conf.d/
    elif [ -f /usr/share/examples/pipewire/10-wireplumber.conf ]; then
        ln -sf /usr/share/examples/pipewire/10-wireplumber.conf /etc/pipewire/pipewire.conf.d/
    fi
    if [ -f /usr/share/examples/pipewire/20-pipewire-pulse.conf ]; then
        ln -sf /usr/share/examples/pipewire/20-pipewire-pulse.conf /etc/pipewire/pipewire.conf.d/
    elif [ -f /usr/share/examples/wireplumber/20-pipewire-pulse.conf ]; then
        ln -sf /usr/share/examples/wireplumber/20-pipewire-pulse.conf /etc/pipewire/pipewire.conf.d/
    fi

    mkdir -p /etc/alsa/conf.d
    if [ -f /usr/share/alsa/alsa.conf.d/50-pipewire.conf ]; then
        ln -sf /usr/share/alsa/alsa.conf.d/50-pipewire.conf /etc/alsa/conf.d/
    fi
    if [ -f /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf ]; then
        ln -sf /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d/
    fi

    mkdir -p /etc/ld.so.conf.d
    echo "/usr/lib/pipewire-0.3/jack" > /etc/ld.so.conf.d/pipewire-jack.conf
    ldconfig 2>/dev/null || true

    mkdir -p /etc/xdg/autostart
    rm -f /etc/xdg/autostart/wireplumber.desktop /etc/xdg/autostart/pipewire-pulse.desktop 2>/dev/null || true
    if [ -f "/usr/share/applications/pipewire.desktop" ]; then
        cp -f "/usr/share/applications/pipewire.desktop" /etc/xdg/autostart/
    fi

    if [ -n "$TARGET_USER" ] && [ -d "/home/$TARGET_USER/.config/autostart" ]; then
        rm -f "/home/$TARGET_USER/.config/autostart/wireplumber.desktop" "/home/$TARGET_USER/.config/autostart/pipewire-pulse.desktop" 2>/dev/null || true
    fi
}

setup_lightdm() {
    pkg_install lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings
    mkdir -p /etc/lightdm
    cat << 'EOF' > /etc/lightdm/lightdm.conf
[Seat:*]
user-session=default
greeter-session=lightdm-gtk-greeter
EOF
}

setup_hyprland_repo() {
    local arch
    arch="$(uname -m)"
    local libc="glibc"
    if ldd --version 2>&1 | grep -q "musl"; then
        libc="musl"
    fi
    local repo_url="https://raw.githubusercontent.com/Makrennel/hyprland-void/repository-${arch}-${libc}"
    mkdir -p /etc/xbps.d
    if [ ! -f /etc/xbps.d/hyprland-void.conf ] || ! grep -q "$repo_url" /etc/xbps.d/hyprland-void.conf 2>/dev/null; then
        echo "repository=${repo_url}" > /etc/xbps.d/hyprland-void.conf
        echo "Configured Makrennel hyprland repository (${arch}-${libc})."
        pkg_update
    fi
}

# --- Desktop Environment Installation Modules ---

mod_kde() {
    echo "=== Installing KDE Plasma v${KDE_VERSION} & SDDM ==="
    pkg_install \
        plasma-desktop plasma-workspace plasma-workspace-x11 kwin kwin-x11 qt6-wayland qt5-wayland xorg-server-xwayland \
        plasma-nm plasma-pa systemsettings kscreen sddm sddm-kcm breeze breeze-gtk desktop-file-utils xdg-desktop-portal-kde \
        bluedevil print-manager discover ocean-sound-theme plasma-browser-integration polkit-kde-agent \
        konsole dolphin dolphin-plugins kate kwrite okular spectacle gwenview ark kcalc partitionmanager kdegraphics-thumbnailers ffmpegthumbs \
        kde-cli-tools kservice kio kio-extras xdg-utils qt6-tools

    mkdir -p /etc/sddm.conf.d
    cat << 'EOF' > /etc/sddm.conf.d/kde_settings.conf
[Theme]
Current=breeze

[General]
DisplayServer=wayland
InputMethod=

[Users]
MaximumUid=60000
MinimumUid=1000
RememberLastSession=true
EOF
}

mod_kde_tools() {
    echo "=== Installing KDE CLI Tools & XDG Open Handlers ==="
    pkg_install kde-cli-tools kservice kio kio-extras xdg-utils qt6-tools
}

mod_gnome() {
    echo "=== Installing GNOME Shell v${GNOME_VERSION} & GDM ==="
    pkg_install \
        gnome gnome-apps gdm gnome-shell gnome-shell-extensions gnome-tweaks gnome-control-center nautilus evince gnome-terminal gnome-software xdg-desktop-portal-gnome
}

mod_xfce() {
    echo "=== Installing XFCE 4 Desktop & LightDM ==="
    setup_lightdm
    pkg_install \
        xfce4 xfce4-plugins xfce4-terminal Thunar ristretto catfish xfburn xfce4-panel xfce4-session xfdesktop xfwm4 \
        xfce4-settings xfce4-power-manager xfce4-appfinder xfce4-notifyd xfce4-pulseaudio-plugin xfce4-whiskermenu-plugin garcon exo
}

mod_cinnamon() {
    echo "=== Installing Cinnamon Desktop & LightDM ==="
    setup_lightdm
    pkg_install \
        cinnamon cinnamon-all cinnamon-settings-daemon nemo cinnamon-screensaver cinnamon-control-center cinnamon-session cjs muffin cinnamon-desktop cinnamon-translations cinnamon-menus gnome-terminal
}

mod_mate() {
    echo "=== Installing MATE Desktop & LightDM ==="
    setup_lightdm
    pkg_install \
        mate mate-extra caja pluma eom atril mate-terminal mate-media mate-control-center mate-session-manager mate-panel marco mate-desktop mate-menus mate-calc mate-system-monitor
}

mod_lxqt() {
    echo "=== Installing LXQt Desktop & SDDM ==="
    pkg_install \
        lxqt sddm qterminal pcmanfm-qt lximage-qt pavucontrol-qt FeatherPad lxqt-archiver lxqt-panel lxqt-session lxqt-runner lxqt-config lxqt-notificationd lxqt-policykit lxqt-powermanagement xdg-desktop-portal-lxqt
}

mod_lxde() {
    echo "=== Installing LXDE Desktop & LightDM ==="
    setup_lightdm
    pkg_install \
        lxde lxterminal pcmanfm gpicview leafpad lxmenu-data lxpanel lxsession openbox lxappearance lxrandr
}

mod_budgie() {
    echo "=== Installing Budgie Desktop & LightDM ==="
    setup_lightdm
    pkg_install \
        budgie-desktop budgie-desktop-view budgie-control-center magpie nautilus gnome-terminal gnome-control-center
}

mod_sway() {
    echo "=== Installing Sway Wayland Desktop & LightDM ==="
    setup_lightdm
    pkg_install \
        sway swaybg swaylock swayidle Waybar foot wofi grim slurp mako polkit-gnome xdg-desktop-portal-wlr
}

mod_enlightenment() {
    echo "=== Installing Enlightenment (E25) & LightDM ==="
    setup_lightdm
    pkg_install \
        enlightenment terminology efl rage-player
}

mod_hyprland() {
    echo "=== Installing Hyprland Dynamic Tiling Wayland Compositor & LightDM ==="
    setup_hyprland_repo
    setup_lightdm

    pkg_install \
        hyprland \
        xdg-desktop-portal-hyprland \
        hyprpaper \
        hyprlock \
        hypridle \
        Waybar \
        wofi \
        kitty \
        foot \
        mako \
        grim \
        slurp \
        wl-clipboard \
        swaybg \
        swaylock \
        polkit-gnome \
        brightnessctl \
        playerctl \
        pamixer \
        wlogout \
        font-awesome6 \
        nerd-fonts-ttf

    if [ -n "$TARGET_USER" ] && id "$TARGET_USER" >/dev/null 2>&1; then
        for g in _seatd input video seat; do
            getent group "$g" >/dev/null 2>&1 || groupadd -r "$g" 2>/dev/null || true
            usermod -aG "$g" "$TARGET_USER" 2>/dev/null || true
        done
    fi

    # Install Hyprland dotfiles/themes
    install_hyprland_themes
}

# --- Desktop Environment Removal Helpers ---

purge_kde_packages() {
    echo "Purging KDE Plasma packages..."
    pkg_remove \
        plasma-desktop plasma-workspace plasma-workspace-x11 kde-plasma-base libplasma plasma-activities plasma-activities-stats \
        plasma-browser-integration plasma-integration plasma-nm plasma-pa plasma5support sddm-kcm kwin kwin-x11 kf6-kdecoration \
        kf6-kdesu kf6-kdeclarative kdeclarative bluedevil print-manager discover ocean-sound-theme polkit-kde-agent kde-cli-tools \
        kservice kio kio-extras xdg-desktop-portal-kde konsole dolphin dolphin-plugins kate kwrite okular spectacle gwenview ark \
        kcalc partitionmanager kdegraphics-thumbnailers ffmpegthumbs breeze breeze-gtk breeze-qt5 breeze-qt6 aurorae kactivitymanagerd \
        kf6-kwayland kglobalacceld kmenuedit knighttime kpipewire kscreen kscreenlocker ksystemstats layer-shell-qt libkf6screen \
        libksysguard milou powerdevil qqc2-breeze-style systemsettings kworkspace kf6-purpose knewstuff kwallet kf6-bluez-qt baloo-widgets kwindowsystem
}

purge_gnome_packages() {
    echo "Purging GNOME Shell packages..."
    pkg_remove \
        gnome gnome-apps gdm gnome-shell gnome-shell-extensions gnome-tweaks gnome-control-center nautilus evince gnome-terminal \
        gnome-software xdg-desktop-portal-gnome gnome-initial-setup gnome-keyring gnome-session gnome-settings-daemon gnome-backgrounds \
        gnome-bluetooth gnome-boxes gnome-builder gnome-calculator gnome-calendar gnome-characters gnome-clocks gnome-color-manager \
        gnome-connections gnome-console gnome-contacts gnome-core gnome-desktop gnome-dictionary gnome-disk-utility gnome-font-viewer \
        gnome-maps gnome-menus gnome-music gnome-nettool gnome-photos gnome-remote-desktop gnome-screenshot gnome-sound-recorder \
        gnome-system-monitor gnome-text-editor gnome-themes-extra gnome-tour gnome-user-docs gnome-video-effects gnome-weather \
        loupe baobab decibels snapshot totem libreoffice-gnome
}

purge_xfce_packages() {
    echo "Purging XFCE packages..."
    pkg_remove \
        xfce4 xfce4-plugins xfce4-terminal Thunar ristretto catfish xfburn xfce4-panel xfce4-session xfdesktop xfwm4 \
        xfce4-settings xfce4-power-manager xfce4-appfinder xfce4-notifyd xfce4-pulseaudio-plugin xfce4-whiskermenu-plugin garcon exo
}

purge_cinnamon_packages() {
    echo "Purging Cinnamon packages..."
    pkg_remove \
        cinnamon cinnamon-all cinnamon-settings-daemon nemo cinnamon-screensaver cinnamon-control-center cinnamon-session cjs muffin cinnamon-desktop cinnamon-translations cinnamon-menus
}

purge_mate_packages() {
    echo "Purging MATE packages..."
    pkg_remove \
        mate mate-extra caja pluma eom atril mate-terminal mate-media mate-control-center mate-session-manager mate-panel marco mate-desktop mate-menus mate-calc mate-system-monitor
}

purge_lxqt_packages() {
    echo "Purging LXQt packages..."
    pkg_remove \
        lxqt qterminal pcmanfm-qt lximage-qt pavucontrol-qt FeatherPad lxqt-archiver lxqt-panel lxqt-session lxqt-runner lxqt-config lxqt-notificationd lxqt-policykit lxqt-powermanagement xdg-desktop-portal-lxqt
}

purge_lxde_packages() {
    echo "Purging LXDE packages..."
    pkg_remove \
        lxde lxterminal pcmanfm gpicview leafpad lxmenu-data lxpanel lxsession openbox lxappearance lxrandr
}

purge_budgie_packages() {
    echo "Purging Budgie packages..."
    pkg_remove \
        budgie-desktop budgie-desktop-view budgie-control-center magpie
}

purge_sway_packages() {
    echo "Purging Sway packages..."
    pkg_remove \
        sway swaybg swaylock swayidle Waybar foot wofi grim slurp mako xdg-desktop-portal-wlr
}

purge_enlightenment_packages() {
    echo "Purging Enlightenment packages..."
    pkg_remove \
        enlightenment terminology efl rage-player
}

purge_hyprland_packages() {
    echo "Purging Hyprland packages..."
    pkg_remove \
        hyprland hyprpaper hyprlock hypridle xdg-desktop-portal-hyprland \
        Waybar wofi foot kitty mako dunst grim slurp wl-clipboard swaybg swaylock polkit-gnome brightnessctl playerctl pamixer wlogout
}

run_orphan_clean() {
    if command -v vpm >/dev/null 2>&1; then
        echo "Cleaning orphaned packages via vpm clean..."
        echo y | vpm clean 2>/dev/null || xbps-remove -yo 2>/dev/null || true
    else
        xbps-remove -yo 2>/dev/null || true
    fi
}

purge_app_packages() {
    echo "Purging core desktop applications..."
    pkg_remove \
        PackageKit AppStream AppStream-qt p7zip unzip zip firefox fastfetch ffmpeg \
        gst-plugins-good1 gst-plugins-bad1 gst-plugins-ugly1 gst-libav \
        ntfs-3g exfatprogs dosfstools btrfs-progs cups xdg-user-dirs \
        libreoffice thunderbird vlc gimp krita easyeffects inkscape \
        telegram-desktop gearlever pika-backup nheko protonplus retroarch \
        jellyfin-desktop filezilla PrismLauncher blender audacity wike \
        foliate nicotine+ vscode Signal-Desktop bleachbit obs
}

purge_gaming_packages() {
    echo "Purging gaming packages & performance tools..."
    pkg_remove \
        steam steam-udev-rules vulkan-loader-32bit mesa-dri-32bit \
        gamemode libgamemode-32bit MangoHud MangoHud-32bit protontricks winetricks wine wine-32bit lutris
}

purge_gpu_packages() {
    echo "Purging extra GPU drivers & acceleration libraries..."
    pkg_remove \
        xf86-video-amdgpu mesa-vulkan-radeon mesa-vulkan-radeon-32bit mesa-vaapi \
        mesa-vulkan-intel mesa-vulkan-intel-32bit intel-video-accel intel-media-driver libva-intel-driver \
        nvidia nvidia-libs-32bit nvidia-dkms nvidia-vaapi-driver libvdpau-va-gl libva-utils
}

purge_audio_packages() {
    echo "Purging PipeWire audio suite..."
    pkg_remove \
        pipewire wireplumber wireplumber-elogind alsa-pipewire libspa-bluetooth pulseaudio-utils pavucontrol libjack-pipewire rtkit
}

purge_portal_packages() {
    echo "Purging desktop portals & extra communication daemons..."
    pkg_remove \
        xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-kde xdg-desktop-portal-gnome \
        xdg-desktop-portal-lxqt xdg-desktop-portal-wlr xdg-desktop-portal-hyprland bluez avahi
}

purge_font_packages() {
    echo "Purging extra TrueType fonts..."
    pkg_remove noto-fonts-ttf noto-fonts-cjk noto-fonts-emoji liberation-fonts-ttf
}

purge_tailscale_packages() {
    echo "Purging Tailscale VPN..."
    pkg_remove tailscale
}

purge_system_modules_packages() {
    echo "Purging system daemons & utilities (zramen, openntpd, power-profiles-daemon, fwupd, socklog)..."
    pkg_remove zramen openntpd power-profiles-daemon fwupd socklog-void
}

purge_void_tools() {
    echo "Purging Void Linux community power-user tools..."
    pkg_remove \
        xtools vsv octoxbps font-awesome6 nerd-fonts-ttf \
        btop fzf ripgrep fd bat eza duf tldr jq
}

purge_flatpaks() {
    if command -v flatpak >/dev/null 2>&1; then
        echo "Purging all installed Flatpak applications..."
        flatpak uninstall --all -y 2>/dev/null || true
        flatpak remote-delete flathub 2>/dev/null || true
    fi
}

mod_purge_to_barebones() {
    echo "========================================================"
    echo " [FRESH START] Purging all packages & DEs down to base-barebones"
    echo "========================================================"
    stop_all_display_managers
    service_disable bluetoothd
    service_disable tailscaled
    service_disable cupsd
    service_disable avahi-daemon
    service_disable rtkit
    service_disable openntpd
    service_disable power-profiles-daemon
    service_disable zramen
    service_disable zram
    service_disable socklog-unix
    service_disable nanoklogd

    echo "[1/6] Purging all Desktop Environments..."
    purge_kde_packages; purge_gnome_packages; purge_xfce_packages; purge_cinnamon_packages
    purge_mate_packages; purge_lxqt_packages; purge_lxde_packages; purge_budgie_packages
    purge_sway_packages; purge_enlightenment_packages; purge_hyprland_packages

    echo "[2/6] Purging applications, tools & gaming stack..."
    purge_app_packages
    purge_gaming_packages
    purge_void_tools
    purge_flatpaks

    echo "[3/6] Purging audio, portals, GPU drivers, and optional system daemons..."
    purge_audio_packages
    purge_portal_packages
    purge_gpu_packages
    purge_font_packages
    purge_tailscale_packages
    purge_system_modules_packages

    echo "[4/6] Ensuring core base-system, D-Bus, elogind & NetworkManager are intact and active..."
    pkg_install base-system NetworkManager wpa_supplicant dbus elogind
    service_enable dbus
    service_enable elogind
    service_enable NetworkManager

    echo "[5/6] Cleaning all orphaned dependencies via vpm clean..."
    run_orphan_clean

    echo "[6/6] System successfully reset to clean base-barebones state with active networking!"
    echo "Please reboot your system (sudo reboot)."
}

# --- Desktop Environment Swap Modules ---

mod_swap_to_kde() {
    echo "=== [Desktop Swap] Swapping Desktop Environment to KDE Plasma ==="
    stop_all_display_managers
    purge_gnome_packages; purge_xfce_packages; purge_cinnamon_packages; purge_mate_packages
    purge_lxqt_packages; purge_lxde_packages; purge_budgie_packages; purge_sway_packages; purge_enlightenment_packages; purge_hyprland_packages
    run_orphan_clean
    mod_kde
    service_enable sddm
    echo "Desktop environment swapped to KDE Plasma! Please reboot."
}

mod_swap_to_gnome() {
    echo "=== [Desktop Swap] Swapping Desktop Environment to GNOME ==="
    stop_all_display_managers
    purge_kde_packages; purge_xfce_packages; purge_cinnamon_packages; purge_mate_packages
    purge_lxqt_packages; purge_lxde_packages; purge_budgie_packages; purge_sway_packages; purge_enlightenment_packages; purge_hyprland_packages
    run_orphan_clean
    mod_gnome
    service_enable gdm
    echo "Desktop environment swapped to GNOME! Please reboot."
}

mod_swap_to_xfce() {
    echo "=== [Desktop Swap] Swapping Desktop Environment to XFCE ==="
    stop_all_display_managers
    purge_kde_packages; purge_gnome_packages; purge_cinnamon_packages; purge_mate_packages
    purge_lxqt_packages; purge_lxde_packages; purge_budgie_packages; purge_sway_packages; purge_enlightenment_packages; purge_hyprland_packages
    run_orphan_clean
    mod_xfce
    service_enable lightdm
    echo "Desktop environment swapped to XFCE! Please reboot."
}

mod_swap_to_cinnamon() {
    echo "=== [Desktop Swap] Swapping Desktop Environment to Cinnamon ==="
    stop_all_display_managers
    purge_kde_packages; purge_gnome_packages; purge_xfce_packages; purge_mate_packages
    purge_lxqt_packages; purge_lxde_packages; purge_budgie_packages; purge_sway_packages; purge_enlightenment_packages; purge_hyprland_packages
    run_orphan_clean
    mod_cinnamon
    service_enable lightdm
    echo "Desktop environment swapped to Cinnamon! Please reboot."
}

mod_swap_to_mate() {
    echo "=== [Desktop Swap] Swapping Desktop Environment to MATE ==="
    stop_all_display_managers
    purge_kde_packages; purge_gnome_packages; purge_xfce_packages; purge_cinnamon_packages
    purge_lxqt_packages; purge_lxde_packages; purge_budgie_packages; purge_sway_packages; purge_enlightenment_packages; purge_hyprland_packages
    run_orphan_clean
    mod_mate
    service_enable lightdm
    echo "Desktop environment swapped to MATE! Please reboot."
}

mod_swap_to_lxqt() {
    echo "=== [Desktop Swap] Swapping Desktop Environment to LXQt ==="
    stop_all_display_managers
    purge_kde_packages; purge_gnome_packages; purge_xfce_packages; purge_cinnamon_packages
    purge_mate_packages; purge_lxde_packages; purge_budgie_packages; purge_sway_packages; purge_enlightenment_packages; purge_hyprland_packages
    run_orphan_clean
    mod_lxqt
    service_enable sddm
    echo "Desktop environment swapped to LXQt! Please reboot."
}

mod_swap_to_lxde() {
    echo "=== [Desktop Swap] Swapping Desktop Environment to LXDE ==="
    stop_all_display_managers
    purge_kde_packages; purge_gnome_packages; purge_xfce_packages; purge_cinnamon_packages
    purge_mate_packages; purge_lxqt_packages; purge_budgie_packages; purge_sway_packages; purge_enlightenment_packages; purge_hyprland_packages
    run_orphan_clean
    mod_lxde
    service_enable lightdm
    echo "Desktop environment swapped to LXDE! Please reboot."
}

mod_swap_to_budgie() {
    echo "=== [Desktop Swap] Swapping Desktop Environment to Budgie ==="
    stop_all_display_managers
    purge_kde_packages; purge_gnome_packages; purge_xfce_packages; purge_cinnamon_packages
    purge_mate_packages; purge_lxqt_packages; purge_lxde_packages; purge_sway_packages; purge_enlightenment_packages; purge_hyprland_packages
    run_orphan_clean
    mod_budgie
    service_enable lightdm
    echo "Desktop environment swapped to Budgie! Please reboot."
}

mod_swap_to_sway() {
    echo "=== [Desktop Swap] Swapping Desktop Environment to Sway ==="
    stop_all_display_managers
    purge_kde_packages; purge_gnome_packages; purge_xfce_packages; purge_cinnamon_packages
    purge_mate_packages; purge_lxqt_packages; purge_lxde_packages; purge_budgie_packages; purge_enlightenment_packages; purge_hyprland_packages
    run_orphan_clean
    mod_sway
    service_enable lightdm
    echo "Desktop environment swapped to Sway! Please reboot."
}

mod_swap_to_enlightenment() {
    echo "=== [Desktop Swap] Swapping Desktop Environment to Enlightenment ==="
    stop_all_display_managers
    purge_kde_packages; purge_gnome_packages; purge_xfce_packages; purge_cinnamon_packages
    purge_mate_packages; purge_lxqt_packages; purge_lxde_packages; purge_budgie_packages; purge_sway_packages; purge_hyprland_packages
    run_orphan_clean
    mod_enlightenment
    service_enable lightdm
    echo "Desktop environment swapped to Enlightenment! Please reboot."
}

mod_swap_to_hyprland() {
    echo "=== [Desktop Swap] Swapping Desktop Environment to Hyprland ==="
    stop_all_display_managers
    purge_kde_packages; purge_gnome_packages; purge_xfce_packages; purge_cinnamon_packages
    purge_mate_packages; purge_lxqt_packages; purge_lxde_packages; purge_budgie_packages; purge_sway_packages; purge_enlightenment_packages
    run_orphan_clean
    mod_hyprland
    service_enable lightdm
    echo "Desktop environment swapped to Hyprland! Please reboot."
}

# --- Core Apps & Gaming Modules ---

mod_apps() {
    echo "=== Installing Core Applications, Codecs, Native Apps & Printing ==="
    pkg_install \
        PackageKit AppStream AppStream-qt p7zip unzip zip firefox fastfetch ffmpeg \
        gst-plugins-good1 gst-plugins-bad1 gst-plugins-ugly1 gst-libav \
        ntfs-3g exfatprogs dosfstools btrfs-progs cups xdg-user-dirs \
        libreoffice thunderbird vlc gimp krita easyeffects inkscape \
        telegram-desktop gearlever pika-backup nheko protonplus retroarch \
        jellyfin-desktop filezilla PrismLauncher blender audacity wike \
        foliate nicotine+ vscode Signal-Desktop bleachbit obs
}

mod_void_tools() {
    echo "=== Installing Void Linux Community Power-User Tools & Utilities ==="
    pkg_install \
        xtools vsv octoxbps font-awesome6 nerd-fonts-ttf \
        btop fzf ripgrep fd bat eza duf tldr jq
}

mod_gaming() {
    echo "=== Installing Steam, Wine, GameMode & Gaming Performance Tweaks ==="
    pkg_install \
        flatpak steam steam-udev-rules vulkan-loader-32bit mesa-dri-32bit \
        gamemode libgamemode-32bit MangoHud MangoHud-32bit protontricks winetricks wine wine-32bit lutris

    mkdir -p /etc/sysctl.d /etc/security/limits.d
    cat << 'EOF' > /etc/sysctl.d/99-gaming.conf
vm.max_map_count = 2147483642
fs.file-max = 2097152
EOF
    sysctl -p /etc/sysctl.d/99-gaming.conf || true

    cat << 'EOF' > /etc/security/limits.d/99-gaming.conf
* hard nofile 1048576
* soft nofile 1048576
EOF
}

mod_flatpaks() {
    echo "=== Installing Flatpaks (Selected apps not available in XBPS) ==="
    pkg_install flatpak
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true

    FLATPAK_LIST=(
        "com.discordapp.Discord"
        "com.github.tchx84.Flatseal"
        "com.bitwarden.desktop"
        "io.github.dvlv.boxbuddyrs"
        "de.leopoldluley.Clapgrep"
        "io.github.flattool.Ignition"
        "io.github.flattool.Warehouse"
        "io.missioncenter.MissionCenter"
        "io.podman_desktop.PodmanDesktop"
        "dev.zed.Zed"
        "io.github.shiftey.Desktop"
        "org.gtk.Gtk3theme.adw-gtk3"
        "org.gtk.Gtk3theme.adw-gtk3-dark"
        "org.gustavoperedo.FontDownloader"
        "sh.loft.devpod"
        "com.heroicgameslauncher.hgl"
        "com.slack.Slack"
        "io.github.victoralvesf.aonsoku"
        "com.usebottles.bottles"
        "md.obsidian.Obsidian"
    )

    for app in "${FLATPAK_LIST[@]}"; do
        echo "Installing Flatpak: $app..."
        flatpak install -y flathub "$app" || true
    done
}

mod_tailscale() {
    echo "=== Installing Tailscale VPN ==="
    pkg_install tailscale
}

mod_time_sync() {
    echo "=== Configuring NTP Time Sync (openntpd) ==="
    pkg_install openntpd

    if [ ! -f /etc/ntpd.conf ]; then
        cat << 'EOF' > /etc/ntpd.conf
# NTP servers for time synchronization
servers pool.ntp.org
EOF
    fi

    service_enable openntpd

    # Sync clock immediately if daemon isn't already running
    if ! pgrep -x openntpd >/dev/null 2>&1; then
        openntpd -s 2>/dev/null || ntpd -s 2>/dev/null || true
    fi

    echo "✓ NTP time sync configured and enabled."
}

mod_power() {
    echo "=== Configuring Power Management ==="
    pkg_install power-profiles-daemon
    service_enable power-profiles-daemon
    echo "✓ Power profiles daemon installed and enabled."
}

mod_trim() {
    echo "=== Configuring Periodic SSD TRIM ==="
    pkg_install util-linux

    mkdir -p /etc/cron.weekly /etc/cron.daily
    if [ ! -f /etc/cron.weekly/fstrim ]; then
        cat << 'EOF' > /etc/cron.weekly/fstrim
#!/bin/sh
/usr/bin/fstrim --all --verbose 2>/dev/null || true
EOF
        chmod 755 /etc/cron.weekly/fstrim
    fi

    echo "✓ Weekly SSD TRIM cron job installed."
}

mod_fwupd() {
    echo "=== Installing Firmware Update Daemon (fwupd) ==="
    pkg_install fwupd
    if [ -d "/etc/sv/fwupd" ]; then
        service_enable fwupd
    fi
    echo "✓ fwupd installed and ready for LVFS firmware updates."
}

mod_locale() {
    echo "=== Configuring System Locale ==="
    if [ -f /etc/default/libc-locales ]; then
        sed -i 's/^#\s*en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/default/libc-locales 2>/dev/null || true
        if ! grep -q "^en_US.UTF-8 UTF-8" /etc/default/libc-locales 2>/dev/null; then
            echo "en_US.UTF-8 UTF-8" >> /etc/default/libc-locales
        fi
        xbps-reconfigure -f glibc-locales 2>/dev/null || xbps-reconfigure -fa 2>/dev/null || true
    fi

    if [ ! -f /etc/locale.conf ] || ! grep -q "^LANG=" /etc/locale.conf; then
        echo "LANG=en_US.UTF-8" > /etc/locale.conf
    fi
    echo "✓ Locale en_US.UTF-8 configured."
}

mod_zram() {
    echo "=== Configuring ZRAM Compressed Swap ==="
    service_disable zram 2>/dev/null || true
    rm -rf /etc/sv/zram /var/service/zram 2>/dev/null || true

    pkg_install zramen

    modprobe zram 2>/dev/null || true
    if [ ! -f /etc/modules-load.d/zram.conf ]; then
        mkdir -p /etc/modules-load.d
        echo "zram" > /etc/modules-load.d/zram.conf
    fi

    service_enable zramen
    echo "✓ ZRAM compressed swap service (zramen) configured and enabled."
}

mod_fonts() {
    echo "=== Installing TrueType Fonts ==="
    pkg_install noto-fonts-ttf noto-fonts-cjk noto-fonts-emoji liberation-fonts-ttf
}

# --- Hyprland Theme Generator & Sub-dialog System ---

generate_hyprland_theme() {
    local theme="$1"
    local u_home="$2"
    local t_dir="$u_home/.config/hypr/themes/$theme"
    mkdir -p "$t_dir/hypr" "$t_dir/waybar" "$t_dir/wofi" "$t_dir/mako" "$t_dir/kitty"

    local active_border inactive_border bg_color accent_color accent_secondary text_color bar_bg module_bg err_color warn_color ok_color

    case "$theme" in
        catppuccin|mocha)
            theme="catppuccin"
            active_border="rgb(cba6f7) rgb(89b4fa) 45deg"
            inactive_border="rgba(585b70aa)"
            bg_color="#1e1e2e"
            accent_color="#cba6f7"
            accent_secondary="#89b4fa"
            text_color="#cdd6f4"
            bar_bg="#181825ee"
            module_bg="#313244"
            ok_color="#a6e3a1"
            warn_color="#fab387"
            err_color="#f38ba8"
            ;;
        tokyo-night|tokyonight)
            theme="tokyo-night"
            active_border="rgb(7aa2f7) rgb(bb9af7) 45deg"
            inactive_border="rgba(414868aa)"
            bg_color="#1a1b26"
            accent_color="#7aa2f7"
            accent_secondary="#bb9af7"
            text_color="#a9b1d6"
            bar_bg="#16161eee"
            module_bg="#24283b"
            ok_color="#9ece6a"
            warn_color="#e0af68"
            err_color="#f7768e"
            ;;
        nord)
            theme="nord"
            active_border="rgb(88c0d0) rgb(81a1c1) 45deg"
            inactive_border="rgba(4c566aaa)"
            bg_color="#2e3440"
            accent_color="#88c0d0"
            accent_secondary="#81a1c1"
            text_color="#eceff4"
            bar_bg="#242933ee"
            module_bg="#3b4252"
            ok_color="#a3be8c"
            warn_color="#ebcb8b"
            err_color="#bf616a"
            ;;
        gruvbox)
            theme="gruvbox"
            active_border="rgb(fabd2f) rgb(fe8019) 45deg"
            inactive_border="rgba(504945aa)"
            bg_color="#282828"
            accent_color="#fabd2f"
            accent_secondary="#fe8019"
            text_color="#ebdbb2"
            bar_bg="#1d2021ee"
            module_bg="#3c3836"
            ok_color="#b8bb26"
            warn_color="#fabd2f"
            err_color="#fb4934"
            ;;
        cyberpunk)
            theme="cyberpunk"
            active_border="rgb(00f0ff) rgb(ff007f) 45deg"
            inactive_border="rgba(261447aa)"
            bg_color="#0d0221"
            accent_color="#00f0ff"
            accent_secondary="#ff007f"
            text_color="#fcee0a"
            bar_bg="#0a0118ee"
            module_bg="#261447"
            ok_color="#05ffa1"
            warn_color="#fcee0a"
            err_color="#ff2a6d"
            ;;
        *)
            return 0
            ;;
    esac

    # 1. hyprland.conf
    cat << EOF > "$t_dir/hypr/hyprland.conf"
# Hyprland Config - Theme: $theme

monitor=,preferred,auto,1

# Autostart
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = /usr/libexec/polkit-gnome-authentication-agent-1
exec-once = waybar
exec-once = mako
exec-once = swaybg -c "$bg_color"

input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = true
    }
}

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = $active_border
    col.inactive_border = $inactive_border
    layout = dwindle
}

decoration {
    rounding = 10
    blur {
        enabled = true
        size = 6
        passes = 2
        new_optimizations = true
    }
    shadow {
        enabled = true
        range = 15
        render_power = 3
        color = rgba(00000088)
    }
}

animations {
    enabled = true
    bezier = overshot, 0.05, 0.9, 0.1, 1.05
    bezier = smoothOut, 0.36, 0, 0.66, -0.56
    bezier = smoothIn, 0.25, 1, 0.5, 1
    animation = windows, 1, 4, overshot, slide
    animation = windowsOut, 1, 4, smoothOut, slide
    animation = border, 1, 10, default
    animation = fade, 1, 4, smoothIn
    animation = workspaces, 1, 5, default, slide
}

dwindle {
    pseudotile = true
    preserve_split = true
}

misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    mouse_move_enables_dpms = true
    key_press_enables_dpms = true
}

windowrule = float, ^(pavucontrol)$
windowrule = float, ^(nm-connection-editor)$
windowrule = float, ^(wlogout)$

\$mainMod = SUPER

bind = \$mainMod, RETURN, exec, kitty
bind = \$mainMod, T, exec, foot
bind = \$mainMod, Q, killactive,
bind = \$mainMod, SPACE, exec, wofi --show drun
bind = \$mainMod, D, exec, wofi --show drun
bind = \$mainMod, E, exec, thunar
bind = \$mainMod, V, togglefloating,
bind = \$mainMod, F, fullscreen, 0
bind = \$mainMod, L, exec, hyprlock
bind = \$mainMod, ESCAPE, exec, wlogout
bind = \$mainMod SHIFT, T, exec, ~/.config/hypr/switch-theme.sh

binde = , XF86AudioRaiseVolume, exec, pamixer -i 5
binde = , XF86AudioLowerVolume, exec, pamixer -d 5
bind = , XF86AudioMute, exec, pamixer -t
bind = , XF86AudioPlay, exec, playerctl play-pause
bind = , XF86AudioNext, exec, playerctl next
bind = , XF86AudioPrev, exec, playerctl previous

binde = , XF86MonBrightnessUp, exec, brightnessctl set 5%+
binde = , XF86MonBrightnessDown, exec, brightnessctl set 5%-

bind = \$mainMod, PRINT, exec, grim - | wl-copy
bind = \$mainMod SHIFT, S, exec, grim -g "\$(slurp)" - | wl-copy

bind = \$mainMod, left, movefocus, l
bind = \$mainMod, right, movefocus, r
bind = \$mainMod, up, movefocus, u
bind = \$mainMod, down, movefocus, d
bind = \$mainMod, H, movefocus, l
bind = \$mainMod, L, movefocus, r
bind = \$mainMod, K, movefocus, u
bind = \$mainMod, J, movefocus, d

bind = \$mainMod, 1, workspace, 1
bind = \$mainMod, 2, workspace, 2
bind = \$mainMod, 3, workspace, 3
bind = \$mainMod, 4, workspace, 4
bind = \$mainMod, 5, workspace, 5
bind = \$mainMod, 6, workspace, 6
bind = \$mainMod, 7, workspace, 7
bind = \$mainMod, 8, workspace, 8
bind = \$mainMod, 9, workspace, 9

bind = \$mainMod SHIFT, 1, movetoworkspace, 1
bind = \$mainMod SHIFT, 2, movetoworkspace, 2
bind = \$mainMod SHIFT, 3, movetoworkspace, 3
bind = \$mainMod SHIFT, 4, movetoworkspace, 4
bind = \$mainMod SHIFT, 5, movetoworkspace, 5
bind = \$mainMod SHIFT, 6, movetoworkspace, 6
bind = \$mainMod SHIFT, 7, movetoworkspace, 7
bind = \$mainMod SHIFT, 8, movetoworkspace, 8
bind = \$mainMod SHIFT, 9, movetoworkspace, 9

bindm = \$mainMod, mouse:272, movewindow
bindm = \$mainMod, mouse:273, resizewindow
EOF

    # 2. waybar config & style.css
    cat << EOF > "$t_dir/waybar/config"
{
    "layer": "top",
    "position": "top",
    "height": 36,
    "spacing": 6,
    "modules-left": ["hyprland/workspaces", "hyprland/window"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "network", "cpu", "memory", "battery", "tray", "custom/power"],
    "hyprland/workspaces": {
        "format": "{id}",
        "on-click": "activate",
        "sort-by-number": true
    },
    "hyprland/window": {
        "format": "{}",
        "max-length": 35
    },
    "clock": {
        "format": " {:%H:%M   %a %d %b}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
    },
    "cpu": {
        "format": " {usage}%",
        "interval": 2
    },
    "memory": {
        "format": " {}%",
        "interval": 2
    },
    "battery": {
        "states": {
            "good": 95,
            "warning": 30,
            "critical": 15
        },
        "format": "{icon} {capacity}%",
        "format-charging": " {capacity}%",
        "format-plugged": " {capacity}%",
        "format-icons": ["", "", "", "", ""]
    },
    "network": {
        "format-wifi": " {signalStrength}%",
        "format-ethernet": "󰈀 Wired",
        "format-disconnected": "⚠ Offline"
    },
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": " Muted",
        "format-icons": {
            "default": ["", "", ""]
        },
        "on-click": "pavucontrol"
    },
    "tray": {
        "spacing": 8
    },
    "custom/power": {
        "format": "",
        "on-click": "wlogout",
        "tooltip": false
    }
}
EOF

    cat << EOF > "$t_dir/waybar/style.css"
* {
    border: none;
    border-radius: 0;
    font-family: "JetBrainsMono Nerd Font", "Noto Sans", sans-serif;
    font-size: 13px;
    min-height: 0;
}

window#waybar {
    background-color: $bar_bg;
    color: $text_color;
    border-bottom: 2px solid $accent_color;
}

#workspaces button {
    padding: 0 8px;
    background-color: transparent;
    color: $text_color;
    border-bottom: 2px solid transparent;
    transition: all 0.3s ease;
}

#workspaces button.active {
    background-color: $module_bg;
    color: $accent_color;
    border-bottom: 2px solid $accent_color;
    border-radius: 6px;
}

#workspaces button:hover {
    background: $module_bg;
    color: $accent_secondary;
    border-radius: 6px;
}

#window,
#clock,
#battery,
#cpu,
#memory,
#network,
#pulseaudio,
#tray,
#custom-power {
    padding: 2px 10px;
    margin: 4px 2px;
    background-color: $module_bg;
    color: $text_color;
    border-radius: 8px;
}

#clock {
    color: $accent_color;
    font-weight: bold;
}

#battery.warning {
    color: $warn_color;
}

#battery.critical {
    color: $err_color;
}

#pulseaudio.muted {
    color: $err_color;
}

#custom-power {
    color: $err_color;
    font-weight: bold;
    padding-right: 12px;
}
EOF

    # 3. wofi config & style.css
    cat << EOF > "$t_dir/wofi/config"
width=460
height=380
location=center
show=drun
prompt=Search...
filter_rate=100
allow_markup=true
no_actions=true
halign=fill
orientation=vertical
content_halign=fill
insensitive=true
allow_images=true
image_size=28
EOF

    cat << EOF > "$t_dir/wofi/style.css"
window {
    margin: 0px;
    background-color: $bg_color;
    border: 2px solid $accent_color;
    border-radius: 12px;
    font-family: "JetBrainsMono Nerd Font", "Noto Sans", sans-serif;
    font-size: 14px;
}

#input {
    margin: 10px;
    padding: 8px 12px;
    border: 1px solid $accent_secondary;
    border-radius: 8px;
    background-color: $module_bg;
    color: $text_color;
}

#inner-box {
    margin: 5px;
    border: none;
    background-color: transparent;
}

#outer-box {
    margin: 5px;
    border: none;
    background-color: transparent;
}

#entry {
    margin: 3px 6px;
    padding: 6px 10px;
    border-radius: 6px;
    color: $text_color;
}

#entry:selected {
    background-color: $accent_color;
    color: $bg_color;
    font-weight: bold;
}
EOF

    # 4. mako config
    cat << EOF > "$t_dir/mako/config"
font=Noto Sans 11
background-color=${bg_color}ee
text-color=$text_color
border-color=$accent_color
border-size=2
border-radius=8
icons=1
max-icon-size=48
default-timeout=5000
margin=12
padding=10
EOF

    # 5. kitty config
    cat << EOF > "$t_dir/kitty/kitty.conf"
font_family      JetBrainsMono Nerd Font
font_size        12.0
background_opacity 0.92
window_padding_width 10
confirm_os_window_close 0

# Colors for theme: $theme
background $bg_color
foreground $text_color
selection_background $accent_color
selection_foreground $bg_color
cursor $accent_color

active_border_color $accent_color
inactive_border_color $module_bg
EOF
}

prompt_target_user_dialog() {
    if command -v dialog >/dev/null 2>&1; then
        local entered_user
        entered_user=$(dialog --clear --stdout --backtitle "Target User Configuration" \
            --inputbox "Confirm or enter the non-root username whose home directory (~/.config) will receive configurations, Hyprland dotfiles, and user permissions:" 10 76 "$TARGET_USER" 2>&1) || true
        if [ -n "$entered_user" ]; then
            TARGET_USER="$entered_user"
        fi
    fi
}

show_hyprland_theme_dialog() {
    if command -v dialog >/dev/null 2>&1; then
        local theme_choices
        theme_choices=$(dialog --clear --stdout --backtitle "Void Linux Hyprland Theming Suite" \
            --checklist "Select Hyprland themes to install into /home/$TARGET_USER/.config/ (SPACE to toggle):" 18 80 5 \
            "catppuccin"  "Catppuccin Mocha (Modern pastel violet & sapphire dark)" ON \
            "tokyo-night" "Tokyo Night (Vibrant deep blue & neon purple aesthetic)" ON \
            "nord"        "Nord Frost (Clean minimalist arctic slate & ice blue)" OFF \
            "gruvbox"     "Gruvbox Retro (Warm earthy gold, amber & forest green)" OFF \
            "cyberpunk"   "Cyberpunk Synthwave (High-contrast neon cyan & magenta)" OFF 2>&1) || true
        if [ -n "$theme_choices" ]; then
            eval "SELECTED_HYPRLAND_THEMES=($theme_choices)"
        fi
    fi
}

install_hyprland_themes() {
    local u_home
    u_home=$(getent passwd "$TARGET_USER" | cut -d: -f6 || echo "/home/$TARGET_USER")
    [ -z "$u_home" ] && u_home="/home/$TARGET_USER"

    echo "=== Installing Hyprland Theme Suite into $u_home/.config ==="

    if [ "${#SELECTED_HYPRLAND_THEMES[@]}" -eq 0 ]; then
        SELECTED_HYPRLAND_THEMES=("catppuccin" "tokyo-night" "nord" "gruvbox" "cyberpunk")
    fi

    # Backup existing hypr config if present and not created by this script
    if [ -d "$u_home/.config/hypr" ] && [ ! -d "$u_home/.config/hypr/themes" ]; then
        local bak_dir="$u_home/.config/hypr.bak.$(date +%Y%m%d%H%M%S)"
        echo "[i] Backing up existing Hyprland configuration to $bak_dir..."
        cp -r "$u_home/.config/hypr" "$bak_dir" 2>/dev/null || true
    fi

    mkdir -p "$u_home/.config/hypr/themes" \
             "$u_home/.config/waybar" \
             "$u_home/.config/wofi" \
             "$u_home/.config/mako" \
             "$u_home/.config/kitty"

    for theme in "${SELECTED_HYPRLAND_THEMES[@]}"; do
        generate_hyprland_theme "$theme" "$u_home"
    done

    # Switch theme script
    cat << 'SWITCHEOC' > "$u_home/.config/hypr/switch-theme.sh"
#!/bin/sh
THEME="$1"
THEMES_DIR="$HOME/.config/hypr/themes"

if [ -z "$THEME" ]; then
    if command -v wofi >/dev/null 2>&1; then
        THEME=$(ls "$THEMES_DIR" 2>/dev/null | wofi --dmenu --prompt "Select Hyprland Theme:")
    else
        echo "Usage: $0 <theme-name>"
        echo "Available themes: $(ls "$THEMES_DIR" 2>/dev/null | tr '\n' ' ')"
        exit 1
    fi
fi

[ -z "$THEME" ] && exit 0

if [ -d "$THEMES_DIR/$THEME" ]; then
    echo "Applying Hyprland theme: $THEME"
    [ -d "$THEMES_DIR/$THEME/hypr" ] && cp -rf "$THEMES_DIR/$THEME/hypr/"* "$HOME/.config/hypr/" 2>/dev/null || true
    [ -d "$THEMES_DIR/$THEME/waybar" ] && cp -rf "$THEMES_DIR/$THEME/waybar/"* "$HOME/.config/waybar/" 2>/dev/null || true
    [ -d "$THEMES_DIR/$THEME/wofi" ] && cp -rf "$THEMES_DIR/$THEME/wofi/"* "$HOME/.config/wofi/" 2>/dev/null || true
    [ -d "$THEMES_DIR/$THEME/mako" ] && cp -rf "$THEMES_DIR/$THEME/mako/"* "$HOME/.config/mako/" 2>/dev/null || true
    [ -d "$THEMES_DIR/$THEME/kitty" ] && cp -rf "$THEMES_DIR/$THEME/kitty/"* "$HOME/.config/kitty/" 2>/dev/null || true

    hyprctl reload >/dev/null 2>&1 || true
    pkill -f waybar 2>/dev/null || true
    waybar >/dev/null 2>&1 &
    makoctl reload >/dev/null 2>&1 || true
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "Hyprland" "Theme Switched" "Active theme: $THEME" 2>/dev/null || true
    fi
else
    echo "Theme '$THEME' not found in $THEMES_DIR" >&2
    exit 1
fi
SWITCHEOC
    chmod 755 "$u_home/.config/hypr/switch-theme.sh"

    # Set primary active theme
    local primary_theme="${SELECTED_HYPRLAND_THEMES[0]}"
    if [ -d "$u_home/.config/hypr/themes/$primary_theme" ]; then
        echo "Setting initial active Hyprland theme to '$primary_theme'..."
        cp -rf "$u_home/.config/hypr/themes/$primary_theme/hypr/"* "$u_home/.config/hypr/" 2>/dev/null || true
        cp -rf "$u_home/.config/hypr/themes/$primary_theme/waybar/"* "$u_home/.config/waybar/" 2>/dev/null || true
        cp -rf "$u_home/.config/hypr/themes/$primary_theme/wofi/"* "$u_home/.config/wofi/" 2>/dev/null || true
        cp -rf "$u_home/.config/hypr/themes/$primary_theme/mako/"* "$u_home/.config/mako/" 2>/dev/null || true
        cp -rf "$u_home/.config/hypr/themes/$primary_theme/kitty/"* "$u_home/.config/kitty/" 2>/dev/null || true
    fi

    if [ -n "$TARGET_USER" ]; then
        chown -R "$TARGET_USER:$TARGET_USER" "$u_home/.config" 2>/dev/null || true
    fi

    echo "✓ Hyprland theme suite installed in $u_home/.config/ (Active: $primary_theme)"
    echo "  Switch themes anytime via SUPER+SHIFT+T or ~/.config/hypr/switch-theme.sh"
}

mod_zsh() {
    echo "=== [Setup Zsh Shell, Oh My Zsh & Starship Prompt] ==="
    local u_home
    u_home=$(getent passwd "$TARGET_USER" | cut -d: -f6 || echo "/home/$TARGET_USER")
    [ -z "$u_home" ] && u_home="/home/$TARGET_USER"
    
    echo "Installing Zsh dependencies via vpm..."
    pkg_install zsh git curl wget tar unzip starship

    local zsh_bin
    zsh_bin=$(command -v zsh || echo "/usr/bin/zsh")

    if [ ! -d "$u_home/.oh-my-zsh" ] && [ -n "$TARGET_USER" ]; then
        echo "Installing Oh My Zsh for $TARGET_USER..."
        su - "$TARGET_USER" -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>/dev/null || \
        sudo -H -u "$TARGET_USER" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>/dev/null || true
    fi

    local zsh_custom="$u_home/.oh-my-zsh/custom"
    if [ -n "$TARGET_USER" ]; then
        mkdir -p "$zsh_custom/plugins"
        if [ ! -d "$zsh_custom/plugins/zsh-autosuggestions" ]; then
            echo "Cloning zsh-autosuggestions..."
            git clone --quiet https://github.com/zsh-users/zsh-autosuggestions "$zsh_custom/plugins/zsh-autosuggestions" 2>/dev/null || true
        fi

        if [ ! -d "$zsh_custom/plugins/zsh-syntax-highlighting" ]; then
            echo "Cloning zsh-syntax-highlighting..."
            git clone --quiet https://github.com/zsh-users/zsh-syntax-highlighting "$zsh_custom/plugins/zsh-syntax-highlighting" 2>/dev/null || true
        fi
    fi

    if [ -f "$u_home/.zshrc" ]; then
        cp "$u_home/.zshrc" "$u_home/.zshrc.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    fi

    cat << 'ZSH_EOF' > "$u_home/.zshrc"
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set theme
ZSH_THEME="terminalparty"

# Plugins configuration
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# Environment settings
export LANG=en_US.UTF-8
export EDITOR="nano"
export VISUAL="nano"
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

# Void Linux & vpm Aliases
alias update="sudo vpm update"
alias clean="sudo vpm clean all"
alias svs="vpm sv"
alias pkg-install="sudo vpm install"
alias pkg-remove="sudo vpm remove"
alias pkg-search="vpm search"

# Modern CLI Replacement Aliases (eza, bat, ripgrep, fd, duf, btop, vsv)
if command -v eza &>/dev/null; then
    alias ls="eza --icons=auto"
    alias ll="eza -la --icons=auto --git"
    alias la="eza -a --icons=auto"
    alias tree="eza --tree --icons=auto"
fi

if command -v bat &>/dev/null; then
    alias cat="bat --paging=never"
fi

if command -v rg &>/dev/null; then
    alias grep="rg"
fi

if command -v fd &>/dev/null; then
    alias find="fd"
fi

if command -v duf &>/dev/null; then
    alias df="duf"
fi

if command -v btop &>/dev/null; then
    alias top="btop"
    alias htop="btop"
fi

if command -v vsv &>/dev/null; then
    alias services="sudo vsv"
fi

# Sourcing Nix daemon if present on system
if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
    . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
fi

# Starship Prompt Integration
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
fi
ZSH_EOF

    if [ -n "$TARGET_USER" ]; then
        chown -R "$TARGET_USER:$TARGET_USER" "$u_home/.zshrc" "$u_home/.oh-my-zsh" 2>/dev/null || true
        if ! grep -qx "$zsh_bin" /etc/shells; then
            echo "$zsh_bin" >> /etc/shells
        fi
        usermod -s "$zsh_bin" "$TARGET_USER" || true
    fi
    echo "✓ Zsh setup complete for $TARGET_USER"
}

mod_catppuccin() {
    echo "=== [Installing Catppuccin Universal Theme Suite System-Wide] ==="
    pkg_install git curl python3 tar unzip

    local tmp_dir="/tmp/catppuccin_installer_$$"
    mkdir -p "$tmp_dir"

    local share_dir="/usr/share"
    local themes_dir="$share_dir/themes"
    local icons_dir="$share_dir/icons"
    local color_schemes_dir="$share_dir/color-schemes"
    local aurorae_dir="$share_dir/aurorae/themes"
    local lookandfeel_dir="$share_dir/plasma/look-and-feel"
    local kvantum_dir="$share_dir/Kvantum"
    local konsole_dir="$share_dir/konsole"
    local wallpapers_dir="$share_dir/wallpapers/Catppuccin"

    mkdir -p "$themes_dir" "$icons_dir" "$color_schemes_dir" "$aurorae_dir" "$lookandfeel_dir" "$kvantum_dir" "$konsole_dir" "$wallpapers_dir"

    echo "Installing KDE Plasma Themes (Catppuccin)..."
    (
        cd "$tmp_dir"
        git clone --quiet https://github.com/catppuccin/kde.git catppuccin-kde 2>/dev/null || true
        if [ -d "catppuccin-kde" ]; then
            cd catppuccin-kde
            for f in 1 2 3 4; do
                for a in $(seq 1 14); do
                    for w in 1 2; do
                        XDG_DATA_HOME="/usr/share" ./install.sh -q --no-cursor "$f" "$a" "$w" >/dev/null 2>&1 || true
                    done
                done
            done
        fi
    )

    echo "Fetching GTK themes & Cursor releases..."
    python3 - << PYEND
import os, sys, json, urllib.request, zipfile, shutil
from concurrent.futures import ThreadPoolExecutor

themes_dir = "$themes_dir"
icons_dir = "$icons_dir"
tmp_dir = "$tmp_dir"

def fetch_json(repo):
    url = f"https://api.github.com/repos/{repo}/releases/latest"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode())

def download_and_extract(url, target_dir):
    try:
        fname = os.path.basename(url)
        zpath = os.path.join(tmp_dir, fname)
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req) as resp, open(zpath, 'wb') as f:
            shutil.copyfileobj(resp, f)
        with zipfile.ZipFile(zpath, 'r') as zf:
            zf.extractall(target_dir)
        os.remove(zpath)
        return True
    except Exception:
        return False

try:
    data = fetch_json('catppuccin/gtk')
    urls = [a['browser_download_url'] for a in data.get('assets', []) if a['name'].endswith('.zip')]
    with ThreadPoolExecutor(max_workers=8) as ex:
        list(ex.map(lambda u: download_and_extract(u, themes_dir), urls))
except Exception:
    pass

try:
    data = fetch_json('catppuccin/cursors')
    urls = [a['browser_download_url'] for a in data.get('assets', []) if a['name'].endswith('.zip')]
    with ThreadPoolExecutor(max_workers=8) as ex:
        list(ex.map(lambda u: download_and_extract(u, icons_dir), urls))
except Exception:
    pass
PYEND

    (
        cd "$tmp_dir"
        git clone --quiet https://github.com/catppuccin/Kvantum.git catppuccin-kvantum 2>/dev/null || true
        if [ -d "catppuccin-kvantum/themes" ]; then
            cp -r catppuccin-kvantum/themes/catppuccin* "$kvantum_dir/" 2>/dev/null || true
        fi
    )

    (
        cd "$tmp_dir"
        git clone --quiet https://github.com/catppuccin/konsole.git catppuccin-konsole 2>/dev/null || true
        if [ -d "catppuccin-konsole/themes" ]; then
            cp catppuccin-konsole/themes/*.colorscheme "$konsole_dir/" 2>/dev/null || true
        fi
    )

    (
        cd "$tmp_dir"
        git clone --quiet https://github.com/catppuccin/papirus-folders.git catppuccin-papirus 2>/dev/null || true
        if [ -d "catppuccin-papirus/src" ]; then
            cp -r catppuccin-papirus/src/* "$icons_dir/" 2>/dev/null || true
        fi
    )

    python3 - << PYEND
import os, sys, urllib.request, zipfile, shutil

wpath = "$wallpapers_dir"
zpath = os.path.join("$tmp_dir", "wallpapers.zip")
tmp_ext = os.path.join("$tmp_dir", "w_extract")

try:
    url = "https://github.com/zhichaoh/catppuccin-wallpapers/archive/refs/heads/main.zip"
    urllib.request.urlretrieve(url, zpath)
    with zipfile.ZipFile(zpath, 'r') as zf:
        zf.extractall(tmp_ext)
    for root, _, files in os.walk(tmp_ext):
        for f in files:
            if f.lower().endswith(('.png', '.jpg', '.jpeg', '.svg', '.webp')):
                src = os.path.join(root, f)
                rel = os.path.relpath(src, tmp_ext)
                rel_parts = rel.split(os.sep)[1:]
                if rel_parts:
                    dest = os.path.join(wpath, *rel_parts)
                    os.makedirs(os.path.dirname(dest), exist_ok=True)
                    shutil.copy(src, dest)
except Exception:
    pass
PYEND

    rm -rf "$tmp_dir"
    echo "✓ Catppuccin Universal Theme Suite installed system-wide!"
}

mod_realtime_audio() {
    echo "=== Installing PipeWire Low-Latency & Realtime Audio Optimizations ==="
    pkg_install rtkit
    service_enable rtkit 2>/dev/null || true

    mkdir -p /etc/security/limits.d
    cat << 'EOF' > /etc/security/limits.d/99-realtime.conf
@realtime - rtprio 98
@realtime - memlock unlimited
@realtime - nice -11
EOF

    if [ -n "$TARGET_USER" ] && id "$TARGET_USER" >/dev/null 2>&1; then
        groupadd -r realtime 2>/dev/null || true
        usermod -aG realtime,audio "$TARGET_USER" || true
    fi
    echo "✓ Realtime audio permissions and rtkit daemon configured."
}

mod_flatpak_themes() {
    echo "=== Configuring Flatpak GTK/Qt & Catppuccin Theme Synchronization ==="
    if command -v flatpak >/dev/null 2>&1; then
        flatpak override --system --filesystem=xdg-config/gtk-3.0:ro 2>/dev/null || true
        flatpak override --system --filesystem=xdg-config/gtk-4.0:ro 2>/dev/null || true
        flatpak override --system --filesystem=/usr/share/themes:ro 2>/dev/null || true
        flatpak override --system --filesystem=/usr/share/icons:ro 2>/dev/null || true
        flatpak override --system --filesystem=/usr/share/fonts:ro 2>/dev/null || true
        flatpak override --system --env=GTK_THEME=Catppuccin-Mocha-Standard-Blue-Dark 2>/dev/null || true
        echo "✓ Flatpak global theme & font overrides applied successfully."
    fi
}

mod_session_config() {
    echo "=== Auto-Configuring Default Session & Display Manager Presets ==="
    mkdir -p /var/lib/AccountsService/users
    if [ -n "$TARGET_USER" ]; then
        local user_acc_file="/var/lib/AccountsService/users/$TARGET_USER"
        if [ ! -f "$user_acc_file" ]; then
            cat << EOF > "$user_acc_file"
[User]
Language=en_US.UTF-8
XSession=gnome
Icon=/home/$TARGET_USER/.face
SystemAccount=false
EOF
            chown root:root "$user_acc_file" 2>/dev/null || true
            chmod 644 "$user_acc_file" 2>/dev/null || true
        fi
    fi
    echo "✓ Default session account preferences generated."
}

mod_maintenance() {
    echo "=== Executing One-Touch System Maintenance & Cleanup ==="
    echo "[1/4] Running system update via vpm..."
    pkg_update

    echo "[2/4] Purging orphaned packages & package cache via vpm clean..."
    if command -v vpm >/dev/null 2>&1; then
        echo y | vpm clean 2>/dev/null || xbps-remove -yo 2>/dev/null || true
    else
        xbps-remove -yo 2>/dev/null || true
    fi

    echo "[3/4] Purging old unused Linux kernel versions via vkpurge..."
    if command -v vkpurge >/dev/null 2>&1; then
        vkpurge rm all || true
    fi

    echo "[4/4] Updating Flatpaks..."
    if command -v flatpak >/dev/null 2>&1; then
        flatpak update -y || true
    fi

    echo "✓ One-touch system maintenance completed successfully!"
}

mod_vpm() {
    echo "=== [Installing / Updating voidPM (vpm) Package Manager Helper] ==="
    local target_bin="/usr/bin/vpm"
    local symlink_bin="/usr/bin/voidpm"
    local tmp_vpm="/tmp/vpm_download_$$"

    if [ -f "$target_bin" ]; then
        echo "[i] Existing $target_bin binary detected. Force-updating to latest upstream build..."
    else
        echo "[i] Fresh installation of $target_bin..."
    fi

    echo "Downloading latest vpm binary from soltros/voidPM repository..."
    
    local download_urls=(
        "https://github.com/soltros/voidPM/releases/latest/download/vpm"
        "https://raw.githubusercontent.com/soltros/voidPM/main/vpm"
    )

    # Query GitHub releases API for specific vpm binary asset
    local release_json
    release_json=$(curl -sSL https://api.github.com/repos/soltros/voidPM/releases/latest 2>/dev/null || echo "")
    if echo "$release_json" | grep -q "browser_download_url"; then
        local api_vpm_url
        api_vpm_url=$(echo "$release_json" | grep "browser_download_url" | grep '/vpm"' | head -n1 | cut -d '"' -f 4 || echo "")
        if [ -n "$api_vpm_url" ]; then
            download_urls=("$api_vpm_url" "${download_urls[@]}")
        fi
    fi

    local downloaded=0
    for url in "${download_urls[@]}"; do
        echo "Fetching binary from: $url"
        rm -f "$tmp_vpm"
        if curl -fsSL "$url" -o "$tmp_vpm" 2>/dev/null && [ -s "$tmp_vpm" ]; then
            chmod +x "$tmp_vpm"
            if "$tmp_vpm" --help >/dev/null 2>&1 || file "$tmp_vpm" 2>/dev/null | grep -q "ELF"; then
                mv -f "$tmp_vpm" "$target_bin"
                chown root:root "$target_bin"
                chmod 755 "$target_bin"
                ln -sf "$target_bin" "$symlink_bin"
                echo "✓ voidPM (vpm) installed successfully to $target_bin and symlinked to $symlink_bin"
                downloaded=1
                break
            else
                echo "[!] File downloaded from $url is not a valid executable binary. Trying fallback..."
                rm -f "$tmp_vpm"
            fi
        fi
    done

    if [ "$downloaded" -ne 1 ]; then
        echo "[ERROR] Failed to download a valid vpm binary from all sources."
        rm -f "$tmp_vpm"
        return 1
    fi
}

mod_services() {
    echo "=== Configuring Runit System Daemons, Socklog Logging & Permissions ==="
    service_disable dhcpcd

    echo "Installing socklog-void for system logging..."
    pkg_install socklog-void

    for service in dbus elogind NetworkManager tailscaled bluetoothd cupsd avahi-daemon socklog-unix nanoklogd openntpd power-profiles-daemon zramen; do
        if [ -d "/etc/sv/$service" ]; then
            service_enable "$service"
        fi
    done

    sv restart dbus 2>/dev/null || true
    sv restart elogind 2>/dev/null || true

    if [ -n "$TARGET_USER" ] && id "$TARGET_USER" >/dev/null 2>&1; then
        for g in video audio storage network input wheel bluetooth lpadmin socklog kvm; do
            getent group "$g" >/dev/null 2>&1 || groupadd -r "$g" 2>/dev/null || true
            usermod -aG "$g" "$TARGET_USER" 2>/dev/null || true
        done
        su - "$TARGET_USER" -c "xdg-user-dirs-update" 2>/dev/null || true
    fi

    if command -v flatpak >/dev/null 2>&1; then
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
        flatpak update --appstream 2>/dev/null || true
    fi

    if command -v appstreamcli >/dev/null 2>&1; then
        appstreamcli refresh --force 2>/dev/null || true
    fi
}

# --- Selection Dialog Logic ---
show_dialog_checklist() {
    AMD_STATE="OFF"
    INTEL_STATE="OFF"
    NVIDIA_STATE="OFF"
    if [ "$GPU_TYPE" = "AMD" ]; then
        AMD_STATE="ON"
    elif [ "$GPU_TYPE" = "INTEL" ]; then
        INTEL_STATE="ON"
    elif [ "$GPU_TYPE" = "NVIDIA" ]; then
        NVIDIA_STATE="ON"
    else
        AMD_STATE="ON"
    fi

    if command -v dialog >/dev/null 2>&1; then
        CHOICES=$(dialog --clear --stdout --backtitle "Void Linux Installer & Desktop Swapper (GPU: $GPU_TYPE | vpm: active)" \
            --checklist "Select tasks to run (UP/DOWN to scroll, SPACE to check/uncheck, ENTER to confirm):" 28 92 20 \
            "REPOS"              "System: Enable Multilib & Non-Free Repositories" ON \
            "VPM"                "System: Install/Update voidPM (vpm) Binary directly to /usr/bin" ON \
            "GPU_AMD"            "Hardware: AMD GPU Drivers & Mesa VA-API" "$AMD_STATE" \
            "GPU_INTEL"          "Hardware: Intel GPU Drivers & iHD VA-API" "$INTEL_STATE" \
            "GPU_NVIDIA"         "Hardware: NVIDIA GPU Proprietary Drivers & DKMS" "$NVIDIA_STATE" \
            "PORTALS"            "System: XDG Desktop Portals & Core Daemons" ON \
            "AUDIO"              "System: PipeWire Audio Suite & WirePlumber" ON \
            "AUDIO_REALTIME"     "System: PipeWire Realtime Low-Latency Optimizations" ON \
            "KDE"                "Install DE: KDE Plasma 6 & SDDM" OFF \
            "GNOME"              "Install DE: GNOME Shell 48 & GDM" OFF \
            "XFCE"               "Install DE: XFCE 4.20 & LightDM" OFF \
            "CINNAMON"           "Install DE: Cinnamon & LightDM" OFF \
            "MATE"               "Install DE: MATE & LightDM" OFF \
            "LXQT"               "Install DE: LXQt & SDDM" OFF \
            "LXDE"               "Install DE: LXDE & LightDM" OFF \
            "BUDGIE"             "Install DE: Budgie & LightDM" OFF \
            "SWAY"               "Install DE: Sway Wayland & LightDM" OFF \
            "ENLIGHTENMENT"      "Install DE: Enlightenment (E25) & LightDM" OFF \
            "HYPRLAND"           "Install DE: Hyprland Dynamic Tiling Wayland & LightDM" OFF \
            "SWAP_KDE"           "DE SWAP: Purge active DE & switch to KDE Plasma 6" OFF \
            "SWAP_GNOME"         "DE SWAP: Purge active DE & switch to GNOME 48" OFF \
            "SWAP_XFCE"          "DE SWAP: Purge active DE & switch to XFCE 4" OFF \
            "SWAP_CINNAMON"      "DE SWAP: Purge active DE & switch to Cinnamon" OFF \
            "SWAP_MATE"          "DE SWAP: Purge active DE & switch to MATE" OFF \
            "SWAP_LXQT"          "DE SWAP: Purge active DE & switch to LXQt" OFF \
            "SWAP_LXDE"          "DE SWAP: Purge active DE & switch to LXDE" OFF \
            "SWAP_BUDGIE"        "DE SWAP: Purge active DE & switch to Budgie" OFF \
            "SWAP_SWAY"          "DE SWAP: Purge active DE & switch to Sway" OFF \
            "SWAP_ENLIGHTENMENT" "DE SWAP: Purge active DE & switch to Enlightenment" OFF \
            "SWAP_HYPRLAND"      "DE SWAP: Purge active DE & switch to Hyprland" OFF \
            "PURGE_BAREBONES"    "FRESH START: Purge all packages & DEs down to base-barebones" OFF \
            "VOID_TOOLS"         "Tools: Void Power-User Suite (xtools, vsv, octoxbps, btop, fzf, etc.)" ON \
            "APPS"               "Apps: Core Native Applications (VLC, OBS, VSCode, etc.)" ON \
            "GAMING"             "Gaming: Steam, Wine, GameMode & MangoHud" ON \
            "FLATPAKS"           "Apps: Flatpaks (Discord, Bitwarden, Obsidian, etc.)" ON \
            "FLATPAK_THEMES"     "Theme: Sync Host GTK/Qt & Catppuccin to Flatpaks" ON \
            "ZSH"                "Shell: Zsh + Oh My Zsh + Starship & vpm Aliases" ON \
            "CATPPUCCIN"         "Theme: Catppuccin Universal Theme Suite & Wallpapers" ON \
            "HYPRLAND_THEMES"    "Theme: Hyprland Dotfiles & Theme Suite (Mocha, Tokyo, Nord, etc.)" OFF \
            "TAILSCALE"          "Network: Tailscale Mesh VPN" ON \
            "TIME_SYNC"          "System: NTP Time Sync (openntpd)" ON \
            "POWER"              "System: Power Profiles Daemon" ON \
            "TRIM"               "System: Periodic SSD TRIM" ON \
            "FWUPD"              "System: Firmware Update Daemon (LVFS)" ON \
            "LOCALE"             "System: Locale Generation (en_US.UTF-8)" ON \
            "ZRAM"               "System: ZRAM Compressed Swap (zramen)" OFF \
            "FONTS"              "System: TrueType Fonts (Noto & Liberation)" ON \
            "SESSION_CONFIG"     "System: Auto-Configure Default Session Presets" ON \
            "MAINTENANCE"        "System: One-Touch Maintenance (vpm update & clean)" OFF \
            "SERVICES"           "System: Configure Runit Services & Permissions" ON 2>&1) || exit 0

        eval "SELECTED_TASKS=($CHOICES)"

        # Confirm or specify target user in interactive dialog
        prompt_target_user_dialog

        # Check if Hyprland was selected to launch the theme sub-checkbox dialog
        for t in "${SELECTED_TASKS[@]}"; do
            if [ "$t" = "HYPRLAND" ] || [ "$t" = "SWAP_HYPRLAND" ] || [ "$t" = "HYPRLAND_THEMES" ]; then
                show_hyprland_theme_dialog
                break
            fi
        done
    else
        echo "Defaulting to detected GPU tasks ($GPU_TYPE)..."
        SELECTED_TASKS=("REPOS" "VPM" "PORTALS" "AUDIO" "GNOME" "VOID_TOOLS" "APPS" "GAMING" "FLATPAKS" "TAILSCALE" "TIME_SYNC" "POWER" "TRIM" "FWUPD" "LOCALE" "FONTS" "SERVICES")
    fi
}

# CLI Argument parsing
SELECTED_TASKS=()
if [ "$#" -gt 0 ]; then
    for arg in "$@"; do
        case $arg in
            --all)                   SELECTED_TASKS=("REPOS" "VPM" "PORTALS" "AUDIO" "GNOME" "VOID_TOOLS" "APPS" "GAMING" "FLATPAKS" "TAILSCALE" "TIME_SYNC" "POWER" "TRIM" "FWUPD" "LOCALE" "FONTS" "SERVICES") ;;
            --repos)                 SELECTED_TASKS+=("REPOS") ;;
            --vpm)                   SELECTED_TASKS+=("VPM") ;;
            --gpu-amd)               SELECTED_TASKS+=("GPU_AMD") ;;
            --gpu-intel)             SELECTED_TASKS+=("GPU_INTEL") ;;
            --gpu-nvidia)            SELECTED_TASKS+=("GPU_NVIDIA") ;;
            --portals)               SELECTED_TASKS+=("PORTALS") ;;
            --audio)                 SELECTED_TASKS+=("AUDIO") ;;
            --realtime-audio)        SELECTED_TASKS+=("AUDIO_REALTIME") ;;
            --kde)                   SELECTED_TASKS+=("KDE") ;;
            --kde-tools)             SELECTED_TASKS+=("KDE_TOOLS") ;;
            --gnome)                 SELECTED_TASKS+=("GNOME") ;;
            --xfce)                  SELECTED_TASKS+=("XFCE") ;;
            --cinnamon)              SELECTED_TASKS+=("CINNAMON") ;;
            --mate)                  SELECTED_TASKS+=("MATE") ;;
            --lxqt)                  SELECTED_TASKS+=("LXQT") ;;
            --lxde)                  SELECTED_TASKS+=("LXDE") ;;
            --budgie)                SELECTED_TASKS+=("BUDGIE") ;;
            --sway)                  SELECTED_TASKS+=("SWAY") ;;
            --enlightenment)         SELECTED_TASKS+=("ENLIGHTENMENT") ;;
            --hyprland)              SELECTED_TASKS+=("HYPRLAND") ;;
            --swap-to-kde)           SELECTED_TASKS+=("SWAP_KDE") ;;
            --swap-to-gnome)         SELECTED_TASKS+=("SWAP_GNOME") ;;
            --swap-to-xfce)          SELECTED_TASKS+=("SWAP_XFCE") ;;
            --swap-to-cinnamon)      SELECTED_TASKS+=("SWAP_CINNAMON") ;;
            --swap-to-mate)          SELECTED_TASKS+=("SWAP_MATE") ;;
            --swap-to-lxqt)          SELECTED_TASKS+=("SWAP_LXQT") ;;
            --swap-to-lxde)          SELECTED_TASKS+=("SWAP_LXDE") ;;
            --swap-to-budgie)        SELECTED_TASKS+=("SWAP_BUDGIE") ;;
            --swap-to-sway)          SELECTED_TASKS+=("SWAP_SWAY") ;;
            --swap-to-enlightenment) SELECTED_TASKS+=("SWAP_ENLIGHTENMENT") ;;
            --swap-to-hyprland)      SELECTED_TASKS+=("SWAP_HYPRLAND") ;;
            --barebones|--fresh-start|--purge-to-barebones) SELECTED_TASKS+=("PURGE_BAREBONES") ;;
            --void-tools|--community-tools) SELECTED_TASKS+=("VOID_TOOLS") ;;
            --apps)                  SELECTED_TASKS+=("APPS") ;;
            --gaming)                SELECTED_TASKS+=("GAMING") ;;
            --flatpaks)              SELECTED_TASKS+=("FLATPAKS") ;;
            --flatpak-themes)        SELECTED_TASKS+=("FLATPAK_THEMES") ;;
            --zsh)                   SELECTED_TASKS+=("ZSH") ;;
            --catppuccin)            SELECTED_TASKS+=("CATPPUCCIN") ;;
            --hyprland-themes)       SELECTED_TASKS+=("HYPRLAND_THEMES") ;;
            --hyprland-theme=*)
                tval="${arg#*=}"
                if [ "$tval" = "all" ]; then
                    SELECTED_HYPRLAND_THEMES=("catppuccin" "tokyo-night" "nord" "gruvbox" "cyberpunk")
                else
                    SELECTED_HYPRLAND_THEMES=("$tval")
                fi
                SELECTED_TASKS+=("HYPRLAND_THEMES")
                ;;
            --user=*|--target-user=*)
                TARGET_USER="${arg#*=}"
                ;;
            --tailscale)             SELECTED_TASKS+=("TAILSCALE") ;;
            --time-sync)             SELECTED_TASKS+=("TIME_SYNC") ;;
            --power)                 SELECTED_TASKS+=("POWER") ;;
            --trim)                  SELECTED_TASKS+=("TRIM") ;;
            --fwupd)                 SELECTED_TASKS+=("FWUPD") ;;
            --locale)                SELECTED_TASKS+=("LOCALE") ;;
            --zram)                  SELECTED_TASKS+=("ZRAM") ;;
            --fonts)                 SELECTED_TASKS+=("FONTS") ;;
            --session-config)        SELECTED_TASKS+=("SESSION_CONFIG") ;;
            --maintenance)           SELECTED_TASKS+=("MAINTENANCE") ;;
            --services)              SELECTED_TASKS+=("SERVICES") ;;
            --gui|--dialog)          show_dialog_checklist ;;
            -h|--help)               print_usage; exit 0 ;;
            *)
                echo "Unknown option: $arg" >&2
                print_usage
                exit 1
                ;;
        esac
    done
fi

if [ "${#SELECTED_TASKS[@]}" -eq 0 ]; then
    show_dialog_checklist
fi

# Canonical execution order to satisfy module prerequisites
CANONICAL_TASKS=(
    "REPOS"
    "VPM"
    "LOCALE"
    "TIME_SYNC"
    "POWER"
    "ZRAM"
    "TRIM"
    "FWUPD"
    "GPU_AMD"
    "GPU_INTEL"
    "GPU_NVIDIA"
    "PORTALS"
    "AUDIO"
    "AUDIO_REALTIME"
    "PURGE_BAREBONES"
    "SWAP_KDE"
    "SWAP_GNOME"
    "SWAP_XFCE"
    "SWAP_CINNAMON"
    "SWAP_MATE"
    "SWAP_LXQT"
    "SWAP_LXDE"
    "SWAP_BUDGIE"
    "SWAP_SWAY"
    "SWAP_ENLIGHTENMENT"
    "SWAP_HYPRLAND"
    "KDE"
    "KDE_TOOLS"
    "GNOME"
    "XFCE"
    "CINNAMON"
    "MATE"
    "LXQT"
    "LXDE"
    "BUDGIE"
    "SWAY"
    "ENLIGHTENMENT"
    "HYPRLAND"
    "HYPRLAND_THEMES"
    "FONTS"
    "VOID_TOOLS"
    "APPS"
    "GAMING"
    "FLATPAKS"
    "FLATPAK_THEMES"
    "CATPPUCCIN"
    "ZSH"
    "TAILSCALE"
    "SESSION_CONFIG"
    "SERVICES"
    "MAINTENANCE"
)

EXECUTION_PLAN=()
for canon in "${CANONICAL_TASKS[@]}"; do
    for sel in "${SELECTED_TASKS[@]}"; do
        if [ "$canon" = "$sel" ]; then
            EXECUTION_PLAN+=("$canon")
            break
        fi
    done
done

clear 2>/dev/null || true
echo ""
echo "Detected Hardware GPU: $GPU_TYPE"
echo "Target Configuration User: $TARGET_USER"
echo "Executing selected installation modules: ${EXECUTION_PLAN[*]}"
echo ""

for task in "${EXECUTION_PLAN[@]}"; do
    case "$task" in
        REPOS)              mod_repos ;;
        VPM)                mod_vpm ;;
        LOCALE)             mod_locale ;;
        TIME_SYNC)          mod_time_sync ;;
        POWER)              mod_power ;;
        ZRAM)               mod_zram ;;
        TRIM)               mod_trim ;;
        FWUPD)              mod_fwupd ;;
        GPU_AMD)            mod_gpu_amd ;;
        GPU_INTEL)          mod_gpu_intel ;;
        GPU_NVIDIA)         mod_gpu_nvidia ;;
        PORTALS)            mod_portals ;;
        AUDIO)              mod_audio ;;
        AUDIO_REALTIME)     mod_realtime_audio ;;
        PURGE_BAREBONES)    mod_purge_to_barebones ;;
        SWAP_KDE)           mod_swap_to_kde ;;
        SWAP_GNOME)         mod_swap_to_gnome ;;
        SWAP_XFCE)          mod_swap_to_xfce ;;
        SWAP_CINNAMON)      mod_swap_to_cinnamon ;;
        SWAP_MATE)          mod_swap_to_mate ;;
        SWAP_LXQT)          mod_swap_to_lxqt ;;
        SWAP_LXDE)          mod_swap_to_lxde ;;
        SWAP_BUDGIE)        mod_swap_to_budgie ;;
        SWAP_SWAY)          mod_swap_to_sway ;;
        SWAP_ENLIGHTENMENT) mod_swap_to_enlightenment ;;
        SWAP_HYPRLAND)      mod_swap_to_hyprland ;;
        KDE)                mod_kde ;;
        KDE_TOOLS)          mod_kde_tools ;;
        GNOME)              mod_gnome ;;
        XFCE)               mod_xfce ;;
        CINNAMON)           mod_cinnamon ;;
        MATE)               mod_mate ;;
        LXQT)               mod_lxqt ;;
        LXDE)               mod_lxde ;;
        BUDGIE)             mod_budgie ;;
        SWAY)               mod_sway ;;
        ENLIGHTENMENT)      mod_enlightenment ;;
        HYPRLAND)           mod_hyprland ;;
        HYPRLAND_THEMES)    install_hyprland_themes ;;
        FONTS)              mod_fonts ;;
        VOID_TOOLS)         mod_void_tools ;;
        APPS)               mod_apps ;;
        GAMING)             mod_gaming ;;
        FLATPAKS)           mod_flatpaks ;;
        FLATPAK_THEMES)     mod_flatpak_themes ;;
        CATPPUCCIN)         mod_catppuccin ;;
        ZSH)                mod_zsh ;;
        TAILSCALE)          mod_tailscale ;;
        SESSION_CONFIG)     mod_session_config ;;
        SERVICES)           mod_services ;;
        MAINTENANCE)        mod_maintenance ;;
    esac
done

echo "========================================================"
echo " Selected tasks executed successfully!"
echo " Reboot your system (sudo reboot) if you modified DE/drivers."
echo "========================================================"
