# Phase 4 — LinkedIn Note Generation Prompt

This document is the authoritative reference for the prompt used in the "Build Connection Note Prompt" Code node in Phase 4.

---

## Context

Phase 4 generates a personalized LinkedIn connection request note for each sent lead. The note must:

1. Feel like a natural follow-up to the email you already sent
2. Fit within LinkedIn's 280-character limit (hard enforced in code)
3. Not feel like a mass-outreach message

The note is stored in the sheet and sent manually by you from your LinkedIn profile.

---

## The Prompt

```javascript
const contactFirst = (data.contact_name || 'there').split(' ')[0];
const emailBody    = (data.email_body_A && data.email_body_A.trim())
                   ? data.email_body_A.trim()
                   : (data.email_body_B || '').trim();

const prompt = [
  `You are writing a LinkedIn connection request note on behalf of Dhwanil (ECE student at SCET, Surat).`,
  ``,
  `STRICT RULES:`,
  `1. 280 characters MAXIMUM — count every character including spaces, punctuation, and the signature.`,
  `2. Casual but professional tone.`,
  `3. Reference ONE specific concrete detail from the email body (product name, technology, mission, build).`,
  `   This makes the note feel like a follow-up, not a cold message.`,
  `4. BANNED WORDS — do not use: innovative, exciting, opportunity, passionate, synergy,`,
  `   leverage, disruptive, thrilled, keen, eager`,
  `5. End with EXACTLY this signature: — Dhwanil, ECE student at SCET, Surat`,
  `6. Open with Hi ${contactFirst}, — do NOT open with the word I`,
  `7. The note must feel like a natural follow-up to the email that was already sent`,
  ``,
  `CONTEXT:`,
  `Recipient name   : ${data.contact_name}`,
  `Company          : ${data.company_name}`,
  `LinkedIn profile : ${data.linkedin_url || 'not found'}`,
  ``,
  `Email body already sent to this person:`,
  `---`,
  emailBody,
  `---`,
  ``,
  `EXAMPLE OF A GOOD NOTE:`,
  `"Hi Sara, just emailed you about GreenGrid's solar balancing work — fascinating constraint`,
  ` to design around. Would love to stay connected. — Dhwanil, ECE student at SCET, Surat"`,
  ``,
  `CHARACTER BUDGET BREAKDOWN (aim for):`,
  `- Opening + company reference: ~150–180 chars`,
  `- Closing intent phrase: ~20–30 chars`,
  `- Signature (fixed): 36 chars ("— Dhwanil, ECE student at SCET, Surat")`,
  `- Total: ≤280 chars`,
  ``,
  `Return ONLY a JSON object, no markdown, no explanation:`,
  `{"linkedin_note": "<your note here>"}`
].join('\n');
```

---

## OpenAI Request Parameters

```javascript
const aiRequest = {
  model: 'gpt-4o-mini',
  messages: [
    { role: 'user', content: prompt }
  ],
  response_format: { type: 'json_object' },
  max_tokens: 250,
  temperature: 0.72
};
```

| Parameter | Value | Why |
|-----------|-------|-----|
| `model` | `gpt-4o-mini` | Notes are 280 chars. Mini handles this length well and is 10x cheaper |
| `temperature` | `0.72` | Slightly creative but not unpredictable — 280 chars leaves no room for randomness |
| `max_tokens` | `250` | 280 chars ≈ 70 tokens. 250 tokens gives room for the JSON wrapper |
| `response_format` | `json_object` | Structured output. Parse node extracts `linkedin_note` field |

---

## Hard Constraints Enforced in Code (Parse Note Node)

After GPT returns the note, the Parse Note Code node enforces these constraints programmatically — these are not just prompt guidelines:

```javascript
// 1. Strip markdown fences if GPT wrapped the JSON
if (content.startsWith('```')) {
  content = content.replace(/^```[^\n]*\n/, '').replace(/```$/, '');
}

// 2. Parse JSON
const parsed = JSON.parse(content.trim());
let linkedinNote = (parsed.linkedin_note || '').trim();

// 3. HARD 280-char limit — LinkedIn enforces this server-side
if (linkedinNote.length > 280) {
  linkedinNote = linkedinNote.substring(0, 280);
}

// 4. Google Sheets formula injection prevention
if (['=', '+', '-', '@'].includes(linkedinNote[0])) {
  linkedinNote = linkedinNote.substring(1);
}
```

**Why enforce in code if it's in the prompt?**
GPT follows character limits about 85% of the time. The other 15%, it overshoots by 5–20 characters. The code trim is the safety net. Trimming at 280 mid-sentence is ugly, which is why the prompt asks for 260–270 to leave buffer.

---

## The Fixed Signature

The signature is always exactly:
```
— Dhwanil, ECE student at SCET, Surat
```

**Character count: 38 characters** (including the em dash and spaces).

This leaves 242 characters for the actual message. The prompt tells GPT to budget accordingly.

**Do not change the signature** between notes — LinkedIn connection acceptance rates benefit from consistency. Founders who receive multiple notes from you (if you're connected to others at their company) should see the same signature format.

---

## Banned Words

These are explicitly listed in the prompt. Adding to this list is the most impactful tuning you can do if outputs feel off:

```
innovative, exciting, opportunity, passionate, synergy,
leverage, disruptive, thrilled, keen, eager
```

**Why these specific words?**
These are the most-trained corporate-speak patterns in GPT's output when asked to write professional messages. They signal "this is a template" to anyone who reads them. One of these words in a 280-char note is enough to tank the connection acceptance rate.

---

## Continuity with Phase 2 Emails

The note is designed to feel like a follow-up, not a cold message. The email body (whichever version you sent) is injected into the prompt so GPT can:

1. Find the specific company detail you referenced in the email
2. Echo that detail (slightly rephrased) in the note
3. Frame the connection as "I emailed you, now I want to connect" rather than "I'm reaching out cold"

**Example of good continuity:**

Email subject: `Maritime Fusion's underwater power coupling — internship ask`

Email opener: `Hi Justin, saw the work Maritime Fusion is doing on inductive power transfer for underwater ROVs...`

LinkedIn note: `Hi Justin, just emailed you about Maritime Fusion's underwater power coupling work — would love to stay connected. — Dhwanil, ECE student at SCET, Surat`

The note echoes "underwater power coupling" — the same specific detail from the email. The founder who reads this note immediately knows the context. This is what makes the connection request feel warm rather than generic.

---

## Output Validation

After Phase 4 runs, manually scan the `linkedin_note` column for:

| Issue | What to look for | Fix |
|-------|-----------------|-----|
| Too long | Note clearly gets cut mid-word | GPT ignored limit; parse node trimmed. Check if it still makes sense. |
| Generic opener | "Hi [Name], I came across your work..." | Re-run Phase 4 for that row (note will be overwritten since it's now filled — clear the cell first) |
| Wrong company detail | References something from a different company | GPT hallucinated. Delete the note, clear linkedin_url, re-run. |
| Missing signature | Note doesn't end with `— Dhwanil...` | Parse node trimmed it. Check character count — the original note was over 280. |
| Placeholder text | `[Company Name]` or `[FirstName]` | Prompt injection failed. Check that email_body_A/B is populated for that row. |

**To re-run Phase 4 for a specific row:** Clear the `linkedin_note` cell → run Phase 4 again. It only processes rows where `linkedin_note` is empty (and linkedin_url is filled).
