# stts

macOS app that shows the status of various services in the menu bar.

## Workflow

- Run `swiftlint lint <file>` after every file change and fix all violations before finishing.

## Project structure

- `stts/Services/Super/` — base classes for each service platform (e.g. `BaseStatusPageService`, `BaseInstatusService`)
- `stts/Services/Generated/` — auto-generated Swift files (AWS, Adobe, Google Cloud, Sendbird, etc.)
- `stts/Services/<Category>/` — individual service definitions, one Swift file each
- `sttsTests/` — XCTest suite; test resources in `sttsTests/Resources/`
- `Resources/services.json` — JSON service definitions used by the stts3 branch

## Active branch work: stts3

`stts3` is an in-progress major refactor. Key changes vs `master`:

- Services defined in `Resources/services.json` instead of individual Swift files
- New preferences window (`PreferencesWindow/`, SwiftUI-based) with Services and General tabs
- Swift Concurrency (`async`/`await`) for status fetching
- `ServiceLoader` system with pluggable providers (`AppDefinedServiceDefinitionProvider`, `BundleServiceDefinitionProvider`, etc.)

### services.json format

Top-level keys are platform identifiers. Each value is an array of service entries.

| Key | Swift base class | ID field |
|---|---|---|
| `statuspage` | `BaseStatusPageService` | `statusPageID` → `id` |
| `instatus` | `BaseInstatusService` | — |
| `betteruptime` | `BaseBetterUptimeService` | — |
| `betterstack` | `BaseBetterStackService` | — |
| `incidentio` | `BaseIncidentIOService` | — |
| `statuscast` | `BaseStatusCastService` | — |
| `statusiov1` | `BaseStatusioV1Service` | `statusPageID` → `id` |
| `site24x7` | `BaseSite24x7Service` | `encryptedStatusPageID` → `id` |
| `sorry` | `BaseSorryService` | `pageID` → `id` |
| `statushub` | `BaseStatusHubService` | — |
| `lamb` | `BaseLambStatusService` | — |
| `statuscake` | `BaseStatusCakeService` | `publicID` → `id` |
| `cstate` | `BaseCStateService` | — |
| `statuspal` | `BaseStatuspalService` | — |
| `sendbird` | `BaseSendbirdService` | `statusPageID` → `id`, always `subservice: true` |

Common entry fields: `name`, `url`, `old_names` (Swift class name, for preference migration).
StatusPage entries may also have `host` (when `domain` is overridden in Swift).

### Validation

- `sttsTests/ServiceCountValidationTests.swift` — XCTest that compares Swift runtime counts vs JSON counts per category using `BaseService.all()`
  - `BaseSendbirdService` must be checked before `BaseStatusPageService` (it's a subclass)
  - Filters out `ServiceCategory` instances (`*All` aggregates) before grouping
