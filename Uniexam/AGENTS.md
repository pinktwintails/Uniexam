<!-- BEGIN:nextjs-agent-rules -->
# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.
<!-- END:nextjs-agent-rules -->

## Uniexam sample data

- Whenever a persisted input field is added, removed, renamed, or changes meaning in `UniversityChoice` or `ExamOption`, update `UniversityChoice.samples` in the same change.
- After changing the sample fixture content, increment `UniversityPersistence.currentSampleVersion` so untouched installed samples receive the update.
- Sample refreshes must never replace data that the user has edited or added.
