## Uniexam sample data

- Whenever a persisted input field is added, removed, renamed, or changes meaning in `UniversityChoice` or `ExamOption`, update `UniversityChoice.samples` in the same change.
- After changing the sample fixture content, increment `UniversityPersistence.currentSampleVersion` so untouched installed samples receive the update.
- Sample refreshes must never replace data that the user has edited or added.
