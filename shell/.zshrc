# ==============================================================================
# Dynamic Prompt Badges (Miniforge + Node.js)
# ==============================================================================
set_development_prompt() {
    local env_badges=""

    # 1. Check for active Miniforge / Conda Environment
    if [[ -n "$CONDA_DEFAULT_ENV" && -n "$CONDA_PREFIX" ]]; then
        env_badges+="(%F{green}$CONDA_DEFAULT_ENV%f) "
    fi

    # 2. Check for active Node.js version
    local node_ver="${NVMRC_VERSION:-}"
    if [[ -n "$node_ver" ]]; then
        env_badges+="(%F{cyan}node:$node_ver%f) "
    fi
    env_badges=${env_badges/\) \(/|}

    # 3. Combine badges with original prompt layout
    PROMPT="$env_badges$ORIG_PROMPT"
}

# Customise prompt layout (default: "%n@%m %1~ %# ")
PROMPT="%n@ %1~ %# "

# Securely store original system prompt layout
if [[ -z "$ORIG_PROMPT" ]]; then
    ORIG_PROMPT="$PROMPT"
fi

autoload -Uz add-zsh-hook
add-zsh-hook precmd set_development_prompt

# ==============================================================================
# NVM Loader & Smart .nvmrc Auto-Switcher
# ==============================================================================
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Automatically switch Node.js version based on .nvmrc
load-nvmrc() {
    local nvmrc_path="$(nvm_find_nvmrc 2>/dev/null)"

    if [[ -n "$nvmrc_path" ]]; then
        if [[ "$CURRENT_NVMRC_PATH" != "$nvmrc_path" ]]; then
            CURRENT_NVMRC_PATH="$nvmrc_path"
            echo "nvm: loading ${nvmrc_path/#$HOME/~}"
        fi

        local nvmrc_node_version
        nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")" 2>/dev/null)

        if [[ "$nvmrc_node_version" = "N/A" ]]; then
            nvm install
            NVMRC_VERSION="$(nvm version)"
        elif [[ "$nvmrc_node_version" != "$(nvm version)" ]]; then
            nvm use --silent
            NVMRC_VERSION="$(nvm version)"
        else
            NVMRC_VERSION="$(nvm version)"
        fi
    elif [[ -n "$CURRENT_NVMRC_PATH" ]]; then
        echo "nvm: unloading"
        CURRENT_NVMRC_PATH=""
        if [[ "$(nvm version)" != "$(nvm version default)" ]]; then
            nvm use default --silent
        fi
        NVMRC_VERSION=""
    elif [[ -z "$nvmrc_path" ]]; then
        NVMRC_VERSION=""
        CURRENT_NVMRC_PATH=""
    fi
}

add-zsh-hook chpwd load-nvmrc
load-nvmrc

# ==============================================================================
# Direnv Shell Hook
# ==============================================================================
if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv hook zsh)"
fi
