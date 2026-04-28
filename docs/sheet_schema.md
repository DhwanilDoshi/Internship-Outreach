# Sheet Schema — Internship_Outreach

**Spreadsheet name:** `Internship_Outreach`
**Tab name:** `Internship_Outreach` (must match exactly — case-sensitive)
**Total columns:** 23

---

## Column Reference

| # | Column Name | Type | Filled By | Required | Description |
|---|-------------|------|-----------|----------|-------------|
| A | `email` | string | Phase 1 | Yes | Founder email address. Primary key — used to match rows on update. |
| B | `company_name` | string | Phase 1 | Yes | YC company name as returned by the YC API. |
| C | `website` | string | Phase 1 | Yes | Company website URL. Used by Phase 2 to scrape content. |
| D | `contact_name` | string | Phase 1 | Yes | Full name of the contact (founder). Required by Phase 4 for LinkedIn lookup. |
| E | `contact_role` | string | Phase 1 | No | Role/title — "Founder", "CEO", etc. Falls back to "Founder" if Hunter.io doesn't return one. |
| F | `batch` | string | Phase 1 | Yes | YC batch — "W25" or "S25". Used to segment outreach by cohort. |
| G | `yc_description` | string | Phase 1 | No | One-line company description from the YC API. Fallback for Phase 2 if website scrape fails. |
| H | `hunter_confidence` | integer | Phase 1 | No | Hunter.io confidence score (0–100). Rows below 70 are filtered out by Phase 1. |
| I | `hunter_verified` | boolean | Phase 1 | No | Whether Hunter.io has verified this email via SMTP check. Values: TRUE / FALSE. |
| J | `email_subject_A` | string | Phase 2 | No | Subject line for Version A (professional). Delete this if you chose Version B. |
| K | `email_body_A` | string | Phase 2 | No | Body for Version A. Multi-line. Phase 3 reads whichever body is non-empty. |
| L | `email_subject_B` | string | Phase 2 | No | Subject line for Version B (casual). Delete this if you chose Version A. |
| M | `email_body_B` | string | Phase 2 | No | Body for Version B. |
| N | `reply_status` | enum | Phases 1–3 | Yes | Current row status. Controls which phase processes this row. See state machine below. |
| O | `email_sent_date` | datetime | Phase 3 | No | ISO timestamp of when the email was sent. Format: `2026-04-27T10:30:00.000Z`. |
| P | `linkedin_url` | string | Manual / Phase 4 | No | LinkedIn `/in/` profile URL. Filled manually by you before running Phase 4. |
| Q | `linkedin_note` | string | Phase 4 | No | AI-generated connection note, max 280 chars. Copy-paste into LinkedIn connection request. |
| R | `linkedin_request_sent` | enum | Manual | No | Set to "YES" when you've sent the LinkedIn connection from your browser. |
| S | `website_scraped_text` | string | Phase 2 | No | Raw website text used as context for GPT. Truncated to 3000 chars. Useful for debugging email quality. |
| T | `created_date` | datetime | Phase 1 | No | When this row was first written (lead discovery timestamp). |
| U | `drafted_date` | datetime | Phase 2 | No | When email drafts were generated. |
| V | `reply_received` | enum | Manual | No | Set to "YES" when the founder replies. Used to track outcome. |
| W | `notes` | string | Manual | No | Free-text notes. Anything relevant: "knows Prof. X", "met at YC event", etc. |

---

## reply_status State Machine

```
   ┌──────────┐      Phase 2 runs      ┌──────────┐
   │  queued  │ ─────────────────────▶ │ drafted  │
   └──────────┘                        └─────┬────┘
        ▲                                    │
        │                            YOU review email
   Phase 1                           pick A or B
   writes                            change cell
        │                                    │
        │                                    ▼
        │                             ┌──────────┐     Phase 3 runs     ┌──────┐
        │                             │ approved │ ──────────────────▶  │ sent │
        │                             └──────────┘                      └──┬───┘
        │                                                                  │
        │                                                           you get a reply
        │                                                                  │
        │                                                                  ▼
        │                                                            ┌─────────┐
        └──────────────────────────────────────────────────────────  │ replied │ (optional)
                                                                     └─────────┘
```

**Valid values for `reply_status`:** `queued`, `drafted`, `approved`, `sent`, `replied`

- Phases filter on exact matches with `.trim().toLowerCase()`. Cell values must be lowercase.
- Setting a status to anything else (e.g., `skip`, `error`) effectively parks the row — no phase will touch it.

---

## Manual Approval Workflow

Phase 2 generates both email versions (A and B) for every row. You review them:

1. Open the sheet
2. Find rows where `reply_status = drafted`
3. Read both versions in columns J–M
4. **Pick one:** delete the subject and body of the version you're NOT using
   - e.g., if you prefer Version A: delete columns L and M for that row
   - Or: leave both in — Phase 3 sends Version A if A is non-empty, falls back to B
5. Change `reply_status` from `drafted` to `approved`
6. Run Phase 3 — it will send all `approved` rows

**Tip:** Color-code approved rows orange before running Phase 3. Once sent, they turn green. Gives you a quick visual diff of what's queued vs. gone.

---

## Common Schema Pitfalls

### Column names are case-sensitive

The Google Sheets update node matches column headers exactly. `Email` ≠ `email`. If you rename a column, update every node that references it.

### Trailing spaces in cells break filters

If a cell contains `"sent "` (with a trailing space), `reply_status === 'sent'` returns false. The Code node filters use `.trim()` to handle this, but double-check if rows are mysteriously not passing.

### reply_status values must be lowercase

All phase filters lowercase the value before comparing. If you manually type `Approved` or `SENT`, add `.toLowerCase()` won't help — actually it will. The `.trim().toLowerCase()` in the filter handles this. But for consistency, use lowercase in the sheet.

### Don't sort the sheet while a workflow is running

n8n reads the row by email match, but Sheets API responses depend on row order for some operations. Sorting mid-execution can cause an update to land on the wrong row in rare edge cases.

### website_scraped_text can be very long

Column S can hold thousands of characters. If your sheet is slow to load, freeze or hide this column. It's only needed by Phase 2 for debugging — not for day-to-day review.

---

## Recommended Sheets Setup

### Data Validation Dropdowns

| Column | Criteria |
|--------|---------|
| N (reply_status) | `queued, drafted, approved, sent, replied` |
| R (linkedin_request_sent) | `YES` |
| V (reply_received) | `YES, NO` |

To add: Select the column → Data → Data validation → Dropdown (from a list) → enter values.

### Conditional Formatting Color Codes

| Status | Background Color | Text Color |
|--------|-----------------|------------|
| queued | `#FFF9C4` (light yellow) | Default |
| drafted | `#BBDEFB` (light blue) | Default |
| approved | `#FFE0B2` (light orange) | Default |
| sent | `#C8E6C9` (light green) | Default |
| replied | `#F3E5F5` (light purple) | Default |

To add: Format → Conditional formatting → apply to column N → "Text is exactly" → enter value → choose fill color.

### Freeze Row 1

View → Freeze → 1 row. Headers stay visible as you scroll down.

### Column Width Recommendations

| Column | Suggested Width |
|--------|----------------|
| email_body_A / B | 400px (wide — you're reading emails here) |
| email_subject_A / B | 250px |
| linkedin_note | 300px |
| website_scraped_text | Hidden (not needed for review) |
| All others | Default |
