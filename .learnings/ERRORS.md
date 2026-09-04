# Errors

## [ERR-20260904-029] duplicate-update-file-patch-operation

**Logged**: 2026-09-04T13:40:45+08:00
**Priority**: low
**Status**: resolved
**Area**: frontend

### Summary
An apply patch payload declared the same file in two separate update operations.

### Error
`invalid patch: multiple operations target ... DashboardView.vue`

### Context
The intended script and template hunks were valid but had to share one Update File section. The tool rejected the patch before editing.

### Suggested Fix
Use one Update File declaration with multiple hunks for each target path.

### Metadata
- Reproducible: yes
- Related Files: apps/web-platform-admin/src/views/DashboardView.vue
- See Also: ERR-20260904-011

### Resolution
- **Resolved**: 2026-09-04T13:40:45+08:00
- **Notes**: Reissued as a single file operation.

---

## [ERR-039] docs-stale-search-backtick-quoting

**Logged**: 2026-09-04T15:22:31+08:00
**Priority**: low
**Status**: resolved
**Area**: documentation

### Summary
The first stale-string audit embedded Markdown backticks in a double-quoted zsh regular expression, so zsh treated parts of the search text as command substitutions.

### Error
`zsh:1: no such file or directory: 141252-five-ui-responsive-v4/public`

`zsh:1: command not found: 572143fb`

`zsh:1: command not found: |$`

### Context
The command failed before producing a trustworthy stale-content result and did not modify any files.

### Suggested Fix
Pass each `rg -e` pattern in single quotes and inspect the deployment table directly for expected rollback references.

### Metadata
- Reproducible: yes
- Related Files: ../askXuan-docs/docs/product/五端视觉回归与业务闭环用例.md
- Tags: docs, zsh, quoting

### Resolution
- **Resolved**: 2026-09-04T15:22:31+08:00
- **Notes**: Replaced the unsafe combined expression with separate single-quoted patterns.

---

## [ERR-20260904-028] shop-report-large-patch-tail-context

**Logged**: 2026-09-04T13:36:38+08:00
**Priority**: medium
**Status**: resolved
**Area**: frontend

### Summary
A large report-page patch failed because its final responsive-style context was inferred from a similar dashboard file rather than the target file.

### Error
`apply_patch verification failed: Failed to find expected lines ... @media (max-width: 767px)`

### Context
The target report ended after a 1200px media query, while the proposed patch expected a 767px block copied from the dashboard shape. No source change was applied.

### Suggested Fix
For large single-file rewrites, patch script state, template, and styles separately after reading the exact tail of the target file.

### Metadata
- Reproducible: yes
- Related Files: apps/web-shop-admin/src/views/ReportView.vue
- See Also: ERR-20260904-026, ERR-20260904-027

### Resolution
- **Resolved**: 2026-09-04T13:36:38+08:00
- **Notes**: Switched to exact, section-scoped patches.

---

## [ERR-20260904-027] h5-state-patch-context

**Logged**: 2026-09-04T13:25:21+08:00
**Priority**: low
**Status**: resolved
**Area**: frontend

### Summary
A combined H5 state-message patch used a parenthesized filter context that differed from the current source.

### Error
`apply_patch verification failed: Failed to find expected lines ... const filtered`

### Context
The edit combined three pages, so one stale context line rejected the whole patch before any change was applied.

### Suggested Fix
Inspect and patch each stateful page independently with exact local context.

### Metadata
- Reproducible: yes
- Related Files: apps/web-h5/src/routes/customer/Temples.tsx
- See Also: ERR-20260904-026

### Resolution
- **Resolved**: 2026-09-04T13:25:21+08:00
- **Notes**: Re-read the source region and split the patch by file.

---

## [ERR-20260904-026] h5-touch-audit-bulk-patch-context

**Logged**: 2026-09-04T12:59:41+08:00
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
A multi-file touch-target patch failed because one expected test-object field did not match the current source.

### Error
`apply_patch verification failed: Failed to find expected lines ... minimumHeight`

### Context
The patch combined the test helper and multiple UI files after inspecting only part of the helper. Patch verification failed before any file was modified.

### Suggested Fix
Read the full edit region first and split broad multi-file changes into smaller context-checked patches.

### Metadata
- Reproducible: yes
- Related Files: e2e/tests/web-h5.spec.ts
- See Also: ERR-20260904-011, ERR-20260904-013

### Resolution
- **Resolved**: 2026-09-04T12:59:41+08:00
- **Notes**: Re-read the full helper and continued with smaller patches.

---

## [ERR-20260904-025] platform-remote-font-screenshot-stall

**Logged**: 2026-09-04T10:16:00+08:00
**Priority**: medium
**Status**: resolved
**Area**: ui-runtime

### Summary
Platform-admin uniquely loaded Google Fonts from external origins, causing Chromium screenshots to stall while waiting for fonts in a restricted network environment.

### Error
`page.screenshot: Timeout 15000ms exceeded` with call log `waiting for fonts to load`.

### Context
The other two admin apps already relied on the shared system-font fallback stack and did not stall. The platform app's external font links were optional visual enhancements, not bundled dependencies.

### Suggested Fix
Do not block rendering on third-party font origins; use the established Chinese system-serif and system-sans fallback stacks unless fonts are self-hosted.

### Metadata
- Reproducible: yes when Google Fonts is unreachable
- Related Files: apps/web-platform-admin/index.html
- Tags: fonts, playwright, performance, availability

### Resolution
- **Resolved**: 2026-09-04T10:16:00+08:00
- **Notes**: Removed all Google Fonts preconnect and stylesheet tags; the shared local fallback stack remains active.

---

## [ERR-20260904-024] parallel-platform-screenshot-timeout

**Logged**: 2026-09-04T10:12:00+08:00
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
Running the 390px and 1440px admin suites together exhausted the 240-second per-test budget while both platform-admin cases captured many full-page screenshots.

### Error
`page.screenshot: Test timeout of 240000ms exceeded` in both platform-admin projects.

### Context
The temple and shop route suites plus all eligible populated mobile cases passed. The failures occurred during screenshot capture rather than a UI, network, console, or assertion failure.

### Suggested Fix
Run the platform-admin viewport projects serially when generating the complete per-route screenshot set, or split screenshot coverage into smaller tests before increasing the timeout.

### Metadata
- Reproducible: under concurrent screenshot load
- Related Files: e2e/tests/web-admin.spec.ts
- Tags: playwright, screenshots, timeout

### Resolution
- **Resolved**: 2026-09-04T10:12:00+08:00
- **Notes**: Classified as concurrent artifact-generation pressure and retried one viewport at a time.

---

## [ERR-20260904-023] playwright-local-server-sandbox

**Logged**: 2026-09-04T10:05:00+08:00
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
The first local admin regression run could not start its Vite web server because the workspace sandbox denied binding to localhost.

### Error
`Error: listen EPERM: operation not permitted 127.0.0.1:5273`

### Context
All three production builds had already passed; Playwright failed before loading application code or running an assertion.

### Suggested Fix
Re-run the same bounded Playwright command with approved local server and browser permissions.

### Metadata
- Reproducible: yes
- Related Files: e2e/playwright.config.ts
- Tags: playwright, vite, sandbox

### Resolution
- **Resolved**: 2026-09-04T10:05:00+08:00
- **Notes**: Classified as an environment restriction and retried with scoped elevated permissions.

---

## [ERR-20260904-022] ecs-public-navigation-race

**Logged**: 2026-09-04T09:40:00+08:00
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
The first no-credential ECS browser matrix had one 768px geometry read race with a client-side navigation.

### Error
`page.evaluate: Execution context was destroyed, most likely because of a navigation` occurred while measuring document width.

### Context
Seven of eight tests passed, and the failure happened before any assertion reported page overflow, console errors, server errors, or credential submission.

### Suggested Fix
Retry only the geometry read when Playwright explicitly reports a destroyed navigation context, waiting for the next DOM content state between attempts.

### Metadata
- Reproducible: intermittent
- Related Files: e2e/tests/web-public.spec.ts

### Resolution
- **Resolved**: 2026-09-04T09:40:00+08:00
- **Notes**: Added a bounded navigation-race retry without weakening layout assertions.

---

## [ERR-20260904-021] zsh-nested-quote-in-legacy-check

**Logged**: 2026-09-04T04:36:00+08:00
**Priority**: low
**Status**: resolved
**Area**: verification

### Summary
The first correction for the legacy-markup count overcomplicated nested quote escaping and produced an unmatched quote.

### Error
zsh stopped with `unmatched quote` before running ripgrep.

### Context
This was a read-only count; source and deployment state were unchanged.

### Suggested Fix
Avoid matching exact quote characters when a simple wildcard character can express the same local source pattern.

### Metadata
- Reproducible: yes
- Related Files: apps/web-h5/src/routes

### Resolution
- **Resolved**: 2026-09-04T04:36:00+08:00
- **Notes**: Replaced nested quote construction with a literal single-quoted expression using `.` for the quote character.

---

## [ERR-20260904-020] zsh-regex-glob-in-legacy-check

**Logged**: 2026-09-04T04:35:00+08:00
**Priority**: low
**Status**: resolved
**Area**: verification

### Summary
The final legacy-markup count used an incorrectly escaped regular expression that zsh attempted to expand as a filename glob.

### Error
The shell reported `no matches found` for the `className` expression, so that individual count was invalid.

### Context
The shared-component check, API audit, diff checks, ECS soft link, service health, and file hash in the same verification stage were unaffected.

### Suggested Fix
Pass the complete ripgrep expression as a single-quoted argument and inspect its explicit count.

### Metadata
- Reproducible: yes
- Related Files: apps/web-h5/src/routes

### Resolution
- **Resolved**: 2026-09-04T04:35:00+08:00
- **Notes**: Re-ran the count with literal quoting and required a zero result.

---

## [ERR-20260904-019] curl-missing-from-shell-path

**Logged**: 2026-09-04T04:33:00+08:00
**Priority**: low
**Status**: resolved
**Area**: deployment-verification

### Summary
The post-deploy public probe loop could not resolve `curl` from the managed shell PATH.

### Error
Each read-only probe returned `zsh: command not found: curl` before making a request.

### Context
Remote file hashes and service health checks in the parallel batch still completed successfully.

### Suggested Fix
Use the macOS system executable `/usr/bin/curl` for deployment probes in this environment.

### Metadata
- Reproducible: yes
- Related Files: none

### Resolution
- **Resolved**: 2026-09-04T04:33:00+08:00
- **Notes**: Re-ran the public checks with the absolute executable path.

---

## [ERR-20260904-018] h5-320-multi-action-wrap

**Logged**: 2026-09-04T05:24:00+08:00
**Priority**: medium
**Status**: resolved
**Area**: responsive-layout

### Summary
The five-viewport H5 regression found that a multi-button bottom action bar wrapped at 320px and grew beyond the shared clearance spacer.

### Error
Rendered action height was 110px while the shared spacer was 96px; the other four H5 widths passed.

### Context
Action buttons inherited flexible widths but allowed Chinese labels to wrap on the narrowest supported viewport.

### Suggested Fix
Give bottom-action children `min-width: 0`, keep action labels on one line, tighten ultra-narrow spacing, and retain a conservative shared spacer.

### Metadata
- Reproducible: yes
- Related Files: apps/web-h5/src/theme/ui.css, e2e/tests/web-h5.spec.ts

### Resolution
- **Resolved**: 2026-09-04T05:24:00+08:00
- **Notes**: Added narrow-screen action sizing and raised the spacer to 112px plus safe-area inset.

---

## [ERR-20260904-017] h5-bottom-action-spacer-height

**Logged**: 2026-09-04T05:16:00+08:00
**Priority**: medium
**Status**: resolved
**Area**: responsive-layout

### Summary
The new geometry regression found the shared H5 bottom-action spacer was four pixels shorter than the rendered booking action bar.

### Error
At the 390px viewport the action bar was 76px high while the spacer was 72px.

### Context
Existing page padding happened to keep the current booking content visible, but the component could not guarantee clearance independently.

### Suggested Fix
Keep the shared spacer at least as tall as the largest one-row action bar and verify it from rendered geometry.

### Metadata
- Reproducible: yes
- Related Files: apps/web-h5/src/theme/ui.css, e2e/tests/web-h5.spec.ts

### Resolution
- **Resolved**: 2026-09-04T05:16:00+08:00
- **Notes**: Raised the shared spacer to 96px plus safe-area inset.

---

## [ERR-20260904-016] playwright-cli-resolved-from-parent

**Logged**: 2026-09-04T05:14:00+08:00
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
Running `npx playwright test` from the frontend parent resolved a different CLI because the parent has no package manifest or local Playwright test binary.

### Error
The command returned `unknown command 'test'` before starting a browser or test server.

### Context
The intended `@playwright/test` dependency and script are scoped to the `e2e` package.

### Suggested Fix
Use `npm --prefix e2e run test:web -- ...` from the frontend parent, or run the local binary from `e2e`.

### Metadata
- Reproducible: yes
- Related Files: e2e/package.json

### Resolution
- **Resolved**: 2026-09-04T05:14:00+08:00
- **Notes**: Switched to the package-scoped test script.

---

## [ERR-20260904-015] h5-timeline-field-mismatch

**Logged**: 2026-09-04T05:10:00+08:00
**Priority**: low
**Status**: resolved
**Area**: build

### Summary
The next H5 build found that the migrated booking timeline still used its legacy `time` field instead of the shared component's `detail` field.

### Error
`TS2353` and `TS2339` reported the unsupported `time` property.

### Context
The first fix constrained the array type and thereby exposed the remaining schema mismatch.

### Suggested Fix
Map legacy timeline models completely to the shared `ProcessTimelineStep` contract before building.

### Metadata
- Reproducible: yes
- Related Files: apps/web-h5/src/routes/master/BookingDetail.tsx

### Resolution
- **Resolved**: 2026-09-04T05:10:00+08:00
- **Notes**: Renamed `time` to `detail` and passed the typed steps directly.

---

## [ERR-20260904-014] h5-timeline-state-inference

**Logged**: 2026-09-04T05:09:00+08:00
**Priority**: low
**Status**: resolved
**Area**: build

### Summary
The H5 build rejected a migrated timeline because TypeScript widened its state values to `string`.

### Error
`TS2322` reported that the generated step array was not assignable to `ProcessTimelineStep[]`.

### Context
The UI states were valid literals, but the intermediate array had no explicit shared-component type.

### Suggested Fix
Annotate timeline arrays with `ProcessTimelineStep[]` whenever conditional expressions construct the state field.

### Metadata
- Reproducible: yes
- Related Files: apps/web-h5/src/routes/master/BookingDetail.tsx

### Resolution
- **Resolved**: 2026-09-04T05:09:00+08:00
- **Notes**: Added the shared step type to the array declaration.

---

## [ERR-20260904-013] h5-flow-nav-bulk-patch-context

**Logged**: 2026-09-04T05:05:00+08:00
**Priority**: low
**Status**: resolved
**Area**: refactor

### Summary
A multi-file H5 navigation migration patch did not apply because one chat page used a different import shape than the assumed context.

### Error
`apply_patch verification failed` while matching the customer chat imports; the patch was rejected before any file changed.

### Context
The attempted patch mixed standard headers with chat-specific and editor-specific header variants across eleven files.

### Suggested Fix
Inspect each variant first and apply smaller patches grouped by exact structure.

### Metadata
- Reproducible: yes
- Related Files: apps/web-h5/src/routes/customer/ChatDetail.tsx

### Resolution
- **Resolved**: 2026-09-04T05:06:00+08:00
- **Notes**: Split the migration into exact per-variant patches.

---

## [ERR-20260814-001] mobile-customer-build-script

**Logged**: 2026-08-14T00:48:00+08:00
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
The Expo fallback client has no `build` script.

### Error
`npm run build` returned `Missing script: "build"` in `apps/mobile-customer`.

### Context
The repository-wide client regression loop assumed every package used the Web build contract.

### Suggested Fix
Use `npm run lint` for the Expo TypeScript compile check and reserve `npm run build` for the Web and Mock packages.

### Metadata
- Reproducible: yes
- Related Files: apps/mobile-customer/package.json

---

## [ERR-20260904-012] element-plus-upload-error-type

**Logged**: 2026-09-04T04:32:00+08:00
**Priority**: low
**Status**: resolved
**Area**: build

### Summary
The shared uploader forwarded a generic `Error` to Element Plus, whose callback type requires `UploadAjaxError` metadata.

### Error
`Argument of type 'Error' is not assignable to parameter of type 'UploadAjaxError'`

### Context
The actual rejection may originate from Axios or response validation and cannot truthfully provide Element Plus transport metadata.

### Suggested Fix
Keep the original runtime error and use a localized boundary cast at the third-party callback, matching the existing app adapters.

### Metadata
- Reproducible: yes
- Related Files: askXuan-frontend/packages/admin-ui/components/ImageUploader.vue
- Tags: typescript, element-plus, upload

### Resolution
- **Resolved**: 2026-09-04T04:33:00+08:00
- **Notes**: Cast only at `options.onError`; all internal handling remains typed as unknown.

---

## [ERR-20260904-011] malformed-multi-file-patch-hunk

**Logged**: 2026-09-04T04:28:00+08:00
**Priority**: low
**Status**: resolved
**Area**: tooling

### Summary
A multi-file patch mixed a new file and an update hunk without closing the update hunk correctly.

### Error
`apply_patch verification failed: invalid hunk`

### Context
No file was changed by the rejected patch.

### Suggested Fix
Split large add-file and update-file operations into separate patches and validate each patch boundary.

### Metadata
- Reproducible: yes
- Tags: apply-patch, tooling

### Resolution
- **Resolved**: 2026-09-04T04:29:00+08:00
- **Notes**: Applied the new file and follow-up updates in two valid patches.

---

## [ERR-20260904-010] sync-script-relative-to-wrong-cwd

**Logged**: 2026-09-04T04:20:00+08:00
**Priority**: low
**Status**: resolved
**Area**: build

### Summary
The shared-component sync command was invoked from an app directory with the repository-root path spelling.

### Error
`Cannot find module '.../apps/web-temple-admin/scripts/sync-admin-ui-components.mjs'`

### Context
The script lives at the frontend repository root; app package scripts correctly use `../../scripts/...`.

### Suggested Fix
Run `node scripts/...` from the frontend root or `node ../../scripts/...` from an admin app.

### Metadata
- Reproducible: yes
- Related Files: askXuan-frontend/scripts/sync-admin-ui-components.mjs
- Tags: node, cwd, build

### Resolution
- **Resolved**: 2026-09-04T04:21:00+08:00
- **Notes**: Re-ran from the frontend root, then built the app normally.

---

## [ERR-20260904-009] shared-vue-sfc-outside-app-include

**Logged**: 2026-09-04T04:12:00+08:00
**Priority**: medium
**Status**: resolved
**Area**: build

### Summary
All three admin `vue-tsc` builds treated shared Vue SFC templates as `{}` because the new package source lived outside each app's TypeScript include set.

### Error
`Property 'title' does not exist on type '{}'` and equivalent template errors for every shared component binding.

### Context
The components were imported through thin compatibility modules, but each app only included its local `src/**/*.vue` files.

### Suggested Fix
Do not type-check cross-root SFC files directly in these three standalone projects. Keep canonical SFCs in the shared package, generate byte-identical local mirrors, and make each build run a synchronization check.

### Metadata
- Reproducible: yes
- Related Files: askXuan-frontend/apps/web-*/tsconfig.json
- Tags: vue, typescript, shared-components

### Resolution
- **Resolved**: 2026-09-04T04:15:00+08:00
- **Notes**: Direct cross-root inclusion still produced empty template instance types. Replaced it with a canonical-package plus checked generated-mirror workflow; every app now type-checks the same component source locally.

---

## [ERR-20260904-001] web-shop-admin-build

**Logged**: 2026-09-04T01:24:00+08:00
**Priority**: low
**Status**: resolved
**Area**: frontend

### Summary
Replacing numeric dashboard defaults with an em dash narrowed the inferred metric value type to string.

### Error
`vue-tsc` reported `Type 'number' is not assignable to type 'string'` when real API values were assigned.

### Context
The UI rewrite changed failed and unloaded metrics from misleading zero values to `—`, while the same reactive array still receives numeric API values after loading.

### Suggested Fix
Declare dashboard metric models explicitly with `value: string | number` whenever the unloaded state uses a textual placeholder.

### Metadata
- Reproducible: yes
- Related Files: apps/web-shop-admin/src/views/DashboardView.vue

### Resolution
- **Resolved**: 2026-09-04T01:25:00+08:00
- **Notes**: Added an explicit typed metric array accepting both placeholders and numeric values.

---

## [ERR-20260904-002] ecs-inspection-command

**Logged**: 2026-09-04T03:20:00+08:00
**Priority**: medium
**Status**: resolved
**Area**: deployment

### Summary
An ECS pre-deployment inspection command ran locally because the explicit SSH invocation was omitted.

### Error
The output showed the local hostname and reported `/var/www/askxuan` as missing.

### Context
The command declared an approved SSH prefix for escalation, but an approval rule does not wrap or transform the command itself.

### Suggested Fix
Start every remote command with an explicit `ssh -o BatchMode=yes -o ConnectTimeout=10 root@101.96.228.71` invocation and verify the returned hostname before using the evidence.

### Metadata
- Reproducible: yes
- Related Files: none

### Resolution
- **Resolved**: 2026-09-04T03:21:00+08:00
- **Notes**: Corrected the command and treated the local output as invalid evidence.

---

## [ERR-20260904-003] zsh-special-parameter-health-check

**Logged**: 2026-09-04T02:59:00+08:00
**Priority**: low
**Status**: resolved
**Area**: deployment

### Summary
The ECS health-check script reused zsh special parameters as ordinary variable names.

### Error
Using `path` removed command lookup for the loop body, and assigning `status` failed because it is read-only in zsh.

### Context
The first root URL request completed, but later route and WASM checks stopped before making their requests. No server state was changed.

### Suggested Fix
Use task-specific names such as `route_path` and `http_code`, or run portable health scripts under an explicitly selected shell.

### Metadata
- Reproducible: yes
- Related Files: none

### Resolution
- **Resolved**: 2026-09-04T02:59:00+08:00
- **Notes**: Renamed both variables and reran the full checks successfully.

---

## [ERR-20260904-004] frontend-contract-search-quoting

**Logged**: 2026-09-04T03:05:00+08:00
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
A shell regex for TypeScript API calls contained a raw backtick and failed before scanning.

### Error
zsh reported `unmatched "` while parsing the command.

### Context
The attempted one-off search mixed shell quoting with JavaScript template-literal syntax. It made no file or runtime changes.

### Suggested Fix
Use the TypeScript parser for endpoint extraction instead of shell regexes that must quote template literals.

### Metadata
- Reproducible: yes
- Related Files: scripts/audit-web-api-contracts.mjs

### Resolution
- **Resolved**: 2026-09-04T03:10:00+08:00
- **Notes**: Added a reusable AST-based frontend-to-backend contract auditor.

---

## [ERR-20260904-005] go-test-cache-sandbox

**Logged**: 2026-09-04T03:11:00+08:00
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
The booking-service test run could not read the macOS Go build cache inside the workspace sandbox.

### Error
`go test ./...` reported `operation not permitted` for files under `Library/Caches/go-build`.

### Context
Formatting completed before the test command reached the sandbox-restricted cache.

### Suggested Fix
Run Go tests with the approved `go test` execution scope when the standard build cache is outside writable roots.

### Metadata
- Reproducible: yes
- Related Files: services/content/booking-service/internal/logic/adminreviewdetail_test.go

### Resolution
- **Resolved**: 2026-09-04T03:12:00+08:00
- **Notes**: Re-ran the same test suite with cache access; all booking-service packages passed.

---

## [ERR-20260904-006] remote-compose-secret-output

**Logged**: 2026-09-04T03:13:00+08:00
**Priority**: medium
**Status**: resolved
**Area**: security

### Summary
A broad remote compose-file preview included an existing database credential field in diagnostic output.

### Error
The requested line range crossed from deployment metadata into the infrastructure environment block.

### Context
The value was only read from ECS and was not copied into source files, reports, or the final response.

### Suggested Fix
Inspect compose labels, service names, and exact keyed blocks without printing neighboring environment sections; never dump broad compose ranges during deployment discovery.

### Metadata
- Reproducible: yes
- Related Files: none

### Resolution
- **Resolved**: 2026-09-04T03:13:00+08:00
- **Notes**: Subsequent remote checks use container labels and exact non-secret fields only.

---

## [ERR-20260904-007] playwright-listen-sandbox

**Logged**: 2026-09-04T03:18:00+08:00
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
The final Playwright matrix could not start its local Vite servers inside the workspace sandbox.

### Error
The first server failed with `listen EPERM: operation not permitted 127.0.0.1:5273`.

### Context
The test suite requires five loopback listeners and a browser process; no test case had started when the sandbox blocked the server.

### Suggested Fix
Run the approved `npx playwright test` command with local listener and browser permissions.

### Metadata
- Reproducible: yes
- Related Files: e2e/playwright.config.ts

### Resolution
- **Resolved**: 2026-09-04T03:22:00+08:00
- **Notes**: The same full matrix completed with 30 passed, 20 expected conditional skips, and 0 failures.

---

## [ERR-030] admin-acceptance-playwright-listen-sandbox

**Logged**: 2026-09-04T14:03:00+08:00
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
The targeted admin acceptance suite could not start its first local Vite server inside the workspace sandbox.

### Error
`listen EPERM: operation not permitted 127.0.0.1:5273`

### Context
The new mobile chart, partial-failure, and high-risk confirmation tests had not started; no application or test state was changed.

### Suggested Fix
Run the same scoped Playwright command with approved local listener and browser permissions.

### Metadata
- Reproducible: yes
- Related Files: e2e/playwright.config.ts, e2e/tests/web-admin.spec.ts
- Tags: playwright, tests, sandbox

### Resolution
- **Resolved**: 2026-09-04T14:04:00+08:00
- **Notes**: Re-ran the same targeted suite with approved local listener and browser permissions.

---

## [ERR-031] shop-report-incomplete-response-shape

**Logged**: 2026-09-04T14:06:00+08:00
**Priority**: medium
**Status**: resolved
**Area**: ui

### Summary
The shop report accepted an HTTP-success response with missing trend arrays and rendered a JavaScript error message instead of a controlled failure state.

### Error
`Cannot read properties of undefined (reading 'length')`

### Context
The route matrix's generic API fixture intentionally omitted report-specific fields, exposing that the page validated transport success but not the report contract shape.

### Suggested Fix
Validate required numeric fields and arrays before assigning the report to render state; route malformed responses through the existing explicit error state.

### Metadata
- Reproducible: yes
- Related Files: apps/web-shop-admin/src/views/ReportView.vue
- Tags: report, contract, error-state

### Resolution
- **Resolved**: 2026-09-04T14:07:00+08:00
- **Notes**: Added structural validation before rendering the report.

---

## [ERR-032] element-plus-select-placeholder-locator

**Logged**: 2026-09-04T14:06:00+08:00
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
The shipping confirmation test located an Element Plus select by visible placeholder text, but the actual combobox exposed the form label as its accessible name.

### Error
`TimeoutError: waiting for getByPlaceholder('请选择快递公司')`

### Context
The dialog snapshot showed an accessible combobox named `快递公司`; the placeholder was rendered by a sibling element rather than as the input placeholder.

### Suggested Fix
Prefer the accessible combobox role and form-label name for Element Plus selects.

### Metadata
- Reproducible: yes
- Related Files: e2e/tests/web-admin.spec.ts
- Tags: playwright, locator, accessibility

### Resolution
- **Resolved**: 2026-09-04T14:07:00+08:00
- **Notes**: Replaced the placeholder locator with `getByRole('combobox', { name: '快递公司' })`.

---

## [ERR-033] element-plus-readonly-combobox-click

**Logged**: 2026-09-04T14:08:00+08:00
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
The accessible combobox input was found, but Element Plus renders it read-only beneath a visible placeholder that intercepts pointer events.

### Error
`el-select__placeholder ... intercepts pointer events`

### Context
The shipping dialog itself was visible and usable; only the test clicked the hidden interaction layer rather than the visible trigger text.

### Suggested Fix
Click the visible select placeholder or wrapper for this Element Plus version, then choose the listbox option by accessible text.

### Metadata
- Reproducible: yes
- Related Files: e2e/tests/web-admin.spec.ts
- Tags: playwright, element-plus, locator

### Resolution
- **Resolved**: 2026-09-04T14:09:00+08:00
- **Notes**: Changed the trigger to the visible `请选择快递公司` text.

---

## [ERR-034] admin-matrix-body-visibility-flake

**Logged**: 2026-09-04T14:10:00+08:00
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
The five-viewport admin matrix used document `body` visibility as its route-ready assertion and produced a transient false negative under parallel navigation.

### Error
`locator('body') expected visible, received hidden`

### Context
The failure snapshot contained the complete coupon-management page and all other platform viewports passed. The body element is a document container, not the user-visible route landmark.

### Suggested Fix
Assert the visible `main` landmark for authenticated routes, while retaining body text checks for runtime errors.

### Metadata
- Reproducible: intermittent
- Related Files: e2e/tests/web-admin.spec.ts
- Tags: playwright, flake, route-ready

### Resolution
- **Resolved**: 2026-09-04T14:11:00+08:00
- **Notes**: Replaced the document-container visibility assertion with the visible `main` landmark.

---

## [ERR-035] ecs-health-check-https-redirect

**Logged**: 2026-09-04T14:18:54+08:00
**Priority**: low
**Status**: resolved
**Area**: deployment

### Summary
The first post-deployment health script required the initial HTTP response to be 200 even though ECS correctly redirects all HTTP traffic to HTTPS.

### Error
All checked routes returned the expected first-hop status `301`, causing the script's exact-200 assertion to exit nonzero.

### Context
The response pattern was uniform across health, app routes, logos, and WASM assets. No ECS state changed during the read-only check.

### Suggested Fix
Follow the production redirect and assert the final HTTPS status, while retaining the first-hop redirect as separate transport evidence.

### Metadata
- Reproducible: yes
- Related Files: none
- Tags: deployment, health-check, https

### Resolution
- **Resolved**: 2026-09-04T14:19:00+08:00
- **Notes**: Re-ran the checks with redirect following and validated final responses.

---

## [ERR-036] ecs-large-wasm-full-download-probe

**Logged**: 2026-09-04T14:26:40+08:00
**Priority**: low
**Status**: resolved
**Area**: deployment

### Summary
The redirected health loop downloaded the complete OpenIM WASM binary and hit its 30-second transfer timeout after all page routes had already passed.

### Error
`curl: (28) Operation timed out after 29899 milliseconds with 360448 out of 37763413 bytes received`

### Context
The probe was intended to verify availability only. Downloading a 37.8 MB static asset was unnecessary and did not indicate an application failure.

### Suggested Fix
Use redirected HEAD requests for large static assets and record status, content type, and content length without downloading their bodies.

### Metadata
- Reproducible: yes
- Related Files: none
- Tags: deployment, curl, wasm

### Resolution
- **Resolved**: 2026-09-04T14:27:00+08:00
- **Notes**: Replaced full-body static probes with HEAD checks.

---

## [ERR-037] ecs-public-matrix-parallel-transfer-timeout

**Logged**: 2026-09-04T14:36:00+08:00
**Priority**: medium
**Status**: resolved
**Area**: tests

### Summary
The first v4 public browser matrix ran four viewport projects concurrently; all login groups stalled at the shop login while concurrently loading the management bundles over the public link.

### Error
Three projects timed out navigating to `/shop/login`; one loaded the document but did not mount `.login-page` before the assertion timeout.

### Context
All four public H5 route groups passed in the same run. Direct static-resource probes were 200, and a single-worker five-login replay passed in 15.4 seconds, identifying concurrent transfer pressure rather than a deterministic application defect.

### Suggested Fix
Run the production public acceptance matrix with one worker so each viewport measures an ordinary single-user navigation path while retaining all HTTP, console, image, overflow, and credential-safety assertions.

### Metadata
- Reproducible: under four concurrent public projects
- Related Files: e2e/playwright.public.config.ts, e2e/tests/web-public.spec.ts
- Tags: playwright, deployment, network, concurrency

### Resolution
- **Resolved**: 2026-09-04T14:45:27+08:00
- **Notes**: The full eight-test public matrix passed with one worker in 2.2 minutes; no assertion was relaxed.

---

## [ERR-038] v5-extract-command-corrupted-body

**Logged**: 2026-09-04T15:00:00+08:00
**Priority**: medium
**Status**: resolved
**Area**: deployment

### Summary
The first v5 extraction command contained unintended placeholder tokens after creating the empty release directory and stopped before extracting files or switching the current symlink.

### Error
`bash: line 4: tarнице=unused: command not found`

### Context
The exact v5 release directory was created but remained empty. The active ECS frontend stayed on v4 and no existing release was modified.

### Suggested Fix
Inspect the exact target directory, confirm it is empty, then rerun a minimal extraction command with only validated shell statements.

### Metadata
- Reproducible: no
- Related Files: none
- Tags: deployment, ssh, command-construction

### Resolution
- **Resolved**: 2026-09-04T15:01:00+08:00
- **Notes**: Confirmed the directory was empty and reran the extraction using a minimal validated command.

---

## [ERR-040] github-remote-check-sandbox-dns

**Logged**: 2026-09-04T16:05:00+08:00
**Priority**: low
**Status**: resolved
**Area**: infra

### Summary
Live `git ls-remote` verification for the four AskXuan repositories failed because the default sandbox could not resolve `github.com`.

### Error
```
ssh: Could not resolve hostname github.com: -65563
fatal: unable to access 'https://github.com/...': Could not resolve host: github.com
```

### Context
- The local branch, HEAD, upstream, and dirty-file checks completed successfully.
- Only the live remote comparison failed; no repository data was changed.

### Suggested Fix
Rerun the same read-only `git ls-remote` checks with approved network access.

### Metadata
- Reproducible: yes
- Related Files: none
- Tags: git, github, dns, sandbox

### Resolution
- **Resolved**: 2026-09-04T16:18:00+08:00
- **Notes**: Retried `git fetch origin` for all four repositories with approved network access; every fetch completed successfully.

---

## [ERR-041] ecs-readonly-ssh-sandbox-denied

**Logged**: 2026-09-04T16:08:00+08:00
**Priority**: low
**Status**: resolved
**Area**: infra

### Summary
The first read-only ECS deployment audit was blocked locally before SSH connected.

### Error
```
ssh: connect to host 101.96.228.71 port 22: Operation not permitted
```

### Context
- The command only requested frontend symlink, Nginx validation, container status, and gateway health.
- No ECS command executed and no remote state changed.

### Suggested Fix
Rerun the exact read-only audit with approved network access.

### Metadata
- Reproducible: under the default sandbox
- Related Files: none
- Tags: ecs, ssh, sandbox, deployment-audit

### Resolution
- **Resolved**: 2026-09-04T16:11:00+08:00
- **Notes**: The same read-only audit succeeded with approved network access; five frontend routes, Nginx, Compose containers, and gateway health were verified.

---

## [ERR-042] ecs-audit-remote-awk-quoting

**Logged**: 2026-09-04T16:10:00+08:00
**Priority**: low
**Status**: resolved
**Area**: infra

### Summary
Nested single quotes around a remote `awk` expression broke the local SSH command and exposed regex pipe characters to zsh.

### Error
```
zsh:1: no such file or directory: Dead/
zsh:1: command not found: Exited
zsh:1: command not found: Restarting
zsh:1: command not found: Created
```

### Context
- The malformed command stopped locally before the ECS audit ran.
- No remote state was changed.

### Suggested Fix
Return raw `docker ps` status lines and classify them locally instead of nesting `awk` inside the SSH command.

### Metadata
- Reproducible: yes
- Related Files: none
- Tags: ecs, ssh, zsh, quoting

### Resolution
- **Resolved**: 2026-09-04T16:10:00+08:00
- **Notes**: Removed the nested remote `awk` expressions from the audit command.

---

## [ERR-043] frontend-root-package-assumption

**Logged**: 2026-09-04T16:24:00+08:00
**Priority**: low
**Status**: resolved
**Area**: config

### Summary
A command-search probe assumed `askXuan-frontend/package.json` existed, but this multi-app parent repository has package manifests under individual applications.

### Error
```
rg: package.json: No such file or directory (os error 2)
```

### Context
- The same search still found the required verification commands in application manifests and the sync script.
- No files were changed by the failed path lookup.

### Suggested Fix
Search only existing application manifests or enumerate them with `rg --files` first.

### Metadata
- Reproducible: yes
- Related Files: apps/web-platform-admin/package.json, apps/web-shop-admin/package.json, apps/web-temple-admin/package.json
- Tags: monorepo, package-json, rg

### Resolution
- **Resolved**: 2026-09-04T16:24:00+08:00
- **Notes**: Used the discovered direct commands instead of relying on a root manifest.

---

## [ERR-044] api-reference-audit-wrong-repository

**Logged**: 2026-09-04T16:26:00+08:00
**Priority**: low
**Status**: resolved
**Area**: docs

### Summary
The API Reference audit was invoked from `askXuan-docs`, but that repository does not contain `scripts/audit-api-reference.mjs`.

### Error
```
Error: Cannot find module '/Users/gaofeng/develop/DongFang/askXuan-docs/scripts/audit-api-reference.mjs'
```

### Context
- Documentation staged-diff validation had not yet run because `set -e` stopped at the missing script.
- No files were changed by the failed invocation.

### Suggested Fix
Locate the script with `rg --files` and run it from its owning repository with the documented arguments.

### Metadata
- Reproducible: yes
- Related Files: ../askXuan-docs/API-REFERENCE.md
- Tags: docs, api-reference, script-path

### Resolution
- **Resolved**: 2026-09-04T16:27:00+08:00
- **Notes**: Located the script in `askXuan-backend/scripts/` and reran it against the docs repository; all 321 runtime and documented contracts matched.

---

## [ERR-045] frontend-git-push-ssh-connection-closed

**Logged**: 2026-09-04T16:33:00+08:00
**Priority**: medium
**Status**: resolved
**Area**: infra

### Summary
The first non-force push of the frontend admin commit was interrupted by the GitHub SSH transport before the remote branch updated.

### Error
```
Connection closed by 198.18.0.205 port 22
fatal: Could not read from remote repository.
```

### Context
- Backend and H5 pushes completed successfully immediately beforehand.
- The frontend branch remained ahead of `origin/master` by one commit.
- No force option was used.

### Suggested Fix
Fetch/inspect the remote branch and retry the same ordinary `git push origin master` after the transient connection recovers.

### Metadata
- Reproducible: intermittent
- Related Files: none
- Tags: git, push, github, ssh, network

### Resolution
- **Resolved**: 2026-09-04T16:36:00+08:00
- **Notes**: Confirmed the remote branch had not advanced, then retried the same non-force push successfully (`29ba667..ea7937a`).

---

## [ERR-046] xcodebuild-list-simulator-sandbox

**Logged**: 2026-09-04T18:46:00+08:00
**Priority**: low
**Status**: resolved
**Area**: config

### Summary
`xcodebuild -list` could not access CoreSimulator system services in the workspace sandbox and was terminated before printing the project inventory.

### Error
```
CoreSimulatorService connection became invalid
Error opening log file ... Operation not permitted
exit 143
```

### Context
- `plutil -lint` had already validated the modified `.pbxproj` syntax successfully.
- The failure was caused by sandboxed simulator/log access, not an Xcode project parse error.

### Suggested Fix
Rerun the read-only `xcodebuild -list` command with approved system access.

### Metadata
- Reproducible: under the workspace sandbox
- Related Files: apps/ios-customer/DongFangApp.xcodeproj/project.pbxproj
- Tags: xcodebuild, simulator, sandbox, ios

### Resolution
- **Resolved**: 2026-09-04T18:48:00+08:00
- **Notes**: The same read-only command succeeded with approved system access and listed the DongFangApp target, tests, configurations, and scheme.

---
