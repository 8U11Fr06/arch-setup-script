#!/bin/bash

# Pentest/CTF Setup Script for Arch Linux on WSL
# This script installs common tools for penetration testing and CTF competitions

set -e # Exit on error

# Colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored status messages
print_status() {
    echo -e "${BLUE}[*]${NC} $1"
}

print_good() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_error() {
    echo -e "${RED}[-]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to clone or update a git repository
clone_or_update_repo() {
    local repo_url="$1"
    local target_dir="$2"
    
    if [ -d "$target_dir/.git" ]; then
        print_status "Updating $(basename $target_dir)..."
        cd "$target_dir"
        git pull
    else
        print_status "Cloning $(basename $repo_url)..."
        git clone "$repo_url" "$target_dir"
    fi
    
    chown -R $USERNAME:$USERNAME "$target_dir"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root"
    exit 1
fi

# Specify your username
USERNAME="faraday"
USER_HOME="/home/$USERNAME"

# Update system first
print_status "Updating system..."
pacman -Syu --noconfirm

# Install fundamentals
print_status "Installing fundamental tools..."
pacman -S --needed --noconfirm zsh git base-devel wget curl neovim

# Install ZSH and make it default for user
print_status "Setting up ZSH as default shell for $USERNAME..."
if ! command_exists zsh; then
    print_error "ZSH installation failed"
    exit 1
fi

# Change default shell for user
if getent passwd $USERNAME | grep -q "/bin/zsh"; then
    print_good "ZSH is already the default shell for $USERNAME"
else
    chsh -s /bin/zsh $USERNAME
    print_good "Changed default shell to ZSH for $USERNAME"
fi

# Setup AUR helper (yay)
if ! command_exists yay; then
    print_status "Installing yay AUR helper..."
    # Create a build directory in user's home
    BUILD_DIR="$USER_HOME/yay_build"
    mkdir -p $BUILD_DIR
    chown $USERNAME:$USERNAME $BUILD_DIR
    
    # Clone and build as the user
    sudo -u $USERNAME bash -c "cd $BUILD_DIR && \
        git clone https://aur.archlinux.org/yay.git && \
        cd yay && \
        makepkg -si --noconfirm"
    
    # Clean up
    rm -rf $BUILD_DIR
    print_good "yay installed successfully"
else
    print_good "yay already installed"
fi

# Add BlackArch repository for additional pentesting tools
setup_blackarch() {
    print_status "Setting up BlackArch repository..."
    if ! grep -q "\[blackarch\]" /etc/pacman.conf; then
        curl -O https://blackarch.org/strap.sh
        chmod +x strap.sh
        ./strap.sh
        rm strap.sh
        print_good "BlackArch repository added successfully"
    else
        print_good "BlackArch repository already configured"
    fi
}

setup_blackarch

# Refresh package databases
print_status "Refreshing package databases..."
pacman -Sy

# Common tools to install via pacman/blackarch
PACMAN_TOOLS=(
    # Network & Recon tools
    "nmap"
    "tcpdump"
    "netcat"      # GNU netcat
    "bind-tools"  # For dig command
    "whois"
    "rdp-sec-check"
    "seclists"
    "dnsenum"
    "onesixtyone"
    "enum4linux-ng"
    
    # Web tools
    "whatweb"
    "gobuster"
    "eyewitness"
    
    # Exploitation
    "metasploit"
    "exploitdb"   # For searchsploit
    
    # Password tools
    "hashcat"
    
    # Authentication & Access tools
    "freerdp"     # Provides xfreerdp
    "smbclient"
    "lftp"        # FTP client (replaces 'ftp')
    "openssh"
    "rsync"
    "nfs-utils"
    "ssh-audit"
    "net-snmp"
    
    # Database tools
    "sqlmap"
    
    # Python
    "python"
    "python-pip"
)

# AUR tools
AUR_TOOLS=(
    "evil-winrm"
)


# Install pacman tools
print_status "Installing tools from official and BlackArch repositories..."
for tool in "${PACMAN_TOOLS[@]}"; do
    if pacman -Q "$tool" >/dev/null 2>&1; then
        print_good "$tool already installed"
    else
        print_status "Installing $tool..."
        if pacman -S --noconfirm "$tool"; then
            print_good "$tool installed successfully"
        else
            print_warning "Failed to install $tool via pacman, trying BlackArch..."
            if pacman -S --noconfirm blackarch-$tool 2>/dev/null || pacman -S --noconfirm $tool 2>/dev/null; then
                print_good "$tool installed successfully from BlackArch"
            else
                print_error "Failed to install $tool"
            fi
        fi
    fi
done

# Install AUR tools
print_status "Installing tools from AUR..."
for tool in "${AUR_TOOLS[@]}"; do
    if pacman -Q "$tool" >/dev/null 2>&1; then
        print_good "$tool already installed"
    else
        print_status "Installing $tool from AUR..."
        if sudo -u $USERNAME yay -S --noconfirm "$tool"; then
            print_good "$tool installed successfully"
        else
            print_error "Failed to install $tool from AUR"
        fi
    fi
done

# Install pipx if not already installed
if ! command_exists pipx; then
    print_status "Installing pipx..."
    pacman -S --needed --noconfirm python-pipx
    print_good "pipx installed successfully"
else
    print_good "pipx already installed"
fi

# Install impacket using pipx
print_status "Installing impacket using pipx..."
if sudo -u $USERNAME python -m pipx install impacket 2>/dev/null; then
    print_good "impacket installed successfully with pipx"
    
    # Ensure pipx bin directory is in PATH
    sudo -u $USERNAME bash -c "pipx ensurepath"
    print_status "Added pipx bin directory to PATH"
    
    # Update current PATH for this session
    export PATH="$USER_HOME/.local/bin:$PATH"
else
    print_error "Failed to install impacket with pipx"
fi

# Create directory structure for tools and CTFs
print_status "Creating CTF directory structure..."
mkdir -p $USER_HOME/ctf/{tools,wordlists,challenges,notes}
chown -R $USERNAME:$USERNAME $USER_HOME/ctf


# Clone GitHub tools
print_status "Installing GitHub tools..."

# Function to clone or update a git repository
clone_or_update_repo() {
    local repo_url="$1"
    local target_dir="$2"
    
    if [ -d "$target_dir/.git" ]; then
        print_status "Updating $(basename $target_dir)..."
        cd "$target_dir"
        git pull
    else
        print_status "Cloning $(basename $repo_url)..."
        git clone "$repo_url" "$target_dir"
    fi
    
    chown -R $USERNAME:$USERNAME "$target_dir"
}


# Install Python requirements for GitHub tools using virtual environments
print_status "Installing Python virtual environments for GitHub tools..."

# Python venv is included in the base python package in Arch Linux
# No need to install python-venv separately


# Additional recommended tools
print_status "Installing additional recommended tools..."

RECOMMENDED_TOOLS=(
    # Web
    "ffuf"
    "dirsearch"
    "nikto"
    
    # Network
    "masscan"
    "rustscan"
    
    # Exploitation
    "crackmapexec"
    "responder"
    
    # Privilege Escalation
    "linpeas"
    "pspy"
    
    # Reverse Engineering
    "gdb"
    "ghidra"
    
    # Utility
    "jq"
    "tmux"
    "vim"
)

for tool in "${RECOMMENDED_TOOLS[@]}"; do
    print_status "Installing $tool..."
    if pacman -Q "$tool" >/dev/null 2>&1; then
        print_good "$tool already installed"
    elif pacman -S --noconfirm "$tool" 2>/dev/null || pacman -S --noconfirm blackarch-$tool 2>/dev/null; then
        print_good "$tool installed successfully"
    else
        print_status "Trying to install $tool via AUR..."
        sudo -u $USERNAME yay -S --noconfirm "$tool" || print_error "Failed to install $tool"
    fi
done


# Install Go and CF-Hero
print_status "Installing Go and CF-Hero..."
if ! command_exists go; then
    pacman -S --needed --noconfirm go
    print_good "Go installed successfully"
else
    print_good "Go already installed"
fi

# Make sure Go bin directory exists
mkdir -p /home/faraday/go/bin
chown -R faraday:faraday /home/faraday/go

# Install CF-Hero
print_status "Installing CF-Hero for Cloudflare reconnaissance..."
sudo -u faraday bash -c "export GOPATH=\$HOME/go && export PATH=\$PATH:\$GOPATH/bin && go install -v github.com/musana/cf-hero/cmd/cf-hero@latest"

# Add Go bin to user's path in .zshrc if not already there
if ! grep -q "export GOPATH=\$HOME/go" "/home/faraday/.zshrc"; then
    echo "export GOPATH=\$HOME/go" >> /home/faraday/.zshrc
    echo "export PATH=\$PATH:\$GOPATH/bin" >> /home/faraday/.zshrc
fi

# Set proper ownership
chown $USERNAME:$USERNAME $USER_HOME/.zshrc


# Install Oh My Zsh for a better terminal experience (optional)
print_status "Installing Oh My Zsh for better terminal experience..."
if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
    sudo -u $USERNAME sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    print_good "Oh My Zsh installed successfully"
else
    print_good "Oh My Zsh already installed"
fi


print_good "Installation complete!"
print_status "Recommended next steps:"
print_status "1. Log out and log back in to activate ZSH"
print_status "2. Check out your tools in $USER_HOME/ctf/tools"
print_status "3. Try out the newctf function to create a new CTF workspace"
