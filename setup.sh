#!/bin/bash

# Visual styling
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -n "Checking Desktop Environment... "
if [[ "$XDG_CURRENT_DESKTOP" == *"GNOME"* ]] || [[ "$XDG_CURRENT_DESKTOP" == *"gnome"* ]]; then
    echo -e "${GREEN}[PASS] GNOME Detected${NC}"
else
    echo -e "${RED}[FAIL] GNOME not detected ($XDG_CURRENT_DESKTOP). Aborting.${NC}"
    exit 1
fi

echo -n "Detecting Distribution... "
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    LIKE=$ID_LIKE
fi

export DISTRO_FAMILY=""
export INSTALL_CMD=""
export PKG_EXT_MAN=""
export PKG_PIP=""
export PKG_PIPX=""
export PKG_GLIB=""
export PKG_GNOME_EXT=""
export PKG_IMAGEMAGICK=""

if [[ "$DISTRO" == "ubuntu" ]] || [[ "$DISTRO" == "debian" ]] || [[ "$LIKE" == *"ubuntu"* ]] || [[ "$LIKE" == *"debian"* ]]; then
    echo -e "${GREEN}[PASS] Debian/Ubuntu Based Distro${NC}"
    export DISTRO_FAMILY="debian"
    export INSTALL_CMD="sudo apt install -y"
    
    # for APT
    export PKG_EXT_MAN="gnome-shell-extension-manager"
    export PKG_PIP="python3-pip"
    export PKG_PIPX="pipx"
    export PKG_GLIB="libglib2.0-bin"
    export PKG_GNOME_EXT="gnome-shell-extensions"
    export PKG_IMAGEMAGICK="imagemagick"

elif [[ "$DISTRO" == "arch" ]] || [[ "$LIKE" == *"arch"* ]]; then
    echo -e "${GREEN}[PASS] Arch Linux Based Distro${NC}"
    export DISTRO_FAMILY="arch"
    export INSTALL_CMD="sudo pacman -S --noconfirm --needed"
    
    # for PACMAN
    export PKG_EXT_MAN="extension-manager"
    export PKG_PIP="python-pip"
    export PKG_PIPX="python-pipx"
    export PKG_GLIB="glib2"
    export PKG_GNOME_EXT="gnome-shell-extensions"
    export PKG_IMAGEMAGICK="imagemagick"

elif [[ "$DISTRO" == "fedora" ]] || [[ "$LIKE" == *"fedora"* ]]; then
    echo -e "${GREEN}[PASS] Fedora Based Distro${NC}"
    export DISTRO_FAMILY="fedora"
    export INSTALL_CMD="sudo dnf install -y"
    
    export PKG_EXT_MAN=""  
    export PKG_PIP="python3-pip"
    export PKG_PIPX="pipx"
    export PKG_GLIB="glib2"
    export PKG_GNOME_EXT="gnome-extensions-app"  # Only gnome-extensions-app exists in Fedora
    export PKG_IMAGEMAGICK="ImageMagick"

else
    echo -e "${RED}[FAIL] Unsupported Distribution: $DISTRO${NC}"
    exit 1
fi
