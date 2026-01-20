# /multi-account-status - Show Detailed Status

Display comprehensive status of all accounts including usage, reset times, and recommendations.

---

## Execution Flow

### Step 1: Gather All Data

Collect usage data from all registered accounts.

### Step 2: Analyze and Display

Show detailed status with visual indicators.

---

## Implementation

```bash
# Get detailed usage for all accounts
bash ${CLAUDE_PLUGIN_ROOT}/scripts/account-manager.sh usage
```

---

## Output Format

```
=== Multi-Account Status ===

Current Account: work (work@example.com)

┌─────────────┬─────────────────────┬────────┬────────┬─────────────┐
│ Account     │ Email               │ 5H     │ 7D     │ Status      │
├─────────────┼─────────────────────┼────────┼────────┼─────────────┤
│ ▶ work      │ work@example.com    │ 45%    │ 30%    │ Available   │
│   personal  │ me@example.com      │ 82%    │ 55%    │ Limited     │
│   backup    │ backup@example.com  │ 15%    │ 20%    │ Available   │
└─────────────┴─────────────────────┴────────┴────────┴─────────────┘

Reset Times:
  work:     5H resets in 2h15m, 7D resets on Mon
  personal: 5H resets in 4h30m, 7D resets on Tue
  backup:   5H resets in 1h45m, 7D resets on Wed

Recommendation:
  Current account (work) is optimal. No switch needed.

Settings:
  Auto-switch: ON
  Threshold: 80%
```

---

## Visual Indicators

### Usage Bars (Catppuccin colors)

- 0-40%: Green gradient
- 40-70%: Yellow gradient
- 70-90%: Orange gradient
- 90-100%: Red gradient

### Status Labels

- **Available**: Can be used freely
- **Limited**: Approaching limit, consider switching
- **Exhausted**: Near or at limit, switch recommended

---

## Notes

- Use this command to get a complete overview
- Includes recommendations based on current usage patterns
- Shows auto-switch settings
