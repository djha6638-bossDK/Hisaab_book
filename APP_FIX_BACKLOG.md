# Hisaab Book - Fix Backlog

Created: July 27, 2026

This document records the agreed technical fixes for the current Hisaab Book
application. When the user asks to apply all fixes, this file is the source of
truth for the implementation scope.

## Session Recovery Protocol

Every future implementation session must read this file before changing code.
Work must continue from the first incomplete item in priority order unless a
dependency requires a different order.

Status format:

- `[ ]` means pending.
- `[ ] **IN PROGRESS:**` means implementation started but is not yet verified.
- `[x]` means implementation and its relevant verification are complete.

Required workflow for every fix:

1. Mark the selected item `IN PROGRESS` before editing implementation files.
2. Implement the fix without reverting unrelated user changes.
3. Run the relevant formatter, analyzer, tests, or build checks.
4. Mark the item complete immediately after verification.
5. Add a short entry to the Progress Log with the date, files changed, and
   verification performed.
6. If work is interrupted, leave the item marked `IN PROGRESS` and record the
   exact remaining work in the Progress Log so the next session can resume it.

## Progress Log

- August 8, 2026: Started the daily attendance flow redesign requested by the
  user. The remaining work is to add launch gating, persistent skip tracking,
  default-present backfill, and verification tests.
- August 8, 2026: Completed the daily attendance flow redesign. Added
  first-route launch gating, persistent per-user daily skip markers, default
  present backfill for missing dates, explicit absence overrides, and updated
  attendance/settings/report tests. Verification passed: `dart format`,
  `flutter analyze --no-pub`, and 40 automated tests.
- July 27, 2026: Implemented the application backlog across `lib/`, Android
  configuration, Firestore rules, schema/release documentation, and `test/`.
  Verification passed: `dart format`, `flutter analyze --no-pub`, 18 automated
  tests, Android debug APK build, and Android release APK build. Physical-device
  PDF intent checks and live release Google Sign-In/Firebase checks remain
  pending because they require a release keystore/SHA registration and device.
- July 27, 2026: Initial analysis and implementation backlog created. No
  application fixes have been implemented yet.

## P0 - Data Safety And Crashes

- [x] Replace the hardcoded default month and year with the current month and year.
- [x] Do not automatically copy every previous-month expense into a new month,
  because one-time expenses must not become recurring accidentally.
- [x] Automatically prefill active recurring expenses with their default amounts
  and include them in the new month's running balance calculation.
- [x] Provide an optional "Copy Previous Month" action that copies both expense
  names and amounts when the user explicitly chooses it.
- [x] Prevent duplicate rows when recurring expenses and copied previous-month
  expenses contain the same item.
- [x] Prevent invalid month/year combinations in Saved Data.
- [x] Generate a PDF only when the selected Firestore document actually exists.
- [x] Handle empty saved records without `firstWhere` or null assertion crashes.
- [x] Add input validation for income and expenses:
  - Required expense name for rows being saved.
  - Valid numeric amount.
  - Reject negative amounts unless a supported refund/adjustment feature exists.
  - Ignore completely empty rows.
- [x] Add proper error handling around login, Firestore reads/writes, logout, and PDF
  generation.
- [x] Prevent duplicate taps and repeated saves with loading states.
- [x] Check `mounted` before using `BuildContext` after asynchronous operations.

## P1 - Daily Attendance Flow

- [x] Open daily attendance before the home screen on the
  user's first app launch of each day, support skipping that day, and treat
  missing historical attendance as default-present while preserving explicit
  absence overrides.

## P1 - Data Model And Firestore

- [x] Store the complete income breakdown, not only the combined opening balance.
- [x] Use one consistent monthly collection and document ID format.
- [x] Remove or migrate the unused/inconsistent `items` and `months` collection code.
- [x] Define typed models for monthly records, income entries, and expense entries.
- [x] Add repository/service classes so screens do not access Firestore directly.
- [x] Preserve `createdAt` for a user instead of overwriting it on every login.
- [x] Track monthly record `createdAt` and `updatedAt` consistently.
- [x] Decide and implement an explicit overwrite/update policy for existing months.
- [x] Add and review Firestore security rules so each authenticated user can access
  only their own records.
- [x] Document the final Firestore schema and any migration needed for existing data.

## P1 - Monthly Entry Experience

- [x] Load an existing month directly in view mode and provide a reliable edit flow.
- [x] In edit mode, load the saved income breakdown and expenses together.
- [x] Add a dedicated Recurring Expenses management screen.
- [x] Allow each recurring expense to store:
  - Expense name.
  - Default monthly amount.
  - Active or inactive status.
  - Optional display order.
- [x] After the user enters monthly income, automatically add all active recurring
  expenses with their default amounts to the new monthly expense screen.
- [x] Keep recurring expense names and amounts editable for the current month.
- [x] Editing a recurring expense during monthly entry must not change its saved
  default unless the user explicitly chooses to update the recurring template.
- [x] Add an optional "Copy Previous Month" action for expenses that are not in the
  recurring list but need to be reused.
- [x] Let the user review copied expenses before saving the month.
- [x] Save every month as an independent snapshot. Later changes to a recurring
  expense must never modify previously saved monthly records.
- [x] Show opening income, total expenses, and final remaining balance.
- [x] Recalculate balances immediately and consistently after adding, editing, or
  removing a row.
- [x] Confirm before discarding unsaved changes.
- [x] Confirm before overwriting an existing monthly record.
- [x] Dispose every `TextEditingController` correctly.
- [x] Ensure adding and removing dynamic income/expense rows cannot corrupt state.

## P1 - Saved Data And PDF

- [x] Make month and year selection represent only real saved records.
- [x] Sort saved records chronologically.
- [x] Provide a clear view action for a selected record.
- [x] Generate reports with `MultiPage` or equivalent pagination so long expense
  lists do not overflow.
- [x] Include all saved income sources in the report.
- [x] Include opening balance, total income, total expenses, and closing balance.
- [x] Format Indian currency consistently.
- [x] Remove production `print` calls and surface useful user-facing errors.
- [ ] Verify PDF preview, print, share, and download behavior on Android.

## P1 - Android And Release Readiness

- [x] Add Android internet permission to the main manifest for release builds.
- [x] Replace debug signing with a proper release signing configuration before
  publishing.
- [ ] Verify Google Sign-In configuration, package name, and release SHA
  fingerprints.
- [ ] Verify Firebase works in release mode, not only debug mode.
- [x] Review app label, version, icon, and production identifiers.
- [x] Do not commit private signing keys or signing credentials.

## P2 - Architecture And Maintainability

- [x] Split the current large `main.dart` into focused files:
  - App initialization and theme.
  - Authentication.
  - Home/month selection.
  - Monthly entry.
  - Saved records.
  - Models.
  - Firebase repositories/services.
  - PDF service.
  - Shared widgets and utilities.
- [x] Remove dead code, unused variables, and unused dependencies.
- [x] Replace deprecated Flutter and PDF APIs.
- [x] Keep business calculations outside widgets and make them unit-testable.
- [x] Introduce consistent naming, formatting, and navigation patterns.
- [x] Add structured logging only where operationally useful.

## P2 - Testing And Verification

- [x] Replace the default counter widget test.
- [x] Add unit tests for:
  - Income and expense totals.
  - Running balance calculations.
  - Previous-month rollover, including January to December.
  - Recurring expense auto-fill and active/inactive behavior.
  - Copy-previous-month behavior, including duplicate prevention.
  - Protection of historical monthly snapshots when recurring defaults change.
  - Validation and empty-row filtering.
  - Firestore serialization and deserialization.
- [x] Add widget tests for:
  - Login and authentication states.
  - New monthly record flow.
  - Existing record view/edit flow.
  - Saved-record selection.
  - Error and loading states.
- [x] Mock Firebase dependencies in tests.
- [x] Add PDF generation tests for empty, normal, and long records.
- [x] Run and pass:
  - `flutter analyze`
  - `flutter test`
  - Android debug build
  - Android release build

## Completion Criteria

The full fix request is complete only when every criterion below is checked:

- [x] Existing supported user data remains readable or is safely migrated.
- [x] A user can create, view, edit, and export a monthly record without crashes.
- [x] Income and expense details remain accurate across app restarts.
- [x] Active recurring expenses prefill with their default amounts and are included
  in the monthly balance calculation.
- [x] Previous-month expenses are copied with their amounts only after an explicit
  user action.
- [x] One-time expenses do not become recurring automatically.
- [x] Changing recurring defaults does not alter previously saved months.
- [x] Saved Data cannot select a nonexistent record.
- [x] Long PDF reports paginate correctly.
- [ ] Firebase authentication and storage work in a release build.
- [x] Static analysis and the updated automated test suite pass.
