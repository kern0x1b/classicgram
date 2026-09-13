# Host tests

No test framework is used — none is available for this project and adding one is out of scope.
This is a plain C/Objective-C binary built with `clang` directly against the Mac's own Foundation
and CoreGraphics frameworks, no iOS SDK involved, that runs a table of test-case functions and
prints one `RUN`/`OK`/`FAIL` line per case.

## Run it

```
scripts/run-host-tests.sh
```

## Expect

1160 `RUN`/`OK` (or `RUN`/`FAIL`) line pairs, one per test case, followed by a summary line:

```
PASSED: 1160 test case(s), 3426 check(s), 0 failure(s)
```

The script exits `0` when every case passes and `1` when any check inside any case fails — nothing
inspects its output to decide pass/fail, only its exit code. `PASSED`/`FAILED` and the counts on
that last line are for a human reading the log.

## What it covers, and why these files

`src/Layout/TGChatMessageLayout.m`, the `TGMessageLayoutBuilder` family under
`src/Screens/Chat/Layout/`, and `src/Wire/Flatten/TGFlattenMessage.m` are pure in the sense the host
tests need: a value in, an immutable value out, no `UIKit`, no `[TGClient shared]`, no ambient
state. Everything the chat screen draws is derived from what the flattener and the layout builder
return, so a case here catches a whole screen's worth of wrong pixels before a build reaches a
device.

- `tests/layout/` (9 cases) exercises the bubble geometry functions: that a row's height never
  disagrees with the frame drawn inside it, that the minimum-height clamp doesn't get the +1
  overflow pad it must only apply above the clamp, that the tail sits on the correct side for
  outgoing versus incoming and is never zero-sized, and that a photo's timestamp plate stays on the
  picture rather than spilling onto the wallpaper next to it.
- `tests/layout_builder/` (15 cases) exercises `TGMessageLayoutBuilder` and its category family
  (`+Photo`, `+Album`, `+Text`, `+Service`, and the rest): that a photo's stamp sits beside the
  bubble rather than on the artwork, that captions wrap at the picture or mosaic width rather than
  the bubble's own, that a channel post shows its comments row and an ordinary message does not,
  and that `TGMessageItemBuilder` carries the destruct fields through unchanged.
  Two of those cases run **every** builder — text, photo, voice, file, call, poll, checklist, rich,
  location, sticker, animated emoji, video note, animated sticker — over one item and assert the settled
  product rules directly: each gives its row a height, each lays out a bubble frame, each keeps the
  timestamp plate beside the bubble, exactly the four wallpaper kinds set `sitsOnWallpaper`, and no
  bubble hangs outside the table width. The service line is asserted separately as the one kind with no
  stamp and a fully rounded plate of its own.
- `tests/flatten_message/` (13 cases) exercises `TGFlattenMessage` itself — see the fuzzing section
  below for what feeds it beyond these hand-built cases.

The rest of `tests/` covers pure logic found elsewhere in `src/` by the same "value in, value out,
no ambient state" bar, some of it always host-testable and some of it extracted out of an otherwise
impure file the same way `TGFlattenMessage.m` itself was split out of `TGClient.m` originally:

- `tests/mosaic_layout/` (18 cases) exercises `TGMosaicLayoutTiles` — the photo-album/mosaic tile
  geometry solver, same caliber of bug surface as the chat-bubble layout tests but for a different
  visual: wrong output here is a photo grid with overlapping or misaligned tiles.
- `tests/utilities/` (16 cases) exercises `TGMediaFormatBytes` (byte-count formatting) and
  `TGContactName`/`TGContactString` (contact display-name fallback order).
- `tests/date_utils/` (16 cases) exercises `TGDateUtils`. Several of its methods call `time(0)`
  internally and its formatting is locale-dependent, so these tests assert relative/structural
  properties (a more-recent timestamp's relative string is never "older" than a less-recent one's,
  a threshold boundary doesn't crash) rather than exact calendar strings — see the file for the
  pattern if extending it.
- `tests/plural_rules/` (10 cases) exercises `TGPluralRules.m`, extracted from `TGLocalization.m` —
  a hand-rolled CLDR plural-category engine (Arabic 6-form, Baltic, Czech/Slovak, Romanian, Slavic
  3-form, French zero-as-one, English default) plus placeholder substitution. Writing these tests
  found a real bug, not yet fixed: Polish is grouped into the Russian-style Slavic rule
  (`n%10==1 && n%100!=11`), but real Polish CLDR "one" is strictly `n==1` — `TGPluralFormName(21,
  @"pl")` returns `"one"` today, which is wrong for Polish. The test asserts the code's actual
  (buggy) behavior rather than silently "fixing" it out from under a fix that belongs in its own
  change. `TGPluralSubstituteCount` is also a global, non-positional replace — a pattern with two
  different placeholders would get the same value in both — fine for every string this app actually
  ships today, asserted as current behavior, worth knowing if that ever changes.
- `tests/flatten_story/` (30 cases), `tests/flatten_weblinks/` (17 cases),
  `tests/flatten_chat_management/` (8 cases), `tests/flatten_account/` (12 cases), and
  `tests/flatten_calls/` (12 cases) exercise pure TDLib-JSON-to-app-shape transforms extracted from
  `TGClient+Stories.m`, `+WebLinks.m`, `+ChatManagement.m`, `+Account.m`, and `+Calls.m` respectively
  — each of those category files is otherwise real TDLib RPC code and can't be host-compiled as a
  whole, but the parsing/formatting logic inside them (story-area/rich-text/page-block flattening,
  admin-rights composition, login-code copy, call-problem mapping) is exactly as pure as
  `TGFlattenMessage` and moved out the same way, as `TGFlatten<Area>.h/.m`. The remaining
  `TGClient+*.m` category files almost certainly hold more of this same shape — see a prior
  inventory pass for the specific candidates not yet extracted.
- `tests/call_end_text/` (7 cases) exercises `TGCallEndText`, extracted from
  `TGCallViewController.m`'s `endText:`. The call screen's end-of-call status maps five known
  backend reason strings onto localized statuses; the reason itself can also be a raw TDLib error
  message (`TGCall.mm` stores `error.message` verbatim for `callStateError`), so the case that
  matters most is the last one: an unrecognized reason must render as the caller's localized
  fallback rather than reaching the user as backend English.
- `tests/topic_mute_text/` (7 cases) exercises `TGTopicMuteText`, extracted from
  `TGTopicInfoController.m` (a view controller, not otherwise host-compilable) into its own small
  pure file next to it.

A second extraction pass pulled the same shape of logic out of every remaining `TGClient+*.m`
category file worth the trouble — each `TGFlatten<Area>.h/.m` pair below sits next to the category
file it came from and that file now just `#import`s it, same call sites, same behavior:

- `tests/flatten_business/` (14), `tests/flatten_app_settings/` (14), `tests/flatten_network/` (17),
  `tests/flatten_stickers/` (20), `tests/flatten_premium/` (10), `tests/flatten_messages/` (21),
  `tests/flatten_user_status/` (13), `tests/flatten_contacts/` (12), `tests/flatten_payments/` (11),
  `tests/flatten_storage/` (11), `tests/flatten_search/` (14), `tests/flatten_channels/` (9),
  `tests/flatten_privacy/` (5), `tests/flatten_chat_list/` (8), `tests/flatten_history/` (8),
  `tests/flatten_gifs/` (4), `tests/flatten_secret_chats/` (7), `tests/flatten_reactions/` (12),
  `tests/flatten_bots/` (7), `tests/flatten_notifications/` (17),
  `tests/flatten_message_content/` (21), `tests/flatten_forums/` (16),
  `tests/flatten_saved_messages/` (21), and `tests/flatten_direct_messages/` (16) extract from
  `TGClient+Business.m`, `+AppSettings.m`, `+Network.m`, `+Stickers.m`, `+Premium.m`, `+Messages.m`
  (the largest category file, 2043 lines), `+UserStatus.m`, `+Contacts.m`, `+Payments.m`,
  `+Storage.m`, `+Search.m`, `+Channels.m`, `+Privacy.m`, `+ChatList.m`, `+History.m`, `+Gifs.m`,
  `+SecretChats.m`, `+Reactions.m`, `+Bots.m`, `+Notifications.m`, `+MessageContent.m`, `+Forums.m`,
  `+SavedMessages.m`, and `+DirectMessages.m` respectively.
- `tests/phone_strip/` (6 cases) exercises `TGPhoneFormat.strip:`, which turned out to already be
  host-compilable as-is (no ivars, no ambient state); the only change needed was declaring it in the
  header so a test in another translation unit could call it.

A third pass swept the last handful of category files a prior survey hadn't reached:

- `tests/flatten_chat_state/` (8 cases) extracts `TGScopeType`/`TGPacksFrom` from
  `TGClient+ChatState.m` plus `TGFlattenFileObjectState` — a `+stateOfFileObject:` class method
  pulled out of `TGClient+UpdateHandling.m` and turned into a plain function; a second, previously
  unnoticed call site for the same method inside `TGClient.m` itself was found and updated to match
  while extracting it.
- `tests/flatten_files/` (18 cases) extracts `TGFilesDataFromBase64`, `TGFileInfo`, and
  `TGFileOfMessageContent` from `TGClient+Files.m`, plus two instance methods
  (`bestPhotoSizeIn:forWidth:scale:`, `decodableThumbnail:`) converted to plain functions since
  neither touched `self` or instance state.
- `tests/flatten_groups/` (25 cases) extracts eleven functions plus two converted instance methods
  (`titleForAdministratorRightKey:`, `titleForMemberPermissionKey:`) from `TGClient+Groups.m`
  (1602 → 1438 lines), the single largest cluster of extraction candidates found in this pass.
- `tests/flatten_translation/` (18 cases) extracts six functions from `TGClient+Translation.m`,
  including one (`TGTrTranscript`) that calls the app's `TGL(...)` localization macro — already
  host-linkable for free, since `tests/support/host_stubs.m` already stubs `TGLocalizedString` and
  `TGLocalization.h`'s only iOS dependency (`UIKit.h`) already resolves through the existing host
  shim, so no new source file needed adding to `pure_app_sources` for this group.

Three independent hand-rolled base64 decoders now exist, on purpose left alone rather than silently
consolidated:

- `TGMCBase64` (`TGFlattenMessageContent.m`) returns an *empty* `NSData` for empty or all-invalid
  input.
- `TGScBase64Decode` (`TGFlattenSecretChats.m`) and `TGFilesDataFromBase64` (`TGFlattenFiles.m`)
  agree with each other — both return `nil` for the same inputs — but disagree with `TGMCBase64`.

All three accept the standard alphabet plus URL-safe `-`/`_` and silently skip invalid characters;
only the nil-vs-empty convention for "nothing decoded" differs. A future consolidation needs to pick
one convention and check no caller depends on either of the other two.
- `TGPluralFormName(21, @"pl")` (see `tests/plural_rules/` above) is unaffected by this pass; still
  open.

One duplication this pass did fix at the root rather than baseline around it:
`TGClient.m`'s `TGResultIsError` was the only non-`static`, genuinely pure function in that file, so
it moved into its own `src/TDLibClient/TGResultIsError.h/.m` — `TGClient.h` now gets the declaration
by importing it, and `TGFlattenMessages.m` calls the real function instead of carrying its own
`static` copy. `scripts/lint-layer-imports.py --rule error-check` exists precisely to catch a
`TGXxxIsError` reimplementation like the one this would otherwise have left behind.

- `tests/wallpaper_row_text/` (6 cases) covers `TGWallpaperRowText`, lifted out of
  `TGSettingsViewController+AutoDownload.m`: the kind fallback, the colour word (including that the high
  byte is masked off, so two colours differing only there must not read as a gradient), the title's
  gradient-versus-solid decision and its one-based numbering, and the detail line's comma-joined parts.
- `tests/saved_messages_text/` (7 cases) covers `TGSavedMessagesText`, the six pure functions lifted out
  of `TGSavedMessagesViewController.m`: the scope-to-`searchMessagesFilter*` mapping (including that scope
  0 sends no filter and an out-of-range scope does not pick a wrong one), that all five empty states are
  distinct, the media kind labels, and the row-text truncation and its media-label fallback.
- `tests/date_day_difference/` (6 cases) covers `TGDateDayDifference`, which `TGDateUtils` now uses in
  place of its old `tm_year`-equality gate. Because it takes two `struct tm` values rather than calling
  `time(0)`, these cases can assert exact literal dates the existing `tests/date_utils/` cases have to skip
  at runtime: 31 December to 1 January is one day, a leap day counts, four years spanning one are 1461
  days, and a minute across midnight is still a whole calendar day.
- `tests/chat_row_text/` (7 cases) covers `TGChatRowText`, extracted from
  `TGChatViewController+Table.m`: the pinned-message descriptor (kind wins over a quoted body, newlines
  flatten to spaces, the fourteen-character truncation goes through the surrogate-safe substring), the
  file-status glyph decision table, and the duration clock's padding and negative clamp.
- `tests/checklist_tasks/` (8 cases) covers `TGChecklistTasks`, extracted from
  `TGChatViewController+Checklist.m`'s three inline task-array rebuilds: the next free task id across gaps,
  replacing and removing one task without disturbing its neighbours (the array is sent as the whole
  checklist, so a dropped neighbour overwrites the real one), and that a rebuilt task carries id and text
  only, since `inputChecklistTask` has no completion field.
- `tests/pure_helpers/` (13 cases) covers five helpers extracted from otherwise impure files, one
  file each next to where they came from: `TGPlayerClock` (the music player's clock formatting,
  including its NaN/negative/ceiling clamps), `TGLiveLocationFix` (CoreLocation's negative
  "unknown" course versus TDLib's 0-means-unknown, and the 360 clamp), `TGDiceEmoji` (the seven
  emoji Telegram animates, the football's variation selector included), and `TGThemeGeometry`
  (wallpaper gradient endpoints per rotation, and the iPad grouped-comment inset), plus
  `TGWebBrowserExceptionURL`'s scheme normalization.

## Testing UIKit-touching code against the host shim

`tests/support/host_shim/UIKit/` is a hand-written stand-in for the parts of UIKit the host tests
need — `UIView`, `UILabel`, `UIButton`, `UIImageView`, `UIFont`, `UIColor` (with a real `CGColor`),
`UIImage`, `UIBezierPath`, the `UIGraphics*` context functions and the `NSString` drawing category.
Drawing calls are no-ops and text measurement is a deterministic `0.55 * pointSize` per character
(`TGHostTextWidthPerPoint`), which is exactly why the layout tests can assert exact geometry.

That means a source file is host-testable even when it imports UIKit, as long as what you assert
does not depend on real glyph metrics. `src/Utilities/TGRichText.m` was brought in this way for
`tests/rich_text/` (12 cases over `TGRichTextBuild`: link/spoiler/custom-emoji attribute mapping,
UTF-16 entity offsets, clamping and malformed-entity handling) — its CoreText use links against the
real framework on the host, and only `TGEmojiSubstituteInString`/`TGEmojiDrawImagesInLine` stay
stubbed in `tests/support/host_stubs.m`.

`src/Utilities/TGEmoji.m` itself is deliberately *not* compiled in: it owns `TGEmojiTextSize`, which
the layout tests need to be the deterministic stub rather than real CoreText measurement. Any file
that needs real text metrics has the same constraint.

Roughly 236 of the 725 sources carry no impurity marker at all (no `[TGClient shared]`, no RPC, no
`NSUserDefaults`, no `dispatch_async`, not a view controller) — the biggest clusters are
`src/Views` (24 files), `src/Screens/Chat/Cells` (21), `src/Utilities` (15), `src/Screens/Settings`
(13 plus its cells and items) and `src/Media` (9). Those are the queue for further coverage rounds.

## Fuzzing the TDLib JSON boundary

`src/Wire/Flatten/TGFlattenMessage.m` is the only place raw TDLib JSON becomes an app-level message
— every field read out of a dictionary that came over the wire is untyped until this function
touches it. The thirteen hand-built cases in `tests/flatten_message/` prove it does the right thing
with well-formed input; the fuzzer's job is to throw malformed and adversarial input at it instead
and let AddressSanitizer/UndefinedBehaviorSanitizer catch what `isKindOfClass:` guards miss.

```
scripts/run-fuzz-flatten-message.sh
```

Xcode's own `clang` doesn't ship a libFuzzer runtime on macOS, so the script looks for a Homebrew
LLVM install (`brew install llvm`) first and falls back to plain `clang` on `$PATH`, which will
fail at the link step with a clear "libclang_rt.fuzzer_osx.a not found" if none is available.
Corpus and crash artifacts land in `tests/fuzz/corpus/` and `tests/fuzz/`, both gitignored — a
found crash reproduces with `build/host-tests/fuzz-flatten-message tests/fuzz/crash-<hash>`.

`tests/support/tg_flatten_message_fixture.m` holds the shared `TGFlattenContext` stub both the
hand-built tests and the fuzzer inject — it's the same context either way, only the message
dictionary itself is adversarial.

## Extending this for Stage 2

When `src/Wire/Decode/` exists, add its sources to `pure_app_sources` in
`scripts/run-host-tests.sh` and its test cases to the table in `tests/host_tests_main.m` the same
way the two files here were added — nothing else in the script needs to change.
