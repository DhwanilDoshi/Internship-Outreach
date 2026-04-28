# YC Internship Outreach Automation

![n8n](https://img.shields.io/badge/n8n-self--hosted-EA4B71?logo=n8n&logoColor=white)
![OpenAI](https://img.shields.io/badge/OpenAI-GPT--4o-412991?logo=openai&logoColor=white)
![Google Sheets](https://img.shields.io/badge/Google_Sheets-data_layer-34A853?logo=googlesheets&logoColor=white)
![Status](https://img.shields.io/badge/status-active-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)

> A 4-phase n8n automation that finds Y Combinator startup founders, personalizes outreach emails with GPT-4o, sends them via Gmail, and prepares LinkedIn connection notes — all tracked in a single Google Sheet.

Built by **Dhwanil Doshi** (ECE, SCET Surat) to replace 3 hours of manual research per day with 15 minutes of review.

---

## What It Does

```
YC API → Hunter.io → Google Sheet → GPT-4o → Gmail → LinkedIn Notes
  (find)   (verify)    (track)      (write)   (send)    (connect)
```

| Phase | Name | What It Does | Manual Step? |
|-------|------|-------------|--------------|
| 1 | Lead Discovery | Scrapes YC W25/S25 founders, finds verified emails via Hunter.io | None |
| 2 | Email Drafting | Scrapes company website, uses GPT-4o to write 2 email versions | Review & pick A or B |
| 3 | Email Sending | Sends approved emails via Gmail with resume attached | Approve rows in sheet |
| 4 | LinkedIn Notes | Generates personalized connection notes (280 char limit) | Look up URLs manually, send connections |

---

## Features

- **Targeted leads** — only YC W25/S25 founders with verified emails (Hunter confidence ≥ 70)
- **Dual email drafts** — Version A (professional, bullet-point format) and Version B (casual, single paragraph)
- **Zero buzzwords** — prompt explicitly bans "exciting", "innovative", "passionate" and similar
- **Full audit trail** — every status change, timestamp, and draft lives in one Google Sheet
- **Resume attachment** — PDF attached automatically on send
- **LinkedIn note generator** — 280-char hard limit, personalized to the email body already sent
- **Rate-limit safe** — 3-second waits between API calls, Hunter.io free tier compatible
- **Idempotent** — re-running any phase skips already-processed rows

---

## Tech Stack

| Tool | Role | Cost |
|------|------|------|
| n8n (self-hosted) | Workflow orchestration | Free |
| Google Sheets | Database / tracking | Free |
| Gmail | Email sending | Free |
| YC API (`yc.com/companies`) | Lead source | Free |
| Hunter.io | Email verification | Free tier (25 searches/mo) |
| OpenAI GPT-4o | Email + note generation | ~$0.01 per 30 emails |
| OpenAI GPT-4o-mini | LinkedIn notes | ~$0.001 per note |

**Total cost for 100 emails: roughly $0.03.**

---

## Project Structure

```
n8n-yc-outreach/
├── workflows/
│   ├── phase1_lead_discovery.json
│   ├── phase2_email_drafting.json
│   ├── phase3_email_sending.json
│   └── phase4_linkedin_assistant.json
├── docs/
│   ├── sheet_schema.md
│   ├── manual_linkedin_lookup.md
│   └── daily_workflow.md
├── prompts/
│   ├── phase2_email_prompt.md
│   └── phase4_linkedin_note.md
├── examples/
│   ├── sample_email_output.md
│   └── sample_sheet_row.csv
├── README.md
├── ARCHITECTURE.md
├── SETUP.md
├── CHANGELOG.md
└── TROUBLESHOOTING.md
```

---

## Quick Start

Full instructions in [SETUP.md](./SETUP.md). Short version:

```bash
# 1. Install n8n
npm install -g n8n

# 2. Start n8n
n8n start

# 3. Open browser
# http://localhost:5678
```

Then:
1. Create a Google Sheet named `Internship_Outreach` with the 23 columns in [docs/sheet_schema.md](./docs/sheet_schema.md)
2. Set up Google Cloud OAuth (Sheets + Gmail)
3. Get Hunter.io and OpenAI API keys
4. Import the 4 workflow JSONs from `/workflows`
5. Run Phase 1 to populate leads

---

## Daily Usage (15 min/day)

See [docs/daily_workflow.md](./docs/daily_workflow.md) for the full routine.

```
Morning:
  1. Open sheet (2 min)
  2. Review drafted emails, pick A or B, mark approved (5 min)
  3. Run Phase 3 → emails send (1 min)
  4. Manual LinkedIn URL lookup for sent rows (5 min)
  5. Run Phase 4 → notes generated (1 min)
  6. Send LinkedIn connections from browser using generated notes (2 min)
```

---

## Performance Expectations

These are realistic numbers based on cold outreach to startup founders:

| Metric | Expected Range | Notes |
|--------|----------------|-------|
| Open rate | 30–50% | Subject line quality + founder curiosity about students |
| Reply rate | 5–15% | Strong for cold outreach; depends on email quality |
| Positive reply rate | 3–8% | Internship offers, referrals, or calls |
| LinkedIn accept rate | 20–40% | Higher when note references specific work |

**Volume processed so far:** 23+ emails sent, 0 bounces, 0 spam reports.

---

## Realistic Limits & Caveats

- **Hunter.io free tier:** 25 searches/month. Upgrade or use multiple accounts for larger batches.
- **YC API:** Public, but structure can change without notice. Phase 1 may need a query tweak if YC updates their API.
- **OpenAI costs:** GPT-4o at ~$0.01/30 emails is fine. Don't run Phase 2 on 500 rows at once.
- **LinkedIn automation:** This project does NOT automate LinkedIn sending. Notes are generated; you send them manually from your browser. LinkedIn's ToS is strict.
- **Gmail sending limits:** Free Gmail = 500 emails/day. More than enough for targeted outreach.
- **No email tracking:** Open/reply rates above are estimates. The sheet tracks `reply_received` manually.
- **Phase 4 URL lookup:** LinkedIn URL discovery is manual (Google → copy → paste). See [docs/manual_linkedin_lookup.md](./docs/manual_linkedin_lookup.md).

---

## About the Builder

**Dhwanil Doshi**
2nd-year ECE student @ SCET, Surat, Gujarat, India

- GitHub: [github.com/DhwanilDoshi](https://github.com/DhwanilDoshi)
- LinkedIn: [linkedin.com/in/dhwanil-doshi](https://linkedin.com/in/dhwanil-doshi)
- Email: doshidhwanil13@gmail.com

Built this because manually researching YC founders, writing personalized emails, and tracking replies in a spreadsheet was taking 3 hours every morning. Now it takes 15 minutes.

---

## License

MIT — see [LICENSE](./LICENSE)
