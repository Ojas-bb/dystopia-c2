#!/usr/bin/env bash

set -e

echo "Starting Dystopia Setup..."

# Determine OS type
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRIB=$ID
    else
        DISTRIB="unknown"
    fi

    echo "Detected distribution: $DISTRIB"

    # Arch-based distributions
    if [[ ${DISTRIB} == "arch" || ${DISTRIB} == "manjaro" ]]; then
        echo "Updating Arch-based system..."
        sudo pacman -Syyu --noconfirm
        sudo pacman -S base-devel git --needed --noconfirm

        # Install yay if not present
        if ! command -v yay &> /dev/null; then
            echo "Installing yay..."
            git clone https://aur.archlinux.org/yay.git
            cd yay
            makepkg -si --noconfirm
            cd ..
            rm -rf yay
        fi

        yay -S python38 wine --noconfirm
        sudo pacman -S python-pip --noconfirm 
        pip3 install -r requirements.txt --break-system-packages || pip3 install -r requirements.txt || true

    # Debian-based distributions (Ubuntu, Kali, Debian)
    elif [[ ${DISTRIB} == "ubuntu" || ${DISTRIB} == "debian" || ${DISTRIB} == "kali" || ${ID_LIKE} == *"debian"* ]]; then
        echo "Updating Debian-based system..."
        sudo apt-get update
        sudo apt-get install -y python3 python3-pip wine wget xvfb

        # Add i386 architecture for wine32
        sudo dpkg --add-architecture i386
        sudo apt-get update
        sudo apt-get install -y wine32 || echo "wine32 installation failed, continuing..."

        echo "Installing Python dependencies for the builder..."
        pip3 install -r requirements.txt --break-system-packages || pip3 install -r requirements.txt || true
    else
        echo "Unsupported distribution: $DISTRIB. Trying general approach..."
        sudo apt-get update || true
        sudo apt-get install -y python3 python3-pip wine wget || true
        pip3 install -r requirements.txt --break-system-packages || pip3 install -r requirements.txt || true
    fi

    # Download Python 3.8.9 installer if not exists
    FILE=python-3.8.9.exe
    if [[ ! -f "$FILE" ]]; then
        echo "Downloading Python 3.8.9 for Windows..."
        wget https://www.python.org/ftp/python/3.8.9/python-3.8.9.exe
    fi

    # Determine installation mode (silent or not)
    QUIET_MODE=""
    for arg in "$@"; do
        if [[ "$arg" == "-s" ]]; then
            QUIET_MODE="/quiet"
            break
        fi
    done

    echo "Installing Python 3.8.9 in Wine..."
    # Using xvfb-run to avoid GUI errors if no X server is present
    if command -v xvfb-run &> /dev/null; then
        xvfb-run wine cmd /c python-3.8.9.exe $QUIET_MODE InstallAllUsers=0 PrependPath=1 || echo "Wine installation command failed, might still have worked."
    else
        wine cmd /c python-3.8.9.exe $QUIET_MODE InstallAllUsers=0 PrependPath=1 || echo "Wine installation command failed, might still have worked."
    fi

    echo "Waiting for Wine to finish..."
    sleep 10

    # Find where it was installed
    CURRENT_USER=$(whoami)
    PYTHON_EXE=$(find "$HOME/.wine" -name "python.exe" | grep "Python38-32" | head -n 1 || true)

    if [[ -z "$PYTHON_EXE" ]]; then
        echo "Searching in /root/.wine as fallback..."
        PYTHON_EXE=$(find "/root/.wine" -name "python.exe" | grep "Python38-32" | head -n 1 || true)
    fi

    if [[ -z "$PYTHON_EXE" ]]; then
        echo "[!] Could not find python.exe in Wine environment."
        echo "[!] You may need to install it manually using: wine python-3.8.9.exe"
    else
        echo "Found Python in Wine: $PYTHON_EXE"
        echo "Installing Python packages in Wine..."
        # Using script to avoid "Invalid handle" errors in non-interactive shells
        INSTALL_CMD="wine \"$PYTHON_EXE\" -m pip install --upgrade pip && \
                     wine \"$PYTHON_EXE\" -m pip install wheel && \
                     wine \"$PYTHON_EXE\" -m pip install psutil==5.9.5 && \
                     wine \"$PYTHON_EXE\" -m pip install pillow==8.3.2 pyscreeze==0.1.28 pyautogui==0.9.52 keyboard==0.13.5 pywin32==303 pycryptodome==3.12.0 pyinstaller==5.3 discord_webhook==0.14.0 discord.py opencv-python==4.5.3.56 sounddevice scipy==1.9.0 pyTelegramBotAPI PyGithub"

        if command -v script &> /dev/null; then
            script -q -c "$INSTALL_CMD" /dev/null
        else
            eval "$INSTALL_CMD"
        fi
    fi
fi

echo "Setup Complete!"
