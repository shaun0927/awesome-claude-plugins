# /multi-account-auto - Configure Auto-Switch

Configure automatic account switching based on usage thresholds.

---

## Execution Flow

### Step 1: Show Current Settings

Display current auto-switch configuration.

### Step 2: Configure (if arguments provided)

Update settings based on user input.

---

## Implementation

```bash
# Show current settings
bash ${CLAUDE_PLUGIN_ROOT}/scripts/account-manager.sh settings

# Enable auto-switch
bash ${CLAUDE_PLUGIN_ROOT}/scripts/account-manager.sh set-auto true

# Disable auto-switch
bash ${CLAUDE_PLUGIN_ROOT}/scripts/account-manager.sh set-auto false

# Set threshold (percentage)
bash ${CLAUDE_PLUGIN_ROOT}/scripts/account-manager.sh set-threshold 80
```

---

## Usage

```
/multi-account-auto              # Show current settings
/multi-account-auto on           # Enable auto-switch
/multi-account-auto off          # Disable auto-switch
/multi-account-auto threshold 75 # Set threshold to 75%
```

---

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| auto_switch | true | Enable/disable automatic switching |
| threshold | 80 | Usage percentage that triggers switch |

---

## How Auto-Switch Works

1. On session start, checks current account's 5H usage
2. If usage >= threshold, finds account with lowest usage
3. If better account exists, switches automatically
4. Logs all switches to `~/.claude/account-switch.log`

---

## Notes

- Auto-switch only happens at session start
- Manual switches are always available via `/multi-account-switch`
- Lower threshold = more aggressive switching
