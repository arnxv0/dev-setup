#!/usr/bin/env bash

# Everything below uses ./scripts paths, so run from the repo root no matter
# where this was invoked from.
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

# --llm enables the optional LLM pieces (Ollama, API key file, nvim AI
# completion); --no-llm turns them off. Either is remembered, so plain
# ./run.sh afterwards keeps whatever this machine last chose.
LLM_ARGS=()
for a in "$@"; do
    case "$a" in
        --llm|--no-llm) LLM_ARGS+=( "$a" ) ;;
        *) echo "usage: ./run.sh [--llm | --no-llm]" >&2; exit 2 ;;
    esac
done

# Detect the operating system
OS=$(uname)

# Run the appropriate .sh files based on the OS
if [[ "$OS" == "Darwin" ]]; then
    echo "Detected macOS. Running macOS setup..."
    chmod -R +x "./scripts"

    # Stop if dependencies failed: deploying configs that reference missing
    # tools produces a broken shell rather than a partial install.
    if ! ./scripts/mac_deps.sh ${LLM_ARGS[@]+"${LLM_ARGS[@]}"}; then
        echo "Dependency installation failed; not touching dotfiles." >&2
        exit 1
    fi

    # setup-dots exits 3 when it found drift it refused to overwrite. That is
    # informational, not a failure.
    ./scripts/setup-dots.sh ${LLM_ARGS[@]+"${LLM_ARGS[@]}"}
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
