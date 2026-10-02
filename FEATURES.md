# ProVoc features

One line per feature. A box is ticked only when the named automated test passes and
exercises the feature through the real application UI.

The tests are named after "test:" (see `scripts/report.py`, which gives a verdict for
each line from the results of `scripts/verify.sh`):

- `ProVocTests/Class/method` run inside the application: key events (with their key
  codes, through `-[ProVocApplication sendEvent:]`, the key equivalents, the text input
  system and the field editor) and mouse clicks are posted to its event queue, and what
  is visible is checked. A name that ends with `*` stands for the two tests made of one
  scenario: `testXInSheet` ("Dim test background" off: the test panel is a sheet) and
  `testXInDimmedModalPanel` (on: an application-modal panel in front of the dimmed
  screen). Both must pass.
- `e2e/name` are scenarios played in the stand-alone application, launched through
  LaunchServices as the Finder does (`scripts/e2e.py`, `ProVocDriver/`): launching,
  documents, undo, quitting, window state, localizations, appearance, recording.
- `scripts/name.sh` drive the application from outside with `osascript`.
- `verify/name` are steps of `scripts/verify.sh` (builds, architectures, signature, logs).

Every suite is run twice in a row by `scripts/verify.sh`; a line passes only if its
tests pass both times.

Notes on behaviour that differs from the wording of the specification are given under the item.

## A. Interrogation (typed answers)

- [x] Start a test with ⌘R. The test panel appears. The answer field has focus with no click. — test: `ProVocTests/ProVocInterrogationTests/testAllCorrect*`
- [x] Correct answer + Return → recorded correct, then the app goes straight to the next word, with the field cleared and focused. — test: `ProVocTests/ProVocInterrogationTests/testAllCorrect*`
- [x] Correct answer + Return when the full answer is displayed (partial synonym, late comment) → the answer is shown and the next Return advances. — test: `ProVocTests/ProVocTestOptionsTests/testLateCommentAndFullAnswer*`
- [x] Wrong answer + Return → window shakes, counted wrong, field stays focused for a retry. — test: `ProVocTests/ProVocInterrogationTests/testWrongAnswersSolutionAcceptRejectAndRepeat*`
- [x] After the configured number of retries, the solution is shown automatically. Then Return = next word. — test: `ProVocTests/ProVocInterrogationTests/testWrongAnswersSolutionAcceptRejectAndRepeat*`
- [x] With the solution shown, Y = accept as correct. — test: `ProVocTests/ProVocInterrogationTests/testWrongAnswersSolutionAcceptRejectAndRepeat*`
- [x] With the solution shown, N = mark wrong. — test: `ProVocTests/ProVocInterrogationTests/testWrongAnswersSolutionAcceptRejectAndRepeat*`
- [x] ⌘G gives the solution. — test: `ProVocTests/ProVocInterrogationTests/testGiveSolutionAcceptFlagAndLabelShortcuts*`
- [x] ⌥ + click Give Solution gives a hint (progressive letters). — test: `ProVocTests/ProVocInterrogationTests/testHintWithOptionClick*`
- [x] ⌘A accepts the answer. — test: `ProVocTests/ProVocInterrogationTests/testGiveSolutionAcceptFlagAndLabelShortcuts*`
- [x] ⇧⌘F marks/unmarks (flags) the word. — test: `ProVocTests/ProVocInterrogationTests/testGiveSolutionAcceptFlagAndLabelShortcuts*`
- [x] ⌘0–⌘9 set the label. — test: `ProVocTests/ProVocInterrogationTests/testGiveSolutionAcceptFlagAndLabelShortcuts*`
- [x] Esc aborts. ⌥ + click Finish/Abort finishes; ⌥-Esc behaves as coded in `cancelTestPanel:`. — test: `ProVocTests/ProVocInterrogationTests/testEscapeFinishesAndOptionEscapeAborts*`
  - As coded in 4.2.3 (and as the button titles say): Esc = "Finish" (the result panel is shown, the words not asked are reported as ignored); with ⌥ the button reads "Abort" and the test is closed at once. The help book describes the two the other way round.
- [x] ⌘P pauses (inside the test panel, ⌘P must pause, not print). Resuming later restores state. — test: `ProVocTests/ProVocInterrogationTests/testPauseAndResume*`
- [x] ⌥ + click Edit edits the current word. — test: `ProVocTests/ProVocInterrogationTests/testEditCurrentWordWithOptionClick*`
- [x] F1 plays question audio. — test: `ProVocTests/ProVocMediaTests/testMediaKeysDuringATest*`
  - Second shortcuts without function keys (Vocabulary menu > Media): ⌘K question / first sound, ⌘L answer / second sound, ⌘B picture in full size, ⌘E movie, ⌥⌘E movie in full size. The original shortcuts are unchanged.
- [x] F2 plays answer audio. — test: `ProVocTests/ProVocMediaTests/testMediaKeysDuringATest*`
- [x] F3 shows the image full size; Esc exits full size. — test: `ProVocTests/ProVocMediaTests/testMediaKeysDuringATest*`
- [x] F4 plays the movie. — test: `ProVocTests/ProVocMediaTests/testMediaKeysDuringATest*`
- [x] ⌥F4 / ⇧F4 plays the movie full size; Esc exits full size. — test: `ProVocTests/ProVocMediaTests/testMediaKeysDuringATest*`
- [x] Keypad Enter = Return. — test: `ProVocTests/ProVocInterrogationTests/testKeypadEnterBehavesLikeReturn*`
- [x] Two deliberate Returns 50 ms apart both register; holding Return does not skip a word. — test: `ProVocTests/ProVocInterrogationTests/testQuickDoubleReturnAndHeldReturn*`
- [x] Answer matching: case-insensitivity. — test: `ProVocTests/ProVocAnswerTests/testCaseSensitivity`, `ProVocTests/ProVocAnswerTests/testExactAnswer`
- [x] Answer matching: accent-insensitivity option. — test: `ProVocTests/ProVocAnswerTests/testAccentSensitivity`
- [x] Answer matching: parentheses and optional parts. — test: `ProVocTests/ProVocAnswerTests/testParenthesesAreOptional`, `ProVocTests/ProVocAnswerTests/testOptionalDeterminants`
- [x] Answer matching: multiple accepted answers / separators. — test: `ProVocTests/ProVocAnswerTests/testSynonymsAndSeparators`, `ProVocTests/ProVocAnswerTests/testCommentSeparator`
- [x] Answer matching: leading/trailing spaces. — test: `ProVocTests/ProVocAnswerTests/testSpaces`
- [x] Answer matching: punctuation. — test: `ProVocTests/ProVocAnswerTests/testPunctuation`
- [x] Answer matching: French accented input. — test: `ProVocTests/ProVocAnswerTests/testFrenchAccentedInput`
- [x] Dead keys and composition in the answer field with the French (AZERTY) layout: `^` then `e` → `ê`, `¨` then `i` → `ï`, ⌥-e then e → `é`, accented letters. — test: `ProVocTests/ProVocInterrogationTests/testDeadKeysAndAccentedLetters*`, `scripts/deadkey-check.sh`, `scripts/deadkey-check-release`
  - `scripts/deadkey-check.sh` has the keys pressed by macOS itself (System Events), typed ahead without waiting, with the French and the ABC layouts, in the test build and in the Release application of `dist/`; it needs the Accessibility permission for the terminal. The hosted tests send the same key codes through the text input system.
- [x] Direction source→target. — test: `ProVocTests/ProVocInterrogationTests/testAllCorrect*`
- [x] Direction target→source. — test: `ProVocTests/ProVocInterrogationTests/testDirectionTargetToSource*`
- [x] Direction both/random. — test: `ProVocTests/ProVocInterrogationTests/testDirectionBoth*`, `ProVocTests/ProVocInterrogationTests/testDirectionRandom*`
- [x] Test mode 0: classic with wrong-word repeat. — test: `ProVocTests/ProVocInterrogationTests/testWrongAnswersSolutionAcceptRejectAndRepeat*`
- [x] Test mode 1: continuous training weighted by difficulty (`indexForRepetition` / history). — test: `ProVocTests/ProVocTrainingTests/testContinuousTrainingWeightedByDifficulty*`
- [x] Test mode 2: until learned (consecutive correct answers, distraction interval). — test: `ProVocTests/ProVocTrainingTests/testUntilLearned*`
- [x] "Test only" label/flag filters. — test: `ProVocTests/ProVocInterrogationTests/testTrainOnlyFilters*`
- [x] Number of words (test limit) and "words not answered since". — test: `ProVocTests/ProVocInterrogationTests/testTrainOnlyFilters*`, `ProVocTests/ProVocTrainingTests/testWordsToReviewAndNotAnsweredSince*`
- [x] Words to review (spaced repetition by `nextReview`). — test: `ProVocTests/ProVocTrainingTests/testWordsToReviewAndNotAnsweredSince*`
- [x] Don't shuffle words (train in order). — test: `ProVocTests/ProVocInterrogationTests/testWordsInListOrder*`
- [x] Training presets (`DefaultPresets.xml`): create, rename, delete, apply. — test: `ProVocTests/ProVocTrainingTests/testTrainingModes`, `ProVocTests/ProVocTrainingTests/testTrainingModeControls`
- [x] Training modes chosen with the keyboard: ⌥⌘2 shows the Training view with the list of modes ready for ↑ / ↓; the chosen mode is applied at once and ⌘R starts it. — test: `ProVocTests/ProVocTrainingTests/testTrainingModeChosenWithTheKeyboard`
- [x] Timer: time limit per test, `timerDidElapse` behaviour, the timer window (`ProVocTimer.nib`). — test: `ProVocTests/ProVocTestOptionsTests/testCountdownOneMoreMinuteThenFinish*`, `ProVocTests/ProVocTestOptionsTests/testCountdownDiscard*`
- [x] Timer: stopwatch (count up). — test: `ProVocTests/ProVocTestOptionsTests/testStopwatch*`
- [x] Notes panel (back translation of a wrong answer that is another word of the list). — test: `ProVocTests/ProVocTestOptionsTests/testBackTranslationNote*`
- [x] Comment display and late comment. — test: `ProVocTests/ProVocTestOptionsTests/testLateCommentAndFullAnswer*`
- [x] Hide question text / show question media first. — test: `ProVocTests/ProVocTestOptionsTests/testQuestionTextOrMediaFirst*`
- [x] Auto-play media. — test: `ProVocTests/ProVocTestOptionsTests/testAutoPlayMedia*`
- [x] Speech synthesis: speak question/answer with the chosen voice, voice selection in the parameters. — test: `ProVocTests/ProVocTestOptionsTests/testSpeechSynthesis*`, `ProVocTests/ProVocTrainingTests/testTrainingModeControls`
- [x] Result panel: correct/wrong/ignored statistics. — test: `ProVocTests/ProVocInterrogationTests/testWrongAnswersSolutionAcceptRejectAndRepeat*`, `ProVocTests/ProVocInterrogationTests/testEscapeFinishesAndOptionEscapeAborts*`
- [x] Result panel: Return = "Repeat Incorrect Words" when there are wrong words, otherwise Return = "Done"; Esc = "Done"; both orders. — test: `ProVocTests/ProVocInterrogationTests/testWrongAnswersSolutionAcceptRejectAndRepeat*`, `ProVocTests/ProVocInterrogationTests/testEscapeFinishesAndOptionEscapeAborts*`
- [x] Result panel: Repeat Incorrect Words loops until done. — test: `ProVocTests/ProVocInterrogationTests/testWrongAnswersSolutionAcceptRejectAndRepeat*`
- [x] Result panel: label or flag the wrong words; slideshow of the wrong words before repeating. — test: `ProVocTests/ProVocTestOptionsTests/testResultPanelLabelsWrongWordsAndSlideshow*`
- [x] The entire interrogation suite runs with "Dim test background" on (app-modal floating panel) and off (sheet). — test: `ProVocTests/ProVocInterrogationTests/test*`, `ProVocTests/ProVocTestOptionsTests/test*`, `ProVocTests/ProVocMCQTests/test*`
- [x] Background styles during tests: color, plug-in backgrounds from `PlugIns/*.pvback`, correct/wrong/answer/results changes via `updateBackground:`. — test: `ProVocTests/ProVocTestBackgroundTests/testGlobeShowsQuestionAndAnswer`, `ProVocTests/ProVocTestBackgroundTests/testPlantsReactToAnswersAndResults`, `ProVocTests/ProVocBackgroundTests/testBuiltInBackgroundsAreDrawnNatively`
- [x] Label display during the test (label pop-up, colored window background, display label text). — test: `ProVocTests/ProVocTestOptionsTests/testLabelDisplay*`

## B. Multiple-choice tests

- [x] Keys 1–9 select a choice. — test: `ProVocTests/ProVocMCQTests/testDigitSelectsReturnVerifies*`
- [x] ↑/↓ move the selection. — test: `ProVocTests/ProVocMCQTests/testArrowsWrongChoiceAndSolution*`
- [x] Return verifies. — test: `ProVocTests/ProVocMCQTests/testDigitSelectsReturnVerifies*`
- [x] Double-click selects and verifies. — test: `ProVocTests/ProVocMCQTests/testDoubleClickSelectsAndVerifies*`
- [x] 0 or Space plays audio. — test: `ProVocTests/ProVocMCQTests/testZeroAndSpacePlayAudio*`
- [x] Image MCQ (grid of 2/3/4 columns). — test: `ProVocTests/ProVocMCQTests/testPictureChoicesInAGrid*`
- [x] Delayed MCQ (choices revealed on Return). — test: `ProVocTests/ProVocMCQTests/testDelayedChoicesAndNumberOfChoices*`
- [x] Configurable number of choices. — test: `ProVocTests/ProVocMCQTests/testDelayedChoicesAndNumberOfChoices*`
- [x] The same correct/wrong/next flow and focus guarantees as typed tests. — test: `ProVocTests/ProVocMCQTests/test*`

## C. Slideshow (⇧⌘R)

- [x] ⇧⌘R starts the slideshow. — test: `ProVocTests/ProVocSlideshowTests/testSlideshowKeys`
- [x] → or click: next word. — test: `ProVocTests/ProVocSlideshowTests/testSlideshowKeys`
- [x] ←: previous word. — test: `ProVocTests/ProVocSlideshowTests/testSlideshowKeys`
- [x] Space: play/pause. — test: `ProVocTests/ProVocSlideshowTests/testSlideshowKeys`, `ProVocTests/ProVocSlideshowTests/testSlideshowAdvancesAutomatically`
- [x] Esc: exit. — test: `ProVocTests/ProVocSlideshowTests/testSlideshowKeys`
- [x] The control view fades in and out. — test: `ProVocTests/ProVocSlideshowTests/testSlideshowKeys`
- [x] Media plays in the slideshow. — test: `ProVocTests/ProVocSlideshowTests/testSlideshowShowsAndPlaysMedia`

## D. Editing (document window)

- [x] New (⌘N). — test: `e2e/document-new-save-close-reopen`
- [x] Open (⌘O). — test: `e2e/launch`, `e2e/document-new-save-close-reopen`, `e2e/launch-with-document`
  - The open and save panels of macOS run in another process and cannot be answered by events sent to the application: the tests check that the shortcut shows the panel, cancel it (Esc is theirs to handle), then do what the panel would do with the chosen file. Documents are also opened from Open Recent and at launch.
- [x] Save (⌘S) and Save As (⇧⌘S); saving round-trips. — test: `e2e/document-new-save-close-reopen`, `ProVocTests/ProVocDeckTests/testUserDecksOpenSaveAndReopenIdentically`
- [x] Revert. — test: `e2e/document-new-save-close-reopen`
- [x] Close (⌘W) with the unsaved-changes prompt. — test: `e2e/document-new-save-close-reopen`
- [x] Both file formats in `Info.plist`: the `.pvoc` package and the old flat `.provoc` file (including the old-format path in `checkOldFormat:`). — test: `e2e/launch-with-document`, `e2e/launch-with-old-format-document`, `ProVocTests/ProVocDeckTests/testGeneratedDecksOpenWithEverything`, `ProVocTests/ProVocDeckTests/testCorruptDeckIsRefusedAndTheExceptionIsLogged`
- [x] Window state restores (size, position, tab, columns, selection). — test: `e2e/window-state`
- [x] Lessons outline: add a lesson and a chapter (name sheet: Return = OK, Esc = Cancel). — test: `e2e/editing-lessons-with-undo`
- [x] Lessons outline: rename. — test: `e2e/editing-lessons-with-undo`
- [x] Lessons outline: delete (select + Delete key). — test: `e2e/editing-lessons-with-undo`
- [x] Lessons outline: drag to rearrange. — test: `e2e/editing-lessons-with-undo`
  - Drags are played at the level of the drop (the data source methods, with a real pasteboard and an `NSDraggingInfo`): the mouse movement of a drag cannot be sent to the application from inside.
- [x] Lessons outline: ⌥-drag to copy. — test: `e2e/editing-lessons-with-undo`
- [x] Drag words onto a lesson to move them. — test: `e2e/editing-lessons-with-undo`
- [x] Add a word: Return = Add, Tab / Shift-Tab chaining source → target → comment (`ProVocTextField` `mNextField`/`mPreviousField`). — test: `ProVocTests/ProVocEditingTests/testAddWordWithTabChainingAndReturn`
- [x] Word table: inline edit. — test: `e2e/editing-words-with-undo`
- [x] Word table: delete with the Delete key. — test: `ProVocTests/ProVocEditingTests/testDeleteKeyUndoRedo`, `e2e/editing-words-with-undo`
- [x] Word table: drag to reorder. — test: `e2e/editing-lessons-with-undo`
- [x] Word table: column sorting. — test: `e2e/editing-words-with-undo`
- [x] Word table: columns shown/hidden (View Options ⌘J, Return = OK, Esc = Cancel). — test: `e2e/window-state`
- [x] Word table: difficulty column, flagged column, labels column. — test: `ProVocTests/ProVocDocumentFeatureTests/testLanguagePopUpsAndColumns`
- [x] Find ⌘F (search field). — test: `ProVocTests/ProVocEditingTests/testFindFiltersTheList`
- [x] Find Double Entries ⌥⌘F. — test: `ProVocTests/ProVocDocumentFeatureTests/testFindDoubleEntries`
- [x] Select None ⇧⌘A (and Select All ⌘A). — test: `ProVocTests/ProVocEditingTests/testSelectionFlagAndLabelShortcuts`
- [x] Mark Selected Words ⇧⌘F. — test: `ProVocTests/ProVocEditingTests/testSelectionFlagAndLabelShortcuts`
- [x] Labels ⌘0–⌘9. — test: `ProVocTests/ProVocEditingTests/testSelectionFlagAndLabelShortcuts`
- [x] Mode switching ⌥⌘1 Editing / ⌥⌘2 Training / ⌥⌘3 History. — test: `ProVocTests/ProVocEditingTests/testModeAndDifficultyShortcuts`
- [x] Font size ⌘← / ⌘→ / ⌘=. — test: `ProVocTests/ProVocEditingTests/testModeAndDifficultyShortcuts`, `ProVocTests/ProVocPreferencesTests/testFontsPane`
  - In 4.2.3 (MainMenu.nib) ⌘→ / ⌘← / ⌘= are the shortcuts of Increase / Decrease / Reset Difficulty; there is no font size command in the menus. The font sizes are set in Preferences > Fonts (`testFontsPane`).
- [x] Undo / Redo (⌘Z / ⇧⌘Z) for every editing operation (`ProVocData+Undo`). — test: `e2e/editing-words-with-undo`, `e2e/editing-lessons-with-undo`, `ProVocTests/ProVocEditingTests/testDeleteKeyUndoRedo`
- [x] Cut / Copy / Paste of words between documents. — test: `e2e/clipboard-between-documents`
- [x] Check Spelling (⌘; / ⌘:). — test: `ProVocTests/ProVocDocumentFeatureTests/testCheckSpelling`
- [x] Import ⇧⌘I: every format offered in the panel. — test: `ProVocTests/ProVocDocumentFeatureTests/testImportAndExportEveryFormat`
  - The panels are shown by the shortcuts, checked (formats, options) and cancelled; each format is then imported and exported through the methods that the panels call with the chosen file.
- [x] Export ⇧⌘E: every format offered in the panel; a deck round-trips through each text format. — test: `ProVocTests/ProVocDocumentFeatureTests/testImportAndExportEveryFormat`
- [x] Print ⌘P (outside tests): the PDF is non-empty and has the words. — test: `ProVocTests/ProVocDocumentFeatureTests/testPrintPageSetupAndCards`
- [x] Page Setup ⇧⌘P. — test: `ProVocTests/ProVocDocumentFeatureTests/testPrintPageSetupAndCards`
- [x] Print Cards ⌥⌘P (`ProVocCardController`, Return = Print, Esc = Cancel): the PDF is non-empty and has the words. — test: `ProVocTests/ProVocDocumentFeatureTests/testPrintPageSetupAndCards`
- [x] Swap source & target / source & comment / target & comment. — test: `ProVocTests/ProVocDocumentFeatureTests/testRevealSwapAndReset`, `e2e/editing-words-with-undo`
- [x] Difficulty: increase, decrease, reset; Reset Difficulty and Last Answered. — test: `ProVocTests/ProVocEditingTests/testModeAndDifficultyShortcuts`, `ProVocTests/ProVocDocumentFeatureTests/testRevealSwapAndReset`
- [x] Reveal Selected Words in Lessons. — test: `ProVocTests/ProVocDocumentFeatureTests/testRevealSwapAndReset`
- [x] Languages: source/target language pop-ups of the document. — test: `ProVocTests/ProVocDocumentFeatureTests/testLanguagePopUpsAndColumns`
- [x] History view (`ProVocHistoryView`): charts render with real data after tests; Clear History. — test: `ProVocTests/ProVocDocumentFeatureTests/testHistoryViewAndClearHistory`

## E. Inspector (⌘I) and media

- [x] Inspector opens (⌘I), follows the selection, shows the word fields. — test: `ProVocTests/ProVocMediaTests/testInspectorFollowsSelectionAndMediaKeys`
- [x] Inspector shows image, audio and movie of the word. — test: `ProVocTests/ProVocMediaTests/testInspectorFollowsSelectionAndMediaKeys`
- [x] Drag an audio / image / movie file onto a word in the list. — test: `ProVocTests/ProVocMediaTests/testDropMediaFilesOnAWordAndOnTheInspector`
- [x] Drag an audio / image / movie file onto the inspector drop views. — test: `ProVocTests/ProVocMediaTests/testDropMediaFilesOnAWordAndOnTheInspector`
- [x] F1 / F2 play source/target audio. — test: `ProVocTests/ProVocMediaTests/testInspectorFollowsSelectionAndMediaKeys`
- [x] F3 shows the image full size; Esc exits. — test: `ProVocTests/ProVocMediaTests/testInspectorFollowsSelectionAndMediaKeys`
- [x] F4 plays the movie; ⌥F4 / ⇧F4 full size; Esc exits. — test: `ProVocTests/ProVocMediaTests/testInspectorFollowsSelectionAndMediaKeys`
- [x] ⌘F1 / ⌘F2 record source/target audio (respecting the `NoShiftRecord` preference logic in `handleKeyDownEvent:`). — test: `e2e/record-audio`
  - macOS has to be told once, by a person, that ProVoc may use the microphone (`scripts/request-capture-access.sh`). Second shortcuts: ⇧⌘K and ⇧⌘L.
- [x] ⌥-click record: the modal recorder (record / stop / play / OK / Cancel; Return = OK, Esc = Cancel). — test: `e2e/record-audio`
- [x] ⌘F3 captures an image (camera). — test: `e2e/capture-image-and-movie`
  - The camera needs the same permission. Second shortcut: ⇧⌘B.
- [x] ⌘F4 records a movie (camera). — test: `e2e/capture-image-and-movie`
  - Second shortcut: ⇧⌘M. Space starts and stops the recording, Return keeps the movie, Esc cancels.
- [x] Choosing media files via the open panels of the inspector; exporting and removing media. — test: `ProVocTests/ProVocMediaTests/testInspectorImportExportAndRemoveMedia`, `ProVocTests/ProVocMediaTests/testPanelMethodsOfTheTimeStillExist`
- [x] Common formats play (`.mov` / `.mp4` / `.m4a` / `.aiff` / `.wav` / `.mp3`); anything AVFoundation cannot decode fails gracefully with a clear message. — test: `ProVocTests/ProVocMediaTests/testCommonSoundFormatsPlay`, `ProVocTests/ProVocMediaTests/testCommonMovieFormatsPlayAndOthersFailGracefully`
- [x] Menu items for the function-key actions (Play Question/Source Audio, Play Answer/Target Audio, Show Image Full Size, Play Movie, Record…) with secondary shortcuts that need no fn key. — test: `ProVocTests/ProVocMediaTests/testInspectorFollowsSelectionAndMediaKeys`, `ProVocTests/ProVocMediaTests/testMediaKeysDuringATest*`, `e2e/record-audio`, `e2e/capture-image-and-movie`, `e2e/localization-english`

## F. App-level

- [x] `NSApp` is a `ProVocApplication` (principal class), so `sendEvent:` runs. — test: `ProVocTests/ProVocAppTests/testApplicationClass`, `e2e/launch`, `ProVocTests/ProVocAppTests/testNoCategoryOfTheApplicationCollidesWithAMethodOfTheSystem`
- [x] Every nib of every localization (English, French, German, Italian, Spanish, Danish) loads with every outlet and action connected; no stale `~` nib is shipped. — test: `ProVocTests/ProVocNibTests/test*`
- [x] No exception is swallowed: exceptions are logged, and the suite fails on any exception in the log. — test: `verify/log-scan-self-test`, `verify/log-scan-hosted-run1`, `verify/log-scan-hosted-run2`, `ProVocTests/ProVocDeckTests/testCorruptDeckIsRefusedAndTheExceptionIsLogged`
- [x] No label or button is too small for its text, in any nib of any localization (the labels were laid out for Lucida Grande). — test: `ProVocTests/ProVocNibTests/test*`
- [x] No category of the application replaces a method of a system class (About ProVoc opened the standard About panel because of one). — test: `ProVocTests/ProVocAppTests/testNoCategoryOfTheApplicationCollidesWithAMethodOfTheSystem`
- [x] A document whose vocabulary cannot be read is refused with an error, not opened empty. — test: `ProVocTests/ProVocDeckTests/testCorruptDeckIsRefusedAndTheExceptionIsLogged`
- [x] Preferences (⌘,): General pane persists and takes effect. — test: `ProVocTests/ProVocPreferencesTests/testGeneralAndTrainingPanes`
- [x] Preferences: fonts (`ProVocFontNameField` + Font panel `changeFont:` routing in `ProVocApplication sendAction:`). — test: `ProVocTests/ProVocPreferencesTests/testFontsPane`
- [x] Preferences: colors, labels and label colors (`NSArchiver` data in the user defaults). — test: `ProVocTests/ProVocPreferencesTests/testLabelTitlesAndColors`
- [x] Preferences: backgrounds, dim background. — test: `ProVocTests/ProVocPreferencesTests/testBackgroundSettings`, `ProVocTests/ProVocTestBackgroundTests/testPlantsReactToAnswersAndResults`, `ProVocTests/ProVocTestBackgroundTests/testGlobeShowsQuestionAndAnswer`
- [x] Preferences: languages (case/accent/punctuation/space sensitivity, optional determinants). — test: `ProVocTests/ProVocPreferencesTests/testLanguagesPane`, `ProVocTests/ProVocAnswerTests/testCaseSensitivity`, `ProVocTests/ProVocAnswerTests/testAccentSensitivity`, `ProVocTests/ProVocAnswerTests/testPunctuation`, `ProVocTests/ProVocAnswerTests/testSpaces`, `ProVocTests/ProVocAnswerTests/testOptionalDeterminants`
- [x] Preferences: training (synonym and comment separators, learning parameters). — test: `ProVocTests/ProVocPreferencesTests/testGeneralAndTrainingPanes`, `ProVocTests/ProVocTrainingTests/testUntilLearned*`
- [x] Starting point / welcome window. — test: `e2e/launch`, `e2e/localization-english`
- [x] About dialog (credits scroll). — test: `ProVocTests/ProVocAppFeatureTests/testAboutWindowScrollsItsCredits`
- [x] Help (⌘?) opens the local help book. — test: `ProVocTests/ProVocAppFeatureTests/testHelpOpensTheLocalHelpBook`
- [x] Spotlight search inside the app (`ProVocSpotlighter`). — test: `ProVocTests/ProVocAppFeatureTests/testSpotlightSearch`
  - The search panel, the query and what is done with its results are tested; what Spotlight has indexed on a given Mac is not something a test can decide.
- [x] Spotlight importer for `.pvoc` files. — test: `ProVocTests/ProVocImporterTests/testImporterIsNativeAndDeclaresTheDocumentType`, `ProVocTests/ProVocImporterTests/testImporterGivesWordsLanguagesAndCount`
  - The importer of the application is loaded as a plug-in and called through the interface Spotlight uses. (The importer of 2008 was a PowerPC / i386 binary: rewritten.)
- [x] AppleScript dictionary (`ProVoc.scriptSuite` / `.scriptTerminology`): `osascript` can open a deck, read words, and start a test. — test: `scripts/applescript-check.sh`, `ProVocTests/ProVocAppleScriptTests/testReadWordsImportAndStartTest`
  - `start test` is a new command (the dictionary of 4.2.3 had `import`, `import text` and `export`): added so that a script can start a test.
- [x] Services menu entry (`NSServices` in `Info.plist`, `ProVocServiceProvider`). — test: `ProVocTests/ProVocAppFeatureTests/testTranslationService`
- [x] Automator actions. — test: `ProVocTests/ProVocAutomatorTests/testActionsAreInTheApplication`, `ProVocTests/ProVocAutomatorTests/testGetContentsOfDocument`, `ProVocTests/ProVocAutomatorTests/testAddTextToVocabulary`, `ProVocTests/ProVocAutomatorTests/testAddFilesToVocabulary`
  - The three actions are built into the application as in 2008. Automator only loads actions of third parties once its user has enabled them (Automator > Third Party Automator Actions…): the tests run the script and the settings view of each action as Automator does, and load the actions with the classes of Automator when that setting is on.
- [x] Every localization launches; English and French are smoke-tested end to end (`-AppleLanguages "(fr)"`). — test: `e2e/localization-english`, `e2e/localization-french`, `e2e/localization-german`, `e2e/localization-italian`, `e2e/localization-spanish`, `e2e/localization-danish`
- [x] Hide / Hide Others / Minimize / Quit (⌘H / ⌥⌘H / ⌘M / ⌘Q) with unsaved-changes prompts. — test: `e2e/quit-with-unsaved-changes`, `e2e/quit-with-two-unsaved-documents`, `e2e/quit-without-changes`
  - Hide Others (⌥⌘H) is checked to be in the menu with its shortcut, not played: it would hide the other applications of the person using this Mac.
- [x] The app builds for arm64 (Release and Debug), is signed, and launches. — test: `verify/clean`, `verify/build-release`, `verify/build-debug`, `verify/arm64-only-release`, `verify/arm64-only-debug`, `verify/dist-signed`, `verify/dist-launches`, `scripts/deadkey-check-release`
- [x] Every deck in `fixtures/user-decks/` opens, can be tested with the keyboard-only flow, saves and reopens identically. — test: `ProVocTests/ProVocDeckTests/testUserDecksOpenSaveAndReopenIdentically`, `ProVocTests/ProVocUserDeckTrainingTests/testEveryDeckIsTrainedWithTheKeyboardSavedAndReopened*`
  - `fixtures/user-decks/` holds copies of real decks and is not in git: in a fresh checkout, `PV_USER_DECKS=<folder> scripts/verify.sh` copies them.
- [x] Light and dark appearance: the panels render correctly in both. — test: `e2e/appearance-light`, `e2e/appearance-dark`, `ProVocTests/ProVocVisualTests/testMainWindowsRender`

## Obsolete features (kept alive with a replacement)

- [x] Send to iPod (notes export, iPod preference pane) — OBSOLETE: no Mac sends notes to an iPod any more (the iPod preference pane never shows: no iPod is ever connected) — replaced by: the command (⌥⌘I) explains it and offers Export… (⇧⌘E), which writes the same words to a text file — test: `ProVocTests/ProVocAppFeatureTests/testSendToiPodOffersToExport`
- [x] Check for Updates (server gone) — OBSOLETE: the update server of Arizona Software is gone — replaced by: the command says so and gives the version of this build — test: `ProVocTests/ProVocAppFeatureTests/testUpdateAndWebSiteCommandsExplainThemselves`
- [x] Web links: Discover ProVoc Features, Visit Arizona Software Home Page, Send Bug Report or Feedback, Download Vocabulary — OBSOLETE: the web site of Arizona Software is gone — replaced by: Discover ProVoc Features opens the quick tour of the help book in the application; the three other commands explain that the site is gone and what to use instead — test: `ProVocTests/ProVocAppFeatureTests/testUpdateAndWebSiteCommandsExplainThemselves`, `ProVocTests/ProVocAppFeatureTests/testHelpOpensTheLocalHelpBook`, `e2e/launch`
- [x] Submit Document (`ProVocSubmitter`, server gone) — OBSOLETE: the vocabulary server (FTP upload + confirmation page) is gone — replaced by: the command explains it and shows the file of the document in the Finder, to be shared by the means of today — test: `e2e/submit-document-reveals-the-file`, `ProVocTests/ProVocAppFeatureTests/testSubmitDocumentExplainsItself`
- [x] Dashboard widget offer at launch and widget log (`ProVocDocument+WidgetLog`) — OBSOLETE: Dashboard was removed from macOS (10.15); the widget cannot run — replaced by: no offer at launch; the answers a widget logged in a document (`Widget.log`) are still read into its statistics and history — test: `ProVocTests/ProVocAppFeatureTests/testWidgetLogOfADocumentIsStillRead`, `e2e/launch`
- [x] Quartz Composer backgrounds — OBSOLETE: Quartz Composer is deprecated and the compositions of the four backgrounds no longer render — replaced by: the same four backgrounds (Plant Shades, Ocean, Globe, Nature) drawn with Core Animation from the pictures of the original plug-ins, with the same reactions to questions and answers — test: `ProVocTests/ProVocBackgroundTests/testBuiltInBackgroundsAreDrawnNatively`, `ProVocTests/ProVocTestBackgroundTests/testGlobeShowsQuestionAndAnswer`, `ProVocTests/ProVocTestBackgroundTests/testPlantsReactToAnswersAndResults`
