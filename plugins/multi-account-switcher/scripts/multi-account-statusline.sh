#!/bin/bash
# ============================================================================
# Multi-Account Statusline for Claude Code
# ============================================================================
# Shows all accounts' usage in statusline with current account highlighted
# Integrates with awesome-statusline design
# ============================================================================

input=$(cat)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACCOUNTS_FILE="${HOME}/.claude/multi-accounts.json"

# Parse JSON input
MODEL=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir // "."')
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
CURRENT_USAGE=$(echo "$input" | jq -r '.context_window.current_usage // null')

# ============================================================================
# Colors (Catppuccin)
# ============================================================================
RESET="\033[0m"
BOLD="\033[1m"
CLR="\033[K"

C_TEAL="\033[38;2;148;226;213m"
C_PINK="\033[38;2;245;194;231m"
C_PEACH="\033[38;2;250;179;135m"
C_GREEN="\033[38;2;166;227;161m"
C_SUBTEXT="\033[38;2;166;173;200m"
C_LAVENDER="\033[38;2;180;190;254m"
C_YELLOW="\033[38;2;249;226;175m"
C_OVERLAY="\033[38;2;108;112;134m"
C_LATTE_GREEN="\033[38;2;64;160;43m"
C_LATTE_RED="\033[38;2;210;15;57m"
C_LATTE_YELLOW="\033[38;2;223;142;29m"
C_SKY="\033[38;2;137;220;235m"
C_MAUVE="\033[38;2;203;166;247m"

# ============================================================================
# Platform Detection
# ============================================================================
get_platform() {
    case "$(uname -s)" in
        Darwin*) echo "darwin" ;;
        Linux*)  echo "linux" ;;
        MINGW*|MSYS*|CYGWIN*) echo "win32" ;;
        *) echo "unknown" ;;
    esac
}

get_current_token() {
    local platform=$(get_platform)
    case "$platform" in
        darwin)
            security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | \
                jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null
            ;;
        linux)
            secret-tool lookup service "Claude Code-credentials" 2>/dev/null | \
                jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null
            ;;
        win32)
            local cred_file="${HOME}/.claude/.credentials.json"
            [[ -f "$cred_file" ]] && jq -r '.claudeAiOauth.accessToken // empty' "$cred_file" 2>/dev/null
            ;;
    esac
}

get_current_account_email() {
    local current_token=$(get_current_token)
    [[ -z "$current_token" ]] && return 1

    # Claude tokens are not JWT, so we match against stored accounts
    [[ ! -f "$ACCOUNTS_FILE" ]] && return 1

    # Compare current token with stored account tokens
    while IFS= read -r line; do
        local email=$(echo "$line" | jq -r '.email')
        local stored_encrypted=$(echo "$line" | jq -r '.token')
        local stored_token=$(echo "$stored_encrypted" | base64 -d 2>/dev/null)

        if [[ "$stored_token" == "$current_token" ]]; then
            echo "$email"
            return 0
        fi
    done < <(jq -c '.accounts[]' "$ACCOUNTS_FILE" 2>/dev/null)

    return 1
}

# ============================================================================
# Gradient Functions
# ============================================================================
get_usage_gradient_color() {
    local pct=$1
    local r g b
    if [[ $pct -lt 40 ]]; then
        r=166; g=227; b=161  # Green
    elif [[ $pct -lt 70 ]]; then
        local t=$(((pct - 40) * 100 / 30))
        r=$((166 + (249 - 166) * t / 100))
        g=$((227 + (226 - 227) * t / 100))
        b=$((161 + (175 - 161) * t / 100))
    elif [[ $pct -lt 90 ]]; then
        local t=$(((pct - 70) * 100 / 20))
        r=$((249 + (210 - 249) * t / 100))
        g=$((226 + (15 - 226) * t / 100))
        b=$((175 + (57 - 175) * t / 100))
    else
        r=210; g=15; b=57  # Red
    fi
    echo "$r;$g;$b"
}

generate_mini_bar() {
    local pct=$1
    local width=5
    local bar=""
    local filled=$(( (pct * width + 50) / 100 ))
    [[ $filled -gt $width ]] && filled=$width

    local color=$(get_usage_gradient_color "$pct")

    for ((i=0; i<filled; i++)); do
        bar+="\033[38;2;${color}m█"
    done
    for ((i=0; i<width-filled; i++)); do
        bar+="\033[38;2;${color}m░"
    done

    printf "%b%b" "$bar" "$RESET"
}

# ============================================================================
# Get All Accounts Usage (cached)
# ============================================================================
CACHE_FILE="/tmp/.claude_multi_account_status"
CACHE_TTL=300

get_cached_accounts_usage() {
    # Check cache
    if [[ -f "$CACHE_FILE" ]]; then
        local file_age=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)))
        if [[ "$file_age" -lt "$CACHE_TTL" ]]; then
            cat "$CACHE_FILE"
            return 0
        fi
    fi

    [[ ! -f "$ACCOUNTS_FILE" ]] && return 1

    local result="[]"

    while IFS=$'\t' read -r name email; do
        [[ -z "$name" ]] && continue

        # Get token from stored accounts
        local encrypted=$(jq -r --arg name "$name" '.accounts[] | select(.name == $name) | .token' "$ACCOUNTS_FILE" 2>/dev/null)
        [[ -z "$encrypted" ]] && continue

        local token=$(echo "$encrypted" | base64 -d 2>/dev/null)
        [[ -z "$token" ]] && continue

        # Get usage
        local usage=$(curl -s --max-time 3 \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            -H "anthropic-beta: oauth-2025-04-20" \
            "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

        if [[ -n "$usage" ]] && echo "$usage" | jq -e '.five_hour' &>/dev/null; then
            local five_hour=$(echo "$usage" | jq -r '.five_hour.utilization // 0' | xargs printf "%.0f")
            local seven_day=$(echo "$usage" | jq -r '.seven_day.utilization // 0' | xargs printf "%.0f")

            local entry=$(jq -n \
                --arg name "$name" \
                --arg email "$email" \
                --argjson five "$five_hour" \
                --argjson seven "$seven_day" \
                '{name: $name, email: $email, five_hour: $five, seven_day: $seven}')

            result=$(echo "$result" | jq --argjson e "$entry" '. += [$e]')
        fi
    done < <(jq -r '.accounts[] | "\(.name)\t\(.email)"' "$ACCOUNTS_FILE" 2>/dev/null)

    # Sort by 5H usage (lowest first)
    result=$(echo "$result" | jq 'sort_by(.five_hour)')

    echo "$result" > "$CACHE_FILE"
    echo "$result"
}

# ============================================================================
# Context Usage
# ============================================================================
CONTEXT_PERCENT=0
if [[ "$CURRENT_USAGE" != "null" && -n "$CURRENT_USAGE" ]]; then
    INPUT_TOKENS=$(echo "$CURRENT_USAGE" | jq -r '.input_tokens // 0')
    CACHE_CREATE=$(echo "$CURRENT_USAGE" | jq -r '.cache_creation_input_tokens // 0')
    CACHE_READ=$(echo "$CURRENT_USAGE" | jq -r '.cache_read_input_tokens // 0')
    CURRENT_TOKENS=$((INPUT_TOKENS + CACHE_CREATE + CACHE_READ))
    [[ "$CONTEXT_SIZE" -gt 0 ]] && CONTEXT_PERCENT=$((CURRENT_TOKENS * 100 / CONTEXT_SIZE))
fi

CTX_COLOR=$(get_usage_gradient_color "$CONTEXT_PERCENT")
CTX_BAR=$(generate_mini_bar "$CONTEXT_PERCENT")

# ============================================================================
# Line 1: Model | Current Account | Context
# ============================================================================
CURRENT_EMAIL=$(get_current_account_email 2>/dev/null)
CURRENT_NAME=""

# Find current account name
if [[ -f "$ACCOUNTS_FILE" ]] && [[ -n "$CURRENT_EMAIL" ]]; then
    CURRENT_NAME=$(jq -r --arg email "$CURRENT_EMAIL" \
        '.accounts[] | select(.email == $email) | .name' "$ACCOUNTS_FILE" 2>/dev/null)
fi

if [[ -n "$CURRENT_NAME" ]]; then
    ACCOUNT_DISPLAY="👤 ${BOLD}${C_SKY}${CURRENT_NAME}${RESET}"
else
    ACCOUNT_DISPLAY="👤 ${C_OVERLAY}Not configured${RESET}"
fi

MODEL_DISPLAY="🤖 ${BOLD}${C_TEAL}${MODEL}${RESET}"
CTX_DISPLAY="🧠 ${CTX_BAR} ${BOLD}\033[38;2;${CTX_COLOR}m${CONTEXT_PERCENT}%${RESET}"

LINE1="${MODEL_DISPLAY} | ${ACCOUNT_DISPLAY} | ${CTX_DISPLAY}"

# ============================================================================
# Line 2: All Accounts Usage (sorted by availability)
# ============================================================================
ACCOUNTS_USAGE=$(get_cached_accounts_usage 2>/dev/null)

if [[ -n "$ACCOUNTS_USAGE" ]] && [[ "$ACCOUNTS_USAGE" != "[]" ]]; then
    LINE2=""
    ACCOUNT_COUNT=$(echo "$ACCOUNTS_USAGE" | jq 'length')

    for ((i=0; i<ACCOUNT_COUNT && i<4; i++)); do  # Max 4 accounts shown
        name=$(echo "$ACCOUNTS_USAGE" | jq -r ".[$i].name")
        email=$(echo "$ACCOUNTS_USAGE" | jq -r ".[$i].email")
        five=$(echo "$ACCOUNTS_USAGE" | jq -r ".[$i].five_hour")
        seven=$(echo "$ACCOUNTS_USAGE" | jq -r ".[$i].seven_day")

        # Highlight current account
        if [[ "$email" == "$CURRENT_EMAIL" ]]; then
            NAME_COLOR="${BOLD}${C_MAUVE}"
            INDICATOR="▶"
        else
            NAME_COLOR="${C_SUBTEXT}"
            INDICATOR=" "
        fi

        FIVE_COLOR=$(get_usage_gradient_color "$five")
        SEVEN_COLOR=$(get_usage_gradient_color "$seven")

        ACCOUNT_ENTRY="${INDICATOR}${NAME_COLOR}${name}${RESET}: "
        ACCOUNT_ENTRY+="${C_LAVENDER}5H${RESET} \033[38;2;${FIVE_COLOR}m${five}%${RESET} "
        ACCOUNT_ENTRY+="${C_YELLOW}7D${RESET} \033[38;2;${SEVEN_COLOR}m${seven}%${RESET}"

        [[ -n "$LINE2" ]] && LINE2+=" │ "
        LINE2+="$ACCOUNT_ENTRY"
    done
else
    # Fallback to single account usage
    TOKEN=$(get_current_token 2>/dev/null)
    if [[ -n "$TOKEN" ]]; then
        USAGE=$(curl -s --max-time 3 \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -H "anthropic-beta: oauth-2025-04-20" \
            "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

        if [[ -n "$USAGE" ]] && echo "$USAGE" | jq -e '.five_hour' &>/dev/null; then
            FIVE=$(echo "$USAGE" | jq -r '.five_hour.utilization // 0' | xargs printf "%.0f")
            SEVEN=$(echo "$USAGE" | jq -r '.seven_day.utilization // 0' | xargs printf "%.0f")

            FIVE_COLOR=$(get_usage_gradient_color "$FIVE")
            SEVEN_COLOR=$(get_usage_gradient_color "$SEVEN")

            LINE2="${C_LAVENDER}5H${RESET} $(generate_mini_bar "$FIVE") \033[38;2;${FIVE_COLOR}m${FIVE}%${RESET} │ "
            LINE2+="${C_YELLOW}7D${RESET} $(generate_mini_bar "$SEVEN") \033[38;2;${SEVEN_COLOR}m${SEVEN}%${RESET}"
        else
            LINE2="${C_OVERLAY}Usage: N/A${RESET}"
        fi
    else
        LINE2="${C_OVERLAY}No accounts configured. Use /multi-account-add${RESET}"
    fi
fi

# ============================================================================
# Output
# ============================================================================
printf "%b%b\n" "$LINE1" "$CLR"
printf "%b%b\n" "$LINE2" "$CLR"
