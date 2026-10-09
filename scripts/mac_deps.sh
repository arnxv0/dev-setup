#!/usr/bin/env bash

# Check if Homebrew is installed, and install it if not
if ! command -v brew &> /dev/null; then
    echo "Homebrew is not installed."
    exit 0
else
    echo "Homebrew is installed."
fi

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
