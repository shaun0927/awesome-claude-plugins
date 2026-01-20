# /multi-account-switch - Manual Account Switch

Manually switch to a specific account.

---

## Execution Flow

### Step 1: Parse Arguments

Get the target account name or email from command arguments.

### Step 2: Validate Account

Check if the account exists in the manager.

### Step 3: Switch Account

Update the credential store with the target account's token.

### Step 4: Notify User

Inform user to restart Claude Code session for changes to take effect.

---

## Implementation

```bash
# Switch to specified account
bash ${CLAUDE_PLUGIN_ROOT}/scripts/account-manager.sh switch "<account_name_or_email>"
```

---

## Usage

```
/multi-account-switch work
/multi-account-switch personal@example.com
```

---

## Notes

- After switching, you need to restart the Claude Code session
- The switch updates the stored OAuth token
- Use `/multi-account-list` to see available accounts
