#!/usr/bin/env bash

# Detect the operating system
OS=$(uname)

# Run the appropriate .sh files based on the OS
if [[ "$OS" == "Darwin" ]]; then
    echo "Detected macOS. Running macOS setup..."
    chmod -R +x "./scripts"

    # Stop if dependencies failed: deploying configs that reference missing
    # tools produces a broken shell rather than a partial install.
    if ! ./scripts/mac_deps.sh; then
        echo "Dependency installation failed; not touching dotfiles." >&2
        exit 1
    fi

    # setup-dots exits 3 when it found drift it refused to overwrite. That is
    # informational, not a failure.
    ./scripts/setup-dots.sh
    rc=$?
    if [ "$rc" -ne 0 ] && [ "$rc" -ne 3 ]; then
        echo "Dotfile setup failed (exit $rc)." >&2
        exit "$rc"
    fi

elif [[ "$OS" == "Linux" ]]; then
    echo "Detected Linux. Setup not configured!"
else
    echo "Unsupported operating system: $OS"
    exit 1
fi
