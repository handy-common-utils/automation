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
# Common Shell Configurations
# ==============================================================================
_shell_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
if [[ -f "$_shell_dir/commonrc.sh" ]]; then
    source "$_shell_dir/commonrc.sh";
fi

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


