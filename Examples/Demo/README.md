# Demo

A command-line app that exercises all six public SerpApi methods in sequence.

## Output

```
SerpApi Swift Demo
==================

1. Standard Search for 'Coffee' in 'Austin, TX'...
   Search ID: 6a26320c1f758a95b0ebee7d
   First Result: Coffee
   Link: https://en.wikipedia.org/wiki/Coffee

2. HTML Search for 'Coffee'...
   HTML received (length: 1648269 chars)

3. Markdown Search for 'Coffee'...
   Markdown received (length: 39950 chars)

4. Location API for 'Austin'...
   Found 3 locations:
   - Austin (ID: 585069b8ee19ad271e9ba949)
   - Austin (ID: 585069b1ee19ad271e9b8fe2)
   - Austin (ID: 585069afee19ad271e9b8550)

5. Account API...
   Account Email: your@email.com
   Plan: Free Plan

6. Async Search Submission...
   Submitted Async Search. ID: 6a26392bd355cc383c48938e
   (Waiting 2 seconds...)
   Fetching from Archive...
   Archive Status: Processing

Demo finished.
```

## What it demonstrates

1. **Search** — Google search with location (`q=Coffee`, `location=Austin, TX`)
2. **HTML search** — raw HTML output from the search engine
3. **Markdown search** — search results converted to Markdown, ready for LLMs / RAG pipelines
4. **Location API** — resolve location names to SerpApi location IDs
5. **Account API** — retrieve account info and plan details
6. **Async / Archive API** — submit a search with `async=true` and fetch results from the archive

## Run

```bash
SERPAPI_KEY=your_key swift run --package-path Examples/Demo
```

Or via Rake from the repo root:

```bash
SERPAPI_KEY=your_key rake demo
```

## Test

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Examples/Demo
```
