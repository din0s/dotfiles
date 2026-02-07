#!/usr/bin/env bash
set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Helpers ---

info()  { printf '\033[1;34m[info]\033[0m  %s\n' "$1"; }
ok()    { printf '\033[1;32m[ok]\033[0m    %s\n' "$1"; }
warn()  { printf '\033[1;33m[warn]\033[0m  %s\n' "$1"; }
err()   { printf '\033[1;31m[error]\033[0m %s\n' "$1"; }

command_exists() { command -v "$1" &>/dev/null; }

# --- Multi-select checkbox menu ---
# Usage: multiselect result_var "header" options_array selected_array
#   result_var:  name of array variable to store results (0/1 per option)
#   header:      text shown above the list
#   options:     array of option labels
#   selected:    array of 0/1 for default selection state
multiselect() {
    set +e
    local result_name="$1" header="$2"
    shift 2
    local -a options=()
    local -a selected=()
    local separator_found=0

    # Read args: options first, then "--" separator, then defaults
    for arg in "$@"; do
        if [[ "$arg" == "--" ]]; then
            separator_found=1
            continue
        fi
        if (( separator_found )); then
            selected+=("$arg")
        else
            options+=("$arg")
        fi
    done

    # Pad selected array with 1s (default: all selected)
    while (( ${#selected[@]} < ${#options[@]} )); do
        selected+=(1)
    done

    local count=${#options[@]}
    local cursor=0

    # Hide cursor
    printf '\033[?25l'

    # Ensure cursor is restored on exit
    trap 'printf "\033[?25h"' RETURN

    # Draw the menu
    draw() {
        # Move cursor up to redraw (skip on first draw)
        if (( ${1:-0} )); then
            printf '\033[%dA' "$((count))"
        fi
        for (( i=0; i<count; i++ )); do
            local marker=" "
            if (( selected[i] )); then
                marker="\033[1;32m✔\033[0m"
            fi
            if (( i == cursor )); then
                printf '\033[1;36m ❯\033[0m %b  %s\033[K\n' "$marker" "${options[i]}"
            else
                printf '   %b  %s\033[K\n' "$marker" "${options[i]}"
            fi
        done
    }

    printf '\n\033[1;35m%s\033[0m\n' "$header"
    printf '\033[2m  (↑/↓ navigate, space toggle, a toggle all, enter confirm)\033[0m\n'
    draw 0

    # Read keypresses
    while true; do
        local key
        IFS= read -rsn1 key

        case "$key" in
            # Arrow key escape sequences
            $'\x1b')
                read -rsn2 seq
                case "$seq" in
                    '[A') (( cursor > 0 )) && (( cursor-- )) ;;       # up
                    '[B') (( cursor < count-1 )) && (( cursor++ )) ;; # down
                esac
                ;;
            # Space - toggle current item
            ' ')
                selected[cursor]=$(( 1 - selected[cursor] ))
                ;;
            # 'a' - toggle all
            a|A)
                # If all selected, deselect all; otherwise select all
                local all_on=1
                for (( i=0; i<count; i++ )); do
                    (( selected[i] )) || { all_on=0; break; }
                done
                local new_val=$(( 1 - all_on ))
                for (( i=0; i<count; i++ )); do
                    selected[i]=$new_val
                done
                ;;
            # Enter - confirm
            '')
                printf '\n'
                break
                ;;
        esac

        draw 1
    done

    # Write results to the named variable
    eval "$result_name"='("${selected[@]}")'
    set -e
}

# --- Detect OS & package manager ---

OS="$(uname -s)"
PKG=""

if [[ "$OS" == "Darwin" ]]; then
    if command_exists zb; then
        PKG="zb"
    elif command_exists brew; then
        PKG="brew"
    else
        warn "No package manager found (zerobrew or homebrew)."
        warn "Install zerobrew: https://github.com/lucasgelfond/zerobrew"
        warn "Falling back to direct installers where possible."
    fi
elif [[ "$OS" == "Linux" ]]; then
    if command_exists apt && sudo -n true 2>/dev/null; then
        PKG="apt"
    elif command_exists apt; then
        if ask "apt found — do you have sudo privileges?"; then
            PKG="apt"
        else
            warn "Skipping apt — falling back to direct installers where possible."
        fi
    fi

    if [[ -z "$PKG" ]]; then
        if command_exists brew; then
            PKG="brew"
        else
            warn "No supported package manager found."
            warn "Falling back to direct installers where possible."
        fi
    fi
fi

echo ""
info "OS: $OS | Package manager: ${PKG:-none}"

pkg_install() {
    case "$PKG" in
        zb)   zb install "$@" ;;
        brew) brew install "$@" ;;
        apt)  sudo apt update && sudo apt install -y "$@" ;;
        *)    return 1 ;;
    esac
}

# --- Build options list, skipping already-installed items ---

labels=()
keys=()
defaults=()

check_or_add() {
    local key="$1" label="$2" check_cmd="$3" check_arg="$4"

    if [[ "$check_cmd" == "command" ]] && command_exists "$check_arg"; then
        ok "$label already installed"
    elif [[ "$check_cmd" == "dir" ]] && [[ -d "$check_arg" ]]; then
        ok "$label already installed"
    else
        labels+=("$label")
        keys+=("$key")
        defaults+=(1)
    fi
}

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

check_or_add zsh        "zsh"                              command zsh
check_or_add omz        "Oh My Zsh"                        dir     "$HOME/.oh-my-zsh"
check_or_add p10k       "Powerlevel10k (theme)"            dir     "$ZSH_CUSTOM/themes/powerlevel10k"
check_or_add plug_auto  "  ├ zsh-autosuggestions"          dir     "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
check_or_add plug_fzf   "  ├ zsh-fzf-history-search"      dir     "$ZSH_CUSTOM/plugins/zsh-fzf-history-search"
check_or_add plug_syn   "  ├ zsh-syntax-highlighting"      dir     "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
check_or_add plug_comp  "  ├ zsh-completions"              dir     "$ZSH_CUSTOM/plugins/zsh-completions"
check_or_add plug_k     "  └ k"                            dir     "$ZSH_CUSTOM/plugins/k"
check_or_add tmux       "tmux"                             command tmux
check_or_add fzf        "fzf"                              command fzf
check_or_add zoxide     "zoxide"                           command zoxide
check_or_add neovim     "neovim"                           command nvim
# Check if all dotfile symlinks already point to this repo
symlinks_ok=true
[[ -L "$HOME/.zshrc" && "$(readlink "$HOME/.zshrc")" == "$DOTFILES_DIR/.zshrc" ]] || symlinks_ok=false
[[ -L "$HOME/.p10k.zsh" && "$(readlink "$HOME/.p10k.zsh")" == "$DOTFILES_DIR/.p10k.zsh" ]] || symlinks_ok=false
[[ -L "$HOME/.tmux.conf" && "$(readlink "$HOME/.tmux.conf")" == "$DOTFILES_DIR/.tmux.conf" ]] || symlinks_ok=false
[[ -L "$HOME/.config/nvim/init.lua" && "$(readlink "$HOME/.config/nvim/init.lua")" == "$DOTFILES_DIR/.config/nvim/init.lua" ]] || symlinks_ok=false
[[ -L "$HOME/.config/ghostty/config" && "$(readlink "$HOME/.config/ghostty/config")" == "$DOTFILES_DIR/.config/ghostty/config" ]] || symlinks_ok=false

if $symlinks_ok; then
    ok "Dotfiles already symlinked"
else
    labels+=("Symlink dotfiles to ~")
    keys+=("symlinks")
    defaults+=(1)
fi

if (( ${#labels[@]} == 0 )); then
    echo ""
    ok "Everything is already installed!"
    exit 0
fi

# --- Show checkbox menu ---

choices=()
multiselect choices "What would you like to install?" "${labels[@]}" -- "${defaults[@]}"

# Helper to check if a key was selected
selected() {
    local target="$1"
    for (( i=0; i<${#keys[@]}; i++ )); do
        if [[ "${keys[i]}" == "$target" ]] && (( choices[i] )); then
            return 0
        fi
    done
    return 1
}

# --- Install selected items ---

# zsh
if selected zsh; then
    info "Installing zsh..."
    if ! pkg_install zsh; then
        err "Cannot install zsh without a package manager. Please install it manually."
        exit 1
    fi
fi

# Oh My Zsh
if selected omz; then
    info "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

clone_if_missing() {
    local repo="$1" dest="$2"
    if [[ -d "$dest" ]]; then
        ok "Already installed: $(basename "$dest")"
    else
        info "Cloning $(basename "$dest")..."
        git clone --depth=1 "$repo" "$dest"
    fi
}

# Powerlevel10k
if selected p10k; then
    clone_if_missing https://github.com/romkatv/powerlevel10k.git \
        "$ZSH_CUSTOM/themes/powerlevel10k"
fi

# OMZ plugins
selected plug_auto && clone_if_missing https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

selected plug_fzf && clone_if_missing https://github.com/joshskidmore/zsh-fzf-history-search \
    "$ZSH_CUSTOM/plugins/zsh-fzf-history-search"

selected plug_syn && clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

selected plug_comp && clone_if_missing https://github.com/zsh-users/zsh-completions \
    "$ZSH_CUSTOM/plugins/zsh-completions"

selected plug_k && clone_if_missing https://github.com/supercrabtree/k \
    "$ZSH_CUSTOM/plugins/k"

# tmux
if selected tmux; then
    info "Installing tmux..."
    if ! pkg_install tmux; then
        err "Could not install tmux. Please install it manually."
    fi
fi

# fzf
if selected fzf; then
    info "Installing fzf..."
    if ! pkg_install fzf; then
        info "Installing fzf via git..."
        git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
        "$HOME/.fzf/install" --bin
        warn "fzf installed to ~/.fzf/bin — add it to your PATH if needed"
    fi
fi

# zoxide
if selected zoxide; then
    info "Installing zoxide..."
    if ! pkg_install zoxide; then
        info "Installing zoxide via installer script..."
        curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
        warn "zoxide installed to ~/.local/bin — make sure it's in your PATH"
    fi
fi

# neovim
if selected neovim; then
    info "Installing neovim..."
    if ! pkg_install neovim; then
        if [[ "$OS" == "Linux" ]]; then
            info "Installing neovim via AppImage..."
            curl -sSfLo /tmp/nvim.appimage https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
            chmod u+x /tmp/nvim.appimage
            mkdir -p "$HOME/.local/bin"
            mv /tmp/nvim.appimage "$HOME/.local/bin/nvim"
            warn "neovim installed to ~/.local/bin/nvim"
        else
            err "Could not install neovim. Please install it manually."
        fi
    fi
fi

# Symlinks
if selected symlinks; then
    symlink() {
        local src="$1" dest="$2"
        if [[ -L "$dest" ]]; then
            ok "Already linked: $dest"
        elif [[ -e "$dest" ]]; then
            warn "$dest exists and is not a symlink — backing up to ${dest}.bak"
            mv "$dest" "${dest}.bak"
            ln -s "$src" "$dest"
            ok "Linked: $dest (old file backed up)"
        else
            ln -s "$src" "$dest"
            ok "Linked: $dest"
        fi
    }

    info "Symlinking dotfiles..."
    symlink "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
    symlink "$DOTFILES_DIR/.p10k.zsh" "$HOME/.p10k.zsh"
    symlink "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"
    mkdir -p "$HOME/.config/nvim"
    symlink "$DOTFILES_DIR/.config/nvim/init.lua" "$HOME/.config/nvim/init.lua"
    mkdir -p "$HOME/.config/ghostty"
    symlink "$DOTFILES_DIR/.config/ghostty/config" "$HOME/.config/ghostty/config"
fi

echo ""
ok "All done! Restart your shell or run: exec zsh"
