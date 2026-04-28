# Phase 2 — Email Generation Prompt

This document is the authoritative reference for the prompt architecture used in the "Build GPT-4o Prompt" Code node in Phase 2.

---

## Context

Phase 2 takes a `queued` lead row (with company info and scraped website text) and calls GPT-4o to generate two email drafts:

- **Version A** — Professional, structured, slightly longer
- **Version B** — Casual, direct, shorter

The output is a JSON object that maps cleanly back to the sheet's columns.

---

## Variables Injected into the Prompt

| Variable | Source | Description |
|----------|--------|-------------|
| `companyName` | `company_name` column | The startup's name |
| `contactFirst` | First word of `contact_name` | First name only for the greeting |
| `ycDescription` | `yc_description` column | One-line YC batch description |
| `cleanText` | `website_scraped_text` (truncated) | Scraped website text, 3000 char cap |

`contactFirst` is derived as: `contact_name.split(' ')[0]`

If `cleanText` is under 100 characters (scrape failed or returned very little), the prompt switches to a fallback mode that relies entirely on `ycDescription`.

---

## The Prompt

```javascript
const contactFirst = (data.contact_name || 'there').split(' ')[0];
const companyName  = data.company_name || 'your company';
const ycDesc       = data.yc_description || '';
const cleanText    = (data.website_scraped_text || '').substring(0, 3000);

const hasWebsiteContent = cleanText.length >= 100;

const contextSection = hasWebsiteContent
  ? `Company website content (use this to find ONE specific, concrete detail to reference):\n${cleanText}`
  : `No website content available. Use only the YC description below and write a more direct, founder-to-founder style email:\n${ycDesc}`;

const prompt = [
  `You are Dhwanil Doshi, a 21-year-old ECE student at SCET, Surat, India.`,
  `You are writing a cold email to ${contactFirst} at ${companyName} asking about internship possibilities.`,
  ``,
  `COMPANY CONTEXT:`,
  `YC Description: ${ycDesc}`,
  contextSection,
  ``,
  `STRICT RULES FOR BOTH VERSIONS:`,
  `1. Max 200 words per version`,
  `2. Do NOT use these words: innovative, exciting, opportunity, passionate, synergy,`,
  `   leverage, disruptive, thrilled, keen, eager, groundbreaking, cutting-edge`,
  `3. Reference ONE specific thing from the company context — a product, technology,`,
  `   mission, or problem they're solving. Not just the company name.`,
  `4. Subject line: concise, specific, NOT "Internship Inquiry". Reference the company's work.`,
  `5. Open with Hi ${contactFirst}, — not Dear, not Hello`,
  `6. Sign off with: — Dhwanil Doshi, ECE (2nd year), SCET Surat`,
  `   Add one relevant project/interest if it fits naturally, don't force it`,
  `7. Do NOT promise things you can't deliver (equity, full-time conversion, etc.)`,
  `8. Do NOT mention grades, GPA, or academic performance`,
  ``,
  `VERSION A (Professional):`,
  `- 3-4 short paragraphs`,
  `- Opener references the specific company detail`,
  `- Second para: what you bring (concise, no fluff)`,
  `- Third para: what you're asking for`,
  `- Clean, confident, not sycophantic`,
  ``,
  `VERSION B (Casual):`,
  `- 2-3 short paragraphs or 1 paragraph + sign-off`,
  `- More direct, like texting a founder you met at a hackathon`,
  `- Same specific detail, different delivery`,
  `- Shorter than Version A`,
  ``,
  `Return ONLY valid JSON, no markdown, no explanation:`,
  `{`,
  `  "subject_a": "...",`,
  `  "body_a": "...",`,
  `  "subject_b": "...",`,
  `  "body_b": "..."`,
  `}`,
  ``,
  `IMPORTANT: Use actual newlines in the body strings (not \\n escape sequences).`,
  `The body will be written directly to a Google Sheet cell.`
].join('\n');
```

---

## OpenAI Request Parameters

```javascript
const aiRequest = {
  model: 'gpt-4o',
  messages: [
    { role: 'user', content: prompt }
  ],
  response_format: { type: 'json_object' },
  max_tokens: 1200,
  temperature: 0.9
};
```

| Parameter | Value | Why |
|-----------|-------|-----|
| `model` | `gpt-4o` | Best opener quality. Mini tested — noticeably worse at specific company hooks |
| `temperature` | `0.9` | Higher variance → more interesting subject lines and openers |
| `max_tokens` | `1200` | 600 per version at ~4 chars/token. Enough headroom |
| `response_format` | `json_object` | Forces structured output. No preamble text |

---

## Expected Output Format

GPT-4o should return exactly:

```json
{
  "subject_a": "Your distributed storage work at [Company] — internship ask",
  "body_a": "Hi Justin,\n\nSaw [Company]'s approach to cold storage replication...",
  "subject_b": "Quick ask — internship at [Company]",
  "body_b": "Hi Justin, cold-emailing because the data deduplication work..."
}
```

The Parse node in Phase 2 then:
1. Strips markdown fences if present
2. `JSON.parse()` the content
3. Maps fields to sheet columns: `subject_a → email_subject_A`, `body_a → email_body_A`, etc.
4. Strips leading formula injection characters from each field
5. Validates no `[` or `]` placeholders remain — if found, sets status to `error`

---

## Website Text Extraction (cleanText)

Before the prompt is built, a Code node scrapes the company website and extracts clean text:

```javascript
// Pseudo-code for text extraction
let html = httpResponseBody;
// Strip script and style tags
html = html.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
html = html.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');
// Strip all remaining HTML tags
let text = html.replace(/<[^>]+>/g, ' ');
// Collapse whitespace
text = text.replace(/\s+/g, ' ').trim();
// Cap at 3000 chars
text = text.substring(0, 3000);
```

This text becomes the `cleanText` variable injected into the prompt.

**Why 3000 chars?** More context → better emails. But GPT-4o charges per token, and 3000 chars is ~750 tokens — adding meaningful signal without meaningful cost.

---

## Tunable Parameters

These are the levers you can pull if output quality is unsatisfactory:

### Model
Change `gpt-4o` → `gpt-4o-mini` to reduce cost by ~10x. Acceptable for simpler companies. Noticeably worse for technical/niche startups where a specific detail needs to be surfaced.

### Temperature
- `0.7` → More consistent, more formulaic subject lines
- `0.9` → Default: interesting but occasionally weird
- `1.0` → Sometimes brilliant, sometimes off-topic

Start at 0.9. If emails feel samey, try 1.0. If emails feel off, try 0.8.

### cleanText cap
Currently 3000 chars. Increase to 5000 if you want more context (costs more). Decrease to 1500 if emails are too specific/verbose.

### max_tokens
1200 gives about 300 words per version with room to spare. Reduce to 800 if you want shorter emails by default (forces GPT to be more concise).

### Word count instruction
The prompt says "Max 200 words". Change this to control email length. 150 words → shorter, punchier. 250 words → more detailed but riskier for cold email.

---

## How to Iterate on This Prompt

When email quality drops (or was never great), iterate in this order:

**1. Check the input context first**
- Is `yc_description` actually useful? Some YC companies have one-liner descriptions that give GPT nothing to work with.
- Is `cleanText` populated? If the website scrape failed (403, JS-rendered page), GPT is flying blind.

**2. Read 3–5 outputs together**
Don't judge on one email. Read 5 consecutive outputs. Patterns will emerge: "GPT always opens with 'I came across'" or "Version B is always too short."

**3. Change one thing at a time**
Change the temperature, run again, compare. Change the banned word list, run again, compare. Don't change the whole prompt at once — you won't know what caused the improvement.

**4. Add a "good example" to the prompt**
GPT is highly sensitive to examples. Add:
```
Example of a good Version B subject: "Quick ask — [Company]'s storage replication"
Example of a good Version B opener: "Hi Justin, saw your approach to cold replication and had to reach out."
```
This single change can improve output quality more than any other prompt tweak.

**5. Tune the banned word list**
If new buzzwords keep appearing, add them. Current banned list:
```
innovative, exciting, opportunity, passionate, synergy, leverage, disruptive,
thrilled, keen, eager, groundbreaking, cutting-edge
```

**6. The nuclear option: few-shot examples**
Paste 2–3 actual emails that worked (got replies) as examples in the prompt. GPT will pattern-match to them heavily. Most impactful, most expensive in tokens.
