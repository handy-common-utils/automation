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


# ==============================================================================
# Generate Random Phrase (e.g. word1-word2)
# Usage:
#   generate-random-phrase             # pseudo-random phrase
#   generate-random-phrase "my-seed"   # deterministic phrase from seed
# ==============================================================================
generate-random-phrase() {
    local seed="${1:-$RANDOM-$RANDOM-$(date +%s%N 2>/dev/null || date +%s)}"
    local hash num1 num2
    hash="$(printf '%s\n' "$seed" | md5sum | awk '{print $1}')"
    num1=$(( 16#${hash:0:8} ))
    num2=$(( 16#${hash:8:8} ))

    local d dict="" phrase=""
    for d in /usr/share/dict/words /usr/share/dict/american-english; do
        if [[ -r "$d" ]]; then
            dict="$d"
            break
        fi
    done

    if [[ -n "$dict" ]]; then
        phrase="$(awk -v s1="$num1" -v s2="$num2" '
            length($0) >= 4 && length($0) <= 8 && $0 ~ /^[a-z]+$/ { words[++n] = $0 }
            END {
                if (n > 0) {
                    print words[s1 % n + 1] "-" words[s2 % n + 1]
                }
            }
        ' "$dict")"
    fi

    # Fallback if system dictionary is unavailable.
    if [[ -z "$phrase" ]]; then
        local adjectives=(autumn breeze crystal dawn ember frosty gentle harbor island mist quiet shadow silver solar tranquil velvet whisper winter zenith)
        local nouns=(canyon cedar falcon forest haven lake meadow mountain oasis ocean river valley voyage wanderer willow)
        local a_idx=$(( num1 % ${#adjectives[@]} ))
        local n_idx=$(( num2 % ${#nouns[@]} ))
        phrase="${adjectives[a_idx]}-${nouns[n_idx]}"
    fi

    printf '%s\n' "$phrase"
}


# ==============================================================================
# Mask OS and user fingerprint.
# Please note that it is not totally reliable.
#
# Usage:
# switchto /data/a alice
# switchto /data/b bob /usr/bin/firefox
# ==============================================================================
switchto() {
    if (( $# < 2 || $# > 3 )); then
        echo "Usage: switchto <profile-dir> <username> [browser-path]" >&2
        return 2
    fi

    local base="${1%/}"
    local username="$2"
    local browser_arg="${3:-}"

    # Validate profile directory.
    if [[ ! -d "$base" ]]; then
        echo "Profile directory does not exist: $base" >&2
        return 1
    fi

    # Read or generate hostname (persisted in $base/hostname).
    local new_hostname=""
    if [[ -f "$base/hostname" ]]; then
        read -r new_hostname < "$base/hostname" || true
    fi

    if [[ -z "$new_hostname" ]]; then
        new_hostname="$(generate-random-phrase "$base:$username")"
        printf '%s\n' "$new_hostname" > "$base/hostname"
        chmod 644 "$base/hostname"
    fi

    # Detect browser: argument -> $BROWSER -> chrome -> firefox -> edge
    local browser="" candidate candidate_path
    for candidate in "${browser_arg:-}" "${BROWSER:-}" chrome google-chrome firefox edge microsoft-edge; do
        if [[ -n "$candidate" ]]; then
            if [[ -x "$candidate" ]]; then
                browser="$candidate"
                break
            elif candidate_path="$(command -v "$candidate" 2>/dev/null)"; then
                browser="$candidate_path"
                break
            fi
        fi
    done

    # Ensure home directory exists.
    mkdir -p "$base/home"

    # Generate machine-id if missing (stable hash from profile-dir and username).
    if [[ ! -f "$base/machine-id" ]]; then
        printf '%s\n' "$base:$username" | md5sum | awk '{print $1}' > "$base/machine-id"
        chmod 644 "$base/machine-id"
    fi

    # Generate passwd file if missing.
    if [[ ! -f "$base/passwd" ]]; then
        local current_uid current_gid
        current_uid="$(id -u)"
        current_gid="$(id -g)"
        cat > "$base/passwd" <<EOF
root:x:0:0:root:/root:/bin/bash
${username}:x:${current_uid}:${current_gid}:${username}:${base}/home:/bin/bash
EOF
        chmod 644 "$base/passwd"
    fi

    # Set up session-specific xdg-open wrapper if a browser was found.
    if [[ -n "$browser" ]]; then
        mkdir -p "$base/bin"
        cat > "$base/bin/xdg-open" <<EOF
#!/bin/bash

# Intercept HTTP/HTTPS URLs only.
if [[ "\${1:-}" =~ ^https?:// ]]; then
    exec "\${BROWSER:-$browser}" "\$@"
fi

# Preserve normal Ubuntu behaviour for everything else.
exec /usr/bin/xdg-open "\$@"
EOF
        chmod +x "$base/bin/xdg-open"
    else
        rm -f "$base/bin/xdg-open"
    fi

    sudo unshare --uts --mount bash -c '
        set -e

        base="$1"
        username="$2"
        new_hostname="$3"
        browser="$4"

        # Prevent mount changes propagating outside this namespace.
        mount --make-rprivate /

        # Apply hostname and OS identity masks.
        hostname "$new_hostname"
        if [[ -f "$base/hostname" && -f /etc/hostname ]]; then
            mount --bind "$base/hostname" /etc/hostname
        fi
        if [[ -f "$base/os-release" ]]; then
            mount --bind "$base/os-release" /etc/os-release
        fi
        mount --bind "$base/machine-id" /etc/machine-id
        mount --bind "$base/passwd" /etc/passwd

        if [[ -f /var/lib/dbus/machine-id ]]; then
            mount --bind "$base/machine-id" /var/lib/dbus/machine-id
        fi

        # Launch the target user shell with a controlled environment.
        env_vars=(
            HOME="$base/home"
            USER="$username"
            LOGNAME="$username"
            USERNAME="$username"
            PATH="$base/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/google/chrome"
            TERM="${TERM:-xterm}"
            DISPLAY="${DISPLAY:-}"
            WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}"
            XAUTHORITY="${XAUTHORITY:-}"
            XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}"
            DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-}"
        )
        if [[ -n "$browser" ]]; then
            env_vars+=(BROWSER="$browser" CHROME_PATH="$browser")
        fi

        exec env -i "${env_vars[@]}" runuser -m -u "$username" -- bash
    ' bash "$base" "$username" "$new_hostname" "$browser"
}
