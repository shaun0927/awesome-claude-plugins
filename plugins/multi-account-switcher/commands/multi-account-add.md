# /multi-account-add - Add Account to Manager

Add a new Claude account to the multi-account manager.

---

## Execution Flow

### Step 1: Get Current Token

Read the current logged-in account's OAuth token from the system credential store.

```bash
# The account-manager.sh script handles platform-specific token retrieval:
# - macOS: security (Keychain)
# - Linux: secret-tool
# - Windows: credentials.json
```

### Step 2: Extract Account Info

Parse the JWT token to extract the account email.

### Step 3: Prompt for Account Name

Ask the user to provide a friendly name for this account.

```markdown
Ask the user:
- "What name would you like to give this account? (e.g., 'work', 'personal', 'main')"
```

### Step 4: Save Account

Run the account manager script to save the account:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/account-manager.sh add "<name>" "<token>" "<email>"
```

### Step 5: Confirm

Display confirmation message with account list.

---

## Implementation

Execute the following steps:

1. Read current token and extract email
2. Ask user for account name using AskUserQuestion
3. Run the add command
4. Show updated account list

```bash
# Get current account info
CURRENT_EMAIL=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/account-manager.sh current)

# Add account (after getting name from user)
bash ${CLAUDE_PLUGIN_ROOT}/scripts/account-manager.sh add "$ACCOUNT_NAME" "$(get_current_token)" "$CURRENT_EMAIL"

# List all accounts
bash ${CLAUDE_PLUGIN_ROOT}/scripts/account-manager.sh list
```

---

## Notes

- Login to the account you want to add BEFORE running this command
- Use `/logout` then `/login` to switch to different account, then run this command again
- Each account needs a unique name
