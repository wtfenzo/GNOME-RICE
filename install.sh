#!/bin/bash

# To capture project path 
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Style variables
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No color

# Parse arguments
FULL_INSTALL=false
if [ "$1" == "--full" ]; then
    FULL_INSTALL=true
fi

# Root check
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}[ERROR] Please do not run this script as root/sudo.${NC}"
    exit 1
fi

# System check
SETUP_SCRIPT="$INSTALLER_DIR/setup.sh"

if [ -f "$SETUP_SCRIPT" ]; then
    source "$SETUP_SCRIPT"
    
    # Capture exit code
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ABORT] System checks failed. Installation stopped.${NC}"
        exit 1
    fi
else
    echo -e "${RED}[ERROR] 'setup.sh' not found. Cannot detect package manager.${NC}"
    exit 1
fi

echo -e "${BLUE}[INFO] Installing required packages...${NC}"

# Update Cache
if [ "$DISTRO_FAMILY" == "debian" ]; then sudo apt update; fi
if [ "$DISTRO_FAMILY" == "arch" ]; then sudo pacman -Sy; fi
if [ "$DISTRO_FAMILY" == "fedora" ]; then sudo dnf check-update || true; fi

# all PKG_ variables are defined in setup.sh
if [ "$DISTRO_FAMILY" == "fedora" ]; then
    # Fedora is such a pain in the ass
    sudo dnf install -y --skip-unavailable \
        gcc curl wget perl make cmake sassc wmctrl gnome-tweaks flatpak jq \
        $PKG_IMAGEMAGICK $PKG_PIP $PKG_PIPX $PKG_GLIB $PKG_GNOME_EXT
else
    $INSTALL_CMD gcc curl wget perl make cmake sassc wmctrl gnome-tweaks flatpak jq \
        $PKG_IMAGEMAGICK $PKG_EXT_MAN $PKG_PIP $PKG_PIPX $PKG_GLIB $PKG_GNOME_EXT
fi


echo ""
echo -e "${BLUE}[INFO] Setting up Ulauncher...${NC}"

if ! command -v ulauncher &> /dev/null; then
    if [ "$DISTRO_FAMILY" == "debian" ]; then
        cd /tmp
        wget -q -O ulauncher.deb "https://github.com/Ulauncher/Ulauncher/releases/download/5.15.15/ulauncher_5.15.15_all.deb"
        sudo dpkg -i ulauncher.deb
        sudo apt install -f -y
        rm ulauncher.deb
        echo -e "${GREEN}[OK] Ulauncher installed (.deb)${NC}"
    elif [ "$DISTRO_FAMILY" == "arch" ]; then
        # Try AUR helper
        if command -v yay &> /dev/null; then yay -S --noconfirm ulauncher; 
        elif command -v paru &> /dev/null; then paru -S --noconfirm ulauncher;
        else echo -e "${YELLOW}[WARN] Please install 'ulauncher' manually from AUR${NC}"; fi
    elif [ "$DISTRO_FAMILY" == "fedora" ]; then
        sudo dnf install -y ulauncher
    fi
else
    echo -e "${GREEN}[OK] Ulauncher already installed${NC}"
fi

# Ulauncher Theme
ULAUNCHER_THEME_DIR="$HOME/.config/ulauncher/user-themes"
TARGET_THEME_PATH="$ULAUNCHER_THEME_DIR/liquid-glass-dark"
rm -rf "$TARGET_THEME_PATH" "/tmp/ulauncher-liquid-glass-repo"
mkdir -p "$ULAUNCHER_THEME_DIR"
git clone -q "https://github.com/kayozxo/ulauncher-liquid-glass" "/tmp/ulauncher-liquid-glass-repo"
cp -r "/tmp/ulauncher-liquid-glass-repo/liquid-glass-dark" "$TARGET_THEME_PATH" 2>/dev/null || \
    cp -r "/tmp/ulauncher-liquid-glass-repo" "$TARGET_THEME_PATH"

# Ulauncher Config
mkdir -p "$HOME/.config/ulauncher"
ULAUNCHER_CONFIG="$HOME/.config/ulauncher/settings.json"
[ ! -f "$ULAUNCHER_CONFIG" ] && echo "{}" > "$ULAUNCHER_CONFIG"
tmp=$(mktemp)
jq '."theme-name" = "liquid-glass-dark" | ."clear-input-on-hide" = true | ."hotkey-show-app" = "<Super>space"' \
    "$ULAUNCHER_CONFIG" > "$tmp" && mv "$tmp" "$ULAUNCHER_CONFIG"
echo -e "${GREEN}[OK] Ulauncher configured${NC}"

gsettings set org.gnome.desktop.interface enable-hot-corners true
EXTS=(
    "tiling-assistant@ubuntu.com"
    "tiling-assistant@leleat-on-github"
    "ubuntu-dock@ubuntu.com"
    "dash-to-dock@micxgx.gmail.com"
    "ding@rastersoft.com"
    "ubuntu-appindicators@ubuntu.com"
)

for ext in "${EXTS[@]}"; do
    if gnome-extensions list 2>/dev/null | grep -q "$ext"; then
        echo -e "${YELLOW}[Disabling] $ext${NC}"
        gnome-extensions disable "$ext" 2>/dev/null
    fi
done

gsettings set org.gnome.shell disable-extension-version-validation true
gsettings set org.gnome.mutter workspaces-only-on-primary false
gsettings set org.gnome.mutter dynamic-workspaces true
gsettings set org.gnome.desktop.wm.preferences focus-mode 'click'

if gsettings list-schemas | grep -q "org.gnome.shell.overrides"; then
    gsettings set org.gnome.shell.overrides edge-tiling false
fi

echo ""
echo -e "${BLUE}[INFO] Installing GNOME Shell Extensions...${NC}"

# Defining extensions to download 
declare -A extensions=(
    ["user-theme@gnome-shell-extensions.gcampax.github.com"]="https://extensions.gnome.org/extension/19/user-themes/"
    ["blur-my-shell@aunetx"]="https://extensions.gnome.org/extension/3193/blur-my-shell/"
    ["dash2dock-lite@icedman.github.com"]="https://extensions.gnome.org/extension/4994/dash2dock-lite/"
    ["space-bar@luchrioh"]="https://extensions.gnome.org/extension/5090/space-bar/"
    ["compiz-windows-effect@hermes83.github.com"]="https://extensions.gnome.org/extension/3210/compiz-windows-effect/"
    ["compiz-alike-magic-lamp-effect@hermes83.github.com"]="https://extensions.gnome.org/extension/3740/compiz-alike-magic-lamp-effect/"
    ["Vitals@CoreCoding.com"]="https://extensions.gnome.org/extension/1460/vitals/"
    ["CoverflowAltTab@palatis.blogspot.com"]="https://extensions.gnome.org/extension/97/coverflow-alt-tab/"
)

if ! command -v gext &> /dev/null; then
    pipx install gnome-extensions-cli --force
    export PATH="$HOME/.local/bin:$PATH"
fi

EXTENSION_DIR="$HOME/.local/share/gnome-shell/extensions"
mkdir -p "$EXTENSION_DIR"

for ext_uuid in "${!extensions[@]}"; do
    if [ ! -d "$EXTENSION_DIR/$ext_uuid" ]; then
        echo -e "${YELLOW}[Installing] $ext_uuid...${NC}"
        gext install "$ext_uuid"
    else
         echo -e "${GREEN}[Checked] $ext_uuid is installed.${NC}"
    fi
    gnome-extensions enable "$ext_uuid" 2>/dev/null
done

echo -e "${BLUE}[INFO] Compiling Extension Schemas...${NC}"
for dir in "$EXTENSION_DIR"/*; do
    if [ -d "$dir/schemas" ]; then
        glib-compile-schemas "$dir/schemas"
    fi
done

DOCK_UUID="dash2dock-lite@icedman.github.com"
DOCK_SCHEMA_DIR="$EXTENSION_DIR/$DOCK_UUID/schemas"
SCHEMA="org.gnome.shell.extensions.dash2dock-lite"

if [ -f "$DOCK_SCHEMA_DIR/gschemas.compiled" ]; then
    export GSETTINGS_SCHEMA_DIR="$DOCK_SCHEMA_DIR:$GSETTINGS_SCHEMA_DIR"
    
    gsettings set $SCHEMA animate-icons true
    gsettings set $SCHEMA animate-icons-unmute true
    gsettings set $SCHEMA animation-bounce 0.75
    gsettings set $SCHEMA animation-fps 0
    gsettings set $SCHEMA animation-magnify 0.3
    gsettings set $SCHEMA animation-rise 0.25
    gsettings set $SCHEMA animation-spread 0.75
    gsettings set $SCHEMA animation-type 0
    gsettings set $SCHEMA apps-icon true
    gsettings set $SCHEMA apps-icon-front false
    gsettings set $SCHEMA autohide-dash true
    gsettings set $SCHEMA autohide-dodge true
    gsettings set $SCHEMA autohide-speed 0.5
    gsettings set $SCHEMA background-color "(0.0, 0.0, 0.0, 0.25)"
    gsettings set $SCHEMA blur-background false
    gsettings set $SCHEMA border-radius 8.0
    gsettings set $SCHEMA border-thickness 0
    gsettings set $SCHEMA dock-location 0
    gsettings set $SCHEMA dock-padding 0.0
    gsettings set $SCHEMA edge-distance 0.1045
    gsettings set $SCHEMA favorites-only false
    gsettings set $SCHEMA hide-labels false
    gsettings set $SCHEMA icon-border-radius 3.0
    gsettings set $SCHEMA icon-border-thickness 0
    gsettings set $SCHEMA icon-effect 0
    gsettings set $SCHEMA icon-shadow true
    gsettings set $SCHEMA icon-size 0.0
    gsettings set $SCHEMA icon-spacing 0.4
    gsettings set $SCHEMA items-pullout-angle 0.5
    gsettings set $SCHEMA label-background-color "(0.0, 0.0, 0.0, 0.25)"
    gsettings set $SCHEMA label-border-radius 0.0
    gsettings set $SCHEMA lamp-app-animation false
    gsettings set $SCHEMA open-app-animation true
    gsettings set $SCHEMA panel-mode false
    gsettings set $SCHEMA peek-hidden-icons false
    gsettings set $SCHEMA pressure-sense false
    gsettings set $SCHEMA running-indicator-style 1
    gsettings set $SCHEMA shrink-icons true
    gsettings set $SCHEMA theme 0
    gsettings set $SCHEMA trash-icon true
    
fi

echo ""
echo -e "${BLUE}[INFO] Installing MacTahoe Themes...${NC}"
rm -rf /tmp/MacTahoe-icon-theme /tmp/MacTahoe-gtk-theme
git clone -q "https://github.com/vinceliuice/MacTahoe-icon-theme" /tmp/MacTahoe-icon-theme
cd /tmp/MacTahoe-icon-theme && bash install.sh >/dev/null

git clone -q "https://github.com/vinceliuice/MacTahoe-gtk-theme.git" --depth=1 /tmp/MacTahoe-gtk-theme

WALLPAPER_DEST="$HOME/Pictures/Wallpapers"
mkdir -p "$WALLPAPER_DEST"
if [ -f "$INSTALLER_DIR/assets/wallpaper.jpg" ]; then
    cp "$INSTALLER_DIR/assets/wallpaper.jpg" "$WALLPAPER_DEST/mactahoe-wallpaper.jpg"
fi

WALLPAPER_PATH="$WALLPAPER_DEST/mactahoe-wallpaper.jpg"

cd /tmp/MacTahoe-gtk-theme
./install.sh -n MacTahoe -t all -l --shell -i simple -h bigger --round >/dev/null

echo ""
echo -e "${CYAN}[INFO] Applying Tweaks...${NC}"
[ -n "$WALLPAPER_PATH" ] && sudo ./tweaks.sh -g -nd -b "$WALLPAPER_PATH" 2>&1 | grep -v "cache file"

cd wallpaper/ && sudo ./install-gnome-backgrounds.sh >/dev/null 2>&1
cd ~

echo ""
echo -e "${BLUE}[INFO] Applying Theme Appearance...${NC}"


gsettings set org.gnome.desktop.interface cursor-theme 'MacTahoe-dark'
gsettings set org.gnome.desktop.interface icon-theme 'MacTahoe-dark'

# Shell Theme
USER_THEME_UUID="user-theme@gnome-shell-extensions.gcampax.github.com"
if [ -d "$EXTENSION_DIR/$USER_THEME_UUID/schemas" ]; then
    export GSETTINGS_SCHEMA_DIR="$EXTENSION_DIR/$USER_THEME_UUID/schemas:$GSETTINGS_SCHEMA_DIR"
    gsettings set org.gnome.shell.extensions.user-theme name 'MacTahoe-Dark'
    echo -e "${GREEN}  ✓ Shell Theme${NC}"
fi

# GTK & WM Themes
gsettings set org.gnome.desktop.interface gtk-theme 'MacTahoe-Dark'
gsettings set org.gnome.desktop.wm.preferences theme 'Adwaita'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
echo -e "${GREEN}  ✓ GTK Themes${NC}"

# Wallpapers
MACTAHOE_DAY="/usr/share/backgrounds/MacTahoe/MacTahoe-day.jpeg"
MACTAHOE_NIGHT="/usr/share/backgrounds/MacTahoe/MacTahoe-night.jpeg"

[ -f "$MACTAHOE_DAY" ] && gsettings set org.gnome.desktop.background picture-uri "file://$MACTAHOE_DAY" || \
    gsettings set org.gnome.desktop.background picture-uri "file://$WALLPAPER_PATH"

[ -f "$MACTAHOE_NIGHT" ] && gsettings set org.gnome.desktop.background picture-uri-dark "file://$MACTAHOE_NIGHT" || \
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$WALLPAPER_PATH"

gsettings set org.gnome.desktop.background picture-options 'zoom'
echo -e "${GREEN}  ✓ Wallpapers${NC}"

# UI Preferences
gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:appmenu'
gsettings set org.gnome.desktop.interface clock-show-seconds false
gsettings set org.gnome.desktop.interface clock-show-weekday true
gsettings set org.gnome.desktop.interface show-battery-percentage true
gsettings set org.gnome.desktop.interface enable-animations true
echo -e "${GREEN}  ✓ UI Preferences${NC}"

echo ""
echo -e "${BLUE}[INFO] Configuring Extensions...${NC}"

BLUR_UUID="blur-my-shell@aunetx"
if [ "$FULL_INSTALL" = true ] && [ -d "$EXTENSION_DIR/$BLUR_UUID/schemas" ]; then
    (
        export GSETTINGS_SCHEMA_DIR="$EXTENSION_DIR/$BLUR_UUID/schemas:$GSETTINGS_SCHEMA_DIR"
        gsettings set org.gnome.shell.extensions.blur-my-shell brightness 0.6
        gsettings set org.gnome.shell.extensions.blur-my-shell sigma 30
        gsettings set org.gnome.shell.extensions.blur-my-shell.panel blur true
        gsettings set org.gnome.shell.extensions.blur-my-shell.panel static-blur true
        gsettings set org.gnome.shell.extensions.blur-my-shell.overview blur true
        gsettings set org.gnome.shell.extensions.blur-my-shell.dash-to-dock blur true
        gsettings set org.gnome.shell.extensions.blur-my-shell.dash-to-dock corner-radius 12
        gsettings set org.gnome.shell.extensions.blur-my-shell.applications blur true
        gsettings set org.gnome.shell.extensions.blur-my-shell.applications opacity 215
        echo -e "${GREEN}  ✓ Blur My Shell${NC}"
    )
else
     echo -e "${YELLOW}  [SKIP] Blur My Shell config (use --full to enable)${NC}"
fi

VITALS_UUID="Vitals@CoreCoding.com"
if [ -d "$EXTENSION_DIR/$VITALS_UUID/schemas" ]; then
    export GSETTINGS_SCHEMA_DIR="$EXTENSION_DIR/$VITALS_UUID/schemas:$GSETTINGS_SCHEMA_DIR"
    gsettings set org.gnome.shell.extensions.vitals hot-sensors "['_memory_usage_', '_processor_usage_']" 2>/dev/null
    gsettings set org.gnome.shell.extensions.vitals position-in-panel 2 2>/dev/null
    echo -e "${GREEN}  ✓ Vitals${NC}"
fi

COVERFLOW_UUID="CoverflowAltTab@palatis.blogspot.com"
if [ -d "$EXTENSION_DIR/$COVERFLOW_UUID/schemas" ]; then
    export GSETTINGS_SCHEMA_DIR="$EXTENSION_DIR/$COVERFLOW_UUID/schemas:$GSETTINGS_SCHEMA_DIR"
    gsettings set org.gnome.shell.extensions.coverflowalttab animation-time 0.25 2>/dev/null
    echo -e "${GREEN}  ✓ CoverFlow Alt-Tab${NC}"
fi

KEYBIND_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['$KEYBIND_PATH']"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEYBIND_PATH name 'Ulauncher'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEYBIND_PATH command 'ulauncher-toggle'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEYBIND_PATH binding '<Ctrl>space'
gsettings set org.gnome.shell.keybindings toggle-overview "[]"

echo ""
echo -e "${GREEN}${BOLD}================================================${NC}"
echo -e "${GREEN}${BOLD}  Installation Complete!${NC}"
echo -e "${GREEN}  Theme: MacTahoe-Dark${NC}"
echo -e "${GREEN}  Icons: MacTahoe${NC}"
echo -e "${GREEN}  Cursor: MacTahoe-dark${NC}"
echo -e "${GREEN}  Ulauncher: Super + Space${NC}"
if [ "$FULL_INSTALL" = true ]; then
    echo -e "${GREEN}  Blur Effects: Enabled${NC}"
fi
echo -e "${GREEN}  Thank you for choosing to install this script, any additional changes can be made using tweaks and gnome-extensions${NC}"
echo -e "${GREEN}  Please reboot for all changes${NC}"
echo -e "${GREEN}  to take effect.${NC}"
echo -e "${GREEN}${BOLD}================================================${NC}"
