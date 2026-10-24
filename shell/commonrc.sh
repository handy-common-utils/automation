# ==============================================================================
# Common Shell Configuration (shared between Bash and Zsh)
# ==============================================================================

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

# ==============================================================================
# Direnv Shell Hook
# ==============================================================================
if command -v direnv >/dev/null 2>&1; then
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        eval "$(direnv hook zsh)"
    elif [[ -n "${BASH_VERSION:-}" ]]; then
        eval "$(direnv hook bash)"
    fi
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
    # Bash arrays are 0-indexed; Zsh arrays are 1-indexed.
    if [[ -z "$phrase" ]]; then
        local adjectives=(autumn breeze crystal dawn ember frosty gentle harbor island mist quiet shadow silver solar tranquil velvet whisper winter zenith)
        local nouns=(canyon cedar falcon forest haven lake meadow mountain oasis ocean river valley voyage wanderer willow)
        local a_idx n_idx
        if [[ -n "${ZSH_VERSION:-}" ]]; then
            a_idx=$(( (num1 % ${#adjectives[@]}) + 1 ))
            n_idx=$(( (num2 % ${#nouns[@]}) + 1 ))
        else
            a_idx=$(( num1 % ${#adjectives[@]} ))
            n_idx=$(( num2 % ${#nouns[@]} ))
        fi
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

    # Determine active shell for target user session (zsh or bash).
    local target_shell="bash"
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        target_shell="zsh"
    fi

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

    local current_uid current_gid
    current_uid="$(id -u)"
    current_gid="$(id -g)"

    # Generate passwd file if missing.
    if [[ ! -f "$base/passwd" ]]; then
        cat > "$base/passwd" <<EOF
root:x:0:0:root:/root:/bin/bash
${username}:x:${current_uid}:${current_gid}:${username}:/home/${username}:/bin/${target_shell}
EOF
        chmod 644 "$base/passwd"
    else
        # Migrate existing passwd file if home was configured outside /home
        sed -i "s|:${base}/home:|:/home/${username}:|g" "$base/passwd"
    fi

    # Set up session-specific xdg-open/open wrappers if a browser was found.
    if [[ -n "$browser" ]]; then
        mkdir -p "$base/bin"
        cat > "$base/bin/xdg-open" <<EOF
#!/bin/bash

target="\${1:-}"

# Intercept HTTP/HTTPS URLs and www.* domains.
if [[ "\$target" =~ ^https?:// ]]; then
    exec "\${BROWSER:-$browser}" "\$@"
elif [[ "\$target" =~ ^www\. ]]; then
    shift
    exec "\${BROWSER:-$browser}" "https://\$target" "\$@"
fi

# Preserve normal Ubuntu behaviour for everything else.
exec /usr/bin/xdg-open "\$@"
EOF
        chmod +x "$base/bin/xdg-open"
        ln -sf xdg-open "$base/bin/open"
    else
        rm -f "$base/bin/xdg-open" "$base/bin/open"
    fi

    sudo unshare --uts --mount bash -c '
        set -e

        base="$1"
        username="$2"
        new_hostname="$3"
        browser="$4"
        target_shell="${5:-bash}"
        user_uid="$6"
        user_gid="$7"

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

        # Mount profile home directory to standard /home/$username for snap/desktop compatibility.
        if [[ ! -d "/home/$username" ]]; then
            mkdir -p "/home/$username"
        fi
        chown "$user_uid:$user_gid" "/home/$username"
        mount --bind "$base/home" "/home/$username"

        # Launch the target user shell with a controlled environment.
        env_vars=(
            HOME="/home/$username"
            USER="$username"
            LOGNAME="$username"
            USERNAME="$username"
            SHELL="/bin/$target_shell"
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

        exec env -i "${env_vars[@]}" runuser -m -u "$username" -- "$target_shell"
    ' bash "$base" "$username" "$new_hostname" "$browser" "$target_shell" "$current_uid" "$current_gid"
}
