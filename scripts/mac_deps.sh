#!/usr/bin/env bash

# Check if Homebrew is installed, and install it if not
if ! command -v brew &> /dev/null; then
    echo "Homebrew is not installed."
    exit 0
else
    echo "Homebrew is installed."
fi

# Update Homebrew to get the latest package information
# echo "Updating Homebrew..."
# brew update

# Install lazygit, neovim, tmux, and other common tools
echo "Installing dependencies..."

# Install lazygit
if ! command -v lazygit &> /dev/null; then
    brew install lazygit
    echo "lazygit installed successfully."
else
    echo "lazygit is already installed."
fi

# Install neovim
if ! command -v nvim &> /dev/null; then
    brew install neovim
    echo "Neovim installed successfully."
else
    echo "Neovim is already installed."
fi

# Install tmux
if ! command -v tmux &> /dev/null; then
    brew install tmux
    echo "tmux installed successfully."
else
    echo "tmux is already installed."
fi

# Install git
if ! command -v git &> /dev/null; then
    brew install git
    echo "git installed successfully."
else
    echo "git is already installed."
fi

# Install ripgrep
if ! command -v ripgrep &> /dev/null; then
    brew install ripgrep
    echo "ripgrep installed successfully."
else
    echo "ripgrep is already installed."
fi

# Install fzf
if ! command -v fzf &> /dev/null; then
    brew install fzf
    echo "fzf installed successfully."
else
    echo "fzf is already installed."
fi

# Install tree-sitter
if ! command -v tree-sitter &> /dev/null; then
    brew install tree-sitter
    echo "tree-sitter installed successfully."
else
    echo "tree-sitter is already installed."
fi

# Install font-hack-nerd-font
if ! command -v font-hack-nerd-font &> /dev/null; then
    brew install font-hack-nerd-font
    echo "font-hack-nerd-font installed successfully."
else
    echo "font-hack-nerd-font is already installed."
fi

echo "All dependencies are installed!"

# Optional: upgrade all installed packages
# Uncomment the following line if you want to upgrade all packages managed by Homebrew
# brew upgrade

