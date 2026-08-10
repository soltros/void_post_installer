#!/usr/bin/env bash
set -eo pipefail

echo "========================================================"
echo " Modular Void Linux Desktop & Gaming Installer (dialog)"
echo " Integrated with voidPM (vpm) - Multi-DE Support"
echo "========================================================"

# Check root privilege
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root (or via sudo)." >&2
    exit 1
fi

# Ensure dialog is installed
if ! command -v dialog >/dev/null 2>&1; then
    echo "Installing dialog..."
    if command -v vpm >/dev/null 2>&1; then
        echo y | vpm install dialog
    else
        xbps-install -Sy dialog
    fi
fi

# Helper functions leveraging voidPM (vpm)
pkg_install() {
    if command -v vpm >/dev/null 2>&1; then
        echo y | vpm install "$@"
    else
        xbps-install -y "$@"
    fi
}

pkg_update() {
    if command -v vpm >/dev/null 2>&1; then
        echo y | vpm update
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
        ln -sf "/etc/sv/$sname" /var/service/
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
if [ "$TARGET_USER" = "root" ]; then
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
}

mod_gpu_intel() {
    echo "=== Installing Intel GPU Drivers & Video Acceleration ==="
    pkg_install \
        xorg-minimal \
        xf86-input-libinput \
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
    fi
    if [ -f /usr/share/examples/wireplumber/20-pipewire-pulse.conf ]; then
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
        xfce4 xfce4-goodies xfce4-terminal thunar ristretto catfish xfburn xfce4-panel xfce4-session xfdesktop xfwm4 \
        xfce4-settings xfce4-power-manager xfce4-appfinder xfce4-notifyd xfce4-pulseaudio-plugin xfce4-whiskermenu-plugin garcon exo
}

mod_cinnamon() {
    echo "=== Installing Cinnamon Desktop & LightDM ==="
    setup_lightdm
    pkg_install \
        cinnamon cinnamon-apps nemo cinnamon-screensaver cinnamon-control-center cinnamon-session cjs muffin cinnamon-desktop cinnamon-translations cinnamon-menus gnome-terminal
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
        lxqt sddm qterminal pcmanfm-qt lximage-qt pavucontrol-qt featherpad screengrab lxqt-archiver lxqt-panel lxqt-session lxqt-runner lxqt-config lxqt-notificationd lxqt-policykit lxqt-powermanagement xdg-desktop-portal-lxqt
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
        sway swaybg swaylock swayidle waybar foot wofi grim slurp mako polkit-gnome xdg-desktop-portal-wlr
}

mod_enlightenment() {
    echo "=== Installing Enlightenment (E25) & LightDM ==="
    setup_lightdm
    pkg_install \
        enlightenment terminology econnman evisum elementary
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
        xfce4 xfce4-goodies xfce4-terminal thunar ristretto catfish xfburn xfce4-panel xfce4-session xfdesktop xfwm4 \
        xfce4-settings xfce4-power-manager xfce4-appfinder xfce4-notifyd xfce4-pulseaudio-plugin xfce4-whiskermenu-plugin garcon exo
}

purge_cinnamon_packages() {
    echo "Purging Cinnamon packages..."
    pkg_remove \
        cinnamon cinnamon-apps nemo cinnamon-screensaver cinnamon-control-center cinnamon-session cjs muffin cinnamon-desktop cinnamon-translations cinnamon-menus
}

purge_mate_packages() {
    echo "Purging MATE packages..."
    pkg_remove \
        mate mate-extra caja pluma eom atril mate-terminal mate-media mate-control-center mate-session-manager mate-panel marco mate-desktop mate-menus mate-calc mate-system-monitor
}

purge_lxqt_packages() {
    echo "Purging LXQt packages..."
    pkg_remove \
        lxqt qterminal pcmanfm-qt lximage-qt pavucontrol-qt featherpad screengrab lxqt-archiver lxqt-panel lxqt-session lxqt-runner lxqt-config lxqt-notificationd lxqt-policykit lxqt-powermanagement xdg-desktop-portal-lxqt
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
        sway swaybg swaylock swayidle waybar foot wofi grim slurp mako xdg-desktop-portal-wlr
}

purge_enlightenment_packages() {
    echo "Purging Enlightenment packages..."
    pkg_remove \
        enlightenment terminology econnman evisum elementary
}

run_orphan_clean() {
    if command -v vpm >/dev/null 2>&1; then
        echo "Cleaning orphaned packages via vpm clean..."
        echo y | vpm clean 2>/dev/null || xbps-remove -yo 2>/dev/null || true
    else
        xbps-remove -yo 2>/dev/null || true
    fi
}

# --- Desktop Environment Swap Modules ---

mod_swap_to_kde() {
    echo "=== [Desktop Swap] Swapping Desktop Environment to KDE Plasma ==="
    stop_all_display_managers
    purge_gnome_packages; purge_xfce_packages; purge_cinnamon_packages; purge_mate_packages
    purge_lxqt_packages; purge_lxde_packages; purge_budgie_packages; purge_sway_packages; purge_enlightenment_packages
    run_orphan_clean
    mod_kde
    service_enable sddm
    echo "Desktop environment swapped to KDE Plasma! Please reboot."
}

mod_swap_to_gnome() {
    echo "=== [Desktop Swap] Swapping Desktop Environment to GNOME ==="
    stop_all_display_managers
    purge_kde_packages; purge_xfce_packages; purge_cinnamon_packages; purge_mate_packages
    purge_lxqt_packages; purge_lxde_packages; purge_budgie_packages; purge_sway_packages; purge_enlightenment_packages
    run_orphan_clean
    mod_gnome
    service_enable gdm
    echo "Desktop environment swapped to GNOME! Please reboot."
}

mod_swap_to_xfce() {
    echo "=== [Desktop Swap] Swapping Desktop Environment to XFCE ==="
    stop_all_display_managers
    purge_kde_packages; purge_gnome_packages; purge_cinnamon_packages; purge_mate_packages
    purge_lxqt_packages; purge_lxde_packages; purge_budgie_packages; purge_sway_packages; purge_enlightenment_packages
    run_orphan_clean
    mod_xfce
    service_enable lightdm
    echo "Desktop environment swapped to XFCE! Please reboot."
}

mod_swap_to_cinnamon() {
    echo "=== [Desktop Swap] Swapping Desktop Environment to Cinnamon ==="
    stop_all_display_managers
    purge_kde_packages; purge_gnome_packages; purge_xfce_packages; purge_mate_packages
    purge_lxqt_packages; purge_lxde_packages; purge_budgie_packages; purge_sway_packages; purge_enlightenment_packages
    run_orphan_clean
    mod_cinnamon
    service_enable lightdm
    echo "Desktop environment swapped to Cinnamon! Please reboot."
}

mod_swap_to_mate() {
    echo "=== [Desktop Swap] Swapping Desktop Environment to MATE ==="
    stop_all_display_managers
    purge_kde_packages; purge_gnome_packages; purge_xfce_packages; purge_cinnamon_packages
    purge_lxqt_packages; purge_lxde_packages; purge_budgie_packages; purge_sway_packages; purge_enlightenment_packages
    run_orphan_clean
    mod_mate
    service_enable lightdm
    echo "Desktop environment swapped to MATE! Please reboot."
}

mod_swap_to_lxqt() {
    echo "=== [Desktop Swap] Swapping Desktop Environment to LXQt ==="
    stop_all_display_managers
    purge_kde_packages; purge_gnome_packages; purge_xfce_packages; purge_cinnamon_packages
    purge_mate_packages; purge_lxde_packages; purge_budgie_packages; purge_sway_packages; purge_enlightenment_packages
    run_orphan_clean
    mod_lxqt
    service_enable sddm
    echo "Desktop environment swapped to LXQt! Please reboot."
}

mod_swap_to_lxde() {
    echo "=== [Desktop Swap] Swapping Desktop Environment to LXDE ==="
    stop_all_display_managers
    purge_kde_packages; purge_gnome_packages; purge_xfce_packages; purge_cinnamon_packages
    purge_mate_packages; purge_lxqt_packages; purge_budgie_packages; purge_sway_packages; purge_enlightenment_packages
    run_orphan_clean
    mod_lxde
    service_enable lightdm
    echo "Desktop environment swapped to LXDE! Please reboot."
}

mod_swap_to_budgie() {
    echo "=== [Desktop Swap] Swapping Desktop Environment to Budgie ==="
    stop_all_display_managers
    purge_kde_packages; purge_gnome_packages; purge_xfce_packages; purge_cinnamon_packages
    purge_mate_packages; purge_lxqt_packages; purge_lxde_packages; purge_sway_packages; purge_enlightenment_packages
    run_orphan_clean
    mod_budgie
    service_enable lightdm
    echo "Desktop environment swapped to Budgie! Please reboot."
}

mod_swap_to_sway() {
    echo "=== [Desktop Swap] Swapping Desktop Environment to Sway ==="
    stop_all_display_managers
    purge_kde_packages; purge_gnome_packages; purge_xfce_packages; purge_cinnamon_packages
    purge_mate_packages; purge_lxqt_packages; purge_lxde_packages; purge_budgie_packages; purge_enlightenment_packages
    run_orphan_clean
    mod_sway
    service_enable lightdm
    echo "Desktop environment swapped to Sway! Please reboot."
}

mod_swap_to_enlightenment() {
    echo "=== [Desktop Swap] Swapping Desktop Environment to Enlightenment ==="
    stop_all_display_managers
    purge_kde_packages; purge_gnome_packages; purge_xfce_packages; purge_cinnamon_packages
    purge_mate_packages; purge_lxqt_packages; purge_lxde_packages; purge_budgie_packages; purge_sway_packages
    run_orphan_clean
    mod_enlightenment
    service_enable lightdm
    echo "Desktop environment swapped to Enlightenment! Please reboot."
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

mod_fonts() {
    echo "=== Installing TrueType Fonts ==="
    pkg_install noto-fonts-ttf noto-fonts-cjk noto-fonts-emoji liberation-fonts-ttf
}

mod_zsh() {
    echo "=== [Setup Zsh Shell, Oh My Zsh & Starship Prompt] ==="
    local u_home
    u_home=$(getent passwd "$TARGET_USER" | cut -d: -f6 || echo "/home/$TARGET_USER")
    
    echo "Installing Zsh dependencies via vpm..."
    pkg_install zsh git curl wget tar unzip starship

    local zsh_bin
    zsh_bin=$(command -v zsh || echo "/usr/bin/zsh")

    if [ ! -d "$u_home/.oh-my-zsh" ]; then
        echo "Installing Oh My Zsh for $TARGET_USER..."
        sudo -H -u "$TARGET_USER" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true
    fi

    local zsh_custom="$u_home/.oh-my-zsh/custom"
    sudo -H -u "$TARGET_USER" mkdir -p "$zsh_custom/plugins"

    if [ ! -d "$zsh_custom/plugins/zsh-autosuggestions" ]; then
        echo "Cloning zsh-autosuggestions..."
        sudo -H -u "$TARGET_USER" git clone https://github.com/zsh-users/zsh-autosuggestions "$zsh_custom/plugins/zsh-autosuggestions" || true
    fi

    if [ ! -d "$zsh_custom/plugins/zsh-syntax-highlighting" ]; then
        echo "Cloning zsh-syntax-highlighting..."
        sudo -H -u "$TARGET_USER" git clone https://github.com/zsh-users/zsh-syntax-highlighting "$zsh_custom/plugins/zsh-syntax-highlighting" || true
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

# Sourcing Nix daemon if present on system
if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
    . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
fi

# Starship Prompt Integration
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
fi
ZSH_EOF

    chown "$TARGET_USER:$TARGET_USER" "$u_home/.zshrc" 2>/dev/null || true

    if ! grep -qx "$zsh_bin" /etc/shells; then
        echo "$zsh_bin" >> /etc/shells
    fi

    usermod -s "$zsh_bin" "$TARGET_USER" || true
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
                        ./install.sh -q --no-cursor "$f" "$a" "$w" >/dev/null 2>&1 || true
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
    pkg_install rtkit realtime-privileges
    service_enable rtkit 2>/dev/null || true

    mkdir -p /etc/security/limits.d
    cat << 'EOF' > /etc/security/limits.d/99-realtime.conf
@realtime - rtprio 98
@realtime - memlock unlimited
@realtime - nice -11
EOF

    if [ -n "$TARGET_USER" ] && id "$TARGET_USER" >/dev/null 2>&1; then
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
        flatpak override --system --env=GTK_THEME=Catppuccin-Mocha-Standard-Blue-Dark 2>/dev/null || true
        echo "✓ Flatpak global theme overrides applied successfully."
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
    local tmp_vpm="/tmp/vpm_download_$$"

    if [ -f "$target_bin" ]; then
        echo "[i] Existing $target_bin binary detected. Force-updating to latest upstream build..."
    else
        echo "[i] Fresh installation of $target_bin..."
    fi

    echo "Downloading latest vpm binary from soltros/voidPM repository..."
    
    local download_url=""
    local release_json
    release_json=$(curl -sSL https://api.github.com/repos/soltros/voidPM/releases/latest 2>/dev/null || echo "")
    if echo "$release_json" | grep -q "browser_download_url"; then
        download_url=$(echo "$release_json" | grep "browser_download_url" | head -n1 | cut -d '"' -f 4)
    fi

    if [ -z "$download_url" ]; then
        download_url="https://raw.githubusercontent.com/soltros/voidPM/main/vpm"
    fi

    echo "Fetching binary from: $download_url"
    curl -fsSL "$download_url" -o "$tmp_vpm"

    if [ -s "$tmp_vpm" ]; then
        chmod +x "$tmp_vpm"
        mv -f "$tmp_vpm" "$target_bin"
        chown root:root "$target_bin"
        chmod 755 "$target_bin"
        echo "✓ voidPM (vpm) force-updated & installed successfully to $target_bin"
    else
        echo "[ERROR] Failed to download vpm binary from $download_url"
        rm -f "$tmp_vpm"
        return 1
    fi
}



mod_services() {
    echo "=== Configuring Runit System Daemons & Permissions via vpm ==="
    service_disable dhcpcd

    for service in dbus elogind NetworkManager tailscaled bluetoothd cupsd avahi-daemon; do
        if [ -d "/etc/sv/$service" ]; then
            service_enable "$service"
        fi
    done

    sv restart dbus || true
    sv restart elogind || true

    if [ -n "$TARGET_USER" ] && id "$TARGET_USER" >/dev/null 2>&1; then
        usermod -aG video,audio,storage,network,input,wheel,bluetooth,lpadmin "$TARGET_USER" || true
        su - "$TARGET_USER" -c "xdg-user-dirs-update" || true
    fi

    if command -v flatpak >/dev/null 2>&1; then
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
        flatpak update --appstream || true
    fi

    if command -v appstreamcli >/dev/null 2>&1; then
        appstreamcli refresh --force || true
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
            --checklist "Select tasks to run (UP/DOWN to scroll, SPACE to check/uncheck, ENTER to confirm):" 28 92 19 \
            "REPOS"              "System: Enable Multilib & Non-Free Repositories" ON \
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
            "APPS"               "Apps: Core Native Applications (VLC, OBS, VSCode, etc.)" ON \
            "GAMING"             "Gaming: Steam, Wine, GameMode & MangoHud" ON \
            "FLATPAKS"           "Apps: Flatpaks (Discord, Bitwarden, Obsidian, etc.)" ON \
            "FLATPAK_THEMES"     "Theme: Sync Host GTK/Qt & Catppuccin to Flatpaks" ON \
            "ZSH"                "Shell: Zsh + Oh My Zsh + Starship & vpm Aliases" ON \
            "CATPPUCCIN"         "Theme: Catppuccin Universal Theme Suite & Wallpapers" ON \
            "VPM"                "System: Install voidPM (vpm) Binary directly to /usr/bin" ON \
            "TAILSCALE"          "Network: Tailscale Mesh VPN" ON \
            "FONTS"              "System: TrueType Fonts (Noto & Liberation)" ON \
            "SESSION_CONFIG"     "System: Auto-Configure Default Session Presets" ON \
            "MAINTENANCE"        "System: One-Touch Maintenance (vpm update & clean)" OFF \
            "SERVICES"           "System: Configure Runit Services & Permissions" ON 2>&1) || exit 0


        eval "SELECTED_TASKS=($CHOICES)"
    else
        echo "Defaulting to detected GPU tasks ($GPU_TYPE)..."
        SELECTED_TASKS=("REPOS" "PORTALS" "AUDIO" "GNOME" "APPS" "GAMING" "FLATPAKS" "TAILSCALE" "FONTS" "SERVICES")
    fi
}

# CLI Argument parsing
if [ "$#" -gt 0 ]; then
    for arg in "$@"; do
        case $arg in
            --all)                   SELECTED_TASKS=("REPOS" "PORTALS" "AUDIO" "GNOME" "APPS" "GAMING" "FLATPAKS" "TAILSCALE" "FONTS" "SERVICES") ;;
            --kde)                   SELECTED_TASKS+=("KDE") ;;
            --gnome)                 SELECTED_TASKS+=("GNOME") ;;
            --xfce)                  SELECTED_TASKS+=("XFCE") ;;
            --cinnamon)              SELECTED_TASKS+=("CINNAMON") ;;
            --mate)                  SELECTED_TASKS+=("MATE") ;;
            --lxqt)                  SELECTED_TASKS+=("LXQT") ;;
            --lxde)                  SELECTED_TASKS+=("LXDE") ;;
            --budgie)                SELECTED_TASKS+=("BUDGIE") ;;
            --sway)                  SELECTED_TASKS+=("SWAY") ;;
            --enlightenment)         SELECTED_TASKS+=("ENLIGHTENMENT") ;;
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
            --gpu-amd)               SELECTED_TASKS+=("GPU_AMD") ;;
            --gpu-intel)             SELECTED_TASKS+=("GPU_INTEL") ;;
            --gpu-nvidia)            SELECTED_TASKS+=("GPU_NVIDIA") ;;
            --flatpaks)              SELECTED_TASKS+=("FLATPAKS") ;;
            --flatpak-themes)        SELECTED_TASKS+=("FLATPAK_THEMES") ;;
            --gaming)                SELECTED_TASKS+=("GAMING") ;;
            --zsh)                   SELECTED_TASKS+=("ZSH") ;;
            --catppuccin)            SELECTED_TASKS+=("CATPPUCCIN") ;;
            --vpm)                   SELECTED_TASKS+=("VPM") ;;
            --audio)                 SELECTED_TASKS+=("AUDIO") ;;
            --realtime-audio)        SELECTED_TASKS+=("AUDIO_REALTIME") ;;
            --session-config)        SELECTED_TASKS+=("SESSION_CONFIG") ;;
            --maintenance)           SELECTED_TASKS+=("MAINTENANCE") ;;
            --gui|--dialog)          show_dialog_checklist ;;

        esac
    done
fi

if [ "${#SELECTED_TASKS[@]}" -eq 0 ]; then
    show_dialog_checklist
fi

clear 2>/dev/null || true
echo ""
echo "Detected Hardware GPU: $GPU_TYPE"
echo "Executing selected installation modules: ${SELECTED_TASKS[*]}"
echo ""

for task in "${SELECTED_TASKS[@]}"; do
    case "$task" in
        REPOS)              mod_repos ;;
        GPU_AMD)            mod_gpu_amd ;;
        GPU_INTEL)          mod_gpu_intel ;;
        GPU_NVIDIA)         mod_gpu_nvidia ;;
        PORTALS)            mod_portals ;;
        AUDIO)              mod_audio ;;
        AUDIO_REALTIME)     mod_realtime_audio ;;
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
        APPS)               mod_apps ;;
        GAMING)             mod_gaming ;;
        FLATPAKS)           mod_flatpaks ;;
        FLATPAK_THEMES)     mod_flatpak_themes ;;
        ZSH)                mod_zsh ;;
        CATPPUCCIN)         mod_catppuccin ;;
        VPM)                mod_vpm ;;
        TAILSCALE)          mod_tailscale ;;
        FONTS)              mod_fonts ;;
        SESSION_CONFIG)     mod_session_config ;;
        MAINTENANCE)        mod_maintenance ;;
        SERVICES)           mod_services ;;
    esac
done



echo "========================================================"
echo " Selected tasks executed successfully!"
echo " Reboot your system (sudo reboot) if you modified DE/drivers."
echo "========================================================"
