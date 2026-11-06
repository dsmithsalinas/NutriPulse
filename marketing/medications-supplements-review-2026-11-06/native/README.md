# Native medication flow validation

November 6, 2026. These are actual iPhone 17 Pro Simulator captures on iOS 26.5, using disposable accounts in the linked hosted project. They are separate from the generated concepts in the parent directory.

The complete UI test passed: sign in, Profile opt-in, create two routines with amounts and two dose times, selected weekdays, Taken/Skipped on Today, history correction, turn off from Today’s Manage sheet, relaunch with the off state preserved, re-enable, add another item, and mark it taken from the expanded OS notification.

| Screen | Capture |
| --- | --- |
| Profile enabled | [Profile](medications-profile-enabled.png) |
| Daily setup | [Vitamin D](medications-setup-Vitamin-D.png) |
| Selected weekday setup | [Magnesium](medications-setup-Magnesium.png) |
| Mixed completion | [Today](medications-today-complete-with-skip.png) |
| History | [History](medications-history.png) |
| Profile off with history retained | [Off state](medications-profile-off.png) |
| Expanded notification actions | [Notification](medications-notification-actions.png) |
| Completed after notification action | [Taken](medications-notification-taken.png) |

Eighteen distinct native XCTest cases passed across targeted runs: thirteen core cases, two hosted sync/category cases, one notification/queue case, and two existing Profile rendering cases including accessibility text size and device stack budget. The full UI flow and four database contract cases also passed. See [validation.json](validation.json) for sanitized results.

The hosted notification event was verified after the OS action. The native pending medication queue changed from 56 requests to 0 when disabled, then back to 56 when enabled; dose history stayed intact. Notification delivery for this UI check used `simctl push`; actual UserNotifications actions and the application handler performed the save. Locked-device, reboot, and unattended local delivery remain physical-device release checks.

The hosted migration is `20261106170529_medications_tracking.sql`. RLS is enabled and the save RPC uses invoker permissions. Disposable hosted accounts and their medication records were deleted after validation, and temporary credentials were removed. No personal account data was used for the medication checks.

## Running checks

Regenerate the project with `xcodegen generate`. Use normal simulator ad-hoc signing for signed-in tests; an unsigned simulator build cannot reliably use the app’s Keychain session. The core suite runs without hosted credentials:

```sh
xcodebuild -project Footing.xcodeproj -scheme Footing \
  -destination 'platform=iOS Simulator,name=Footing Medications QA' \
  -only-testing:FootingTests/MedicationTests \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
node --experimental-strip-types --test scripts/medications-db.contract.mts
```

Hosted and UI tests are opt-in and skip when the disposable fixture is absent. They expect a privately provisioned fixture at `/private/tmp/footing-medications-e2e/ios-credentials.json`; use newly created test accounts, never personal credentials. The UI routine uses 8 AM and 7 PM and should run before 7 PM local time on a selected weekday. Its notification step also requires a matching `simctl` payload after the `notification-ready` marker. The fixture and payload credentials are intentionally excluded from the repository.
