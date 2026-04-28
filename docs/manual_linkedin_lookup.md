# Manual LinkedIn URL Lookup

## Why This Is Manual

Phase 4 was designed with automated LinkedIn URL discovery, but every practical option had blockers:

| Option | Problem |
|--------|---------|
| Google Custom Search API | Requires billing account — Indian payment methods weren't accepted during setup |
| Hunter.io | Only finds emails, not LinkedIn URLs |
| Phantombuster | Paid plan required ($69/month minimum) |
| Apollo.io | Paid plan for bulk LinkedIn enrichment |
| LinkedIn API | Partner program only — not available to individuals |
| Scraping LinkedIn directly | Violates ToS; accounts get banned fast |

**Manual lookup takes 20–30 seconds per person.** For 23 sent leads, that's under 12 minutes total. The ROI on engineering an automated solution doesn't justify the time or cost.

---

## The Process

For each row where `reply_status = sent` and `linkedin_url` is empty:

### Step 1 — Open Google

Go to [google.com](https://google.com) in your browser.

### Step 2 — Search for the Person

Type the following into the search bar:
```
{contact_name} {company_name} linkedin
```

**Examples:**
```
Justin Waugh Maritime Fusion linkedin
Sara Chen Helios Energy linkedin
Rohan Mehta Stackr linkedin
```

### Step 3 — Identify the Right Result

Look for a result matching this pattern:
```
linkedin.com/in/firstname-lastname-xxxxx
```

**Signs it's the right person:**
- The LinkedIn URL slug contains their name
- The search snippet mentions their company
- Their role matches what's in your sheet (founder / CEO / CTO)

**Skip if:**
- The result is a `/company/` page (not a person)
- The URL is for someone with the same name at a different company
- No LinkedIn result appears in the first 5 results

### Step 4 — Copy the Clean URL

Click the LinkedIn result. Once the page loads, copy the URL from the address bar.

**Clean the URL before copying:**
- Remove everything after `?` (tracking parameters)
- Remove trailing `/`

**Raw URL from LinkedIn:** `https://www.linkedin.com/in/justin-waugh-48b2391b2?utm_source=share&utm_campaign=share_via`
**Clean URL to paste:** `https://www.linkedin.com/in/justin-waugh-48b2391b2`

You can also copy directly from the Google search result's green URL text (shown below the title) — Google typically shows the clean URL without tracking params.

### Step 5 — Paste into the Sheet

1. Find the row for this person in your Google Sheet
2. Click the `linkedin_url` cell (column P)
3. Paste the clean URL
4. Press Enter

### Step 6 — Run Phase 4

Once you've filled in LinkedIn URLs for all the `sent` rows you could find, run Phase 4. It will:
1. Find rows where `reply_status = sent` AND `linkedin_url` is NOT empty AND `linkedin_note` IS empty
2. Generate a personalized connection note for each
3. Write the note back to the `linkedin_note` column

---

## When You Can't Find a LinkedIn URL

Some people aren't on LinkedIn, use a different name professionally, or have a private profile. This happens ~10–15% of the time.

**What to do:**
- Leave `linkedin_url` empty for that row
- Phase 4 will skip it (it only processes rows where `linkedin_url` is filled)
- If you later find the URL, add it and run Phase 4 again — it will process only new/unfilled notes

**Don't fill in a wrong URL** just to have something there. A note referencing the wrong person's profile is worse than no connection request.

---

## Sending the LinkedIn Connection

Phase 4 generates the note — you send it manually.

1. Open the person's LinkedIn profile URL from column P
2. Click **Connect**
3. Click **Add a note**
4. Copy the text from `linkedin_note` (column Q) in your sheet
5. Paste into the connection note field
6. Click **Send**
7. Go back to your sheet → set `linkedin_request_sent` (column R) to `YES`

**Note length check:** LinkedIn allows max 300 characters for connection notes. Your notes are generated at 280 chars max, so you'll never hit this limit. But if you edit the note manually, count characters before sending.

---

## Batch Workflow Tips

**Do lookups in one sitting, not one-at-a-time.** Open a separate browser window with your sheet. Search for each person, paste URL, move to the next. Don't run Phase 4 after each one — do all the lookups first, then run Phase 4 once for the whole batch.

**Use a browser session where you're already logged into LinkedIn.** This way you can verify you found the right profile quickly without extra login steps.

**Prioritize by company relevance.** If you got a reply from some founders but not others, focus LinkedIn connections on the non-replies — they're warm leads who've opened your email but haven't responded yet.

---

## Lookup Success Rate

Based on 23 sent leads:

| Outcome | Count | Percentage |
|---------|-------|-----------|
| LinkedIn URL found on first Google result | ~18 | ~78% |
| URL found but required 2–3 searches to confirm | ~3 | ~13% |
| No LinkedIn found / wrong person / private | ~2 | ~9% |

Average lookup time: ~25 seconds per person when done in batch.
