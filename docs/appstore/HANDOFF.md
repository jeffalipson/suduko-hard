# Handoff: ship Really Really Hard Sudoku to the App Store

Repo: `/Users/jeffreylipson/suduko-hard` (GitHub: jeffalipson/suduko-hard, public).
Branch with everything: `appstore-prep` (PR #11 into `main`). Read `docs/appstore/listing.md` first.

## 1. Finish the puzzle library
Already committed on `appstore-prep`: 100 puzzles per Classic tier, Killer Easy–Fiendish 100 each, Killer Nightmare 80.
Only **Killer Diabolical** is short (20 in `App/Library/killer-diabolical.json`). A build of 60 was started into `$TMPDIR/biglib/killer-diabolical.json`:
- If that file exists and has more than 20 puzzles, copy it to `App/Library/`.
- Otherwise generate it (release build; ~4 min per puzzle, so 60 takes ~4 hours — it's fine to ship with fewer):
  ```bash
  swift build --package-path SudokuCore -c release
  SudokuCore/.build/release/sudoku-forge --mode killer --tier diabolical --count 60 --timeout 1800 \
    --out App/Library/killer-diabolical.json
  ```
- Check counts: `python3 -c "import json,glob; [print(f, len(json.load(open(f)))) for f in sorted(glob.glob('App/Library/*.json'))]"`.
- Commit on `appstore-prep`, push, then merge: `gh pr merge 11 --merge`.

## 2. Verify the web pages (GitHub Pages serves `docs/` on `main`)
- Privacy policy: https://jeffalipson.github.io/suduko-hard/appstore/privacy-policy.html
- Support: https://jeffalipson.github.io/suduko-hard/appstore/support.html
Both must load (Pages can take a few minutes after the merge).

## 3. Signing
- Find the Team ID (Xcode › Settings › Accounts, or ask the user). In `project.yml` under the `HardSudoku` target's `settings.base`, add `DEVELOPMENT_TEAM: <TEAMID>` and `CODE_SIGN_STYLE: Automatic`, then `xcodegen generate`.
- Bundle ID is `com.jeffreylipson.hardsudoku`. Automatic signing with `-allowProvisioningUpdates` registers it.
- Bump `CURRENT_PROJECT_VERSION` in `project.yml` for every upload.

## 4. Tests before shipping
```bash
swift test -c release --package-path SudokuCore
xcodebuild -project HardSudoku.xcodeproj -scheme HardSudoku -destination 'platform=iOS Simulator,name=iPhone 17' test CODE_SIGNING_ALLOWED=NO
```

## 5. App Store Connect app record (web, needs the user's login)
App Store Connect › Apps › + New App: iOS, name **Really Really Hard Sudoku** (fall back to a variant if taken, and tell the user), primary language English, bundle ID `com.jeffreylipson.hardsudoku`, SKU `hardsudoku`.

## 6. Archive and upload
```bash
xcodebuild -project HardSudoku.xcodeproj -scheme HardSudoku -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/HardSudoku.xcarchive archive -allowProvisioningUpdates
cat > build/ExportOptions.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
EOF
xcodebuild -exportArchive -archivePath build/HardSudoku.xcarchive -exportOptionsPlist build/ExportOptions.plist \
  -exportPath build/export -allowProvisioningUpdates
```
(Or open the archive in Xcode › Organizer › Distribute App.) Wait for processing, add the build to TestFlight internal testing, and have the user try it on their iPhone.

## 7. Listing (from `docs/appstore/listing.md`)
- Subtitle, promotional text, description, keywords, category Games › Puzzle, age rating questionnaire (all "None" → 4+), price.
- Screenshots: upload `docs/appstore/screenshots/*.png` (6.9", 1320×2868) in order 1–6.
- Privacy Policy URL and Support URL from step 2; App Privacy: **Data Not Collected**.
- Review notes from the listing. Export compliance is already answered in Info.plist.

## 8. Submit
Select the TestFlight-tested build, Add for Review, Submit. Report back the status and anything the user must decide (price, name fallback).
