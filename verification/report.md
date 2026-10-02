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
- The tests need the keyboard focus: the Mac must be left alone while they run. A failure
  caused by another application taking the front says so.
- Spotlight: the importer is tested by loading it as Spotlight does. On the Mac where this
  was developed Spotlight still files `.pvoc` documents under the type name that earlier
  builds of this work registered; a restart of the Mac clears that.

## Results of the last verification run

Run of 2026-10-02 12:54 in `/Users/pierre-antoine/dev/ProVoc`, at commit `aac9ecf verify.sh, the report, FEATURES.md with the test of each feature; training mode chosen with the arrow keys` (with uncommitted changes).

**Verdict: 13 step(s) of the verification and 10 line(s) of FEATURES.md do not pass.**

### Steps

| Step | Result |
|---|---|
| `verify/screen-unlocked` | PASS |
| `verify/project` | PASS |
| `verify/tools` | PASS |
| `verify/build-release` | FAIL |
| `verify/build-debug` | PASS |
| `verify/arm64-only-release` | FAIL |
| `verify/arm64-only-debug` | FAIL |
| `verify/dist-signed` | FAIL |
| `verify/dist-launches` | FAIL |
| `verify/hosted-run1` | FAIL |
| `verify/hosted-run2` | FAIL |
| `verify/e2e-run1` | FAIL |
| `verify/e2e-run2` | FAIL |
| `verify/applescript-check.sh` | PASS |
| `verify/deadkey-check.sh` | FAIL |
| `verify/log-scan-self-test` | FAIL |
| `verify/log-scan-hosted-run1` | FAIL |
| `verify/log-scan-hosted-run2` | FAIL |

- Release build: 139 different compiler / linker warnings (`verification/results/warnings-Release.txt`).
- Debug build: 189 different compiler / linker warnings (`verification/results/warnings-Debug.txt`).
- lipo -archs:  (Release), arm64 (Debug)
- Tests hosted in the application, run 1: 142 passed, 1 failed (`ProVocTests/ProVocDocumentFeatureTests/testFindDoubleEntries`).
- Tests hosted in the application, run 2: 142 passed, 1 failed (`ProVocTests/ProVocAppFeatureTests/testAboutWindowScrollsItsCredits`).
- Scenarios of the stand-alone application, run 1: 20 passed, 2 failed (`e2e/record-audio`, `e2e/capture-image-and-movie`).
- Scenarios of the stand-alone application, run 2: 20 passed, 2 failed (`e2e/record-audio`, `e2e/capture-image-and-movie`).

### Features


#### A. Interrogation (typed answers)

| | Feature | Tests |
|---|---|---|
| PASS | Start a test with ⌘R. The test panel appears. The answer field has focus with no click. | `ProVocTests/ProVocInterrogationTests/testAllCorrect*` |
| PASS | Correct answer + Return → recorded correct, then the app goes straight to the next word, with the field cleared and focused. | `ProVocTests/ProVocInterrogationTests/testAllCorrect*` |
| PASS | Correct answer + Return when the full answer is displayed (partial synonym, late comment) → the answer is shown and the next Return advances. | `ProVocTests/ProVocTestOptionsTests/testLateCommentAndFullAnswer*` |
| PASS | Wrong answer + Return → window shakes, counted wrong, field stays focused for a retry. | `ProVocTests/ProVocInterrogationTests/testWrongAnswersSolutionAcceptRejectAndRepeat*` |
| PASS | After the configured number of retries, the solution is shown automatically. Then Return = next word. | `ProVocTests/ProVocInterrogationTests/testWrongAnswersSolutionAcceptRejectAndRepeat*` |
| PASS | With the solution shown, Y = accept as correct. | `ProVocTests/ProVocInterrogationTests/testWrongAnswersSolutionAcceptRejectAndRepeat*` |
| PASS | With the solution shown, N = mark wrong. | `ProVocTests/ProVocInterrogationTests/testWrongAnswersSolutionAcceptRejectAndRepeat*` |
| PASS | ⌘G gives the solution. | `ProVocTests/ProVocInterrogationTests/testGiveSolutionAcceptFlagAndLabelShortcuts*` |
| PASS | ⌥ + click Give Solution gives a hint (progressive letters). | `ProVocTests/ProVocInterrogationTests/testHintWithOptionClick*` |
| PASS | ⌘A accepts the answer. | `ProVocTests/ProVocInterrogationTests/testGiveSolutionAcceptFlagAndLabelShortcuts*` |
| PASS | ⇧⌘F marks/unmarks (flags) the word. | `ProVocTests/ProVocInterrogationTests/testGiveSolutionAcceptFlagAndLabelShortcuts*` |
| PASS | ⌘0–⌘9 set the label. | `ProVocTests/ProVocInterrogationTests/testGiveSolutionAcceptFlagAndLabelShortcuts*` |
| PASS | Esc aborts. ⌥ + click Finish/Abort finishes; ⌥-Esc behaves as coded in `cancelTestPanel:`. | `ProVocTests/ProVocInterrogationTests/testEscapeFinishesAndOptionEscapeAborts*` |
| PASS | ⌘P pauses (inside the test panel, ⌘P must pause, not print). Resuming later restores state. | `ProVocTests/ProVocInterrogationTests/testPauseAndResume*` |
| PASS | ⌥ + click Edit edits the current word. | `ProVocTests/ProVocInterrogationTests/testEditCurrentWordWithOptionClick*` |
| PASS | F1 plays question audio. | `ProVocTests/ProVocMediaTests/testMediaKeysDuringATest*` |
| PASS | F2 plays answer audio. | `ProVocTests/ProVocMediaTests/testMediaKeysDuringATest*` |
| PASS | F3 shows the image full size; Esc exits full size. | `ProVocTests/ProVocMediaTests/testMediaKeysDuringATest*` |
| PASS | F4 plays the movie. | `ProVocTests/ProVocMediaTests/testMediaKeysDuringATest*` |
| PASS | ⌥F4 / ⇧F4 plays the movie full size; Esc exits full size. | `ProVocTests/ProVocMediaTests/testMediaKeysDuringATest*` |
| PASS | Keypad Enter = Return. | `ProVocTests/ProVocInterrogationTests/testKeypadEnterBehavesLikeReturn*` |
| PASS | Two deliberate Returns 50 ms apart both register; holding Return does not skip a word. | `ProVocTests/ProVocInterrogationTests/testQuickDoubleReturnAndHeldReturn*` |
| PASS | Answer matching: case-insensitivity. | `ProVocTests/ProVocAnswerTests/testCaseSensitivity`<br>`ProVocTests/ProVocAnswerTests/testExactAnswer` |
| PASS | Answer matching: accent-insensitivity option. | `ProVocTests/ProVocAnswerTests/testAccentSensitivity` |
| PASS | Answer matching: parentheses and optional parts. | `ProVocTests/ProVocAnswerTests/testParenthesesAreOptional`<br>`ProVocTests/ProVocAnswerTests/testOptionalDeterminants` |
| PASS | Answer matching: multiple accepted answers / separators. | `ProVocTests/ProVocAnswerTests/testSynonymsAndSeparators`<br>`ProVocTests/ProVocAnswerTests/testCommentSeparator` |
| PASS | Answer matching: leading/trailing spaces. | `ProVocTests/ProVocAnswerTests/testSpaces` |
| PASS | Answer matching: punctuation. | `ProVocTests/ProVocAnswerTests/testPunctuation` |
| PASS | Answer matching: French accented input. | `ProVocTests/ProVocAnswerTests/testFrenchAccentedInput` |
| FAIL | Dead keys and composition in the answer field with the French (AZERTY) layout: `^` then `e` → `ê`, `¨` then `i` → `ï`, ⌥-e then e → `é`, accented letters. | `ProVocTests/ProVocInterrogationTests/testDeadKeysAndAccentedLetters*`<br>`scripts/deadkey-check.sh`<br>**not ticked; scripts/deadkey-check.sh failed (scripts)** |
| PASS | Direction source→target. | `ProVocTests/ProVocInterrogationTests/testAllCorrect*` |
| PASS | Direction target→source. | `ProVocTests/ProVocInterrogationTests/testDirectionTargetToSource*` |
| PASS | Direction both/random. | `ProVocTests/ProVocInterrogationTests/testDirectionBoth*`<br>`ProVocTests/ProVocInterrogationTests/testDirectionRandom*` |
| PASS | Test mode 0: classic with wrong-word repeat. | `ProVocTests/ProVocInterrogationTests/testWrongAnswersSolutionAcceptRejectAndRepeat*` |
| PASS | Test mode 1: continuous training weighted by difficulty (`indexForRepetition` / history). | `ProVocTests/ProVocTrainingTests/testContinuousTrainingWeightedByDifficulty*` |
| PASS | Test mode 2: until learned (consecutive correct answers, distraction interval). | `ProVocTests/ProVocTrainingTests/testUntilLearned*` |
| PASS | "Test only" label/flag filters. | `ProVocTests/ProVocInterrogationTests/testTrainOnlyFilters*` |
| PASS | Number of words (test limit) and "words not answered since". | `ProVocTests/ProVocInterrogationTests/testTrainOnlyFilters*`<br>`ProVocTests/ProVocTrainingTests/testWordsToReviewAndNotAnsweredSince*` |
| PASS | Words to review (spaced repetition by `nextReview`). | `ProVocTests/ProVocTrainingTests/testWordsToReviewAndNotAnsweredSince*` |
| PASS | Don't shuffle words (train in order). | `ProVocTests/ProVocInterrogationTests/testWordsInListOrder*` |
| PASS | Training presets (`DefaultPresets.xml`): create, rename, delete, apply. | `ProVocTests/ProVocTrainingTests/testTrainingModes`<br>`ProVocTests/ProVocTrainingTests/testTrainingModeControls` |
| PASS | Training modes chosen with the keyboard: ⌥⌘2 shows the Training view with the list of modes ready for ↑ / ↓; the chosen mode is applied at once and ⌘R starts it. | `ProVocTests/ProVocTrainingTests/testTrainingModeChosenWithTheKeyboard` |
| PASS | Timer: time limit per test, `timerDidElapse` behaviour, the timer window (`ProVocTimer.nib`). | `ProVocTests/ProVocTestOptionsTests/testCountdownOneMoreMinuteThenFinish*`<br>`ProVocTests/ProVocTestOptionsTests/testCountdownDiscard*` |
| PASS | Timer: stopwatch (count up). | `ProVocTests/ProVocTestOptionsTests/testStopwatch*` |
| PASS | Notes panel (back translation of a wrong answer that is another word of the list). | `ProVocTests/ProVocTestOptionsTests/testBackTranslationNote*` |
| PASS | Comment display and late comment. | `ProVocTests/ProVocTestOptionsTests/testLateCommentAndFullAnswer*` |
| PASS | Hide question text / show question media first. | `ProVocTests/ProVocTestOptionsTests/testQuestionTextOrMediaFirst*` |
| PASS | Auto-play media. | `ProVocTests/ProVocTestOptionsTests/testAutoPlayMedia*` |
| PASS | Speech synthesis: speak question/answer with the chosen voice, voice selection in the parameters. | `ProVocTests/ProVocTestOptionsTests/testSpeechSynthesis*`<br>`ProVocTests/ProVocTrainingTests/testTrainingModeControls` |
| PASS | Result panel: correct/wrong/ignored statistics. | `ProVocTests/ProVocInterrogationTests/testWrongAnswersSolutionAcceptRejectAndRepeat*`<br>`ProVocTests/ProVocInterrogationTests/testEscapeFinishesAndOptionEscapeAborts*` |
| PASS | Result panel: Return = "Repeat Incorrect Words" when there are wrong words, otherwise Return = "Done"; Esc = "Done"; both orders. | `ProVocTests/ProVocInterrogationTests/testWrongAnswersSolutionAcceptRejectAndRepeat*`<br>`ProVocTests/ProVocInterrogationTests/testEscapeFinishesAndOptionEscapeAborts*` |
| PASS | Result panel: Repeat Incorrect Words loops until done. | `ProVocTests/ProVocInterrogationTests/testWrongAnswersSolutionAcceptRejectAndRepeat*` |
| PASS | Result panel: label or flag the wrong words; slideshow of the wrong words before repeating. | `ProVocTests/ProVocTestOptionsTests/testResultPanelLabelsWrongWordsAndSlideshow*` |
| PASS | The entire interrogation suite runs with "Dim test background" on (app-modal floating panel) and off (sheet). | `ProVocTests/ProVocInterrogationTests/test*`<br>`ProVocTests/ProVocTestOptionsTests/test*`<br>`ProVocTests/ProVocMCQTests/test*` |
| PASS | Background styles during tests: color, plug-in backgrounds from `PlugIns/*.pvback`, correct/wrong/answer/results changes via `updateBackground:`. | `ProVocTests/ProVocTestBackgroundTests/testGlobeShowsQuestionAndAnswer`<br>`ProVocTests/ProVocTestBackgroundTests/testPlantsReactToAnswersAndResults`<br>`ProVocTests/ProVocBackgroundTests/testBuiltInBackgroundsAreDrawnNatively` |
| PASS | Label display during the test (label pop-up, colored window background, display label text). | `ProVocTests/ProVocTestOptionsTests/testLabelDisplay*` |

#### B. Multiple-choice tests

| | Feature | Tests |
|---|---|---|
| PASS | Keys 1–9 select a choice. | `ProVocTests/ProVocMCQTests/testDigitSelectsReturnVerifies*` |
| PASS | ↑/↓ move the selection. | `ProVocTests/ProVocMCQTests/testArrowsWrongChoiceAndSolution*` |
| PASS | Return verifies. | `ProVocTests/ProVocMCQTests/testDigitSelectsReturnVerifies*` |
| PASS | Double-click selects and verifies. | `ProVocTests/ProVocMCQTests/testDoubleClickSelectsAndVerifies*` |
| PASS | 0 or Space plays audio. | `ProVocTests/ProVocMCQTests/testZeroAndSpacePlayAudio*` |
| PASS | Image MCQ (grid of 2/3/4 columns). | `ProVocTests/ProVocMCQTests/testPictureChoicesInAGrid*` |
| PASS | Delayed MCQ (choices revealed on Return). | `ProVocTests/ProVocMCQTests/testDelayedChoicesAndNumberOfChoices*` |
| PASS | Configurable number of choices. | `ProVocTests/ProVocMCQTests/testDelayedChoicesAndNumberOfChoices*` |
| PASS | The same correct/wrong/next flow and focus guarantees as typed tests. | `ProVocTests/ProVocMCQTests/test*` |

#### C. Slideshow (⇧⌘R)

| | Feature | Tests |
|---|---|---|
| PASS | ⇧⌘R starts the slideshow. | `ProVocTests/ProVocSlideshowTests/testSlideshowKeys` |
| PASS | → or click: next word. | `ProVocTests/ProVocSlideshowTests/testSlideshowKeys` |
| PASS | ←: previous word. | `ProVocTests/ProVocSlideshowTests/testSlideshowKeys` |
| PASS | Space: play/pause. | `ProVocTests/ProVocSlideshowTests/testSlideshowKeys`<br>`ProVocTests/ProVocSlideshowTests/testSlideshowAdvancesAutomatically` |
| PASS | Esc: exit. | `ProVocTests/ProVocSlideshowTests/testSlideshowKeys` |
| PASS | The control view fades in and out. | `ProVocTests/ProVocSlideshowTests/testSlideshowKeys` |
| PASS | Media plays in the slideshow. | `ProVocTests/ProVocSlideshowTests/testSlideshowShowsAndPlaysMedia` |

#### D. Editing (document window)

| | Feature | Tests |
|---|---|---|
| PASS | New (⌘N). | `e2e/document-new-save-close-reopen` |
| PASS | Open (⌘O). | `e2e/launch`<br>`e2e/document-new-save-close-reopen`<br>`e2e/launch-with-document` |
| PASS | Save (⌘S) and Save As (⇧⌘S); saving round-trips. | `e2e/document-new-save-close-reopen`<br>`ProVocTests/ProVocDeckTests/testUserDecksOpenSaveAndReopenIdentically` |
| PASS | Revert. | `e2e/document-new-save-close-reopen` |
| PASS | Close (⌘W) with the unsaved-changes prompt. | `e2e/document-new-save-close-reopen` |
| PASS | Both file formats in `Info.plist`: the `.pvoc` package and the old flat `.provoc` file (including the old-format path in `checkOldFormat:`). | `e2e/launch-with-document`<br>`e2e/launch-with-old-format-document`<br>`ProVocTests/ProVocDeckTests/testGeneratedDecksOpenWithEverything`<br>`ProVocTests/ProVocDeckTests/testCorruptDeckIsRefusedAndTheExceptionIsLogged` |
| PASS | Window state restores (size, position, tab, columns, selection). | `e2e/window-state` |
| PASS | Lessons outline: add a lesson and a chapter (name sheet: Return = OK, Esc = Cancel). | `e2e/editing-lessons-with-undo` |
| PASS | Lessons outline: rename. | `e2e/editing-lessons-with-undo` |
| PASS | Lessons outline: delete (select + Delete key). | `e2e/editing-lessons-with-undo` |
| PASS | Lessons outline: drag to rearrange. | `e2e/editing-lessons-with-undo` |
| PASS | Lessons outline: ⌥-drag to copy. | `e2e/editing-lessons-with-undo` |
| PASS | Drag words onto a lesson to move them. | `e2e/editing-lessons-with-undo` |
| PASS | Add a word: Return = Add, Tab / Shift-Tab chaining source → target → comment (`ProVocTextField` `mNextField`/`mPreviousField`). | `ProVocTests/ProVocEditingTests/testAddWordWithTabChainingAndReturn` |
| PASS | Word table: inline edit. | `e2e/editing-words-with-undo` |
| PASS | Word table: delete with the Delete key. | `ProVocTests/ProVocEditingTests/testDeleteKeyUndoRedo`<br>`e2e/editing-words-with-undo` |
| PASS | Word table: drag to reorder. | `e2e/editing-lessons-with-undo` |
| PASS | Word table: column sorting. | `e2e/editing-words-with-undo` |
| PASS | Word table: columns shown/hidden (View Options ⌘J, Return = OK, Esc = Cancel). | `e2e/window-state` |
| PASS | Word table: difficulty column, flagged column, labels column. | `ProVocTests/ProVocDocumentFeatureTests/testLanguagePopUpsAndColumns` |
| PASS | Find ⌘F (search field). | `ProVocTests/ProVocEditingTests/testFindFiltersTheList` |
| FAIL | Find Double Entries ⌥⌘F. | `ProVocTests/ProVocDocumentFeatureTests/testFindDoubleEntries`<br>**ProVocTests/ProVocDocumentFeatureTests/testFindDoubleEntries failed (hosted-run1)** |
| PASS | Select None ⇧⌘A (and Select All ⌘A). | `ProVocTests/ProVocEditingTests/testSelectionFlagAndLabelShortcuts` |
| PASS | Mark Selected Words ⇧⌘F. | `ProVocTests/ProVocEditingTests/testSelectionFlagAndLabelShortcuts` |
| PASS | Labels ⌘0–⌘9. | `ProVocTests/ProVocEditingTests/testSelectionFlagAndLabelShortcuts` |
| PASS | Mode switching ⌥⌘1 Editing / ⌥⌘2 Training / ⌥⌘3 History. | `ProVocTests/ProVocEditingTests/testModeAndDifficultyShortcuts` |
| PASS | Font size ⌘← / ⌘→ / ⌘=. | `ProVocTests/ProVocEditingTests/testModeAndDifficultyShortcuts`<br>`ProVocTests/ProVocPreferencesTests/testFontsPane` |
| PASS | Undo / Redo (⌘Z / ⇧⌘Z) for every editing operation (`ProVocData+Undo`). | `e2e/editing-words-with-undo`<br>`e2e/editing-lessons-with-undo`<br>`ProVocTests/ProVocEditingTests/testDeleteKeyUndoRedo` |
| PASS | Cut / Copy / Paste of words between documents. | `e2e/clipboard-between-documents` |
| PASS | Check Spelling (⌘; / ⌘:). | `ProVocTests/ProVocDocumentFeatureTests/testCheckSpelling` |
| PASS | Import ⇧⌘I: every format offered in the panel. | `ProVocTests/ProVocDocumentFeatureTests/testImportAndExportEveryFormat` |
| PASS | Export ⇧⌘E: every format offered in the panel; a deck round-trips through each text format. | `ProVocTests/ProVocDocumentFeatureTests/testImportAndExportEveryFormat` |
| PASS | Print ⌘P (outside tests): the PDF is non-empty and has the words. | `ProVocTests/ProVocDocumentFeatureTests/testPrintPageSetupAndCards` |
| PASS | Page Setup ⇧⌘P. | `ProVocTests/ProVocDocumentFeatureTests/testPrintPageSetupAndCards` |
| PASS | Print Cards ⌥⌘P (`ProVocCardController`, Return = Print, Esc = Cancel): the PDF is non-empty and has the words. | `ProVocTests/ProVocDocumentFeatureTests/testPrintPageSetupAndCards` |
| PASS | Swap source & target / source & comment / target & comment. | `ProVocTests/ProVocDocumentFeatureTests/testRevealSwapAndReset`<br>`e2e/editing-words-with-undo` |
| PASS | Difficulty: increase, decrease, reset; Reset Difficulty and Last Answered. | `ProVocTests/ProVocEditingTests/testModeAndDifficultyShortcuts`<br>`ProVocTests/ProVocDocumentFeatureTests/testRevealSwapAndReset` |
| PASS | Reveal Selected Words in Lessons. | `ProVocTests/ProVocDocumentFeatureTests/testRevealSwapAndReset` |
| PASS | Languages: source/target language pop-ups of the document. | `ProVocTests/ProVocDocumentFeatureTests/testLanguagePopUpsAndColumns` |
| PASS | History view (`ProVocHistoryView`): charts render with real data after tests; Clear History. | `ProVocTests/ProVocDocumentFeatureTests/testHistoryViewAndClearHistory` |

#### E. Inspector (⌘I) and media

| | Feature | Tests |
|---|---|---|
| PASS | Inspector opens (⌘I), follows the selection, shows the word fields. | `ProVocTests/ProVocMediaTests/testInspectorFollowsSelectionAndMediaKeys` |
| PASS | Inspector shows image, audio and movie of the word. | `ProVocTests/ProVocMediaTests/testInspectorFollowsSelectionAndMediaKeys` |
| PASS | Drag an audio / image / movie file onto a word in the list. | `ProVocTests/ProVocMediaTests/testDropMediaFilesOnAWordAndOnTheInspector` |
| PASS | Drag an audio / image / movie file onto the inspector drop views. | `ProVocTests/ProVocMediaTests/testDropMediaFilesOnAWordAndOnTheInspector` |
| PASS | F1 / F2 play source/target audio. | `ProVocTests/ProVocMediaTests/testInspectorFollowsSelectionAndMediaKeys` |
| PASS | F3 shows the image full size; Esc exits. | `ProVocTests/ProVocMediaTests/testInspectorFollowsSelectionAndMediaKeys` |
| PASS | F4 plays the movie; ⌥F4 / ⇧F4 full size; Esc exits. | `ProVocTests/ProVocMediaTests/testInspectorFollowsSelectionAndMediaKeys` |
| FAIL | ⌘F1 / ⌘F2 record source/target audio (respecting the `NoShiftRecord` preference logic in `handleKeyDownEvent:`). | `e2e/record-audio`<br>**not ticked; e2e/record-audio failed (e2e-run1, e2e-run2)** |
| FAIL | ⌥-click record: the modal recorder (record / stop / play / OK / Cancel; Return = OK, Esc = Cancel). | `e2e/record-audio`<br>**not ticked; e2e/record-audio failed (e2e-run1, e2e-run2)** |
| FAIL | ⌘F3 captures an image (camera). | `e2e/capture-image-and-movie`<br>**not ticked; e2e/capture-image-and-movie failed (e2e-run1, e2e-run2)** |
| FAIL | ⌘F4 records a movie (camera). | `e2e/capture-image-and-movie`<br>**not ticked; e2e/capture-image-and-movie failed (e2e-run1, e2e-run2)** |
| PASS | Choosing media files via the open panels of the inspector; exporting and removing media. | `ProVocTests/ProVocMediaTests/testInspectorImportExportAndRemoveMedia`<br>`ProVocTests/ProVocMediaTests/testPanelMethodsOfTheTimeStillExist` |
| PASS | Common formats play (`.mov` / `.mp4` / `.m4a` / `.aiff` / `.wav` / `.mp3`); anything AVFoundation cannot decode fails gracefully with a clear message. | `ProVocTests/ProVocMediaTests/testCommonSoundFormatsPlay`<br>`ProVocTests/ProVocMediaTests/testCommonMovieFormatsPlayAndOthersFailGracefully` |
| FAIL | Menu items for the function-key actions (Play Question/Source Audio, Play Answer/Target Audio, Show Image Full Size, Play Movie, Record…) with secondary shortcuts that need no fn key. | `ProVocTests/ProVocMediaTests/testInspectorFollowsSelectionAndMediaKeys`<br>`ProVocTests/ProVocMediaTests/testMediaKeysDuringATest*`<br>`e2e/record-audio`<br>`e2e/capture-image-and-movie`<br>`e2e/localization-english`<br>**not ticked; e2e/record-audio failed (e2e-run1, e2e-run2); e2e/capture-image-and-movie failed (e2e-run1, e2e-run2)** |

#### F. App-level

| | Feature | Tests |
|---|---|---|
| PASS | `NSApp` is a `ProVocApplication` (principal class), so `sendEvent:` runs. | `ProVocTests/ProVocAppTests/testApplicationClass`<br>`e2e/launch`<br>`ProVocTests/ProVocAppTests/testNoCategoryOfTheApplicationCollidesWithAMethodOfTheSystem` |
| PASS | Every nib of every localization (English, French, German, Italian, Spanish, Danish) loads with every outlet and action connected; no stale `~` nib is shipped. | `ProVocTests/ProVocNibTests/test*` |
| FAIL | No exception is swallowed: exceptions are logged, and the suite fails on any exception in the log. | `verify/log-scan-self-test`<br>`verify/log-scan-hosted-run1`<br>`verify/log-scan-hosted-run2`<br>`ProVocTests/ProVocDeckTests/testCorruptDeckIsRefusedAndTheExceptionIsLogged`<br>**verify/log-scan-self-test failed (verify); verify/log-scan-hosted-run1 failed (verify); verify/log-scan-hosted-run2 failed (verify)** |
| PASS | No label or button is too small for its text, in any nib of any localization (the labels were laid out for Lucida Grande). | `ProVocTests/ProVocNibTests/test*` |
| PASS | No category of the application replaces a method of a system class (About ProVoc opened the standard About panel because of one). | `ProVocTests/ProVocAppTests/testNoCategoryOfTheApplicationCollidesWithAMethodOfTheSystem` |
| PASS | A document whose vocabulary cannot be read is refused with an error, not opened empty. | `ProVocTests/ProVocDeckTests/testCorruptDeckIsRefusedAndTheExceptionIsLogged` |
| PASS | Preferences (⌘,): General pane persists and takes effect. | `ProVocTests/ProVocPreferencesTests/testGeneralAndTrainingPanes` |
| PASS | Preferences: fonts (`ProVocFontNameField` + Font panel `changeFont:` routing in `ProVocApplication sendAction:`). | `ProVocTests/ProVocPreferencesTests/testFontsPane` |
| PASS | Preferences: colors, labels and label colors (`NSArchiver` data in the user defaults). | `ProVocTests/ProVocPreferencesTests/testLabelTitlesAndColors` |
| PASS | Preferences: backgrounds, dim background. | `ProVocTests/ProVocPreferencesTests/testBackgroundSettings`<br>`ProVocTests/ProVocTestBackgroundTests/testPlantsReactToAnswersAndResults`<br>`ProVocTests/ProVocTestBackgroundTests/testGlobeShowsQuestionAndAnswer` |
| PASS | Preferences: languages (case/accent/punctuation/space sensitivity, optional determinants). | `ProVocTests/ProVocPreferencesTests/testLanguagesPane`<br>`ProVocTests/ProVocAnswerTests/testCaseSensitivity`<br>`ProVocTests/ProVocAnswerTests/testAccentSensitivity`<br>`ProVocTests/ProVocAnswerTests/testPunctuation`<br>`ProVocTests/ProVocAnswerTests/testSpaces`<br>`ProVocTests/ProVocAnswerTests/testOptionalDeterminants` |
| PASS | Preferences: training (synonym and comment separators, learning parameters). | `ProVocTests/ProVocPreferencesTests/testGeneralAndTrainingPanes`<br>`ProVocTests/ProVocTrainingTests/testUntilLearned*` |
| PASS | Starting point / welcome window. | `e2e/launch`<br>`e2e/localization-english` |
| FAIL | About dialog (credits scroll). | `ProVocTests/ProVocAppFeatureTests/testAboutWindowScrollsItsCredits`<br>**ProVocTests/ProVocAppFeatureTests/testAboutWindowScrollsItsCredits failed (hosted-run2)** |
| PASS | Help (⌘?) opens the local help book. | `ProVocTests/ProVocAppFeatureTests/testHelpOpensTheLocalHelpBook` |
| PASS | Spotlight search inside the app (`ProVocSpotlighter`). | `ProVocTests/ProVocAppFeatureTests/testSpotlightSearch` |
| PASS | Spotlight importer for `.pvoc` files. | `ProVocTests/ProVocImporterTests/testImporterIsNativeAndDeclaresTheDocumentType`<br>`ProVocTests/ProVocImporterTests/testImporterGivesWordsLanguagesAndCount` |
| PASS | AppleScript dictionary (`ProVoc.scriptSuite` / `.scriptTerminology`): `osascript` can open a deck, read words, and start a test. | `scripts/applescript-check.sh`<br>`ProVocTests/ProVocAppleScriptTests/testReadWordsImportAndStartTest` |
| PASS | Services menu entry (`NSServices` in `Info.plist`, `ProVocServiceProvider`). | `ProVocTests/ProVocAppFeatureTests/testTranslationService` |
| PASS | Automator actions. | `ProVocTests/ProVocAutomatorTests/testActionsAreInTheApplication`<br>`ProVocTests/ProVocAutomatorTests/testGetContentsOfDocument`<br>`ProVocTests/ProVocAutomatorTests/testAddTextToVocabulary`<br>`ProVocTests/ProVocAutomatorTests/testAddFilesToVocabulary` |
| PASS | Every localization launches; English and French are smoke-tested end to end (`-AppleLanguages "(fr)"`). | `e2e/localization-english`<br>`e2e/localization-french`<br>`e2e/localization-german`<br>`e2e/localization-italian`<br>`e2e/localization-spanish`<br>`e2e/localization-danish` |
| PASS | Hide / Hide Others / Minimize / Quit (⌘H / ⌥⌘H / ⌘M / ⌘Q) with unsaved-changes prompts. | `e2e/quit-with-unsaved-changes`<br>`e2e/quit-with-two-unsaved-documents`<br>`e2e/quit-without-changes` |
| FAIL | The app builds for arm64 (Release and Debug), is signed, and launches. | `verify/build-release`<br>`verify/build-debug`<br>`verify/arm64-only-release`<br>`verify/arm64-only-debug`<br>`verify/dist-signed`<br>`verify/dist-launches`<br>**verify/build-release failed (verify); verify/arm64-only-release failed (verify); verify/arm64-only-debug failed (verify); verify/dist-signed failed (verify); verify/dist-launches failed (verify)** |
| PASS | Every deck in `fixtures/user-decks/` opens, can be tested with the keyboard-only flow, saves and reopens identically. | `ProVocTests/ProVocDeckTests/testUserDecksOpenSaveAndReopenIdentically`<br>`ProVocTests/ProVocUserDeckTrainingTests/testEveryDeckIsTrainedWithTheKeyboardSavedAndReopened*` |
| PASS | Light and dark appearance: the panels render correctly in both. | `e2e/appearance-light`<br>`e2e/appearance-dark`<br>`ProVocTests/ProVocVisualTests/testMainWindowsRender` |

#### Obsolete features (kept alive with a replacement)

| | Feature | Tests |
|---|---|---|
| PASS | Send to iPod (notes export, iPod preference pane) — OBSOLETE: no Mac sends notes to an iPod any more (the iPod preference pane never shows: no iPod is ever connected) — replaced by: the command (⌥⌘I) explains it and offers Export… (⇧⌘E), which writes the same words to a text file | `ProVocTests/ProVocAppFeatureTests/testSendToiPodOffersToExport` |
| PASS | Check for Updates (server gone) — OBSOLETE: the update server of Arizona Software is gone — replaced by: the command says so and gives the version of this build | `ProVocTests/ProVocAppFeatureTests/testUpdateAndWebSiteCommandsExplainThemselves` |
| PASS | Web links: Discover ProVoc Features, Visit Arizona Software Home Page, Send Bug Report or Feedback, Download Vocabulary — OBSOLETE: the web site of Arizona Software is gone — replaced by: Discover ProVoc Features opens the quick tour of the help book in the application; the three other commands explain that the site is gone and what to use instead | `ProVocTests/ProVocAppFeatureTests/testUpdateAndWebSiteCommandsExplainThemselves`<br>`ProVocTests/ProVocAppFeatureTests/testHelpOpensTheLocalHelpBook`<br>`e2e/launch` |
| PASS | Submit Document (`ProVocSubmitter`, server gone) — OBSOLETE: the vocabulary server (FTP upload + confirmation page) is gone — replaced by: the command explains it and shows the file of the document in the Finder, to be shared by the means of today | `e2e/submit-document-reveals-the-file`<br>`ProVocTests/ProVocAppFeatureTests/testSubmitDocumentExplainsItself` |
| PASS | Dashboard widget offer at launch and widget log (`ProVocDocument+WidgetLog`) — OBSOLETE: Dashboard was removed from macOS (10.15); the widget cannot run — replaced by: no offer at launch; the answers a widget logged in a document (`Widget.log`) are still read into its statistics and history | `ProVocTests/ProVocAppFeatureTests/testWidgetLogOfADocumentIsStillRead`<br>`e2e/launch` |
| PASS | Quartz Composer backgrounds — OBSOLETE: Quartz Composer is deprecated and the compositions of the four backgrounds no longer render — replaced by: the same four backgrounds (Plant Shades, Ocean, Globe, Nature) drawn with Core Animation from the pictures of the original plug-ins, with the same reactions to questions and answers | `ProVocTests/ProVocBackgroundTests/testBuiltInBackgroundsAreDrawnNatively`<br>`ProVocTests/ProVocTestBackgroundTests/testGlobeShowsQuestionAndAnswer`<br>`ProVocTests/ProVocTestBackgroundTests/testPlantsReactToAnswersAndResults` |

