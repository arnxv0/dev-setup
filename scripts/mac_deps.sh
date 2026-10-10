#!/usr/bin/env bash

set -uo pipefail

# Homebrew is a hard prerequisite: every tool below comes from it. Exiting 0
# here used to report success while installing nothing, after which run.sh
# cheerfully deployed configs referencing nvim/tmux/fzf that did not exist.
if ! command -v brew &> /dev/null; then
    # Apple Silicon and Intel install to different prefixes; pick up either if
    # brew is present but not yet on PATH (common on a fresh machine).
    for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [ -x "$p" ]; then
            eval "$("$p" shellenv)"
            break
        fi
    done
fi

if ! command -v brew &> /dev/null; then
    cat >&2 <<'MSG'
Homebrew is required and was not found.

Install it, then re-run ./run.sh:
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

Afterwards make sure brew is on PATH (the installer prints the exact line;
on Apple Silicon it is: eval "$(/opt/homebrew/bin/brew shellenv)").
MSG
    exit 1
fi
echo "Homebrew found: $(command -v brew)"

echo "Installing dependencies..."

# ── lazygit ──────────────────────────────────────────────────────────────────
if ! command -v lazygit &> /dev/null; then
    brew install lazygit
    echo "lazygit installed."
else
    echo "lazygit already installed."
fi

# ── Neovim (ensure 0.12+) ─────────────────────────────────────────────────────
if ! command -v nvim &> /dev/null; then
    brew install neovim
    echo "Neovim installed."
else
    echo "Neovim found — upgrading to ensure 0.12+..."
    brew upgrade neovim 2>/dev/null || echo "Neovim is already at the latest version."
fi

# ── tmux ─────────────────────────────────────────────────────────────────────
if ! command -v tmux &> /dev/null; then
    brew install tmux
    echo "tmux installed."
else
    echo "tmux already installed."
fi

# ── git ──────────────────────────────────────────────────────────────────────
if ! command -v git &> /dev/null; then
    brew install git
    echo "git installed."
else
    echo "git already installed."
fi

# ── ripgrep ──────────────────────────────────────────────────────────────────
if ! command -v rg &> /dev/null; then
    brew install ripgrep
    echo "ripgrep installed."
else
    echo "ripgrep already installed."
fi

# ── fzf ──────────────────────────────────────────────────────────────────────
if ! command -v fzf &> /dev/null; then
    brew install fzf
    echo "fzf installed."
else
    echo "fzf already installed."
fi

# ── tree-sitter CLI (required by nvim-treesitter main branch to compile parsers)
# NOTE: the `tree-sitter` formula is library-only; the CLI is `tree-sitter-cli`.
if ! command -v tree-sitter &> /dev/null; then
    brew install tree-sitter-cli
    echo "tree-sitter CLI installed."
else
    echo "tree-sitter CLI already installed."
fi

# ── Hack Nerd Font ────────────────────────────────────────────────────────────
# Used by Ghostty and Neovim (web-devicons, lualine icons, etc.)
if ! brew list --cask font-hack-nerd-font &> /dev/null; then
    brew install --cask font-hack-nerd-font
    echo "font-hack-nerd-font installed."
else
    echo "font-hack-nerd-font already installed."
fi

# ── Ghostty terminal emulator ─────────────────────────────────────────────────
if ! brew list --cask ghostty &> /dev/null; then
    brew install --cask ghostty
    echo "Ghostty installed."
else
    echo "Ghostty already installed."
fi

# ── TPM (tmux plugin manager) ─────────────────────────────────────────────────
# Needed by tmux-resurrect / tmux-continuum, which capture session state.
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" \
        && echo "TPM installed."
else
    echo "TPM already installed."
fi

# Install/update the plugins tmux.conf declares, without needing prefix+I.
if [ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
    "$HOME/.tmux/plugins/tpm/bin/install_plugins" > /dev/null 2>&1 \
        && echo "tmux plugins installed." \
        || echo "tmux plugin install skipped (run prefix+I inside tmux)."
fi

echo ""
echo "All dependencies are installed!"
