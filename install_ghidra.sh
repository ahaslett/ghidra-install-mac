#!/bin/bash

# Script to install Ghidra on macOS (Intel and Apple Silicon) using Homebrew
# Date: February 23, 2025
# Supports both Intel (x86_64) and Apple Silicon (aarch64) architectures

# Detect system architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    BREW_PREFIX="/usr/local"
    echo "Detected Intel (x86_64) architecture."
elif [ "$ARCH" = "arm64" ]; then
    BREW_PREFIX="/opt/homebrew"
    echo "Detected Apple Silicon (arm64) architecture."
else
    echo "Unsupported architecture: $ARCH. This script supports Intel and Apple Silicon only."
    exit 1
fi

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ $? -ne 0 ]; then
        echo "Failed to install Homebrew. Please install manually and rerun this script."
        exit 1
    fi
    # Ensure Homebrew is in PATH for the current session
    eval "$(${BREW_PREFIX}/bin/brew shellenv)"
    echo "Homebrew installed successfully."
else
    echo "Homebrew is already installed."
    # Ensure Homebrew is in PATH
    eval "$(${BREW_PREFIX}/bin/brew shellenv)"
fi

# Update Homebrew to ensure we have the latest package definitions
echo "Updating Homebrew..."
brew update
if [ $? -ne 0 ]; then
    echo "Failed to update Homebrew. Please check your internet connection or permissions."
    exit 1
fi

# Install Xcode Command Line Tools (required for Ghidra building or debugging)
if ! xcode-select -p &> /dev/null; then
    echo "Xcode Command Line Tools not found. Installing..."
    xcode-select --install
    echo "Please follow the prompts to install Xcode Command Line Tools, then rerun this script if needed."
    exit 1
else
    echo "Xcode Command Line Tools are already installed."
fi

# Install OpenJDK 21 (required for Ghidra 11.3.1+)
if ! command -v java &> /dev/null; then
    echo "Java not found. Installing OpenJDK 21 (required for Ghidra)..."
    brew install openjdk@21
    if [ $? -ne 0 ]; then
        echo "Failed to install OpenJDK 21. Please install manually (e.g., via brew install openjdk@21) and rerun this script."
        exit 1
    fi
    # Set PATH and JAVA_HOME for the current session and persist in .zshrc
    echo "Configuring Java PATH and JAVA_HOME..."
    echo 'export PATH="'${BREW_PREFIX}'/opt/openjdk@21/bin:$PATH"' >> ~/.zshrc
    echo 'export JAVA_HOME="'${BREW_PREFIX}'/opt/openjdk@21"' >> ~/.zshrc
    source ~/.zshrc
    echo "OpenJDK 21 installed and configured."
else
    echo "Java is already installed. Checking version..."
    JAVA_VERSION=$(java -version 2>&1 | grep version | awk '{print $3}' | tr -d '"')
    if [[ $JAVA_VERSION < "21" ]]; then
        echo "Java version is too old ($JAVA_VERSION). Installing OpenJDK 21..."
        brew uninstall openjdk@17  # Remove older version if present
        brew install openjdk@21
        echo 'export PATH="'${BREW_PREFIX}'/opt/openjdk@21/bin:$PATH"' >> ~/.zshrc
        echo 'export JAVA_HOME="'${BREW_PREFIX}'/opt/openjdk@21"' >> ~/.zshrc
        source ~/.zshrc
    else
        echo "Java version $JAVA_VERSION is compatible with Ghidra."
    fi
fi

# Install Ghidra using Homebrew (via Cask for GUI applications)
echo "Installing Ghidra..."
brew install --cask ghidra
if [ $? -ne 0 ]; then
    echo "Failed to install Ghidra. Please check for errors and try again."
    exit 1
fi
echo "Ghidra installed successfully."

# Verify Ghidra installation (check both /Applications and cellar for both architectures)
GHIDRA_APP_PATH="/Applications/Ghidra.app"
GHIDRA_CELLAR_PATH="${BREW_PREFIX}/Cellar/ghidra"
if [ -d "$GHIDRA_APP_PATH" ]; then
    echo "Ghidra is installed at $GHIDRA_APP_PATH. You can launch it with 'open $GHIDRA_APP_PATH'."
elif [ -d "$GHIDRA_CELLAR_PATH" ]; then
    LATEST_VERSION=$(ls -d "$GHIDRA_CELLAR_PATH"/*/ | tail -n 1)
    GHIDRA_RUN="$LATEST_VERSION/ghidraRun"
    if [ -f "$GHIDRA_RUN" ]; then
        echo "Ghidra is installed in the cellar at $LATEST_VERSION. You can launch it with './ghidraRun' from $LATEST_VERSION."
        # Optionally move Ghidra.app to /Applications for convenience
        if [ -d "$LATEST_VERSION/Ghidra.app" ]; then
            echo "Moving Ghidra.app to /Applications for easier access..."
            sudo mv "$LATEST_VERSION/Ghidra.app" /Applications/
            echo "Ghidra moved to /Applications/Ghidra.app. Launch with 'open /Applications/Ghidra.app'."
        fi
    else
        echo "Ghidra installation verification failed. Please check manually in $GHIDRA_CELLAR_PATH."
        exit 1
    fi
else
    echo "Ghidra installation verification failed. Please check manually in /Applications or $GHIDRA_CELLAR_PATH."
    exit 1
fi

# Symlink JDK for system Java wrappers (optional, improves integration)
JDK_SYMLINK="/Library/Java/JavaVirtualMachines/openjdk-21.jdk"
if [ ! -L "$JDK_SYMLINK" ]; then
    echo "Symlinking OpenJDK 21 for system Java wrappers..."
    sudo ln -sfn "${BREW_PREFIX}/opt/openjdk@21/libexec/openjdk.jdk" "$JDK_SYMLINK"
    echo "OpenJDK 21 symlinked successfully."
else
    echo "OpenJDK 21 is already symlinked for system use."
fi

echo "Ghidra installation completed successfully! Run Ghidra from /Applications or the cellar directory as instructed."
