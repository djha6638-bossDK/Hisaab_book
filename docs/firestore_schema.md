# Firestore schema

All user-owned data is stored below `users/{uid}`. Firestore rules require the
authenticated UID to match `{uid}`.

## User profile

`users/{uid}`

- `uid`, `name`, `email`, `photoUrl`
- `createdAt`: set only when the profile is first created
- `lastLoginAt`: updated after each successful login

## Monthly records

`users/{uid}/monthlyRecords/{YYYY-MM}`

- `schemaVersion`: `4`
- `year`: integer
- `month`: integer from 1 through 12
- `monthName`: display-only month name
- `incomes`: array of `{name, amount}`
- `expenses`: array of `{name, amount, fromRecurringTemplate,
  assignedPersonId?, assignedPersonName?}`
- `totalIncome`, `totalExpenses`
- `createdAt`, `updatedAt`

Each monthly document is an independent snapshot. Updating a recurring template
does not modify an existing monthly record.

## Recurring expenses

`users/{uid}/recurringExpenses/{autoId}`

- `name`
- `defaultAmount`
- `isActive`
- `displayOrder`
- `updatedAt`

## Payment people

`users/{uid}/paymentPeople/{autoId}`

- `name`
- `updatedAt`

An expense without assigned-person fields belongs to `Self`. Monthly records
store both the person ID and a name snapshot so historical records remain
readable if the reusable people list changes later.

## Credit card entries

`users/{uid}/creditCardEntries/{autoId}`

- `type`: `spend` or `payment`
- `amount`: positive number
- `description`: what the money was spent on, or a payment note
- `date`: `YYYY-MM-DD`
- `year`, `month`, `day`: integer copies for reporting
- `createdAt`
- `updatedAt`

Spends and payments stay independent of monthly records and income. The
outstanding amount is calculated as total spends minus total payments.

## Existing-data migration

Older releases stored records in `users/{uid}/expenses/{Month_Year}` with
`totalBalance` and `expenses`. The repository reads these documents, converts
`totalBalance` into a legacy income entry, and writes the result to
`monthlyRecords/{YYYY-MM}`.
The legacy collection is read-only in the supplied security rules and can be
removed after all active users have opened the upgraded app and migration has
been audited.

The unused `items` and `months` collections are no longer read or written.
