# Changelog — Bugs Hit During Build

This documents every real bug encountered building this project, in the order they were hit. 27 bugs total across 4 phases.

If you're setting up a similar workflow and something breaks, start here.

---

## Phase 1 — Lead Discovery (10 bugs)

### Bug 1 — Apify cost shock
**Symptom:** Tried using Apify to scrape YC's website. First run cost $2.40 for 100 companies.
**Cause:** Apify charges per actor run + compute units. YC scraping is compute-heavy.
**Fix:** Switched entirely to YC's public JSON API (`yc.com/companies?batch=W25`). Free, fast, structured. No scraper needed.

---

### Bug 2 — YC API pagination missing
**Symptom:** Phase 1 only returned 20 companies, not the full batch.
**Cause:** The YC API paginates results. The initial implementation fetched page 1 and stopped.
**Fix:** Added a pagination loop using a `limit` and `page` parameter. Loop runs until the API returns fewer items than the page size.

---

### Bug 3 — Sheet tab name mismatch
**Symptom:** Google Sheets append node threw `Unable to find sheet "Sheet1"`.
**Cause:** The Google Sheets node was configured with the default tab name `Sheet1`, but the actual tab was named `Internship_Outreach`.
**Fix:** Updated the `sheetName` parameter in every Sheets node to `Internship_Outreach`. Tab names are case-sensitive.

---

### Bug 4 — Dedup logic missing
**Symptom:** Re-running Phase 1 added duplicate rows for the same companies.
**Cause:** The append node doesn't check for existing rows. It just appends.
**Fix:** Added a Code node that reads all existing emails from the sheet into a Set, then filters the incoming batch against it before appending. O(n) read once per run, not per company.

---

### Bug 5 — SplitInBatches loop not closing
**Symptom:** Workflow processed the first company and then stopped. The loop didn't continue.
**Cause:** The connection from the final node (Sheets append) back to SplitInBatches was missing. n8n requires an explicit loop-back wire.
**Fix:** Drew a connection from the Sheets append node output back to the SplitInBatches node input. The loop now iterates correctly.

---

### Bug 6 — Format Lead node wrong mode
**Symptom:** Code node in `runOnceForAllItems` mode returned only one item even when processing multiple companies.
**Cause:** Used `runOnceForAllItems` mode and returned a single object instead of an array. n8n requires an array of `{ json: ... }` objects when running for all items.
**Fix:** Changed mode to `runOnceForEachItem` and used `return { json: { ...data } }` (single object per execution). Alternatively, in all-items mode, `return filteredArray` where each element is `{ json: {...} }`.

---

### Bug 7 — Format Lead return value wrong shape
**Symptom:** Next node received `undefined` for all fields.
**Cause:** Code node returned a plain object `{ email: ..., company: ... }` instead of `{ json: { email: ..., company: ... } }`.
**Fix:** Wrapped all returns in `{ json: { ... } }`. n8n's Code node requires this envelope — it doesn't auto-wrap plain objects.

---

### Bug 8 — Google Sheets rate limiting
**Symptom:** Sheets append failed intermittently with `429 Too Many Requests` on batches > 30 companies.
**Cause:** Google Sheets API free tier allows ~100 requests/minute. Processing without any delay hit this.
**Fix:** Added a `Wait` node (1 second) between the Hunter.io request and the Sheets append. For very large batches, increase to 2 seconds.

---

### Bug 9 — Hunter.io column casing mismatch
**Symptom:** Email field was populated but `hunter_confidence` was always empty in the sheet.
**Cause:** Hunter.io returns `data.score` not `confidence`. The field name was wrong in the mapping.
**Fix:** Logged the full Hunter.io response object in the Code node to inspect actual field names. Updated mapping to use `response.data.score` → `hunter_confidence`.

---

### Bug 10 — contact_role empty for most leads
**Symptom:** `contact_role` column was blank for ~80% of rows.
**Cause:** Hunter.io's email-finder endpoint returns a `position` field, not `role`. Some records also had it nested under `data.emails[0].position`.
**Fix:** Updated extraction to check `response.data.position || response.data.emails?.[0]?.position || 'Founder'`. Falls back to "Founder" since YC founders are the target anyway.

---

## Phase 2 — Email Drafting (12 bugs)

### Bug 11 — Gemini 400 JSON error
**Symptom:** Initially used Google Gemini. Every request returned `400 Bad Request` with `response_format not supported`.
**Cause:** Gemini's API at the time did not support OpenAI-style `response_format: { type: "json_object" }`. It has its own JSON mode syntax.
**Fix:** Switched to OpenAI GPT-4o. Better quality, consistent JSON mode, no format surprises.

---

### Bug 12 — Gemini 429 quota exhausted
**Symptom:** Gemini requests started failing with `429` after 15 companies.
**Cause:** Gemini free tier has a very low RPM (requests per minute) limit.
**Fix:** Already switched to OpenAI (see Bug 11). Noted: for high-volume use, OpenAI's paid tier is more predictable than free Gemini.

---

### Bug 13 — Gemini model deprecated
**Symptom:** `gemini-pro` model ID started returning `404 Model not found`.
**Cause:** Google deprecated the `gemini-pro` endpoint, requiring migration to `gemini-1.5-pro`.
**Fix:** Moot — had already switched to OpenAI. Lesson: model IDs on every provider change frequently. Don't hardcode without checking deprecation dates.

---

### Bug 14 — OpenAI HTTP Request body format wrong
**Symptom:** OpenAI returned `400 Invalid request body`. The node was configured but GPT never received a valid message.
**Cause:** The HTTP Request node was using `specifyBody: "keypairs"` which sends form-encoded body, not JSON. The OpenAI API requires `Content-Type: application/json`.
**Fix:** Changed to `specifyBody: "string"` with `body: {{ JSON.stringify($json._ai_request) }}` and added `Content-Type: application/json` header manually.

---

### Bug 15 — Generic email outputs: boring subject lines
**Symptom:** GPT-4o was producing subject lines like "Internship Inquiry at [Company]" and bodies opening with "I am a passionate engineering student..."
**Cause:** The initial prompt had no guardrails against generic phrasing. GPT defaults to the most common patterns in its training data.
**Fix:** Rewrote the prompt with an explicit banned word list: `innovative, exciting, opportunity, passionate, synergy, leverage, disruptive`. Added a rule requiring the opener to reference one specific company detail. Switched to temperature 0.9.

---

### Bug 16 — Skilleton over-defaults
**Symptom:** Email bodies all had a similar structure — three bullet points in Version A, one paragraph in Version B — regardless of the company context.
**Cause:** Prompt was too prescriptive about structure. GPT followed the format rules too literally.
**Fix:** Removed rigid structure instructions. Replaced with: "Version A should feel professional. Version B should feel like texting a founder." This gave GPT freedom to match the company's voice.

---

### Bug 17 — Missing company description breaks email quality
**Symptom:** Some emails had no specific company detail — just generic filler text.
**Cause:** Some YC companies didn't have a website yet (very early stage). The website scrape returned empty, and the YC description was 1 sentence.
**Fix:** When `cleanText` is under 100 chars, the prompt explicitly instructs GPT to work only from `yc_description` and craft a more founder-to-founder tone. Emails for these companies are shorter but more honest.

---

### Bug 18 — Newlines stored as literal `\n` in sheet
**Symptom:** Email body in the sheet showed `Hi Justin,\n\nI saw your work...` with visible `\n` characters.
**Cause:** The Code node built the email body with JavaScript `\n` escape sequences in a regular string. These were stored as literal backslash-n characters in the cell.
**Fix:** In the Code node, used actual newlines in the string (using template literals with real line breaks) before writing to the sheet. Alternatively: `.replace(/\\n/g, '\n')` to convert escaped sequences.

---

### Bug 19 — Sheet #ERROR! in email body cells
**Symptom:** Some email body cells showed `#ERROR!` in Google Sheets instead of the email text.
**Cause:** GPT occasionally started the email body with `=` (e.g., `= I saw your work...` as a poetic opener). Google Sheets interprets cells starting with `=` as formulas.
**Fix:** Added formula injection prevention in the Parse node: strip leading `=`, `+`, `-`, `@` characters from all text fields before writing to the sheet.

---

### Bug 20 — Broken placeholders in final emails
**Symptom:** Sent emails had text like `Hi [FirstName],` or `[Company]'s work on...`.
**Cause:** GPT sometimes returned placeholder text instead of the actual values, especially when the prompt injected the variable names as examples.
**Fix:** Added a validation step in the Parse node that checks for `[` or `]` in the output. If found, the row is flagged with `reply_status = "error"` instead of `drafted`, so you know to re-run it manually.

---

### Bug 21 — "Hii" typo in template
**Symptom:** Emails opened with "Hii Justin," (double i).
**Cause:** The prompt example had a typo: `"Example opener: Hii [FirstName],"`. GPT followed the example exactly.
**Fix:** Fixed the typo in the prompt. Added a note to always proofread prompt examples — GPT treats them as gold standard.

---

### Bug 22 — Age/college info outdated
**Symptom:** Emails said "3rd-year ECE student" but Dhwanil is in his 2nd year.
**Cause:** The initial prompt hardcoded "3rd-year" from a previous draft. Wasn't updated.
**Fix:** Updated prompt to "2nd-year ECE student at SCET, Surat". Lesson: anything about you that changes (year, projects, GPA) should be in one place — the prompt file — not scattered across multiple nodes.

---

## Phase 3 — Email Sending (5 bugs)

### Bug 23 — Filter approved column mismatch
**Symptom:** Phase 3 ran but sent 0 emails. Filter node passed 0 rows.
**Cause:** The filter checked `item.json.status === 'approved'` but the column was named `reply_status`.
**Fix:** Updated filter to `item.json.reply_status === 'approved'`. Column names in the Code node must match the exact header text in the Google Sheet.

---

### Bug 24 — Resume not found: .n8n-files folder restriction
**Symptom:** Gmail node threw `File not found: master_resume.pdf`.
**Cause:** n8n's Read Binary File node is sandboxed to the `.n8n-files` folder in the user's home directory. The resume was in `Downloads/`.
**Fix:** Moved `master_resume.pdf` to `C:\Users\Hp\.n8n-files\master_resume.pdf`. Updated the node path accordingly.

---

### Bug 25 — n8n attribution signature in sent emails
**Symptom:** Every sent email had a footer: `Sent with n8n`.
**Cause:** Some versions of the n8n Gmail node append a signature by default.
**Fix:** In the Gmail node advanced options, disabled the `Append n8n Attribution` toggle. Alternatively: not visible in some n8n versions — wrapping the body in a full HTML template with no attribution fixed it.

---

### Bug 26 — Plain text email wrapping
**Symptom:** Emails displayed with awkward line breaks at ~72 characters in Gmail recipients' inboxes.
**Cause:** Gmail node was in plain text mode. Email clients wrap plain text at 72–80 chars.
**Fix:** Switched Gmail node to HTML mode. Wrapped the body in basic HTML: `<p>paragraph</p>` tags for each paragraph. Preserved line breaks with `<br>`. Emails now render as intended.

---

### Bug 27 — Resume not attaching despite correct config
**Symptom:** Email sent successfully (status 200) but recipient confirmed no attachment.
**Cause:** The Read Binary File node was connected but its output (binary data) wasn't passed correctly to the Gmail node's attachments field. The attachment field was empty.
**Fix:** Checked that the binary property name in Read Binary File matched what the Gmail node expected. Default is `data`. Gmail node attachments field: set `Property Name` to `data`. Once names matched, attachment worked.

---

## Lessons Learned

### Patterns across all 27 bugs:

**1. Field names are everywhere and nothing auto-maps**
Bugs 3, 9, 10, 23 were all some version of "I assumed the field was called X but it was called Y." Log the raw response before mapping anything. Never guess API response shapes.

**2. Read the n8n Code node docs once before writing anything**
Bugs 6 and 7 (wrong mode, wrong return shape) are hit by almost everyone using Code nodes for the first time. The `{ json: { ... } }` envelope is not optional.

**3. GPT does what the prompt says, including the mistakes**
Bugs 15, 16, 21 show that GPT is a mirror. A lazy prompt produces lazy emails. A prompt with a typo produces emails with that typo. Spend 80% of your time on the prompt.

**4. Handle empty/missing data explicitly**
Bugs 17, 20 came from not planning for the case where upstream data was thin. Always write the fallback path before the happy path.

**5. Google Sheets is a database until it isn't**
Bugs 18, 19 (newlines, formula injection) are Sheets-specific annoyances. When writing user-generated text to a sheet, always sanitize: strip leading formula chars, convert `\n` to real newlines.

**6. Platform restrictions are real**
Bug 24 (.n8n-files restriction) is not documented prominently. n8n sandboxes binary file access. When something isn't where you put it, check if the tool has a path restriction before debugging the logic.

**7. Switching models mid-build is worth it early**
Bugs 11–13 (Gemini failures) cost 4 hours. Switching to OpenAI GPT-4o cost 20 minutes and produced better output. When a foundational dependency isn't working, switch fast rather than debugging deep.
