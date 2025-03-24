#!/usr/bin/env bash

# Detect the operating system
OS=$(uname)

# Run the appropriate .sh files based on the OS
if [[ "$OS" == "Darwin" ]]; then
    echo "Detected macOS. Running macOS setup..."
    chmod -R +x "./scripts"
    ./scripts/mac_deps.sh
    ./scripts/setup-dots.sh

elif [[ "$OS" == "Linux" ]]; then
    echo "Detected Linux. Setup not configured!"
else
    echo "Unsupported operating system: $OS"
    exit 1
fi
