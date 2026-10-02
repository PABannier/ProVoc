# ProVoc 4.2.3 on Apple Silicon — verification report

ProVoc (Arizona Software, 2005–2008; sources last touched in 2013) builds and runs
natively on arm64, on macOS 13 and later. This report says what was broken and why,
what was done about it, what replaces the features that cannot exist any more, how to
rebuild, and how to train with the keyboard alone. The last section is written by
`scripts/verify.sh`: the result of each step and of each line of `FEATURES.md`.

The code is still manual reference counting (no ARC conversion), the nibs are the
original Interface Builder 2 nibs, no original shortcut was changed or removed, and
nothing a user needs requires the Control key.

## What was broken, why, and what was done

### It did not build

| Broken | Root cause | Fix |
|---|---|---|
| No build for arm64 | The project targeted PowerPC / i386 and linked QTKit, QuickTime, Carbon and two prebuilt frameworks (sound recorder, sequence grabber) that do not exist for arm64 | `project.yml` (XcodeGen) generates the project: arm64 only, macOS 13, MRC. QTMovie / QTMovieView are small classes of the same names on AVFoundation / AVKit, so that the nibs that archive them still load. Gestalt, HideMenuBar and friends are replaced by AppKit calls |
| Compilation errors | 32-bit assumptions: `int` compared with `NSNotFound`, `float` where delegates take `CGFloat`, comparators, archiver lengths | Corrected one by one |
| Nibs cannot be opened by Xcode | Interface Builder 2 format | They are already compiled: copied as they are by a build phase. Stale `~` backups removed |
| The Spotlight importer | A PowerPC / i386 binary | Rewritten (`Importer/`): same attributes (text content, languages, number of words), embedded in `Contents/Library/Spotlight` |

### It built but features did nothing (damage of the 2013 "modernization")

| Broken | Root cause | Fix |
|---|---|---|
| Progress, button titles, question text, enabled states never refreshed | `+setKeys:triggerChangeNotificationsForDependentKey:` had been replaced by `+keyPathsForValuesAffecting…` with the dependency inverted | The original declarations are back |
| Saving a package, copy / paste, undo, the slideshow raised exceptions (swallowed) | Nil-terminated constructors turned into literals, which raise on nil | Nil-safe again |
| English search field and other outlets dead | The four English nibs had been rebuilt around a toolbar | The original English nibs are restored: the six localizations have the same structure |
| About window missing in five languages | Pre-keyed `objects.nib` format, which AppKit no longer loads | One keyed nib for all |
| Recording a sound, capturing a picture or a movie did nothing | The recorder was a stub returning strings | A real recorder (AVAudioRecorder) and camera window (AVCaptureSession); missing permission or device is explained |

### The keyboard flow of a test

| Broken | Root cause | Fix |
|---|---|---|
| The second of two quick Returns was lost ("check", then "next word") | `ignoreRebound` dropped every Return within 0.2 s of the previous one | Only auto-repeat is ignored |
| Every key went through `interpretKeyEvents:` to detect Tab, which destroyed dead-key state (no `ê` with `^` then `e`) | `sendEvent:` override | Tab is detected by key code; dead keys reach the field editor |
| Exceptions in `sendEvent:` were swallowed | A catch-all handler | Removed; exceptions that AppKit catches are logged by `-[ProVocApplication reportException:]` |
| `NSApp` was not a `ProVocApplication` in some launches | `+sharedApplication` overridden in a category | `NSPrincipalClass` |
| Digits 1–9 did nothing in multiple choice on an AZERTY keyboard | The handler compared characters; AZERTY types digits with Shift | Key codes |
| A dead key in a list raised a range exception | `characterAtIndex:0` of an empty string | Guarded |
| Result panel: Return / Esc did the wrong thing after the first use | Key equivalents were set one way only | Set both ways each time: Return = Repeat Incorrect Words when there are some, otherwise Done; Esc = Done |
| "Time is over!" never appeared after a correct answer | Logic error in the deferral of the alert (original bug) | Fixed |
| The splash window at launch took the keyboard for three seconds | It became key instead of the document | It cannot become key when shown at launch |
| A click on a movie took the focus from the answer field | The movie view accepted first responder | It no longer does in a test panel |
| F1–F4 need the fn key on current keyboards | — | Vocabulary > Media: the same commands with second shortcuts (below) |

### Crashes and data safety

| Broken | Root cause | Fix |
|---|---|---|
| Test panel crashed while drawing | A gradient callback read an autoreleased array later (drawing is recorded and replayed today) | The callback retains its data |
| Test backgrounds crashed or stayed black | Quartz Composer is deprecated; the compositions no longer render | Drawn with Core Animation (see Obsolete features) |
| Find Double Entries crashed | A window was created on a background thread | Created on the main thread |
| ⌘P crashed | A dangling pointer to the current page | Cleared |
| View Options raised for a hidden column | The column was looked up in the table, where hidden columns are not | Looked up in the list of the document |
| Opening some real decks raised "mutated while being enumerated" | Enumeration of a dictionary that the loop changed | A copy is enumerated |
| **A corrupt deck opened as an empty document, ready to be saved over the file** | The unarchiver of 2008 raised an exception (the document was refused); today it returns nil | No vocabulary is an error again, for both file formats |
| The window grew by the height of its title bar at each save / reopen | The saved frame was restored as a content size | Restored as a frame |
| Training panels leaked (hundreds of live windows) | Top-level nib windows need a release by their owner under MRC | Released |

### Things that looked or behaved wrong on a current macOS

| Broken | Root cause | Fix |
|---|---|---|
| **About ProVoc opened the standard About panel** | `-orderFrontStandardAboutPanel:` was replaced by a category of NSApplication; AppKit's own method now wins | The override is in `ProVocApplication`. A test fails if any category of the application defines a method its system class already has; four more were found and removed (`-[NSAttributedString size]`, `-[NSString sizeWithAttributes:]`, `+[NSCharacterSet newlineCharacterSet]`, `-[NSScanner scanHexLongLong:]`), one renamed (`-[NSDate isToday]`) |
| Labels lost their last letters ("Fas", "Len", "Piccol") | The labels have the exact width of their text in Lucida Grande and wrap; the system font is wider | A one-line label no longer wraps and takes the room its neighbours leave |
| Inspector showed only "Text"; the history chart covered the controls | Since macOS 14 views are not clipped and `drawRect:` may get a larger rectangle; three views filled it | They fill their bounds |
| Unreadable lists in Dark Mode | Nibs and cells are drawn for a light appearance | `NSRequiresAquaSystemAppearance`: light windows whatever the system appearance |
| Preference pane icons hidden behind ">>" | Unified toolbar | Preference toolbar style |
| Movie import panel accepted any file; the custom background panel too | `runModalForTypes:` no longer filters | `allowedFileTypes` |
| UTF-8 text files imported as garbage | Read with the legacy encoding only | Encoding detection first |
| Double click on a training mode did nothing; removing the last mode selected the first | AppKit no longer asks `shouldEdit` for such cells | Double action of the table; selection kept |
| Multiple choice: 0 / Space did not play the sound of the selected choice | Copy-paste error in the second branch (original bug) | Fixed |
| `import text` from Automator raised an exception | Cocoa scripting no longer turns a list of one text into a text | The command joins the texts of a list |
| Help did nothing | Help Viewer cannot open a help book of 2008 | The help book opens in a window of the application |

## Shortcuts that were added

No original shortcut was changed. These are second shortcuts for the commands on
function keys (Vocabulary > Media), and one AppleScript command.

| Command | Original | Added |
|---|---|---|
| Play the sound of the question / first language | F1 | ⌘K |
| Play the sound of the answer / second language | F2 | ⌘L |
| Show the picture in full size | F3 | ⌘B |
| Play the movie | F4 | ⌘E |
| Play the movie in full size | ⌥F4 or ⇧F4 | ⌥⌘E |
| Record the first sound | ⌘F1 | ⇧⌘K |
| Record the second sound | ⌘F2 | ⇧⌘L |
| Capture a picture | ⌘F3 | ⇧⌘B |
| Record a movie | ⌘F4 | ⇧⌘M |

(⌘D was avoided: it answers "Don't Save" in the sheets of macOS.) In the recorder:
Space = record / stop, Return = OK, Esc = Cancel. In the camera window: Return takes
the picture; for a movie Space starts and stops, Return keeps it, Esc cancels.

AppleScript: `start test` (new) next to `import`, `import text` and `export`.

## Obsolete features and what replaces them

| Feature | Why it cannot work | Replacement |
|---|---|---|
| Send to iPod, iPod preferences | No Mac sends notes to an iPod | The command explains it and offers Export… |
| Check for Updates | The update server is gone | The command says so and gives the version |
| Visit Home Page, Send Feedback, Download Vocabulary | The web site is gone | Each explains it; Discover ProVoc Features opens the quick tour of the built-in help |
| Submit Document | The upload server is gone | The command explains it and shows the file in the Finder |
| Dashboard widget offer and log | Dashboard was removed from macOS | No offer; a `Widget.log` in a document is still read |
| Quartz Composer backgrounds | Deprecated; the compositions no longer render | The same four backgrounds drawn with Core Animation |

## How to rebuild

```
brew install xcodegen                      # once
scripts/verify.sh                          # everything: builds, tests, dist/ProVoc.app, this report
```

or only the application:

```
xcodegen generate && xcodebuild -project ProVoc.xcodeproj -scheme ProVoc -configuration Release -derivedDataPath build/DerivedData ARCHS=arm64 ONLY_ACTIVE_ARCH=NO clean build && rm -rf dist && mkdir dist && cp -R build/DerivedData/Build/Products/Release/ProVoc.app dist/ && codesign --force --deep -s - dist/ProVoc.app
```

`scripts/install.sh` copies `dist/ProVoc.app` to `/Applications` (an older copy is moved
to `~/ProVoc backups/` first).

## Training with the keyboard only

1. Open a deck (double-click it, or ⌘O). ⌥⌘2 shows the Training view, ↑ / ↓ choose the training mode.
2. ⌘R starts the test. The answer field has the focus: just type.
3. Return checks the answer. Right: the next word comes at once (when the full answer or a comment is displayed first, Return again).
4. Wrong: the window shakes and the field keeps the focus; type again. After the allowed tries the solution is shown: Return goes on, Y counts it right after all, N wrong.
5. ⌘G gives the solution, ⌘A accepts your answer, ⇧⌘F flags the word, ⌘0…⌘9 label it.
6. ⌘K (or F1) plays the sound of the question, ⌘L (F2) of the answer; ⌘B (F3) shows the picture in full size, ⌘E (F4) plays the movie, ⌥⌘E in full size; Esc leaves full size.
7. ⌘P pauses, ⌘R resumes. Esc finishes (results); ⌥Esc aborts at once.
8. Results: Return repeats the wrong words (Done when there are none), Esc is Done.
9. Multiple choice: 1…9 choose, ↑ / ↓ move, Return verifies, 0 or Space plays the sound.
10. ⇧⌘R is the slideshow (→ next, ← previous, Space play / pause, Esc exit). ⌘S saves, ⌘Q quits.

## What the tests are, and their limits

- XCUITest needs "Automation Mode", which this Mac only enables with an administrator
  password. The interface is therefore driven from inside the application: key events
  (with their key codes) and mouse clicks are posted to its event queue and go through
  `sendEvent:`, the key equivalents, the text input system and the field editor, and the
  visible state is checked. `scripts/deadkey-check.sh` and `scripts/applescript-check.sh`
  drive it from outside with `osascript`.
- The stand-alone scenarios launch the application through LaunchServices, as the Finder
  does, with a small library inserted that plays the scenario from the application's own
  event loop.
- Open and save panels, the Font and Color panels' internals, and drags cannot be played
  by events: the tests check that the panel comes, then do what it would do.
- The tests run in the Debug build, which is compiled with the same optimization as the
  Release build (-Os): they exercise the code as it ships. The Release application
  itself (`dist/ProVoc.app`) is checked for its architecture and signature, launched
  through LaunchServices and quit; `scripts/deadkey-check.sh` can be given its path.
- macOS ties the microphone and camera permission of an ad hoc signed build to its exact
  binary. With `sign.local.xcconfig` (local to a Mac, not in git) the Debug build is
  signed with a development certificate and keeps the permission across rebuilds; the
  Release build is always signed ad hoc.
- The tests need the keyboard focus: the Mac must be left alone while they run. A failure
  caused by another application taking the front says so.
- Spotlight: the importer is tested by loading it as Spotlight does. On the Mac where this
  was developed Spotlight still files `.pvoc` documents under the type name that earlier
  builds of this work registered; a restart of the Mac clears that.
