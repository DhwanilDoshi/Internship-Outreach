# Troubleshooting

Quick lookup for errors you'll actually hit. Organized by category.

---

## General Errors

### Workflow runs but processes 0 rows

**Cause:** The filter condition doesn't match any rows.
**Fix:**
1. Open the filter Code node → click "Test step" on it alone
2. Look at the output — how many items came in? How many passed?
3. Log every condition: `console.log(status, email, contactName)` to see what the actual values are
4. Check for case sensitivity: `"Sent"` ≠ `"sent"`. The filters use `.trim().toLowerCase()`.
5. Check for trailing spaces in sheet cells — copy the cell value, paste into a text editor, look for hidden spaces

---

### Node shows green but no data came through

**Cause:** An upstream node filtered everything out, or a Code node returned an empty array.
**Fix:** Click on each node from left to right. Check the output panel. The first node showing 0 items is the culprit.

---

### Workflow stops mid-loop without error

**Cause:** The loop-back connection is missing. SplitInBatches needs a wire coming back from the last node in the pipeline.
**Fix:** Check that the last node (usually the Sheets update) has a wire going back to the SplitInBatches input. In n8n, this loop-back wire is what triggers the next batch.

---

### "Expression Error" in a node

**Cause:** The expression references data that doesn't exist at that point in the execution.
**Fix:**
- Check if the referenced node name matches exactly (case-sensitive): `$('Split In Batches')` not `$('split in batches')`
- Check if the data field exists: add `|| ''` as a fallback — e.g., `$json.email_body_A || ''`
- Check the execution order — some nodes need data from earlier nodes that may not have run yet

---

## OAuth & Authentication

### Google Sheets: "The caller does not have permission"

**Cause:** The OAuth credential authorized the wrong Google account, or Sheets API isn't enabled.
**Fix:**
1. Go to Google Cloud Console → APIs & Services → Library → confirm Google Sheets API is enabled
2. In n8n, delete the credential and re-authorize, making sure you're logged into the right Google account
3. Confirm the spreadsheet is owned by or shared with the authorized account

---

### Gmail: "Request had insufficient authentication scopes"

**Cause:** The Gmail OAuth credential was created without the Send scope.
**Fix:**
1. In n8n, delete the Gmail credential
2. Re-create it — n8n's Gmail OAuth2 node requests the correct scopes automatically when you click "Sign in with Google"
3. If re-creating doesn't fix it: in Google Cloud Console → Credentials → edit the OAuth client → verify redirect URI is `http://localhost:5678/rest/oauth2-credential/callback`

---

### OAuth redirect URI mismatch

**Symptom:** Clicking "Sign in with Google" redirects but shows "redirect_uri_mismatch" error.
**Cause:** The redirect URI registered in Google Cloud doesn't match what n8n is using.
**Fix:** In Google Cloud Console → Credentials → your OAuth client ID → add exactly:
```
http://localhost:5678/rest/oauth2-credential/callback
```
No trailing slash. No HTTPS (for local setup).

---

### Credential stops working after a few days

**Cause:** Google OAuth access tokens expire. n8n should auto-refresh using the refresh token, but sometimes the refresh token is invalid or expired.
**Fix:** Delete and re-authorize the credential. If this keeps happening, check that your Google Cloud OAuth consent screen is in "Published" state (not "Testing" — testing mode credentials expire after 7 days).

---

## OpenAI / API Issues

### OpenAI: "401 Unauthorized"

**Cause:** Wrong API key or the key has been revoked.
**Fix:**
1. Go to platform.openai.com → API keys → verify the key is active
2. In the Call OpenAI node, check the Authorization header: must be exactly `Bearer sk-...` with a space after "Bearer"
3. Re-copy the key — no leading/trailing spaces

---

### OpenAI: "429 Too Many Requests"

**Cause:** Rate limit hit (requests per minute or tokens per minute).
**Fix:**
1. Add a Wait node (5 seconds) before the OpenAI call
2. Check your OpenAI account tier — free tier has very low RPM limits
3. For Phase 2 processing large batches, increase the wait to 10 seconds

---

### OpenAI: "400 Invalid request body"

**Cause:** The request body isn't valid JSON or the Content-Type header is wrong.
**Fix:**
1. Check the HTTP Request node body setting: must be `specifyBody: "string"` with `body: {{ JSON.stringify($json._ai_request) }}`
2. Confirm the `Content-Type: application/json` header is set
3. Add a console.log in the Build Prompt node to print `JSON.stringify($json._ai_request)` and verify it's valid JSON

---

### Parse node gets empty note / parse error

**Cause:** OpenAI returned an error response (no `choices` field), or returned malformed JSON.
**Fix:**
1. Check the `continueOnFail` node output — the error object will be in `$json.error`
2. Add more error logging in the Parse node: `console.log(JSON.stringify(openAiResponse))`
3. Check your OpenAI account has sufficient credits

---

### Hunter.io: "401 Invalid API key"

**Cause:** Hunter.io key is wrong or revoked.
**Fix:** Go to hunter.io → Dashboard → API → copy the key again. Replace in the Phase 1 HTTP Request node URL or query parameter.

---

### Hunter.io returns 0 results

**Cause:** The company isn't in Hunter.io's database, or the domain is very new.
**Fix:** This is expected for very early-stage YC startups. The row will be written with an empty email field and filtered out in later phases. No action needed — it just won't be outreached.

---

## Email Issues

### Emails send but have visible `\n` characters

**Cause:** Email body was stored with literal `\n` escape sequences, not actual newlines.
**Fix:** In your email client, this shows as `\n` in the text. The Phase 2 Parse node should convert: `.replace(/\\n/g, '\n')`. Check if this replacement is present.

---

### Email sent but no attachment

**Cause:** Binary property name mismatch between Read Binary File node and Gmail node.
**Fix:**
1. Read Binary File node → check the output property name (default: `data`)
2. Gmail node → Attachments section → Property Name field must match (set to `data`)
3. Confirm `master_resume.pdf` is in `C:\Users\YourName\.n8n-files\`

---

### Resume file not found

**Symptom:** `Error: ENOENT: no such file or directory, open 'master_resume.pdf'`
**Fix:**
1. The file must be in your `.n8n-files` folder: `C:\Users\YourName\.n8n-files\master_resume.pdf`
2. Check for typos in the filename — it must be exactly `master_resume.pdf`
3. Create the folder if it doesn't exist:
   ```powershell
   New-Item -ItemType Directory -Force "$env:USERPROFILE\.n8n-files"
   ```

---

### Email sends but body is blank

**Cause:** The email body expression references the wrong field name, or the field is empty.
**Fix:** Check the Gmail node's Body field. Confirm it references `email_body_A` (the one you kept). If you deleted both versions, the cell is empty and the email sends blank.

---

### "n8n attribution" footer appears in sent emails

**Fix:** In the Gmail node → Advanced Options → disable "Append n8n Attribution" if visible. If not visible in your version, wrap the email body in a full HTML document:
```html
<html><body>{{ $json.email_body_A }}</body></html>
```
This bypasses the default attribution injection.

---

## Sheet / Data Issues

### Google Sheets: "Unable to find sheet"

**Cause:** The `sheetName` parameter doesn't match the actual tab name.
**Fix:** The sheet tab must be named exactly `Internship_Outreach` (case-sensitive, no spaces). Check the bottom of your spreadsheet for the actual tab name.

---

### Cells show `#ERROR!` in Google Sheets

**Cause:** Text starting with `=`, `+`, `-`, or `@` is interpreted as a formula.
**Fix:** The Parse nodes should strip these leading characters. If you see this error in existing cells:
1. Click the cell → press F2 to edit → add a space before the `=`
2. Or: Format the column as Plain Text before writing (Format → Number → Plain text)

---

### Duplicate rows appearing

**Cause:** Phase 1 was run multiple times without the dedup Code node properly checking for existing emails.
**Fix:** The dedup logic reads all emails from the sheet into a Set. Check that this step is running and the field name being checked is `email` (exact match to the column header).

---

### Fields are empty when the Code node should have set them

**Cause:** Code node returned the wrong shape. n8n requires `{ json: { ... } }` not `{ ... }`.
**Fix:** In every Code node, check every `return` statement. Must be:
```javascript
return { json: { field: value } }
// or in runOnceForAllItems:
return arrayOfItems; // where each item is { json: { ... } }
```

---

## n8n-Specific Quirks

### Execution history fills up disk

**Cause:** n8n stores every execution by default.
**Fix:** In n8n Settings → Executions → set "Prune data older than" to 30 days. Or: Settings → `executions.pruneData: true` in config.

---

### n8n is slow on Windows after running for a few days

**Cause:** SQLite database (n8n's default) accumulates execution data.
**Fix:** Restart n8n. Long-term: enable execution pruning (see above). For production use, switch to PostgreSQL.

---

### "Cannot read property of undefined" in Code node

**Cause:** Trying to access a nested field that doesn't exist on some rows.
**Fix:** Use optional chaining and fallbacks:
```javascript
// Instead of:
const name = data.contact.first_name;

// Use:
const name = data?.contact?.first_name || '';
```

---

## Debugging Workflow

When something breaks and you don't know where, follow this sequence:

```
1. Open the failing workflow
2. Click "Execute Workflow" (not any individual node)
3. Watch for the first RED node — that's where it broke
4. Click that node → examine the error message
5. Click the node BEFORE it → examine its output data
      → Is the data shape what you expected?
      → Are the field names correct?
      → Are there null/undefined values?
6. If the error is in a Code node:
      → Add console.log() statements to print intermediate values
      → Re-run and check the execution log (click the node → Logs tab)
7. If the error is in an HTTP Request node:
      → Check Status Code in the output
      → Check the full response body — the error message is usually there
      → Verify URL, headers, body separately
8. If the Sheets node fails:
      → Confirm Sheet ID is correct (not the file name, the ID from the URL)
      → Confirm tab name matches exactly
      → Confirm credential is still authorized (try re-authorizing)
```

**The most common finding:** The data shape coming out of node N isn't what node N+1 expected. Always check the output panel of the node before the failing one first.
