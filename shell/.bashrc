# ==============================================================================
# Dynamic Prompt Badges (Miniforge + Node.js) for Bash
# ==============================================================================
set_development_prompt() {
    local env_badges=""

    # 1. Check for active Miniforge / Conda Environment
    if [[ -n "$CONDA_DEFAULT_ENV" && -n "$CONDA_PREFIX" ]]; then
        env_badges+="(\[\e[32m\]${CONDA_DEFAULT_ENV}\[\e[0m\]) "
    fi

    # 2. Check for active Node.js version
    local node_ver="${NVMRC_VERSION:-}"
    if [[ -n "$node_ver" ]]; then
        env_badges+="(\[\e[36m\]node:${node_ver}\[\e[0m\]) "
    fi
    env_badges="${env_badges/\) \(/|}"

    PS1="${env_badges}${ORIG_PS1:-\u@ \W \$ }"
}

# Preserve original prompt layout if not set
if [[ -z "$ORIG_PS1" ]]; then
    ORIG_PS1="${PS1:-\u@ \W \$ }"
fi

# ==============================================================================
# NVM Loader & Smart .nvmrc Auto-Switcher
# ==============================================================================
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

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

# ==============================================================================
# Bash Prompt & Directory Change Hook
# ==============================================================================
__prompt_and_nvm_hook() {
    # Only run load-nvmrc when the directory actually changes
    if [[ "$PWD" != "$__PREV_PWD" ]]; then
        __PREV_PWD="$PWD"
        load-nvmrc
    fi
    set_development_prompt
}

# Safely register to PROMPT_COMMAND (compatible with Bash 3.2, 4.x, and 5.x)
if [[ ";${PROMPT_COMMAND[*]:-};" != *";__prompt_and_nvm_hook;"* ]]; then
    if [[ "$(declare -p PROMPT_COMMAND 2>&1)" == "declare -a"* ]]; then
        PROMPT_COMMAND+=("__prompt_and_nvm_hook")
    else
        PROMPT_COMMAND="${PROMPT_COMMAND:+${PROMPT_COMMAND};}__prompt_and_nvm_hook"
    fi
fi

# ==============================================================================
# Direnv Shell Hook
# ==============================================================================
if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv hook bash)"
fi
