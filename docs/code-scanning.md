# Code-scanning coverage

## Investigation — October 2, 2026

Product Health Agent finding `dda81d3409313c6aaf47514a86dda3ef8994dbee1b4f64bd4db53dce85c656cc` belongs to `github.code_scanning@dsmithsalinas/NutriPulse`.

Read-only GitHub checks confirmed the repository is public, its default branch is `main`, and the code-scanning alerts API returns HTTP 404 with `no analysis found`. The only existing workflow was the legacy Pages redirect deployment. No code-scanning workflow existed. This establishes missing scan coverage, not a detected vulnerability or a product outage. The local GitHub CLI identity is separate from the production monitoring token; the latter must be checked again after analysis is available.

Public repositories are eligible for [GitHub code scanning](https://docs.github.com/en/code-security/reference/code-scanning/codeql/build-options-for-compiled-languages). This repository must not be classified as an unsupported private-repository capability.

## Proposed fix

`.github/workflows/codeql.yml` runs on main pushes, pull requests, manual dispatch, and weekly. Separate jobs analyze Swift, JavaScript/TypeScript, and Python. SQL, HTML/CSS, and shell are not additional CodeQL language targets.

Swift requires a macOS build. The workflow generates the ignored Xcode project from `project.yml`, copies only the non-secret configuration template, and builds the Footing scheme for the simulator without signing or launching the app. This includes the widget dependency. The other language jobs require no app build. No production credentials or service calls are required. Results upload to GitHub code scanning with a distinct category per language. Repository contents remain read-only; only security-event upload gets write permission.

## Activation and verification

This change is prepared locally, not activated. After approval, publish and merge the workflow. Confirm all three analysis jobs complete and each category appears in GitHub's analysis inventory on main. Then allow a normal Product Health Agent run to query the alert feed with its production token. An HTTP 200 with zero alerts establishes a successful empty feed; a 403/404 still needs investigation. Any actual alerts remain actionable.

Do not manually clear the existing finding, mark the feed unsupported, or treat a successful workflow alone as proof that monitoring access works. No application deployment, repository visibility change, plan change, or token-permission expansion is part of this fix. Existing Pages redirects are unchanged.

## Local validation

- `actionlint .github/workflows/codeql.yml`: passed.
- `xcodegen generate`: passed against the current main revision `74b0b8a`.
- The workflow's unsigned arm64 simulator `xcodebuild build` command: passed with local Xcode 27.0, including Footing and FootingWidgets. Only template configuration was used.
- Git whitespace validation: passed. Only the workflow and this document are new; generated project/build configuration remains ignored.

CodeQL extraction, query execution, and GitHub upload have not run. The hosted macOS runner's Xcode/CodeQL compatibility remains to be verified on activation; local build success does not prove scanning or connector recovery.

## Hosted validation follow-up

The first PR scan passed JavaScript/TypeScript and Python analysis/upload with zero results. Swift failed under hosted Xcode 26.6 because the large `TodayView.body` expression exceeded the compiler's type-checking limit (the local Xcode 27 build passed). The canvas and presentation chains are now separate computed view properties, preserving modifier order and behavior while bounding each type-checking expression. The unsigned local simulator build passes after that refactor. Package resolution now runs before CodeQL initialization; compilation remains traced.
