#!/bin/bash
################################################################################
# Hyprland Installer - Minimal Output Edition
# Unified installer for AMD/Nvidia/Intel GPUs with simplified progress output
################################################################################

set -euo pipefail

################################################################################
# COLORS & STYLES
################################################################################

RST="\e[0m"
BLK="\e[30m"; RED="\e[31m"; GRN="\e[32m"; YLW="\e[33m"
BLU="\e[34m"; MAG="\e[35m"; CYN="\e[36m"; WHT="\e[37m"
BBLK="\e[90m"; BRED="\e[91m"; BGRN="\e[92m"; BYLW="\e[93m"
BBLU="\e[94m"; BMAG="\e[95m"; BCYN="\e[96m"; BWHT="\e[97m"
BLD="\e[1m"; DIM="\e[2m"; ITL="\e[3m"; UND="\e[4m"

STEP=0
TOTAL_STEPS=10

################################################################################
# HELPER FUNCTIONS
################################################################################

_cols() { tput cols 2>/dev/null || echo 80; }

hr() {
    local cols=$(_cols)
    echo -e "${BBLK}$(printf "%${cols}s" | tr ' ' "─")${RST}"
}

center() {
    local text="$1"
    local raw; raw=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local len=${#raw}
    local cols=$(_cols)
    local pad=$(( (cols - len) / 2 ))
    [[ $pad -lt 0 ]] && pad=0
    printf "%${pad}s" ""
    echo -e "$text"
}

spinner() {
    local pid=$1 msg="$2"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    tput civis 2>/dev/null || true
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r    ${BCYN}${frames[$i]}${RST}  ${DIM}${msg}${RST}\033[K"
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.07
    done
    tput cnorm 2>/dev/null || true
    printf "\r"
}

print_banner() {
    clear
    echo ""
    echo ""
    center "${BLD}${BCYN}hyprland${RST}${BLD}${BBLK} · arch linux · 2026${RST}"
    echo ""
    center "${DIM}${BBLK}automated desktop environment installer${RST}"
    echo ""
    echo ""
    hr
    echo ""
}

print_phase() {
    STEP=$((STEP + 1))
    local title="$1"
    local pct=$(( STEP * 100 / TOTAL_STEPS ))
    local done_blocks=$(( STEP * 20 / TOTAL_STEPS ))
    local todo_blocks=$(( 20 - done_blocks ))
    local bar="${BCYN}$(printf '%0.s▪' $(seq 1 $done_blocks))${RST}${BBLK}$(printf '%0.s▫' $(seq 1 $todo_blocks))${RST}"

    echo -e "  ${bar}  ${BLD}${BWHT}${title}${RST}  ${BBLK}${pct}%${RST}"
}

print_ok()   { printf "\r    ${BGRN}✓${RST}  ${DIM}%s${RST}\033[K\n\n" "$1"; }
print_err()  { echo -e "\n    ${BRED}✗  ${BLD}$1${RST}\n" >&2; exit 1; }

run_command() {
    local cmd="$1" desc="$2"
    eval "$cmd" > /tmp/hypr_install_log 2>&1 &
    local pid=$!
    spinner "$pid" "$desc"
    wait "$pid" || print_err "Failed: $desc  →  /tmp/hypr_install_log"
    print_ok "$desc"
}

################################################################################
# CONFIGURATION
################################################################################

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
CONFIG_DIR="$USER_HOME/.config"
CACHE_DIR="$USER_HOME/.cache"
WAL_CACHE="$CACHE_DIR/wal"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_SRC="$REPO_ROOT/scripts"
CONFIGS_SRC="$REPO_ROOT/configs"
WALLPAPERS_SRC="$REPO_ROOT/Pictures/Wallpapers"

print_banner

[[ "$EUID" -eq 0 ]] || print_err "Run as root  →  sudo $0"

echo -e "    ${BBLK}user${RST}    ${WHT}${USER_NAME}${RST}"
echo -e "    ${BBLK}home${RST}    ${WHT}${USER_HOME}${RST}"
echo -e "    ${BBLK}repo${RST}    ${WHT}${REPO_ROOT}${RST}"
echo ""

read -r -s -p "    $(echo -e "${BCYN}sudo password:${RST} ")" USER_PASS
echo ""

if ! echo "$USER_PASS" | su -c "true" "$USER_NAME" 2>/dev/null; then
    print_err "Incorrect password"
fi

SUDOERS_TMP="/etc/sudoers.d/hypr-install-tmp"
echo "$USER_NAME ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS_TMP"
chmod 0440 "$SUDOERS_TMP"
trap 'rm -f "$SUDOERS_TMP"; echo ""' EXIT

echo ""
hr
echo ""

################################################################################
# SYSTEM UPDATE & DRIVERS
################################################################################

print_phase "System update & driver detection"

run_command "pacman -Syu --noconfirm" "Updating package databases"

GPU_INFO=$(lspci | grep -Ei "VGA|3D" || true)

if echo "$GPU_INFO" | grep -qi nvidia; then
    run_command "pacman -S --noconfirm --needed nvidia-open-dkms nvidia-utils lib32-nvidia-utils linux-headers" \
        "Installing NVIDIA drivers"
elif echo "$GPU_INFO" | grep -qi amd; then
    run_command "pacman -S --noconfirm --needed xf86-video-amdgpu mesa vulkan-radeon lib32-vulkan-radeon linux-headers" \
        "Installing AMD drivers"
elif echo "$GPU_INFO" | grep -qi intel; then
    run_command "pacman -S --noconfirm --needed mesa lib32-mesa vulkan-intel lib32-vulkan-intel linux-headers" \
        "Installing Intel drivers"
fi

################################################################################
# PACKAGE INSTALLATION
################################################################################

print_phase "Package Installation"

CORE_PACKAGES=(hyprland awww mako zed ly pacman-contrib xdg-desktop-portal-hyprland)
TERMINAL_PACKAGES=(kitty starship fastfetch)
UTILITY_PACKAGES=(grim slurp wl-clipboard polkit-kde-agent brightnessctl bluez bluez-utils blueman udiskie udisks2 gvfs networkmanager)
FILE_PACKAGES=(thunar thunar-volman thunar-archive-plugin tumbler ffmpegthumbnailer file-roller exo)
APP_PACKAGES=(firefox celluloid imv pavucontrol btop gnome-disk-utility steam)
DEV_PACKAGES=(git base-devel wget curl nano jq)
FONT_PACKAGES=(ttf-jetbrains-mono-nerd ttf-hack-nerd ttf-iosevka-nerd ttf-cascadia-code-nerd)
MEDIA_PACKAGES=(poppler imagemagick ffmpeg chafa)
COMPRESSION_PACKAGES=(unzip p7zip tar gzip xz bzip2 unrar trash-cli)
PYTHON_PACKAGES=(python-pyqt5 python-pyqt6 python-pillow python-opencv)
QT_PACKAGES=(qt5-wayland qt6-wayland)

ALL_PACKAGES=(
    "${CORE_PACKAGES[@]}" "${TERMINAL_PACKAGES[@]}" "${UTILITY_PACKAGES[@]}"
    "${FILE_PACKAGES[@]}" "${APP_PACKAGES[@]}" "${DEV_PACKAGES[@]}"
    "${FONT_PACKAGES[@]}" "${MEDIA_PACKAGES[@]}" "${COMPRESSION_PACKAGES[@]}"
    "${PYTHON_PACKAGES[@]}" "${QT_PACKAGES[@]}"
)

run_command "pacman -S --noconfirm --needed ${ALL_PACKAGES[*]}" \
    "Installing base system packages"

################################################################################
# AUR HELPER & PACKAGES
################################################################################

print_phase "AUR packages"

if ! command -v yay &>/dev/null; then
    run_command "rm -rf /tmp/yay && sudo -u $USER_NAME git clone https://aur.archlinux.org/yay.git /tmp/yay && cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm" \
        "Building and installing yay"
fi

run_command "sudo -u $USER_NAME yay -S --noconfirm python-pywal16 localsend-bin quickshell-git" \
    "Installing pywal16, localsend, quickshell"

################################################################################
# DIRECTORY STRUCTURE
################################################################################

print_phase "Directory Structure"

CONFIG_DIRS=(
    "$CONFIG_DIR/hypr" "$CONFIG_DIR/quickshell" "$CONFIG_DIR/kitty"
    "$CONFIG_DIR/fastfetch" "$CONFIG_DIR/mako" "$CONFIG_DIR/scripts"
    "$CONFIG_DIR/wal/templates" "$CONFIG_DIR/btop" "$CONFIG_DIR/gtk-3.0"
    "$CONFIG_DIR/gtk-4.0" "$CONFIG_DIR/zed/themes" "$WAL_CACHE"
    "$USER_HOME/Pictures/Wallpapers" "$USER_HOME/.local/share/icons"
)

run_command "mkdir -p ${CONFIG_DIRS[*]} && chown -R $USER_NAME:$USER_NAME ${CONFIG_DIRS[*]}" \
    "Creating system directories"

################################################################################
# CONFIGURATION FILES
################################################################################

print_phase "Configuration files"

SETUP_CONFIGS_CMD="
sudo -u $USER_NAME rm -f '$CONFIG_DIR/kitty/kitty.conf' '$CONFIG_DIR/mako/config' '$CONFIG_DIR/zed/themes/zed.json' 2>/dev/null || true
[[ -d '$CONFIGS_SRC/hypr' ]] && sudo -u $USER_NAME cp -rf '$CONFIGS_SRC/hypr/'* '$CONFIG_DIR/hypr/'
[[ -d '$CONFIGS_SRC/quickshell' ]] && sudo -u $USER_NAME cp -rf '$CONFIGS_SRC/quickshell/'* '$CONFIG_DIR/quickshell/'
[[ -f '$CONFIGS_SRC/kitty/kitty.conf' ]] && sudo -u $USER_NAME cp '$CONFIGS_SRC/kitty/kitty.conf' '$CONFIG_DIR/kitty/kitty.conf'
[[ -f '$CONFIGS_SRC/fastfetch/config.jsonc' ]] && sudo -u $USER_NAME cp '$CONFIGS_SRC/fastfetch/config.jsonc' '$CONFIG_DIR/fastfetch/config.jsonc'
[[ -f '$CONFIGS_SRC/starship/starship.toml' ]] && sudo -u $USER_NAME cp '$CONFIGS_SRC/starship/starship.toml' '$CONFIG_DIR/starship.toml'
[[ -f '$CONFIGS_SRC/btop/btop.conf' ]] && sudo -u $USER_NAME cp '$CONFIGS_SRC/btop/btop.conf' '$CONFIG_DIR/btop/btop.conf'
[[ -d '$CONFIGS_SRC/wal/templates' ]] && sudo -u $USER_NAME cp -rf '$CONFIGS_SRC/wal/templates/'* '$CONFIG_DIR/wal/templates/'

sudo -u $USER_NAME bash -c \"cat > '$CONFIG_DIR/gtk-3.0/settings.ini' << 'EOF'
[Settings]
gtk-icon-theme-name=Colloid-Dynamic-Dark
gtk-theme-name=Adwaita-dark
gtk-application-prefer-dark-theme=1
EOF\"

sudo -u $USER_NAME bash -c \"cat > '$CONFIG_DIR/gtk-4.0/settings.ini' << 'EOF'
[Settings]
gtk-icon-theme-name=Colloid-Dynamic-Dark
gtk-theme-name=Adwaita-dark
gtk-application-prefer-dark-theme=1
EOF\"
"

run_command "$SETUP_CONFIGS_CMD" "Deploying desktop configurations"

################################################################################
# GPU-SPECIFIC ENVIRONMENT
################################################################################

print_phase "GPU environment"

GPU_ENV_FILE="$CONFIG_DIR/hypr/gpu-env.lua"
GPU_CMD="sudo -u $USER_NAME bash -c \"echo '-- GPU environment' > '$GPU_ENV_FILE'\""

if echo "$GPU_INFO" | grep -qi nvidia; then
    GPU_CMD+=" && sudo -u $USER_NAME bash -c \"cat >> '$GPU_ENV_FILE' << 'EOF'
return {
  LIBVA_DRIVER_NAME         = 'nvidia',
  XDG_SESSION_TYPE          = 'wayland',
  __GLX_VENDOR_LIBRARY_NAME = 'nvidia',
  GBM_BACKEND               = 'nvidia-drm',
  WLR_NO_HARDWARE_CURSORS   = '1',
  __GL_GSYNC_ALLOWED        = '1',
  __GL_VRR_ALLOWED          = '1',
  QT_QPA_PLATFORM           = 'wayland',
}
EOF\""
else
    GPU_CMD+=" && sudo -u $USER_NAME bash -c \"cat >> '$GPU_ENV_FILE' << 'EOF'
return {
  XDG_SESSION_TYPE = 'wayland',
  QT_QPA_PLATFORM  = 'wayland',
}
EOF\""
fi

run_command "$GPU_CMD" "Generating GPU profile"

################################################################################
# SCRIPTS, WALLPAPERS & SHELL
################################################################################

print_phase "Scripts, wallpapers & shell"

ASSETS_CMD="
[[ -d '$SCRIPTS_SRC' ]] && sudo -u $USER_NAME cp -rf '$SCRIPTS_SRC/'* '$CONFIG_DIR/scripts/' && chmod +x '$CONFIG_DIR/scripts/'* 2>/dev/null || true
[[ -d '$WALLPAPERS_SRC' ]] && sudo -u $USER_NAME cp -rf '$WALLPAPERS_SRC/'* '$USER_HOME/Pictures/Wallpapers/'
sudo -u $USER_NAME cat > '$USER_HOME/.bashrc' << 'EOF'
#!/bin/bash
[[ -f ~/.cache/wal/sequences ]] && cat ~/.cache/wal/sequences
command -v starship >/dev/null && eval \"\$(starship init bash)\"
command -v fastfetch >/dev/null && fastfetch
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias update='sudo pacman -Syu'
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'
EOF
"

run_command "$ASSETS_CMD" "Setting up dotfiles & shell environments"

################################################################################
# COLLOID ICON THEME
################################################################################

print_phase "Colloid icon theme"

COLLOID_SRC="$CONFIG_DIR/colloid-src"
THEME_CMD="
if [ ! -d '$COLLOID_SRC' ]; then
    sudo -u $USER_NAME git clone --depth 1 https://github.com/Saltyfunnel/colloid.git '$COLLOID_SRC'
fi
cd '$COLLOID_SRC' && sudo -u $USER_NAME ./install.sh -d '$USER_HOME/.local/share/icons' -n Colloid-Dynamic -s default
"

run_command "$THEME_CMD" "Installing Colloid icon themes"

################################################################################
# THUNAR & PYWAL SETUP
################################################################################

print_phase "Thunar & Pywal linking"

INTEGRATION_CMD="
sudo -u $USER_NAME mkdir -p '$CONFIG_DIR/Thunar'
sudo -u $USER_NAME bash -c \"cat > '$CONFIG_DIR/Thunar/uca.xml' << 'EOF'
<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?>
<actions>
<action>
    <icon>kitty</icon>
    <name>Open Kitty Here</name>
    <unique-id>kitty-open-here</unique-id>
    <command>kitty --directory %f</command>
    <description>Open Kitty terminal in this directory</description>
    <patterns>*</patterns>
    <directories/>
</action>
</actions>
EOF\"

[[ -f '$CONFIG_DIR/wal/templates/mako-config' ]] && sudo -u $USER_NAME ln -sf '$WAL_CACHE/mako-config' '$CONFIG_DIR/mako/config' || true
[[ -f '$CONFIG_DIR/wal/templates/zed.json' ]] && sudo -u $USER_NAME ln -sf '$WAL_CACHE/colors-zed.json' '$CONFIG_DIR/zed/themes/zed.json' || true
"

run_command "$INTEGRATION_CMD" "Configuring file actions & pywal targets"

################################################################################
# SERVICES & PERMISSIONS
################################################################################

print_phase "Services & permissions"

SERVICE_CMD="
systemctl enable ly@tty2.service 2>/dev/null || true
systemctl enable bluetooth.service 2>/dev/null || true
systemctl enable NetworkManager.service 2>/dev/null || true
chown -R '$USER_NAME:$USER_NAME' '$CONFIG_DIR' '$CACHE_DIR' '$USER_HOME/Pictures' '$USER_HOME/.local' 2>/dev/null || true
"

run_command "$SERVICE_CMD" "Enabling systemd services"

################################################################################
# DONE
################################################################################

clear
print_banner

echo ""
center "${BCYN}╭─────────────────────────────────────────────────────────────╮${RST}"
center "${BCYN}│                                                             │${RST}"
center "${BCYN}│         ${BLD}${BGRN}✦  H Y P R L A N D   I N S T A L L E D  ✦${RST}${BCYN}         │${RST}"
center "${BCYN}│                                                             │${RST}"
center "${BCYN}╰─────────────────────────────────────────────────────────────╯${RST}"
echo ""

center "${DIM}All packages installed, dotfiles deployed, and services enabled.${RST}"
echo ""
hr
echo ""

read -rp "    $(echo -e "${BYLW}${BLD}Reboot system now?${RST} [y/N]: ")" REBOOT_CHOICE
echo ""

if [[ "$REBOOT_CHOICE" =~ ^[Yy]$ ]]; then
    echo ""
    center "${BLD}${BCYN}Rebooting... Enjoy your setup!${RST}"
    echo ""
    sleep 1.5
    reboot
else
    echo ""
    center "${DIM}${BBLK}Setup complete. Run 'sudo reboot' whenever you're ready.${RST}"
    echo ""
fi
