# Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                     YC Internship Outreach System                   │
│                                                                     │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────────┐  │
│  │ Phase 1  │    │ Phase 2  │    │ Phase 3  │    │   Phase 4    │  │
│  │  FIND    │───▶│  DRAFT   │───▶│   SEND   │───▶│   CONNECT   │  │
│  │          │    │          │    │          │    │              │  │
│  │ YC API   │    │ Website  │    │  Gmail   │    │ Note Gen     │  │
│  │ Hunter   │    │ GPT-4o   │    │ + Resume │    │ GPT-4o-mini  │  │
│  └──────────┘    └──────────┘    └──────────┘    └──────────────┘  │
│        │               │               │                │           │
│        └───────────────┴───────────────┴────────────────┘           │
│                                │                                    │
│                    ┌───────────▼───────────┐                        │
│                    │    Google Sheet        │                        │
│                    │  Internship_Outreach   │                        │
│                    │  (23 columns, source   │                        │
│                    │   of truth for all     │                        │
│                    │   phases)              │                        │
│                    └───────────────────────┘                        │
└─────────────────────────────────────────────────────────────────────┘
```

---

## The Sheet-as-Database Pattern

Each phase reads from and writes back to the same Google Sheet. This is intentional.

**Why a sheet instead of a real database:**

| Concern | Answer |
|---------|--------|
| Visibility | You can see every row, every field, every status at a glance |
| Manual intervention | Edit any cell directly without touching code |
| No infra | No Postgres, no Redis, no Docker database sidecar |
| Approval workflow | Change `reply_status` from `drafted` to `approved` in a cell — that's the entire approval gate |
| Debugging | If something goes wrong, read the row. The data tells the story. |
| Portability | Export to CSV, share with anyone, open in Excel |

The tradeoff: it's slow (Sheets API has rate limits, ~100 reads/min on free tier) and there's no transactions. For outreach volume (< 500 rows), this is completely fine.

---

## reply_status State Machine

```
                    ┌─────────────┐
                    │   queued    │  ← Phase 1 writes this
                    └──────┬──────┘
                           │ Phase 2 runs
                           ▼
                    ┌─────────────┐
                    │   drafted   │  ← Phase 2 writes this
                    └──────┬──────┘
                           │ YOU review + pick A or B
                           │ YOU change cell to "approved"
                           ▼
                    ┌─────────────┐
                    │  approved   │  ← Manual (you set this)
                    └──────┬──────┘
                           │ Phase 3 runs
                           ▼
                    ┌─────────────┐
                    │    sent     │  ← Phase 3 writes this
                    └──────┬──────┘
                           │ (manual) you get a reply
                           ▼
                    ┌─────────────┐
                    │   replied   │  ← Optional, manual
                    └─────────────┘
```

**Each phase filters strictly on its expected input status.** Phase 3 will never touch a `drafted` row. Phase 2 will never re-process a `drafted` row. This makes re-running any phase safe.

---

## Phase 1 — Lead Discovery

```
Manual Trigger
     │
     ▼
Fetch YC Batch (HTTP GET)
  └─ yc.com/companies?batch=W25&limit=100
     │
     ▼
Split Companies (SplitInBatches, size=1)
     │
     ▼
Wait 1s (rate limit)
     │
     ▼
Hunter.io Email Find (HTTP GET)
  └─ api.hunter.io/v2/email-finder
     │
     ▼
Filter Valid Emails (Code node)
  └─ confidence >= 70
  └─ type = "personal" or "generic"
  └─ not already in sheet
     │
     ▼
Format Lead (Code node)
  └─ normalize fields
  └─ set reply_status = "queued"
  └─ set created_date = now
     │
     ▼
Append to Sheet (Google Sheets append)
     │
     └──────────────────▶ loop back to SplitInBatches
```

**Key Decisions — Phase 1:**

| Decision | Why |
|----------|-----|
| Hunter.io over other finders | Has a free tier, confidence scoring, and n8n's HTTP Request handles it with no extra node |
| confidence >= 70 threshold | Below 70, bounce rate climbs sharply. 70+ is Hunter's "likely deliverable" zone |
| Append (not update) | Each row is a new lead — no existing row to match against |
| Dedup in Code node, not Sheet | Sheet lookups for dedup require reading the whole sheet per company. Doing it once in-memory in the Code node is faster |
| batchSize = 1 | Hunter.io free tier = 25 requests/month. One-at-a-time with a 1s wait is intentional throttling |

---

## Phase 2 — Email Drafting

```
Manual Trigger
     │
     ▼
Read All Sheet Rows (Google Sheets)
     │
     ▼
Filter Queued Rows (Code node)
  └─ reply_status === "queued"
  └─ email not empty
     │
     ▼
SplitInBatches (size=1)
     │
     ▼
Wait 2s
     │
     ▼
Scrape Website (HTTP GET)
  └─ company website URL
  └─ continueOnFail: true
     │
     ▼
Extract Clean Text (Code node)
  └─ strip HTML tags
  └─ cap at 3000 chars
  └─ fallback to YC description if scrape failed
     │
     ▼
Build GPT-4o Prompt (Code node)
  └─ inject: companyName, contactFirst, ycDescription, cleanText
  └─ rules: 2 versions, no buzzwords, 200 words max, JSON response
     │
     ▼
Call OpenAI GPT-4o (HTTP Request POST)
  └─ response_format: json_object
  └─ temperature: 0.9
  └─ continueOnFail: true
     │
     ▼
Parse Email Drafts (Code node)
  └─ extract subject_a, body_a, subject_b, body_b
  └─ strip formula injection chars
  └─ set reply_status = "drafted"
     │
     ▼
Update Sheet Row (Google Sheets update, match by email)
     │
     └──────────────────▶ loop back to SplitInBatches
```

**Key Decisions — Phase 2:**

| Decision | Why |
|----------|-----|
| GPT-4o over GPT-4o-mini | Email quality is the whole point. Mini saves $0.005/email but produces noticeably worse openers |
| temperature: 0.9 | High variance produces more interesting openers. 0.7 was too formulaic |
| Two versions (A/B) | Different founders respond to different tones. Lets you pick without re-running |
| Website scrape + fallback to YC description | YC description is 1 sentence. Website copy gives GPT real signal. Fallback prevents failure if scrape returns 403 |
| 3000-char website text cap | GPT-4o context isn't the limit — cost is. 3000 chars is enough signal for a 200-word email |
| JSON response_format | Structured output prevents GPT from adding preamble ("Here are your two email versions...") which breaks parsing |
| Match by email on update | Email is the natural primary key. Avoids row-number drift if rows are inserted elsewhere |

---

## Phase 3 — Email Sending

```
Manual Trigger (or Schedule)
     │
     ▼
Read All Sheet Rows
     │
     ▼
Filter Approved Rows (Code node)
  └─ reply_status === "approved"
  └─ email not empty
  └─ email_subject_A or email_subject_B not empty
     │
     ▼
SplitInBatches (size=1)
     │
     ▼
Wait 3s
     │
     ▼
Send Gmail (Gmail node)
  └─ to: email
  └─ subject: email_subject_A (whichever was kept)
  └─ body: email_body_A (HTML mode)
  └─ attachment: master_resume.pdf (binary from .n8n-files/)
     │
     ▼
Update Sheet (mark sent, write email_sent_date)
     │
     └──────────────────▶ loop back to SplitInBatches
```

**Key Decisions — Phase 3:**

| Decision | Why |
|----------|-----|
| HTML email body | Plain text wraps awkwardly at 72 chars in most email clients. HTML preserves paragraph breaks and lets you bold things |
| .n8n-files/ for resume | n8n's binary file node only reads from this restricted folder on self-hosted. Can't use arbitrary paths |
| email_sent_date timestamp | You need to know *when* you sent each email to follow up at the right time |
| 3s wait between sends | Gmail doesn't rate-limit at this volume, but being polite to APIs is a habit worth keeping |
| Filter checks for subject line | If someone deleted both subject lines by mistake, the email would send blank. Filter catches this |

---

## Phase 4 — LinkedIn Notes

```
Manual Trigger
     │
     ▼
Read All Sheet Rows
     │
     ▼
Filter Sent Without LinkedIn (Code node)
  └─ reply_status === "sent"
  └─ email not empty
  └─ contact_name not empty
  └─ linkedin_url empty  ← gate: only unprocessed rows
     │
     ▼
SplitInBatches (size=1)
     │
     ▼
Wait 3s
     │
     ▼
Build Note Prompt (Code node)
  └─ inject: contact_name, company_name, email_body_A/B, linkedin_url
  └─ rules: 280 char HARD limit, banned words, exact signature
     │
     ▼
Call OpenAI GPT-4o-mini (HTTP Request POST)
  └─ response_format: json_object
  └─ continueOnFail: true
     │
     ▼
Parse Note (Code node)
  └─ strip markdown fences
  └─ trim to 280 chars
  └─ strip formula injection chars
     │
     ▼
Update Sheet (write linkedin_note)
     │
     └──────────────────▶ loop back to SplitInBatches
```

**Note:** `linkedin_url` is filled manually by you before running Phase 4. See [docs/manual_linkedin_lookup.md](../docs/manual_linkedin_lookup.md).

**Key Decisions — Phase 4:**

| Decision | Why |
|----------|-----|
| GPT-4o-mini | Notes are 280 chars. Mini is plenty capable at this length and 10x cheaper |
| No automated LinkedIn URL search | Google Custom Search API requires a billing account. Hunter.io doesn't find LinkedIn URLs. Phantombuster/Apollo require paid plans. Manual lookup takes 30 seconds per person |
| continueOnFail on OpenAI | If API fails, sheet still gets written (with empty note). Row won't be reprocessed since the URL is now filled |
| 280-char hard trim in code | LinkedIn enforces this server-side. Better to trim in the note than have the send fail |
| Reads email body for context | Continuity — the note should feel like a follow-up to the email, not a cold message |
