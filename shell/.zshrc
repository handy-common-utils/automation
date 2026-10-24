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
# Common Shell Configurations
# ==============================================================================
_shell_dir="$(cd -- "$(dirname -- "${(%):-%N}")" >/dev/null 2>&1 && pwd)"
if [[ -f "$_shell_dir/commonrc.sh" ]]; then
    source "$_shell_dir/commonrc.sh";
fi

add-zsh-hook chpwd load-nvmrc
load-nvmrc


