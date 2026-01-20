# /multi-account-list - List All Accounts

Display all registered accounts with their current usage statistics.

---

## Execution Flow

### Step 1: Get All Accounts Usage

Query usage data for all registered accounts.

### Step 2: Display Table

Show accounts sorted by availability (lowest usage first).

---

## Implementation

Run the account manager script:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/account-manager.sh usage
```

### Output Format

Display a formatted table:

| # | Name | Email | 5H Usage | 7D Usage | Status |
|---|------|-------|----------|----------|--------|
| 1 | work | work@example.com | 25% | 40% | Available |
| 2 | personal | me@example.com | 85% | 60% | Limited |

### Status Indicators

- **Available** (green): 5H < 70%
- **Limited** (yellow): 5H 70-89%
- **Exhausted** (red): 5H >= 90%

---

## Notes

- Current active account is highlighted
- Accounts are sorted by availability score
- Usage data is cached for 5 minutes
