# LedgerShield MY

LedgerShield MY is a one-handed payment-triage demo built with Flutter. You swipe through 20 pending purchase-order items, hold up to 5 of them for review, and then see how your picks compare with the model's picks and with what actually happened.

## Running the app

On Chrome:

```
flutter run -d chrome
```

On the Android emulator:

1. Accept the Android licenses once: `flutter doctor --android-licenses`.
2. Launch the emulator: `flutter emulators --launch Pixel_6a`.
3. Wait until `flutter devices` lists it (cold boot can take up to a minute).
4. Run: `flutter run -d emulator-5554`.

The first Android build downloads Gradle and related artifacts, so do it once while online. If Gradle complains about the spaces in the project path, create a junction from PowerShell and build from there:

```
New-Item -ItemType Junction -Path D:\lsmy -Target "D:\HACKERDORM 26\PROJECT\LedgerShield MY\ledgershield_my"
```

## Honesty rules

These rules come from section 10 of the app spec and are reproduced verbatim:

- Held-out historical replay validates the forecasts. It does not prove real-world savings.
- Rule-derived exceptions are proxy outcomes, not confirmed fraud or realized losses.
- Values are transformed and shown in exposure units.
- The model does not make payment decisions. A human approves every action and the decision is logged.
- MyInvois rollout dates and thresholds must be checked against current LHDN guidance before the pitch.

## Sample data

`assets/data/batch.json` holds PLACEHOLDER sample data. Replace it with the model export before the event; the app reads the file at startup and shows a PLACEHOLDER badge on the Proof screen while every proof number is still zero.

## Fonts

Inter and JetBrains Mono are bundled under `assets/fonts/`. Both are licensed under the SIL Open Font License 1.1; the license texts are in the same folder and are registered on the in-app licenses page.
"# LedgerShieldMY" 
