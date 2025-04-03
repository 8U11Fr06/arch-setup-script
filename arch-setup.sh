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
    
    # Web tools
    "whatweb"
    "gobuster"
    
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
    
    # Database tools
    "sqlmap"
    
    # Python
    "python"
    "python-pip"
)

# AUR tools
AUR_TOOLS=(
    "evil-winrm"
    "rdp-sec-check"
    "seclists"
)

# GitHub tools to download manually
GITHUB_TOOLS=(
    "https://github.com/maaaaz/impacket-examples-windows.git" # ODAT alternative
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

# ODAT Tools (Oracle Database Attack Tool)
print_status "Installing ODAT from GitHub..."
clone_or_update_repo "https://github.com/quentinhardy/odat.git" "$USER_HOME/ctf/tools/odat"

# Install ODAT requirements if possible
if [ -f "$USER_HOME/ctf/tools/odat/requirements.txt" ]; then
    print_status "Setting up venv for ODAT..."
    sudo -u $USERNAME bash -c "cd $USER_HOME/ctf/tools/odat && \
        python -m venv venv && \
        source venv/bin/activate && \
        pip install -r requirements.txt && \
        deactivate"
    
    # Create a wrapper script to run ODAT with the virtual environment
    cat > "$USER_HOME/ctf/tools/odat/run-odat.sh" << 'EOF'
#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR/venv/bin/activate"
python "$DIR/odat.py" "$@"
deactivate
EOF
    chmod +x "$USER_HOME/ctf/tools/odat/run-odat.sh"
    chown $USERNAME:$USERNAME "$USER_HOME/ctf/tools/odat/run-odat.sh"
fi

# Add Oracle client if needed
print_status "Checking for Oracle client..."
if ! command_exists sqlplus; then
    print_status "Installing Oracle client (if available)..."
    sudo -u $USERNAME yay -S --noconfirm oracle-instantclient-sqlplus 2>/dev/null || \
    print_warning "Oracle client not found in AUR. Manual installation may be required."
else
    print_good "Oracle client (sqlplus) already installed"
fi

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

# enum4linux-ng
clone_or_update_repo "https://github.com/cddmp/enum4linux-ng.git" "$USER_HOME/ctf/tools/enum4linux-ng"

# dnsenum
clone_or_update_repo "https://github.com/fwaeytens/dnsenum.git" "$USER_HOME/ctf/tools/dnsenum"

# EyeWitness
clone_or_update_repo "https://github.com/RedSiege/EyeWitness.git" "$USER_HOME/ctf/tools/EyeWitness"

# Install Python requirements for GitHub tools using virtual environments
print_status "Installing Python virtual environments for GitHub tools..."

# Python venv is included in the base python package in Arch Linux
# No need to install python-venv separately

# Setup virtual environment for enum4linux-ng
if [ -f "$USER_HOME/ctf/tools/enum4linux-ng/requirements.txt" ]; then
    print_status "Setting up venv for enum4linux-ng..."
    sudo -u $USERNAME bash -c "cd $USER_HOME/ctf/tools/enum4linux-ng && \
        python -m venv venv && \
        source venv/bin/activate && \
        pip install -r requirements.txt && \
        deactivate"
    
    # Create a wrapper script to run enum4linux-ng with the virtual environment
    cat > "$USER_HOME/ctf/tools/enum4linux-ng/run-enum4linux-ng.sh" << 'EOF'
#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR/venv/bin/activate"
python "$DIR/enum4linux-ng.py" "$@"
deactivate
EOF
    chmod +x "$USER_HOME/ctf/tools/enum4linux-ng/run-enum4linux-ng.sh"
    chown $USERNAME:$USERNAME "$USER_HOME/ctf/tools/enum4linux-ng/run-enum4linux-ng.sh"
fi

# Setup virtual environment for dnsenum
if [ -f "$USER_HOME/ctf/tools/dnsenum/requirements.txt" ]; then
    print_status "Setting up venv for dnsenum..."
    sudo -u $USERNAME bash -c "cd $USER_HOME/ctf/tools/dnsenum && \
        python -m venv venv && \
        source venv/bin/activate && \
        pip install -r requirements.txt && \
        deactivate"
    
    # Create a wrapper script to run dnsenum with the virtual environment
    cat > "$USER_HOME/ctf/tools/dnsenum/run-dnsenum.sh" << 'EOF'
#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR/venv/bin/activate"
perl "$DIR/dnsenum.pl" "$@"
deactivate
EOF
    chmod +x "$USER_HOME/ctf/tools/dnsenum/run-dnsenum.sh"
    chown $USERNAME:$USERNAME "$USER_HOME/ctf/tools/dnsenum/run-dnsenum.sh"
fi

# Setup virtual environment for EyeWitness
if [ -f "$USER_HOME/ctf/tools/EyeWitness/Python/requirements.txt" ]; then
    print_status "Setting up venv for EyeWitness..."
    sudo -u $USERNAME bash -c "cd $USER_HOME/ctf/tools/EyeWitness/Python && \
        python -m venv venv && \
        source venv/bin/activate && \
        pip install -r requirements.txt && \
        deactivate"
    
    # Create a wrapper script to run EyeWitness with the virtual environment
    cat > "$USER_HOME/ctf/tools/EyeWitness/Python/run-eyewitness.sh" << 'EOF'
#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR/venv/bin/activate"
python "$DIR/EyeWitness.py" "$@"
deactivate
EOF
    chmod +x "$USER_HOME/ctf/tools/EyeWitness/Python/run-eyewitness.sh"
    chown $USERNAME:$USERNAME "$USER_HOME/ctf/tools/EyeWitness/Python/run-eyewitness.sh"
fi

# Make tools executable
chmod +x "$USER_HOME/ctf/tools/enum4linux-ng/enum4linux-ng.py"
chmod +x "$USER_HOME/ctf/tools/dnsenum/dnsenum.pl"
chmod +x "$USER_HOME/ctf/tools/EyeWitness/Python/EyeWitness.py"

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

# Set up aliases and environment
print_status "Setting up aliases and environment..."
cat > $USER_HOME/.zsh_pentest << 'EOL'
# Pentest/CTF aliases and functions
alias nmap-full="sudo nmap -sC -sV -p-"
alias nmap-quick="sudo nmap -sC -sV --top-ports 1000"

# Impacket aliases


# Tool path aliases
alias enum4linux-ng="~/ctf/tools/enum4linux-ng/run-enum4linux-ng.sh"
alias dnsenum="~/ctf/tools/dnsenum/run-dnsenum.sh"
alias eyewitness="~/ctf/tools/EyeWitness/Python/run-eyewitness.sh"
alias odat="~/ctf/tools/odat/run-odat.sh"

# Add ctf tools to path
export PATH=$PATH:$HOME/ctf/tools
export PATH=$PATH:$HOME/ctf/tools/enum4linux-ng
export PATH=$PATH:$HOME/ctf/tools/dnsenum
export PATH=$PATH:$HOME/ctf/tools/EyeWitness/Python

# Environment variables
export WORDLISTS=/usr/share/wordlists

# Function to quickly create a new CTF workspace
function newctf() {
    if [ -z "$1" ]; then
        echo "Usage: newctf <ctf_name>"
        return 1
    fi
    
    local ctf_dir="$HOME/ctf/challenges/$1"
    mkdir -p "$ctf_dir"/{recon,exploit,loot,notes}
    echo "# $1 CTF Notes" > "$ctf_dir/notes/README.md"
    echo "Created CTF workspace at $ctf_dir"
    cd "$ctf_dir"
}
EOL

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


# Add source to .zshrc if not already there
if ! grep -q "source ~/.zsh_pentest" "$USER_HOME/.zshrc" 2>/dev/null; then
    echo "source ~/.zsh_pentest" >> "$USER_HOME/.zshrc"
fi

# Set proper ownership
chown $USERNAME:$USERNAME $USER_HOME/.zsh_pentest
if [ -f "$USER_HOME/.zshrc" ]; then
    chown $USERNAME:$USERNAME $USER_HOME/.zshrc
fi

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
