# App Store Connect Listing — Watt + Weight (en)

## Name
Watt + Weight

## Subtitle (max 30 characters)
(max. 30 characters — 30 used)

Routines & strength in one app

## Description (max 4000 characters)
(max. 4000 characters)

Watt + Weight is your strength training companion: it generates
automatic routines tailored to your level and goal, guides you set by
set through every workout, and tracks your progress over time.

KEY FEATURES

• Automatic routines — generate a complete routine based on your
experience level, goal (strength, hypertrophy, endurance), and days
available per week, or build your own exercise by exercise.

• Guided workout sessions — one exercise at a time, with a per-set
timer: start the set, mark it done, and an automatic rest period (90
seconds for compound exercises, 60 for isolation) tells you when to
continue. Adjust the number of sets on the fly.

• Progress tracking — charts for total volume, workout streak, and
max weight progress per exercise over time.

• Exercise catalog — over 140 exercises with instructions, the muscle
group worked, and tips for proper form.

• Health app integration — automatically import your weight, height,
date of birth, and biological sex from the Health app (optional, and
read-only — Watt + Weight never writes data back to Health).

• Complete, editable profile — sex, height, and weight editable at
any time, with support for metric (kg/cm) or imperial (lbs/ft) units.

• Multi-language — available in Spanish, English, and French.

• 100% private — all your personal data is stored only on your
device. No accounts, no ads, no third-party analytics.

Start your strength training routine with Watt + Weight today.

## Keywords
(max. 100 characters, comma-separated — no spaces after commas — 76 used)

gym,routine,strength,training,fitness,weights,muscle,workout,health,exercise

## Primary category
Health & Fitness

## Secondary category
Sports — optional, leave blank if App Store Connect only allows one

## Support contact (URL or email)
ldiego900@gmail.com

## Privacy policy URL
(fill in with the GitHub Pages URL once published — see docs/app-store/submission-checklist.md, step 1)

## Note for Apple's review team
("Notes" field in App Store Connect, not visible to the public)

Watt + Weight is a fully local app for user data: it has no server of
its own, sends no personal data to any backend, and uses no
third-party analytics SDKs. The only exception is that the demo
images in the exercise catalog are downloaded from a public, open
exercise database hosted on GitHub (identified only by the exercise
name, with no user data involved), and are cached locally after the
first download. The HealthKit permission is used only to READ weight,
height, date of birth, and biological sex when importing Health data
— the app never writes data back to Health
(`NSHealthUpdateUsageDescription` is declared because Apple requires
it, but there is no actual write in the code). The camera permission
is used only for the profile photo, saved as local `Data` on the
user's device. No test account is required — every feature is
accessible by creating a local profile directly in the app, with no
login.
