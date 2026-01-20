#!/bin/bash
# ============================================================================
# Multi-Account Manager for Claude Code
# ============================================================================
# Manages multiple Claude accounts and their OAuth tokens
# Supports macOS (Keychain), Linux (secret-tool), Windows (credential manager)
# ============================================================================

ACCOUNTS_FILE="${HOME}/.claude/multi-accounts.json"
CACHE_DIR="/tmp/.claude_multi_account"
CACHE_TTL=300  # 5 minutes

# ============================================================================
# Platform Detection & Token Access
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
            # Windows: read from Claude's credential file (~/.claude/.credentials.json)
            local cred_file="${HOME}/.claude/.credentials.json"
            [[ -f "$cred_file" ]] && jq -r '.claudeAiOauth.accessToken // empty' "$cred_file" 2>/dev/null
            ;;
    esac
}

get_current_account_email() {
    local current_token=$(get_current_token)
    [[ -z "$current_token" ]] && return 1

    # Claude tokens are not JWT, so we match against stored accounts
    init_accounts_file

    # Compare current token with stored account tokens
    while IFS= read -r line; do
        local name=$(echo "$line" | jq -r '.name')
        local email=$(echo "$line" | jq -r '.email')
        local stored_encrypted=$(echo "$line" | jq -r '.token')
        local stored_token=$(echo "$stored_encrypted" | base64 -d 2>/dev/null)

        if [[ "$stored_token" == "$current_token" ]]; then
            echo "$email"
            return 0
        fi
    done < <(jq -c '.accounts[]' "$ACCOUNTS_FILE" 2>/dev/null)

    # If no match found, return empty (account not registered)
    return 1
}

# ============================================================================
# Account Storage Management
# ============================================================================

init_accounts_file() {
    [[ ! -f "$ACCOUNTS_FILE" ]] && echo '{"accounts":[],"settings":{"auto_switch":true,"threshold":80}}' > "$ACCOUNTS_FILE"
    mkdir -p "$CACHE_DIR"
}

add_account() {
    local name="$1"
    local token="$2"
    local email="$3"

    init_accounts_file

    # Encrypt token (simple base64 for now, can be enhanced)
    local encrypted=$(echo "$token" | base64)

    local new_account=$(jq -n \
        --arg name "$name" \
        --arg email "$email" \
        --arg token "$encrypted" \
        --arg added "$(date -Iseconds)" \
        '{name: $name, email: $email, token: $token, added_at: $added}')

    # Check if account with same email exists
    local existing=$(jq -r --arg email "$email" '.accounts[] | select(.email == $email) | .name' "$ACCOUNTS_FILE" 2>/dev/null)

    if [[ -n "$existing" ]]; then
        # Update existing
        jq --arg email "$email" --argjson acc "$new_account" \
            '.accounts = [.accounts[] | if .email == $email then $acc else . end]' \
            "$ACCOUNTS_FILE" > "${ACCOUNTS_FILE}.tmp" && mv "${ACCOUNTS_FILE}.tmp" "$ACCOUNTS_FILE"
        echo "Updated account: $name ($email)"
    else
        # Add new
        jq --argjson acc "$new_account" '.accounts += [$acc]' \
            "$ACCOUNTS_FILE" > "${ACCOUNTS_FILE}.tmp" && mv "${ACCOUNTS_FILE}.tmp" "$ACCOUNTS_FILE"
        echo "Added account: $name ($email)"
    fi
}

list_accounts() {
    init_accounts_file
    jq -r '.accounts[] | "\(.name)\t\(.email)"' "$ACCOUNTS_FILE" 2>/dev/null
}

get_account_token() {
    local identifier="$1"  # name or email
    init_accounts_file

    local encrypted=$(jq -r --arg id "$identifier" \
        '.accounts[] | select(.name == $id or .email == $id) | .token' \
        "$ACCOUNTS_FILE" 2>/dev/null)

    [[ -n "$encrypted" ]] && echo "$encrypted" | base64 -d 2>/dev/null
}

remove_account() {
    local identifier="$1"
    init_accounts_file

    jq --arg id "$identifier" \
        '.accounts = [.accounts[] | select(.name != $id and .email != $id)]' \
        "$ACCOUNTS_FILE" > "${ACCOUNTS_FILE}.tmp" && mv "${ACCOUNTS_FILE}.tmp" "$ACCOUNTS_FILE"

    echo "Removed account: $identifier"
}

# ============================================================================
# Usage API
# ============================================================================

get_usage_for_token() {
    local token="$1"
    [[ -z "$token" ]] && return 1

    curl -s --max-time 5 \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -H "anthropic-beta: oauth-2025-04-20" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null
}

get_usage_for_account() {
    local identifier="$1"
    local token=$(get_account_token "$identifier")
    [[ -z "$token" ]] && return 1

    # Check cache
    local cache_file="${CACHE_DIR}/${identifier//[^a-zA-Z0-9]/_}.json"
    if [[ -f "$cache_file" ]]; then
        local file_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null || echo 0)))
        if [[ "$file_age" -lt "$CACHE_TTL" ]]; then
            cat "$cache_file"
            return 0
        fi
    fi

    local response=$(get_usage_for_token "$token")
    if [[ -n "$response" ]] && echo "$response" | jq -e '.five_hour' &>/dev/null; then
        echo "$response" > "$cache_file"
        echo "$response"
        return 0
    fi
    return 1
}

# ============================================================================
# Usage Comparison & Auto-Switch Logic
# ============================================================================

get_all_accounts_usage() {
    init_accounts_file

    local result="[]"

    while IFS=$'\t' read -r name email; do
        [[ -z "$name" ]] && continue

        local token=$(get_account_token "$name")
        [[ -z "$token" ]] && continue

        local usage=$(get_usage_for_account "$name")
        if [[ -n "$usage" ]]; then
            local five_hour=$(echo "$usage" | jq -r '.five_hour.utilization // 100' | tr -d '\r' | xargs printf "%.0f" 2>/dev/null)
            local seven_day=$(echo "$usage" | jq -r '.seven_day.utilization // 100' | tr -d '\r' | xargs printf "%.0f" 2>/dev/null)
            local five_reset=$(echo "$usage" | jq -r '.five_hour.resets_at // ""')
            local seven_reset=$(echo "$usage" | jq -r '.seven_day.resets_at // ""')

            # Calculate "availability score" (lower usage = higher availability)
            # Weight 5H more heavily as it resets faster
            local score=$((100 - (five_hour * 7 + seven_day * 3) / 10))

            local entry=$(jq -n \
                --arg name "$name" \
                --arg email "$email" \
                --argjson five_hour "$five_hour" \
                --argjson seven_day "$seven_day" \
                --arg five_reset "$five_reset" \
                --arg seven_reset "$seven_reset" \
                --argjson score "$score" \
                '{name: $name, email: $email, five_hour: $five_hour, seven_day: $seven_day, five_reset: $five_reset, seven_reset: $seven_reset, score: $score}')

            result=$(echo "$result" | jq --argjson e "$entry" '. += [$e]')
        fi
    done < <(list_accounts)

    # Sort by score (highest first = most available)
    echo "$result" | jq 'sort_by(-.score)'
}

get_best_account() {
    local all_usage=$(get_all_accounts_usage)
    echo "$all_usage" | jq -r '.[0].name // empty'
}

should_switch() {
    local threshold=$(jq -r '.settings.threshold // 80' "$ACCOUNTS_FILE" 2>/dev/null)
    local current_email=$(get_current_account_email)

    [[ -z "$current_email" ]] && return 1

    # Get current account usage
    local current_usage=$(get_all_accounts_usage | jq -r --arg email "$current_email" \
        '.[] | select(.email == $email) | .five_hour // 0')

    if [[ "$current_usage" -ge "$threshold" ]]; then
        # Find better account
        local best=$(get_best_account)
        local best_email=$(jq -r --arg name "$best" '.accounts[] | select(.name == $name) | .email' "$ACCOUNTS_FILE" 2>/dev/null)

        if [[ "$best_email" != "$current_email" ]]; then
            echo "$best"
            return 0
        fi
    fi
    return 1
}

# ============================================================================
# Account Switching
# ============================================================================

switch_to_account() {
    local identifier="$1"
    local token=$(get_account_token "$identifier")

    [[ -z "$token" ]] && echo "Error: Account not found: $identifier" && return 1

    local platform=$(get_platform)

    case "$platform" in
        darwin)
            # Update Keychain
            local creds=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
            local new_creds=$(echo "$creds" | jq --arg token "$token" '.claudeAiOauth.accessToken = $token')
            security delete-generic-password -s "Claude Code-credentials" 2>/dev/null
            security add-generic-password -s "Claude Code-credentials" -w "$new_creds" 2>/dev/null
            ;;
        linux)
            local creds=$(secret-tool lookup service "Claude Code-credentials" 2>/dev/null)
            local new_creds=$(echo "$creds" | jq --arg token "$token" '.claudeAiOauth.accessToken = $token')
            echo "$new_creds" | secret-tool store --label "Claude Code" service "Claude Code-credentials" 2>/dev/null
            ;;
        win32)
            local cred_file="${HOME}/.claude/.credentials.json"
            if [[ -f "$cred_file" ]]; then
                local new_creds=$(jq --arg token "$token" '.claudeAiOauth.accessToken = $token' "$cred_file")
                echo "$new_creds" > "$cred_file"
            fi
            ;;
    esac

    local email=$(jq -r --arg id "$identifier" '.accounts[] | select(.name == $id or .email == $id) | .email' "$ACCOUNTS_FILE" 2>/dev/null)
    echo "Switched to account: $identifier ($email)"

    # Log switch
    echo "$(date -Iseconds) - Switched to: $identifier" >> "${HOME}/.claude/account-switch.log"
}

# ============================================================================
# Settings
# ============================================================================

set_auto_switch() {
    local enabled="$1"
    init_accounts_file
    jq --argjson enabled "$enabled" '.settings.auto_switch = $enabled' \
        "$ACCOUNTS_FILE" > "${ACCOUNTS_FILE}.tmp" && mv "${ACCOUNTS_FILE}.tmp" "$ACCOUNTS_FILE"
}

set_threshold() {
    local threshold="$1"
    init_accounts_file
    jq --argjson threshold "$threshold" '.settings.threshold = $threshold' \
        "$ACCOUNTS_FILE" > "${ACCOUNTS_FILE}.tmp" && mv "${ACCOUNTS_FILE}.tmp" "$ACCOUNTS_FILE"
}

get_settings() {
    init_accounts_file
    jq '.settings' "$ACCOUNTS_FILE"
}

# ============================================================================
# CLI Interface (only run if script is executed directly, not sourced)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
case "$1" in
    add)
        shift
        add_account "$@"
        ;;
    list)
        list_accounts
        ;;
    remove)
        shift
        remove_account "$1"
        ;;
    usage)
        shift
        if [[ -n "$1" ]]; then
            get_usage_for_account "$1" | jq .
        else
            get_all_accounts_usage | jq .
        fi
        ;;
    best)
        get_best_account
        ;;
    should-switch)
        should_switch
        ;;
    switch)
        shift
        switch_to_account "$1"
        ;;
    auto-switch)
        if auto_switch=$(should_switch); then
            switch_to_account "$auto_switch"
        else
            echo "No switch needed"
        fi
        ;;
    current)
        get_current_account_email
        ;;
    settings)
        get_settings
        ;;
    set-auto)
        shift
        set_auto_switch "$1"
        ;;
    set-threshold)
        shift
        set_threshold "$1"
        ;;
    *)
        echo "Usage: $0 {add|list|remove|usage|best|should-switch|switch|auto-switch|current|settings|set-auto|set-threshold}"
        exit 1
        ;;
esac
fi
