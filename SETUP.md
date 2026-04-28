# Setup Guide

**Estimated time: 45 minutes**

This guide takes you from zero to a working 4-phase outreach system. Follow the steps in order — each phase depends on the one before it.

---

## Prerequisites Checklist

Before starting, make sure you have:

- [ ] Node.js 18+ installed (`node --version`)
- [ ] A Google account (for Sheets + Gmail)
- [ ] A Hunter.io account (free tier is fine) — [hunter.io](https://hunter.io)
- [ ] An OpenAI account with credits — [platform.openai.com](https://platform.openai.com)
- [ ] Your resume as a PDF file

---

## Step 1 — Install n8n (5 min)

```bash
# Install globally
npm install -g n8n

# Start n8n
n8n start
```

Open `http://localhost:5678` in your browser. Create an account when prompted (local only — not sent anywhere).

**Windows note:** If `n8n` isn't recognized after install, restart your terminal or add npm's global bin to PATH.

To run n8n persistently in the background:
```bash
# Option A: keep the terminal open
n8n start

# Option B: run as background process (PowerShell)
Start-Process n8n -ArgumentList "start" -WindowStyle Hidden
```

---

## Step 2 — Get API Keys (10 min)

### Hunter.io

1. Go to [hunter.io](https://hunter.io) → Sign Up (free)
2. Dashboard → API → copy your API key
3. Keep it handy — you'll paste it into the Phase 1 workflow

Free tier: **25 email finder requests/month**. Each company = 1 request.

### OpenAI

1. Go to [platform.openai.com](https://platform.openai.com) → API Keys
2. Create a new secret key → copy it immediately (shown once)
3. Add $5 credit minimum — enough for ~500 emails

**Important:** Store the key somewhere safe. You'll need it for Phase 2 and Phase 4 workflows.

---

## Step 3 — Google Cloud OAuth Setup (15 min)

This is the longest step. You need OAuth credentials for both the Google Sheets and Gmail APIs.

### 3a. Create a Google Cloud Project

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Click the project dropdown (top left) → **New Project**
3. Name it `n8n-outreach` → Create
4. Make sure the new project is selected in the dropdown

### 3b. Enable APIs

1. Go to **APIs & Services → Library**
2. Search and enable:
   - **Google Sheets API** → Enable
   - **Gmail API** → Enable

### 3c. Configure OAuth Consent Screen

1. Go to **APIs & Services → OAuth consent screen**
2. User type: **External** → Create
3. Fill in:
   - App name: `n8n Outreach`
   - User support email: your Gmail
   - Developer contact: your Gmail
4. Click **Save and Continue** through all steps (Scopes and Test Users pages can be skipped for now)
5. Back on the consent screen, click **Publish App** → Confirm

### 3d. Create OAuth Credentials

1. Go to **APIs & Services → Credentials**
2. Click **Create Credentials → OAuth client ID**
3. Application type: **Web application**
4. Name: `n8n`
5. Under **Authorized redirect URIs**, add:
   ```
   http://localhost:5678/rest/oauth2-credential/callback
   ```
6. Click **Create**
7. Copy the **Client ID** and **Client Secret** — you need these in n8n

### 3e. Add Credentials in n8n

In n8n (`http://localhost:5678`):

1. Left sidebar → **Credentials** → **Add Credential**
2. Search `Google Sheets OAuth2 API` → select it
3. Paste Client ID and Client Secret → click **Sign in with Google**
4. Authorize with your Google account
5. Repeat for `Gmail OAuth2 API` using the same Client ID and Secret

---

## Step 4 — Create the Tracking Sheet (5 min)

1. Go to [sheets.google.com](https://sheets.google.com) → Create a new blank spreadsheet
2. Name the spreadsheet: `Internship_Outreach` (the tab name matters — it must match exactly)
3. Rename the first tab (bottom) to: `Internship_Outreach`
4. Add these 23 column headers in row 1, exactly as written (case-sensitive):

```
A: email
B: company_name
C: website
D: contact_name
E: contact_role
F: batch
G: yc_description
H: hunter_confidence
I: hunter_verified
J: email_subject_A
K: email_body_A
L: email_subject_B
M: email_body_B
N: reply_status
O: email_sent_date
P: linkedin_url
Q: linkedin_note
R: linkedin_request_sent
S: website_scraped_text
T: created_date
U: drafted_date
V: reply_received
W: notes
```

5. Copy the URL from your browser. The Sheet ID is the long string between `/d/` and `/edit`:
   ```
   https://docs.google.com/spreadsheets/d/THIS_IS_YOUR_SHEET_ID/edit
   ```
   Save this — you'll paste it into the workflows.

### Recommended: Add Data Validation

For `reply_status` (column N), add a dropdown:
- Select column N → **Data → Data validation**
- Criteria: **Dropdown (from a list)**: `queued, drafted, approved, sent, replied`

For `reply_received` (column V): dropdown with `YES, NO`
For `linkedin_request_sent` (column R): dropdown with `YES`

### Recommended: Conditional Formatting

- `queued` rows → light yellow background
- `drafted` rows → light blue background
- `approved` rows → light orange background
- `sent` rows → light green background

---

## Step 5 — Place Your Resume (2 min)

n8n's file reading is restricted to the `.n8n-files` folder in your home directory.

```
Windows path: C:\Users\YourName\.n8n-files\master_resume.pdf
```

Copy your resume PDF there and name it exactly `master_resume.pdf`.

To verify the folder exists (create it if not):
```powershell
# PowerShell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.n8n-files"
Copy-Item "C:\path\to\your\resume.pdf" "$env:USERPROFILE\.n8n-files\master_resume.pdf"
```

---

## Step 6 — Import Workflows (5 min)

1. In n8n, go to **Workflows** → **Import from file**
2. Import these 4 files from the `/workflows` folder in this repo:
   - `phase1_lead_discovery.json`
   - `phase2_email_drafting.json`
   - `phase3_email_sending.json`
   - `phase4_linkedin_assistant.json`

Each workflow imports inactive by default. **Do not activate them yet.**

---

## Step 7 — Configure Credentials Per Node (5 min)

For each imported workflow, open it and connect credentials:

**Phase 1:**
- Hunter.io HTTP Request node → no credential needed (API key is in the URL as a query param — hardcode it directly)
- Google Sheets (append) → select your `Google Sheets OAuth2 API` credential

**Phase 2:**
- Google Sheets (read) → select your credential
- OpenAI HTTP Request → no credential node; the `Authorization: Bearer YOUR_OPENAI_KEY` header is hardcoded
- Google Sheets (update) → select your credential

**Phase 3:**
- Google Sheets (read) → select your credential
- Gmail node → select your `Gmail OAuth2 API` credential
- Google Sheets (update) → select your credential

**Phase 4:**
- Google Sheets (read) → select your credential
- OpenAI HTTP Request → same as Phase 2
- Google Sheets (update) → select your credential

---

## Step 8 — Hardcode Sheet ID and API Keys

Since self-hosted n8n's free tier doesn't expose the Environment Variables UI, you'll hardcode values directly in the nodes.

### Sheet ID

In every Google Sheets node, the `documentId` field defaults to `={{ $env.GSHEET_ID }}`. Replace this with your actual Sheet ID:

1. Open the node
2. In the Document ID field, click the expression toggle (looks like `{}`) to switch from expression to fixed value
3. Paste your Sheet ID

Do this for all Sheets nodes across all 4 workflows (approximately 8 nodes total).

### API Keys

**Hunter.io (Phase 1):**
Find the HTTP Request node hitting the Hunter.io API. The URL or query params will have `HUNTER_API_KEY` as a placeholder. Replace it with your actual key.

**OpenAI (Phase 2 and Phase 4):**
Find the HTTP Request nodes hitting `api.openai.com`. The Authorization header will have `Bearer YOUR_OPENAI_KEY`. Replace `YOUR_OPENAI_KEY` with your actual key.

---

## Step 9 — Test Each Phase (5 min)

Run phases in order, checking after each one.

### Test Phase 1

1. Open Phase 1 workflow
2. Click **Execute Workflow**
3. Watch the execution — check for green nodes (success) or red (error)
4. Open your Google Sheet — you should see rows appearing with `reply_status = queued`

**If it fails:** Check the error in the failing node. Most common: wrong Sheet ID, wrong tab name, Hunter.io key missing.

### Test Phase 2

1. Make sure you have at least 1 row with `reply_status = queued`
2. Execute Phase 2
3. Check the sheet — the row should now have email drafts in columns J–M and `reply_status = drafted`

**If it fails:** Check OpenAI key, check that the sheet tab name is spelled correctly.

### Manually Approve a Row

1. Find a `drafted` row in the sheet
2. Pick Version A or B: delete the subject/body you don't want (or just leave both — Phase 3 uses A by default)
3. Change `reply_status` from `drafted` to `approved`

### Test Phase 3

1. Make sure you have at least 1 row with `reply_status = approved`
2. Execute Phase 3
3. Check your Gmail Sent folder — the email should be there with your resume attached
4. Check the sheet — `reply_status` should now be `sent` and `email_sent_date` filled

**Safety check before running Phase 3:**
- [ ] The email addresses are real founders (not test data)
- [ ] The email body looks good — no `[PLACEHOLDER]` text remaining
- [ ] Your resume is in `.n8n-files/master_resume.pdf`
- [ ] You're okay sending this email right now

### Test Phase 4

1. Find a `sent` row and manually add a LinkedIn URL in the `linkedin_url` column
   (Look up: `{contact_name} {company_name} linkedin` on Google)
2. Execute Phase 4
3. Check the sheet — `linkedin_note` should be filled with a ≤280 char note

---

## You're Set Up

From here, the daily routine is:
1. Run Phase 1 periodically to refresh the lead pool (once a week is plenty for YC batches)
2. Run Phase 2 daily on new `queued` rows
3. Review and approve in the sheet
4. Run Phase 3 to send
5. Manual LinkedIn lookups → Run Phase 4 → Send connections from browser

See [docs/daily_workflow.md](./docs/daily_workflow.md) for the full routine.
