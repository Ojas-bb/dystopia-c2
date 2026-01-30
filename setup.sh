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

    # Prepare Wine environment
    export WINEARCH=win32
    export WINEDEBUG=-all

    echo "Initializing Wine prefix (win32)..."
    if command -v xvfb-run &> /dev/null; then
        xvfb-run -a wineboot -i
    else
        wineboot -i
    fi

    echo "Installing Python 3.8.9 in Wine..."
    echo "This process is silent and may take 2-5 minutes. Please wait..."

    # Force /quiet mode for headless compatibility
    INSTALL_CMD="wine python-3.8.9.exe /quiet InstallAllUsers=0 PrependPath=1"

    if command -v xvfb-run &> /dev/null; then
        xvfb-run -a $INSTALL_CMD || echo "Wine installation command returned non-zero, checking if it worked anyway..."
    else
        $INSTALL_CMD || echo "Wine installation command returned non-zero, checking if it worked anyway..."
    fi

    echo "Waiting for installation to settle..."
    sleep 20

    # Find where it was installed with retries
    PYTHON_EXE=""
    for i in {1..6}; do
        echo "Searching for python.exe (Attempt $i)..."
        PYTHON_EXE=$(find "$HOME/.wine" -name "python.exe" | grep "Python38-32" | head -n 1 || true)
        if [[ -n "$PYTHON_EXE" ]]; then break; fi
        sleep 10
    done

    if [[ -z "$PYTHON_EXE" ]]; then
        echo "Searching in /root/.wine as fallback..."
        PYTHON_EXE=$(find "/root/.wine" -name "python.exe" | grep "Python38-32" | head -n 1 || true)
    fi

    if [[ -z "$PYTHON_EXE" ]]; then
        echo "[!] Could not find python.exe in Wine environment."
        echo "[!] Installation likely failed. Try running: xvfb-run -a wine python-3.8.9.exe"
    else
        echo "Found Python in Wine: $PYTHON_EXE"
        echo "Installing Python packages in Wine..."

        # Use absolute path for pip and handle "Invalid handle" issues
        # psutil 5.9.5 has pre-built 32-bit wheels for Python 3.8
        INSTALL_CMD="wine \"$PYTHON_EXE\" -m pip install --upgrade pip && \
                     wine \"$PYTHON_EXE\" -m pip install wheel && \
                     wine \"$PYTHON_EXE\" -m pip install psutil==5.9.5 && \
                     wine \"$PYTHON_EXE\" -m pip install pillow==8.3.2 pyscreeze==0.1.28 pyautogui==0.9.52 keyboard==0.13.5 pywin32==303 pycryptodome==3.12.0 pyinstaller==5.3 discord_webhook==0.14.0 discord.py opencv-python==4.5.3.56 sounddevice scipy==1.9.0 pyTelegramBotAPI PyGithub"

        if command -v script &> /dev/null; then
            script -q -c "export WINEDEBUG=-all && export WINEARCH=win32 && $INSTALL_CMD" /dev/null
        else
            eval "export WINEDEBUG=-all && export WINEARCH=win32 && $INSTALL_CMD"
        fi
    fi
fi

echo "Setup Complete!"
