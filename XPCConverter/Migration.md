# Rewriting the Converter XPC Service onto `XPCSession`/`XPCListener`

Implementation assignment for migrating the DVD converter XPC service from the
legacy `NSXPCConnection`/`NSXPCListener` (remote-object-proxy) model to the
modern message-based `XPCSession`/`XPCListener` model (Apple's `XPC`
framework, macOS 14+).

## 1. Objective

Replace every use of the legacy XPC API in the `XPCConverter` target and the
`MovieArchiveConverter` package with the modern `XPC` framework, while
keeping:
- the public API surface (`DVDReader`, `ConverterPublisher`, `ConverterOutput`)
    — except `ConverterError` collapses to a single connection-error case
    (§2.6);
- the internal calls `DVDReader` makes to the converter as **plain `async
  throwing` functions**;
- all behavior (progress/messaging push, per-instance single-threadedness,
  lifecycle cleanup);
- **every** existing test (none added, none removed); tests whose mechanism no
  longer applies are rewritten **in place**.

The modern `XPC` framework exchanges `Codable`/`XPCReceivedMessage` payloads.
It has **no** `NSXPCInterface` typed remote proxy and **no**
`exportedObject`/`remoteObjectProxy`; every protocol-driven call becomes an
encoded message.

## 2. Global assumptions

### 2.1 Environment & platform
- macOS; `MovieArchiveConverter` targets `.macOS(.v26)`; `XPC` needs macOS 14+,
  so it resolves. `import XPC` is available in the `MovieArchiveConverter`
  package and the `converter` XPC service target.
- The XPC service is an app-bundle service, id
    `de.reactorcontrol.movie-archive.converter`, `Info.plist`
    `XPCService/ServiceType = Application`. Launched by `launchd`
    (app-bundle) in production; in the Playground case by a manually-registered
  Mach service (debug-only fallback).
- Sandbox entitlements, `Info.plist`, and the service name **do not change**.
  Only the in-process wire and lifecycle change.

### 2.2 The wire is message-based
Three `Codable & Sendable` enums live in a new
`XPCConverter/Converter/Messages.swift`:

- `ConverterRequest { case open(URL); case readInfo(UUID); case close(UUID) }`
    (client→service requests; `.close` is one-way, no reply)
- `ConverterResponse { case open(UUID?); case readInfo(Data?) }`
    (the coupled service→client **reply**; `.close` has no reply)
- `ConverterPush {
    case message(OSLogType, LocalizedStringResource)
    case progress(UUID, completed: Int64, total: Int64, description: LocalizedStringResource)
    }`
    (**uncoupled** service→client push — the progress/messaging channel only)

`ConverterRequest`/`ConverterResponse` are a coupled request/reply pair
(`send(_:replyHandler:)` ↔ the reply on that call's `replyHandler`).
`ConverterPush` is **uncoupled**: it is not the answer to any request and is
delivered on the client's separate `setIncomingMessageHandler` (the service
sends it via the peer `XPCSession` captured at `accept`). Proof it is uncoupled:
`.message`/`.progress` can arrive while an `open`/`readInfo` reply is still
pending.

**Connection errors are NOT `ConverterPush` cases.** With
`ConverterPush = { .message, .progress }`, connection failure is sourced from
the framework's native events (§2.6), not pushed across the wire.

`OSLogType` is `@objc` and **not** `Codable`. Provide
`@retroactive extension OSLogType: Codable` that encodes/decodes
`rawValue: UInt8` only.

`LocalizedStringResource` is `Codable & Sendable` in the current SDK, so
`ConverterPush` carries it directly. This resolves the TODO at
`ReturnChannel.swift:71`; the `StringLocalizationKey = String` typealias is
deleted.

### 2.3 Public API stability
Unchanged: `DVDReader` (actor) `init(source:) async throws`,
`var publisher: ConverterPublisher`, `func info() async throws -> DVDInfo`,
`isolated deinit`; `ConverterPublisher =
AnyPublisher<ConverterOutput, ConverterError>`;
`ConverterOutput { case message(level: OSLogType, LocalizedStringResource);
case progress(Progress) }`.
`Importers/DVDImporter.swift` and `Importers/Importer.swift` do not change
(they use only `DVDReader.publisher`/`.info()`).

### 2.4 Invariants to preserve
- **Single-threaded per instance.** The new
    `XPCListener(service:targetQueue:)` and `XPCSession(xpcService:targetQueue:)`
   default to `DISPATCH_TARGET_QUEUE_DEFAULT` (concurrent). **Pass a per-session
   serial `DispatchQueue`** to the listener and to every accepted session, and
   keep **all** `state`/`Progress` mutation on it.
- **Lifecycle/keepalive.** Drop `xpc_transaction_begin/end` entirely. The
   per-session `XPCSession` lives until the client cancels it. Reader-state
   cleanup runs on **two idempotent triggers**:
    1. `XPCPeerHandler.handleIncomingRequest(.close(id))` runs the `state[id]`
       cleanup handler, and
    2. `XPCPeerHandler.handleCancellation(error:)` runs any **remaining**
        `state` cleanup (backstop for a session torn down mid-read).
   Both must be safe against already-cleaned or unknown ids.

### 2.5 Teardown & the `close` request
- `ConverterRequest.close(UUID)` **remains in the wire enum** (symmetry; lets
   close-related assertions exist).
- `DVDReader.deinit` **cannot `await`**. It issues a **synchronous,
   fire-and-forget** `close` — `XPCSession.send(.close(id))` via the
    **no-reply** overload, discarding the throw so a throw never blocks
    `deinit` — then `ConverterConnection.deinit` cancels the session.
- **Ordering:** the client delivers `close` **before** `cancel()`, because
   session cancellation is not a guaranteed flush of unsent sends. A no-reply
    `close` sent synchronously ahead of `cancel()` preserves the order;
    `handleCancellation` is the idempotent backstop.
- `readerInitDeinit`'s "close should be called" stays true: the mock still
   receives a `close` request.

### 2.6 Connection-error model (collapsed)
- `ConverterError` **collapses to a single** connection-error case
    `case connectionInvalid` and **drops `case connectionInterrupted`**.
   Update `ConverterError`'s `LocalizedError` conformance
    (`errorDescription`) accordingly, and the "two connection error cases can
   happen out-of-band" comment in `ReturnChannel.swift`.
- Connection failure is **framework-sourced**, not pushed:
    - **Real path:** client `XPCSession.cancellationHandler` **and** a
      reply-failure `XPCRichError` from `send(_:replyHandler:)` /
      `sendSync` each **feed the publisher directly** with
      `.failure(.connectionInvalid)`. **No local `sendConnection*` methods** are
      recreated on the client sink.
    - **Mock path:** the existing injectable `publisher` argument of
      `withUnsafeMocks(..., publisher:)` supplies a publisher that completes with
      `.failure(.connectionInvalid)`, so unit tests synthesize the failure
      without a real session or a wire-mirror method.
- Service-side: `XPCPeerHandler.handleCancellation(error:)` runs remaining
   reader cleanup (§2.4).

### 2.7 The push channel
The service reaches the client through the **per-connection peer `XPCSession`**
captured inside `IncomingSessionRequest.accept { session in … }` (the legacy code
fetched this from `NSXPCConnection.current()?.remoteObjectProxy`; the modern
equivalent is the peer session captured at accept time). The service pushes
`ConverterPush` via `peer.send(_:)`; on the client,
`XPCSession.setIncomingMessageHandler` decodes each `ConverterPush` and forwards
it into the `ReturnImplementation`-backed `PassthroughSubject`, producing the
existing `ConverterPublisher`. `ReturnImplementation` stops being an `@objc`
return object and becomes a client-side sink.

### 2.8 Concurrency / reply semantics
- Request helpers on the client: `open(URL) async throws -> UUID?` and
    `readInfo(UUID) async throws -> Data?` use
    `XPCSession.send(_:replyHandler:)` + `withCheckedThrowingContinuation`
    (non-blocking; return on the actor via the continuation). `close` uses the
   no-reply synchronous send.
- The existing `withErrorHandling` wrapper (`Connection.swift:123`) that throws
   out-of-band failures/`finished` is **retained** and applied to the new async
   request helpers.

### 2.9 Scope
- **In scope:** `XPCConverter/main.swift`,
    `XPCConverter/DVDReaderService.swift`,
    `XPCConverter/Converter/Connection.swift`,
    `XPCConverter/Converter/DVDReader.swift`,
    `XPCConverter/Converter/ReturnChannel.swift`, new
    `XPCConverter/Converter/Messages.swift`, and `Tests/Common.swift`,
    `Tests/Importers.swift`, `Tests/Recorded.swift`.
- **Out of scope:** vendored `Dependencies/HandBrake/…` XPC service (separate
   Objective-C service — leave it), the `Intercept`/`libdvdread`/`libdvdcss`
  layers, `Importers/`, `Model/`, app-bundle/entitlement changes, and live
  end-to-end (real app↔service pipe) coverage. The test suite stays
    **mock-only** "as today."

## 3. Background — current architecture (context only)
- `main.swift`: `ConverterImplementation` (per-connection state; an `@objc`
    `ReturnInterface` proxy fetched from `NSXPCConnection.current()`);
    `ConverterDelegate: NSXPCListenerDelegate` wires the interfaces and resumes;
    `NSXPCListener.service()` is the listener.
- `DVDReaderService.swift`: `ConverterImplementation: ConverterDVDReader`;
    `DVDData.Progress` pushes through a `ReturnInterface?`;
    `xpc_transaction_begin/end` keep the service alive while a reader is open.
- `Connection.swift`: `ConverterConnection<Interface>` holds an
    `NSXPCConnection`; `makeConnection()` builds
    `NSXPCConnection(machServiceName:)` (Playground) or
    `NSXPCConnection(serviceName:)` (app-bundle); exposes `remote`,
    `publisher`, `withErrorHandling`; `withUnsafeMocks(proxy:publisher:)`
    (`@TaskLocal`) is the test injection.
- `DVDReader.swift`: `public actor DVDReader` wraps
    `ConverterConnection<ConverterDVDReader>()`; bridges completion-handler calls
   to `async throws` via `withErrorHandling`/continuations.
- `ReturnChannel.swift`: `ReturnImplementation: @objc ReturnInterface` adapts
    `sendMessage`/`sendProgress`/`sendConnectionInvalid`/`sendConnectionInterrupted`
   into a `PassthroughSubject<ConverterOutput, ConverterError>`.

## 4. Test policy (drives commit structure)
- **No test added, none removed.** Each `@Test` keeps its name/location;
   inapplicable ones are rewritten **in place**.

- **Unaffected (no XPC surface, stay passing untouched):**
    `ModelTests`.{ `mediaTreeEditing`, `mediaTreeJSON`, `passExecution`,
    `clientInteraction`, `errorToPublisher`, `cancellation` },
    `UnsupportedSourceTests.unsupportedSource`,
    `DVDImporterTests.dvdInfoJSON`, `JSONCodingTests`.{ `keyedContainer`,
    `unkeyedContainer`, `singleValueContainer`, `decodingErrors` },
    `InterceptTests.dlopen`.
- **Live, no body change** (drive the real service via the rewired wire):
    `DVDImporterTests.minimalDVD`.
- **Rewritten in place onto the new seam** (mock switches from
  `proxy`/completion-handler @objc mocks to `backend`-based mocks; push via
   the sink's `receive(_:)`; no wire-mirror methods):
    `ConverterTests.{ deinitialization, messagePropagation, progressPropagation,
   xpcErrorWrapper }`, `DVDImporterTests.{ readerInitDeinit, readInfoError }`,
    `RecordedTests.recordedDVDs`.
- **`errorLocalization` is rewritten in place**: drop the
    `ConverterError.connectionInterrupted.errorDescription` assertion (case
   removed; §2.6).
- **`xpcErrorPropagation` is rewritten in place at the cutover, with no disable
   window.** Its current body builds a real
    `NSXPCConnection(serviceName: "invalid")`, which cannot compile once the
    `NSXPCConnection`/`NSXPCInterface` seam is deleted; `@Test(.disabled:)` only
   skips *execution*, not compilation, so it is the wrong mechanism. Rewrite it
   to a mock-injection form on the collapsed `.connectionInvalid` case, mirroring
    `xpcErrorWrapper` (which remains as the representative test).
- After all commits, **all** `@Test`s are active and passing.

## 5. Commit plan
Each commit must build and leave **every active** test passing. No test is disabled
at the end of any commit.

### C1 — Codable wire contract + `OSLogType: Codable` (inert)
**Obligations**
- Create `XPCConverter/Converter/Messages.swift`: `ConverterRequest`,
    `ConverterResponse`, `ConverterPush` (as in §2.2), all `Codable & Sendable`.
- Add `@retroactive extension OSLogType: Codable` (`rawValue: UInt8` only).
- Wire nothing; do **not** touch production or tests.

**Acceptance:** builds Debug+Release; all existing `@Test`s pass unchanged; the
new file is compile-only inert.

### C2 — Cutover production to the new wire (old seam coexists; collapse error case)
**Obligations**
- **Service** (`main.swift` + `DVDReaderService.swift`):
    - Replace `NSXPCListener.service()`/`ConverterDelegate` with
      `XPCListener(service: "de.reactorcontrol.movie-archive.converter",
      targetQueue: serialQueue) { request in request.accept { session in
      ConverterImplementation(session: session) } }; dispatchMain()`.
    - `ConverterImplementation: XPCPeerHandler`
      (`Input = ConverterRequest`, `Output = any Encodable`, returning a
      `ConverterResponse`). `handleIncomingRequest` switches on
      `ConverterRequest`: `.open`/`.readInfo` return the matching
      `ConverterResponse`; `.close` returns `nil` (no reply) and runs the cleanup
      handler; `handleCancellation(error:)` runs remaining `state` cleanup.
    - Push client `ConverterPush`es through the **peer session captured at
     accept time** (not `NSXPCConnection.current()`).
    - `DVDData.Progress.channel` type changes from `ReturnInterface?` to the
      service-side push channel.
    - **Drop `xpc_transaction_begin/end` entirely.**
    - Per-session **serial `DispatchQueue`** on the listener and each session
     (§2.4).
- **Client** (`Connection.swift` + `ReturnChannel.swift` + `DVDReader.swift`):
    - Replace `NSXPCConnection`/`NSXPCInterface` client internals with
      `XPCSession(xpcService:machService:)` (keep the Playground
      `CFMessagePort`/`XPCSession(machService:)` branch) +
      `setIncomingMessageHandler` decoding `ConverterPush` into the publisher +
      `cancellationHandler`/reply-`XPCRichError` → `.connectionInvalid` on the
      publisher directly (§2.6).
    - `open`/`readInfo` via `send(_:replyHandler:)` +
      `withCheckedThrowingContinuation`; `close` via the no-reply synchronous
      send. Keep `withErrorHandling`.
    - `DVDReader` calls the new `async throws` helpers (drop completion-handler
     bridging); public API unchanged; `DVDReader.deinit` issues a synchronous
     fire-and-forget `close` (§2.5).
    - `ReturnImplementation` becomes a client-side sink; drop `@objc`/
      `ReturnInterface`.
    - **Collapsing the error case:** change `ConverterError` to
      `{ sourceNotSupported, sourceReadError, connectionInvalid }` (drop
      `connectionInterrupted`); update its `errorDescription`; update the
      `ReturnChannel.swift` comment.
    - **Introduce the new test seam:** an internal `ConverterBackend`
      (asynchronous `open`/`readInfo`/`close`) and `withUnsafeMocks(backend:)`,
     while the existing injectable `publisher` still supplies
      `.failure(.connectionInvalid)` for the error tests (§2.6).
    - **Old `@objc` seam coexists**: keep `ConverterConnection<Interface>`,
      `ConverterInterface`, `ConverterDVDReader`, `ReturnInterface`,
      `withUnsafeMocks(proxy:)` compiling so the seven mock tests in §4 still
      build and pass **unchanged** (they ride the coexisting seam).
    - **Rewrite `xpcErrorPropagation` in place** to a mock-injection form on
      `.connectionInvalid` (mirror `xpcErrorWrapper`); no
      `NSXPCConnection`/`NSXPCInterface` outside the coexisting old seam; no
      disable window.

**Acceptance:** builds Debug+Release; all active `@Test`s pass. The new wire is
the active production path; the old seam remains as compilation support for C3.

**Correctness notes:**
- Map both `cancellationHandler` and reply `XPCRichError` to
    `.connectionInvalid` straight into the publisher.
- Enforce client-then-cancel ordering for `close`.
- Verify `@retroactive OSLogType: Codable` has no synthesis collision.

### C3 — Rewrite the seven mock tests + `errorLocalization` in place; delete the old seam
**Obligations**
- Rewrite each test in the §4 "rewritten in place" list to the `backend` seam:
   mocks become `ConverterBackend` conformers with **asynchronous**,
   completion-handler-free methods; push tests drive the sink's `receive(_:)`;
   `deinitialization` asserts the same two deinits via the new seam;
   `readerInitDeinit`/`readInfoError`/`recordedDVDs` use
   `withUnsafeMocks(backend:)`.
- `errorLocalization`: drop the `.connectionInterrupted` assertion.
- **Delete** the now-unused old seam: `@objc` `ConverterInterface`,
    `ConverterDVDReader`, `@objc` `ReturnInterface`, `withUnsafeMocks(proxy:)`,
   stray `@objc` `ConverterTesting` (`Tests/Common.swift`), the
    `StringLocalizationKey` typealias, and the `ReturnChannel.swift:71` TODO.

**Acceptance:** builds Debug+Release; all `@Test`s pass and exercise the new
wire; no `NSXPCConnection`/`NSXPCInterface`/`@objc` interface protocol remains;
no test disabled/removed/added.

### C4 — Final legacy cleanup
**Obligations:** sweep for residual legacy references a C3 missed (stray
`StringLocalizationKey`, a coexisting `withUnsafeMocks` overload, an unused
`@objc` declaration). If C3 leaves the tree clean, this is a verification (or
empty) commit and may be omitted.

**Acceptance:** builds Debug+Release; all `@Test`s pass; grep for
`NSXPCConnection|NSXPCInterface|ConverterDVDReader|ConverterInterface|
ReturnInterface|StringLocalizationKey|withUnsafeMocks(proxy|.connectionInterrupted`
returns nothing.

## 6. Risks & watch-outs
- **C2 coverage gap:** the seven mock tests exercise the coexisting old seam
   until C3 (accepted; the task is mock-only). C3 closes it.
- **Session cancellation is not a flush:** send the no-reply `close`
   synchronously **before** `cancel()`; keep `handleCancellation` idempotent
   (§2.5).
- **`DVDReader.deinit` cannot `await`:** `close` is a synchronous no-reply send;
   a throw must not block teardown.
- **Concurrency:** both ends honor the per-session serial queue; all
   `state`/`Progress` mutation stays on it.
- **Error contract:** preserve out-of-band `.connectionInvalid` publisher
   failures via both `cancellationHandler` and reply `XPCRichError`.
- **`ConverterError` collapse** (§2.6): update `errorDescription`, the
    `ReturnChannel` comment, and `errorLocalization`; `ConverterPush` carries
   only `{ .message, .progress }`.
- **`OSLogType` Codable:** `@retroactive` extension on a C-backed struct encodes
   only `rawValue: UInt8`; verify no `Codable` synthesis collision.
- **`XPCRichError`** is a `struct` with `canRetry`; map any reply failure to
    `.connectionInvalid`.
- **Playground branch:** keep the `CFMessagePortCreateRemote` presence check and
    `XPCSession(machService:)` for the debug-only manual-registration case.

## 7. Definition of done
- `import XPC` used; no legacy `NSXPCConnection`/`NSXPCListener`/
    `NSXPCInterface` remains in `XPCConverter`/`MovieArchiveConverter`.
- `DVDReader`'s public API unchanged; its internal calls are plain
    `async throws`.
- Service uses `XPCListener` + `XPCPeerHandler`; client uses `XPCSession` +
    `setIncomingMessageHandler`; `xpc_transaction_begin/end` gone; cleanup is
    close/cancellation-driven and idempotent.
- Push carries `OSLogType`/`LocalizedStringResource` via `ConverterPush`
    `{ .message, .progress }`; `StringLocalizationKey` and its TODO gone.
- `ConverterError` has a single connection case `.connectionInvalid`;
    `connectionInterrupted` removed everywhere (`errorLocalization` updated).
- All `@Test`s active and passing; none added or removed.
- Both Debug and Release build.
