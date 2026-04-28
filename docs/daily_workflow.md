# Daily Workflow

**Time required: ~15 minutes/day**

This is the actual morning routine. Everything below assumes Phase 1 has already run and the sheet has leads in it.

---

## The Flow at a Glance

```
┌─────────────────────────────────────────────────────────────────────┐
│                    DAILY OUTREACH ROUTINE (~15 min)                 │
└─────────────────────────────────────────────────────────────────────┘

    OPEN SHEET
        │
        ▼
    Any "queued" rows? ─── YES ──▶ Run Phase 2 (2 min, automated)
        │                                    │
        │ NO                                 ▼
        │                          Rows are now "drafted"
        │
        ▼
    Review "drafted" rows ──────────────────────────────── (5 min)
    Read Version A and B for each
    Delete the version you don't want
    Change reply_status to "approved"
        │
        ▼
    Any "approved" rows? ─── YES ──▶ Run Phase 3 (1 min, automated)
        │                                    │
        │ NO                                 ▼
        │                          Emails sent, rows become "sent"
        │
        ▼
    Any "sent" rows without linkedin_url?
        │
        YES ──▶ Manual LinkedIn lookup ─────────────────── (5 min)
        │       {name} {company} linkedin on Google
        │       Paste clean URL into sheet
        │
        ▼
    Run Phase 4 ─────────────────────────────────────────── (1 min, automated)
    Notes generated in linkedin_note column
        │
        ▼
    Open LinkedIn in browser ───────────────────────────── (2 min)
    For each row with a linkedin_note:
        Find profile → Connect → Add note → paste → Send
        Mark linkedin_request_sent = YES in sheet
        │
        ▼
    DONE FOR THE DAY
```

---

## Step-by-Step Detail

### Step 1 — Open the Sheet (1 min)

Open your `Internship_Outreach` Google Sheet. Scan the `reply_status` column (column N). You're looking for:

- `queued` rows → need Phase 2 (email drafting)
- `drafted` rows → need your review and approval
- `approved` rows → need Phase 3 (email sending)
- `sent` rows with empty `linkedin_url` → need LinkedIn lookup + Phase 4

Use the conditional formatting colors to spot these at a glance.

---

### Step 2 — Draft New Leads (if queued rows exist)

If there are any `queued` rows:

1. Open n8n (`http://localhost:5678`)
2. Open the Phase 2 workflow
3. Click **Execute Workflow**
4. Wait 1–2 minutes (roughly 30s per company with the wait node)
5. Go back to the sheet — rows should now show `drafted` status with email content in columns J–M

If no `queued` rows exist, skip this step.

---

### Step 3 — Review and Approve Emails (5 min)

This is the most important step. You're the quality gate.

For each `drafted` row:

1. **Read the company name and role** (columns B and E) — who are you talking to?
2. **Read Version A** (columns J and K) — professional tone, usually has structure
3. **Read Version B** (columns L and M) — casual tone, usually shorter
4. **Ask yourself:**
   - Does it sound like me or like a corporate template?
   - Does it mention something specific about the company (not just the name)?
   - Would I be comfortable if this founder showed this email to someone else?
   - Are there any typos, placeholder text (`[FirstName]`), or awkward phrases?

5. **Pick one version:**
   - Delete the subject and body of the version you're NOT sending
   - Or: edit the body of the version you're keeping if something needs fixing

6. **Change `reply_status`** from `drafted` to `approved`

**Red flags that should stop you from approving:**
- Email body is generic (no company-specific detail)
- Contains buzzwords: "innovative", "exciting", "opportunity"
- Opens with "I am a passionate student..."
- Subject line is "Internship Inquiry at [Company]"

If any of these appear, change `reply_status` back to `queued` and re-run Phase 2 for that row. GPT at temperature 0.9 will give you different output on the second run.

---

### Step 4 — Send Approved Emails (1 min)

Once you've approved rows:

1. In n8n, open Phase 3 workflow
2. Click **Execute Workflow**
3. Watch the execution — green = sent, red = check the error
4. Go back to the sheet — `reply_status` should now be `sent` with `email_sent_date` filled

**Before you run Phase 3, do this sanity check:**
- [ ] You've personally read every approved email
- [ ] No placeholder text remains in any body
- [ ] Your resume is still at `C:\Users\YourName\.n8n-files\master_resume.pdf`
- [ ] The email addresses look real (not `test@example.com` from Phase 1 testing)

---

### Step 5 — Manual LinkedIn URL Lookup (5 min)

For every row where `reply_status = sent` and `linkedin_url` is empty:

1. Open Google in a new tab
2. Search: `{contact_name} {company_name} linkedin`
   - Example: `Justin Waugh Maritime Fusion linkedin`
3. Click the LinkedIn result
4. Copy the URL from the address bar — strip tracking params (everything after `?`)
5. Paste into the `linkedin_url` column for that row

Details in [manual_linkedin_lookup.md](./manual_linkedin_lookup.md).

Skip rows where you genuinely can't find the right profile. Leave `linkedin_url` empty — Phase 4 won't touch it.

---

### Step 6 — Generate LinkedIn Notes (1 min)

1. In n8n, open Phase 4 workflow
2. Click **Execute Workflow**
3. Phase 4 processes only rows where:
   - `reply_status = sent`
   - `linkedin_url` is filled
   - `linkedin_note` is empty
4. Check the sheet — `linkedin_note` column should now have notes ready to copy

---

### Step 7 — Send LinkedIn Connections (2 min)

For each row with a filled `linkedin_note`:

1. Open the LinkedIn URL from column P in your browser
2. Click **Connect** on their profile
3. Click **Add a note**
4. Copy the text from `linkedin_note` (column Q)
5. Paste → Send
6. Go back to your sheet → set `linkedin_request_sent` (column R) to `YES`

Do this for 3–5 people max per day. LinkedIn has undocumented limits on connection requests. Staying under 10/day is safe.

---

## Weekly Rhythm

| Task | Frequency | Time |
|------|-----------|------|
| Phase 1 (discover new leads) | Once a week | 5 min |
| Phase 2 (draft emails) | Daily if queued rows exist | 2 min |
| Phase 2 review + approve | Daily | 5 min |
| Phase 3 (send emails) | Daily if approved rows exist | 1 min |
| LinkedIn lookup | Daily for sent rows | 5 min |
| Phase 4 (generate notes) | Daily after lookups | 1 min |
| LinkedIn connections | Daily | 2 min |
| Check replies in Gmail | Daily | 2 min |

**Total: ~15 min/day active, ~5 min/week for new lead discovery.**

---

## Tracking Replies

When a founder replies:

1. Go to the relevant row in your sheet
2. Set `reply_received` (column V) to `YES`
3. Set `reply_status` to `replied`
4. Add any context in `notes` (column W): "Interested, wants a call", "Said no internships right now", etc.

This keeps your conversion tracking accurate without any automation overhead.

---

## When Nothing Needs to Be Done

Some days all your rows are already `sent` or `replied` and there's nothing to process. That's fine — it means:
- Phase 1 needs a run to bring in new leads (do this once a week for new YC batches)
- Or you've worked through your current batch completely

The system is designed to be idle between batches. Don't run phases unnecessarily.
