#!/bin/bash
# ============================================================================
# Auto-Switch Script for Multi-Account Manager
# ============================================================================
# Called at session start or periodically to check if account switch is needed
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/account-manager.sh" 2>/dev/null

ACCOUNTS_FILE="${HOME}/.claude/multi-accounts.json"

# Colors
RESET="\033[0m"
BOLD="\033[1m"
C_GREEN="\033[38;2;166;227;161m"
C_YELLOW="\033[38;2;249;226;175m"
C_RED="\033[38;2;210;15;57m"
C_TEAL="\033[38;2;148;226;213m"
C_PINK="\033[38;2;245;194;231m"

# ============================================================================
# Check if auto-switch is enabled
# ============================================================================

is_auto_switch_enabled() {
    [[ ! -f "$ACCOUNTS_FILE" ]] && return 1
    local enabled=$(jq -r '.settings.auto_switch // false' "$ACCOUNTS_FILE" 2>/dev/null)
    [[ "$enabled" == "true" ]]
}

# ============================================================================
# Main auto-switch logic
# ============================================================================

perform_auto_switch() {
    # Check if auto-switch is enabled
    if ! is_auto_switch_enabled; then
        return 0
    fi

    # Get settings
    local threshold=$(jq -r '.settings.threshold // 80' "$ACCOUNTS_FILE" 2>/dev/null)

    # Get current account info
    local current_email=$(get_current_account_email 2>/dev/null)
    [[ -z "$current_email" ]] && return 0

    # Get all accounts usage
    local all_usage=$(get_all_accounts_usage 2>/dev/null)
    [[ -z "$all_usage" ]] && return 0

    # Get current account's usage
    local current_five=$(echo "$all_usage" | jq -r --arg email "$current_email" \
        '.[] | select(.email == $email) | .five_hour // 0')
    local current_seven=$(echo "$all_usage" | jq -r --arg email "$current_email" \
        '.[] | select(.email == $email) | .seven_day // 0')

    # Check if current account exceeds threshold
    if [[ "${current_five:-0}" -ge "$threshold" ]] || [[ "${current_seven:-0}" -ge "$threshold" ]]; then
        # Find the best available account
        local best_account=$(echo "$all_usage" | jq -r '.[0].name // empty')
        local best_email=$(echo "$all_usage" | jq -r '.[0].email // empty')
        local best_five=$(echo "$all_usage" | jq -r '.[0].five_hour // 0')

        # Only switch if best account is different and has lower usage
        if [[ "$best_email" != "$current_email" ]] && [[ "$best_five" -lt "$current_five" ]]; then
            printf "${C_YELLOW}[Multi-Account]${RESET} Usage threshold reached (${current_five}%% >= ${threshold}%%)\n"
            printf "${C_GREEN}[Multi-Account]${RESET} Switching to: ${BOLD}${best_account}${RESET} (${best_email}, ${best_five}%% usage)\n"

            switch_to_account "$best_account" >/dev/null 2>&1

            printf "${C_TEAL}[Multi-Account]${RESET} Switch complete. Please restart Claude Code session.\n"
            return 0
        fi
    fi

    return 0
}

# ============================================================================
# Session start check
# ============================================================================

session_start_check() {
    [[ ! -f "$ACCOUNTS_FILE" ]] && return 0

    local account_count=$(jq -r '.accounts | length' "$ACCOUNTS_FILE" 2>/dev/null)
    [[ "$account_count" -lt 2 ]] && return 0

    printf "${C_PINK}[Multi-Account]${RESET} ${account_count} accounts configured\n"

    # Show current account
    local current=$(get_current_account_email 2>/dev/null)
    [[ -n "$current" ]] && printf "${C_TEAL}[Multi-Account]${RESET} Current: ${BOLD}${current}${RESET}\n"

    # Perform auto-switch if enabled
    perform_auto_switch
}

# ============================================================================
# CLI
# ============================================================================

case "$1" in
    check)
        session_start_check
        ;;
    switch)
        perform_auto_switch
        ;;
    *)
        session_start_check
        ;;
esac
