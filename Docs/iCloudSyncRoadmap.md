# iCloud Sync Roadmap

## Current release policy

- The initial App Store release is local-only.
- `ContentView` must not call `UniexamCloudSync`.
- The Release configuration must not include the iCloud entitlement.
- Existing local persistence remains the source of truth.

## Local data that must survive a future update

- Universities and exam options: `uniexam.universities.v2`
- Legacy exam data: `uniexam.schools.v1`
- Mock exam results: `uniexam.mockExamResults.v1`
- User calendar events and custom colors through their existing persistence types
- Checklist items, links, scores, schedules, hidden state, and university colors embedded in those models

Do not rename or delete these keys without a tested migration.

## Future sync update

When iCloud sync is reintroduced:

1. Load all existing local data before starting any cloud operation.
2. Create an immutable local safety backup.
3. On the first sync, merge by stable IDs and upload local-only records.
4. Never treat an empty new device as a deletion of existing cloud data.
5. Keep local data usable when iCloud is unavailable or offline.
6. Add explicit conflict and deletion semantics before enabling sync in Release.
7. Deploy the CloudKit schema to Production before TestFlight or App Store testing.
8. Test fresh and existing installs with multiple Apple Accounts and two devices each.

An App Store update keeps the app container when the bundle identifier remains
`app.Iwasaki.Iwako.Uniexam`, so users of the initial local-only release can have
their existing data imported and uploaded by a later sync-enabled update. App
deletion removes the local container, so deleted apps cannot be migrated unless
the user has another backup.
