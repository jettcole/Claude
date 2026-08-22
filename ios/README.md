# Tallyroll for iOS

The native version: a real SwiftUI app that installs on the phone, with no
browser involved.

## The honest constraints

These come from Apple, not from the code:

- **An iOS app can only be compiled on macOS.** There is no way around this.
  What there *is* a way around is owning a Mac — `.github/workflows/ios.yml`
  builds and tests this project on GitHub's macOS machines on every push, so the
  code is verified without one.
- **Getting it onto a phone that has never been plugged into a computer requires
  an Apple Developer Program membership**, $99 a year. TestFlight then installs
  it over the air. The free Apple ID route needs a Mac or PC to sign the app
  every seven days, so it is not an option if a phone is all you have.

## Getting it on your phone

1. **Join the Apple Developer Program** — developer.apple.com, or the Apple
   Developer app on the phone. Approval usually takes a day or two.
2. **Create the app record** in App Store Connect with the bundle identifier
   from `project.yml` (`com.tallyroll.app`; change it if you like — it has to be
   unique across the App Store).
3. **Create an App Store Connect API key**: Users and Access → Integrations →
   App Store Connect API → "+", role **App Manager**. Download the `.p8`. Apple
   allows that download exactly once.
4. **Add four repository secrets** (Settings → Secrets and variables → Actions):
   `APPLE_TEAM_ID`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`,
   and `APP_STORE_CONNECT_PRIVATE_KEY` (the whole `.p8` text, BEGIN and END lines
   included).
5. **Run the TestFlight workflow** — Actions → TestFlight → Run workflow, giving
   a build number higher than the last one.
6. **Install TestFlight** on the phone from the App Store, sign in with the same
   Apple ID, and Tallyroll appears there.

Builds stay installable for 90 days. Re-run the workflow with a higher build
number to replace it. Putting it on the public App Store is the same build plus
App Review.

## Working on it without a Mac

Push to any `claude/**` branch or to `main` and the **iOS** workflow generates
the Xcode project, builds it, and runs the unit tests on a simulator. Compile
errors and test failures show up in the Actions log.

The tests cover the parts that lose money when they are wrong: cents arithmetic,
discount rounding and stacking, tax applied after discounts, the change owed,
what a completed sale records, voiding, and the CSV.

## If you do get to a Mac

```sh
brew install xcodegen
cd ios/Tallyroll
xcodegen generate
open Tallyroll.xcodeproj
```

The project file is generated from `project.yml` and is deliberately not
committed, which keeps merge conflicts out of a file nobody can read.

## Layout

```
project.yml                Project definition (XcodeGen builds the .xcodeproj)
Sources/Model/             Money, the data types, the till arithmetic, storage
Sources/Support/           Colours and type, CSV, camera, share sheet
Sources/Features/          One file per screen
Tests/                     Unit tests for everything that touches money
Resources/Assets.xcassets  App icon
```

Data lives in a JSON file in the app's own Documents directory, with item photos
as JPEGs beside it. Nothing leaves the phone. A backup file folds the photos in
as base64 so a restore on another phone is complete.
