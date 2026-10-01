//
//  SoundRecorderController.m
//  ProVoc
//

#import "SoundRecorderController.h"

#import <AVFoundation/AVFoundation.h>

#define OK 1
#define CANCEL 0

static NSString *ProVocNewCaptureFile(NSString *inExtension)
{
	static int index = 0;
	NSString *name = [NSString stringWithFormat:@"ProVoc Recording %i-%i.%@", [[NSProcessInfo processInfo] processIdentifier], ++index, inExtension];
	return [NSTemporaryDirectory() stringByAppendingPathComponent:name];
}

static NSButton *ProVocPanelButton(NSString *inTitleKey, NSRect inFrame, id inTarget, SEL inAction, NSString *inKeyEquivalent, NSString *inIdentifier)
{
	NSButton *button = [[[NSButton alloc] initWithFrame:inFrame] autorelease];
	[button setBezelStyle:NSBezelStyleRounded];
	[button setTitle:NSLocalizedString(inTitleKey, @"")];
	[button setTarget:inTarget];
	[button setAction:inAction];
	[button setKeyEquivalent:inKeyEquivalent];
	[button setAccessibilityIdentifier:inIdentifier];
	return button;
}

BOOL ProVocEnsureCaptureAccess(NSString *inMediaType)
{
	BOOL audio = [inMediaType isEqualToString:AVMediaTypeAudio];
	AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:inMediaType];
	if (status == AVAuthorizationStatusNotDetermined) {
		// the system asks the user; keep the application alive meanwhile (also inside a modal session)
		__block BOOL answered = NO;
		[AVCaptureDevice requestAccessForMediaType:inMediaType completionHandler:^(BOOL inGranted) {
			dispatch_async(dispatch_get_main_queue(), ^{ answered = YES; });
		}];
		while (!answered)
			[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
		status = [AVCaptureDevice authorizationStatusForMediaType:inMediaType];
	}
	NSString *problem = nil;
	if (status != AVAuthorizationStatusAuthorized)
		problem = audio ? @"Microphone Access Denied Message" : @"Camera Access Denied Message";
	else if (![AVCaptureDevice defaultDeviceWithMediaType:inMediaType])
		problem = audio ? @"No Microphone Message" : @"No Camera Message";
	if (!problem)
		return YES;

	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setMessageText:NSLocalizedString(audio ? @"Microphone Unavailable Title" : @"Camera Unavailable Title", @"")];
	[alert setInformativeText:NSLocalizedString(problem, @"")];
	[alert addButtonWithTitle:NSLocalizedString(@"OK", @"")];
	if (status != AVAuthorizationStatusAuthorized)
		[alert addButtonWithTitle:NSLocalizedString(@"Open System Settings Button", @"")];
	if ([alert runModal] == NSAlertSecondButtonReturn)
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:audio ? @"x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone" : @"x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"]];
	return NO;
}

@implementation SoundRecorderController

+(SoundRecorderController *)sharedController
{
	static SoundRecorderController *sharedController = nil;
	if (!sharedController)
		sharedController = [[self alloc] init];
	return sharedController;
}

-(id)init
{
	NSPanel *panel = [[[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 380, 132) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:YES] autorelease];
	if (self = [super initWithWindow:panel]) {
		[panel setTitle:NSLocalizedString(@"Recorder Window Title", @"")];
		[panel setReleasedWhenClosed:NO];
		NSView *content = [panel contentView];

		mStatusField = [[NSTextField labelWithString:@""] retain];
		[mStatusField setFrame:NSMakeRect(20, 98, 340, 18)];
		[mStatusField setAccessibilityIdentifier:@"RecorderStatus"];
		[content addSubview:mStatusField];

		mLevelIndicator = [[NSLevelIndicator alloc] initWithFrame:NSMakeRect(20, 70, 340, 16)];
		[mLevelIndicator setLevelIndicatorStyle:NSLevelIndicatorStyleContinuousCapacity];
		[mLevelIndicator setMinValue:0];
		[mLevelIndicator setMaxValue:1];
		[mLevelIndicator setWarningValue:0.8];
		[mLevelIndicator setCriticalValue:0.95];
		[content addSubview:mLevelIndicator];

		mRecordButton = [ProVocPanelButton(@"Recorder Record Button", NSMakeRect(14, 13, 96, 32), self, @selector(record:), @" ", @"RecorderRecord") retain];
		mPlayButton = [ProVocPanelButton(@"Recorder Play Button", NSMakeRect(106, 13, 80, 32), self, @selector(play:), @"", @"RecorderPlay") retain];
		NSButton *cancelButton = ProVocPanelButton(@"Recorder Cancel Button", NSMakeRect(192, 13, 90, 32), self, @selector(close:), @"\033", @"RecorderCancel");
		mOKButton = [ProVocPanelButton(@"Recorder OK Button", NSMakeRect(278, 13, 90, 32), self, @selector(close:), @"\r", @"RecorderOK") retain];
		[mOKButton setTag:OK];
		[cancelButton setTag:CANCEL];
		for (NSButton *button in @[mRecordButton, mPlayButton, cancelButton, mOKButton])
			[content addSubview:button];
	}
	return self;
}

-(void)dealloc
{
	[mTimer invalidate];
	[mRecorder release];
	[mPlayingSound release];
	[mRecordedFile release];
	[mRecordButton release];
	[mPlayButton release];
	[mOKButton release];
	[mStatusField release];
	[mLevelIndicator release];
	[super dealloc];
}

-(NSString *)recordedFile
{
	return mHasRecordedSound ? mRecordedFile : nil;
}

-(BOOL)isRecording
{
	return [mRecorder isRecording];
}

-(void)update:(id)inSender
{
	BOOL recording = [self isRecording];
	[mRecordButton setTitle:NSLocalizedString(recording ? @"Recorder Stop Button" : @"Recorder Record Button", @"")];
	[mPlayButton setEnabled:!recording && mHasRecordedSound];
	[mOKButton setEnabled:recording || mHasRecordedSound];
	if (recording) {
		[mRecorder updateMeters];
		[mLevelIndicator setDoubleValue:pow(10, [mRecorder averagePowerForChannel:0] / 20) * 3];
		[mStatusField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Recorder Recording Status (%.1f s)", @""), [mRecorder currentTime]]];
	} else {
		[mLevelIndicator setDoubleValue:0];
		[mStatusField setStringValue:NSLocalizedString(mHasRecordedSound ? @"Recorder Recorded Status" : @"Recorder Ready Status", @"")];
	}
}

-(void)stopPlaying
{
	[mPlayingSound stop];
	[mPlayingSound release];
	mPlayingSound = nil;
}

-(void)startRecording
{
	[self stopPlaying];
	[mRecorder release];
	[mRecordedFile release];
	mRecordedFile = [ProVocNewCaptureFile(@"m4a") retain];
	mHasRecordedSound = NO;
	NSDictionary *settings = @{AVFormatIDKey: @(kAudioFormatMPEG4AAC), AVSampleRateKey: @44100.0, AVNumberOfChannelsKey: @1, AVEncoderAudioQualityKey: @(AVAudioQualityHigh)};
	NSError *error = nil;
	mRecorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:mRecordedFile] settings:settings error:&error];
	[mRecorder setMeteringEnabled:YES];
	if (![mRecorder record]) {
		NSLog(@"ProVoc: cannot record sound: %@", error);
		[mRecorder release];
		mRecorder = nil;
		NSBeep();
	}
	[self update:nil];
}

-(void)stopRecording
{
	if ([self isRecording]) {
		[mRecorder stop];
		mHasRecordedSound = [[NSFileManager defaultManager] fileExistsAtPath:mRecordedFile];
	}
	[self update:nil];
}

-(IBAction)record:(id)inSender
{
	if ([self isRecording])
		[self stopRecording];
	else
		[self startRecording];
}

-(IBAction)play:(id)inSender
{
	[self stopPlaying];
	if (mHasRecordedSound) {
		mPlayingSound = [[NSSound alloc] initWithContentsOfFile:mRecordedFile byReference:YES];
		[mPlayingSound play];
	}
}

-(IBAction)close:(id)inSender
{
	[self stopRecording];
	[self stopPlaying];
	[NSApp stopModalWithCode:[inSender tag] == OK && mHasRecordedSound ? OK : CANCEL];
}

-(IBAction)settings:(id)inSender
{
	// "Sound Input…": the input device and its level are chosen in the system settings
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.Sound-Settings.extension?input"]];
}

-(BOOL)runRecordingImmediately:(BOOL)inRecordImmediately
{
	if (!ProVocEnsureCaptureAccess(AVMediaTypeAudio))
		return NO;
	mHasRecordedSound = NO;
	[[self window] center];
	[self update:nil];
	if (inRecordImmediately)
		[self startRecording];
	mTimer = [NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(update:) userInfo:nil repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:mTimer forMode:NSRunLoopCommonModes];
	NSInteger result = [NSApp runModalForWindow:[self window]];
	[mTimer invalidate];
	mTimer = nil;
	[self stopRecording];
	[[self window] orderOut:nil];
	if (result != OK) {
		[[NSFileManager defaultManager] removeItemAtPath:mRecordedFile error:NULL];
		mHasRecordedSound = NO;
	}
	return result == OK;
}

-(BOOL)runModal
{
	return [self runRecordingImmediately:NO];
}

-(NSString *)singleShotRecord
{
	return [self runRecordingImmediately:YES] ? [self recordedFile] : nil;
}

@end

@interface ProVocCameraGrabber () <AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate>
@end

@implementation ProVocCameraGrabber

+(ProVocCameraGrabber *)sharedGrabber
{
	static ProVocCameraGrabber *sharedGrabber = nil;
	if (!sharedGrabber)
		sharedGrabber = [[self alloc] init];
	return sharedGrabber;
}

-(id)init
{
	NSPanel *panel = [[[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 480, 430) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:YES] autorelease];
	if (self = [super initWithWindow:panel]) {
		[panel setReleasedWhenClosed:NO];
		NSView *content = [panel contentView];

		mPreviewView = [[NSView alloc] initWithFrame:NSMakeRect(0, 70, 480, 360)];
		[mPreviewView setWantsLayer:YES];
		[[mPreviewView layer] setBackgroundColor:[[NSColor blackColor] CGColor]];
		[mPreviewView setAccessibilityIdentifier:@"CameraPreview"];
		[content addSubview:mPreviewView];

		mStatusField = [[NSTextField labelWithString:@""] retain];
		[mStatusField setFrame:NSMakeRect(20, 46, 440, 18)];
		[mStatusField setAccessibilityIdentifier:@"CameraStatus"];
		[content addSubview:mStatusField];

		mActionButton = [ProVocPanelButton(@"Camera Capture Button", NSMakeRect(14, 8, 110, 32), self, @selector(action:), @"", @"CameraAction") retain];
		NSButton *cancelButton = ProVocPanelButton(@"Recorder Cancel Button", NSMakeRect(292, 8, 90, 32), self, @selector(close:), @"\033", @"CameraCancel");
		mOKButton = [ProVocPanelButton(@"Recorder OK Button", NSMakeRect(378, 8, 90, 32), self, @selector(close:), @"\r", @"CameraOK") retain];
		[mOKButton setTag:OK];
		[cancelButton setTag:CANCEL];
		for (NSButton *button in @[mActionButton, cancelButton, mOKButton])
			[content addSubview:button];
	}
	return self;
}

-(void)dealloc
{
	[mSession release];
	[mPhotoOutput release];
	[mMovieOutput release];
	[mPreviewLayer release];
	[mCapturedImage release];
	[mMovieFile release];
	[mPreviewView release];
	[mActionButton release];
	[mOKButton release];
	[mStatusField release];
	[super dealloc];
}

-(BOOL)isRecordingMovie
{
	return mCapturingMovie;
}

-(BOOL)startSessionForMovie:(BOOL)inMovie
{
	if (!ProVocEnsureCaptureAccess(AVMediaTypeVideo))
		return NO;
	mSession = [[AVCaptureSession alloc] init];
	NSError *error = nil;
	AVCaptureDeviceInput *camera = [AVCaptureDeviceInput deviceInputWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo] error:&error];
	if (!camera || ![mSession canAddInput:camera]) {
		NSLog(@"ProVoc: cannot use the camera: %@", error);
		[mSession release];
		mSession = nil;
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setMessageText:NSLocalizedString(@"Camera Unavailable Title", @"")];
		[alert setInformativeText:error ? [error localizedDescription] : NSLocalizedString(@"No Camera Message", @"")];
		[alert runModal];
		return NO;
	}
	[mSession addInput:camera];
	if (inMovie) {
		// the sound too, if the microphone may be used (no question asked here)
		if ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio] == AVAuthorizationStatusAuthorized) {
			AVCaptureDevice *microphone = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
			AVCaptureDeviceInput *audio = microphone ? [AVCaptureDeviceInput deviceInputWithDevice:microphone error:NULL] : nil;
			if (audio && [mSession canAddInput:audio])
				[mSession addInput:audio];
		}
		mMovieOutput = [[AVCaptureMovieFileOutput alloc] init];
		if ([mSession canAddOutput:mMovieOutput])
			[mSession addOutput:mMovieOutput];
	} else {
		mPhotoOutput = [[AVCapturePhotoOutput alloc] init];
		if ([mSession canAddOutput:mPhotoOutput])
			[mSession addOutput:mPhotoOutput];
	}
	mPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:mSession];
	[mPreviewLayer setFrame:[[mPreviewView layer] bounds]];
	[mPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
	[[mPreviewView layer] addSublayer:mPreviewLayer];
	[mSession startRunning];
	return YES;
}

-(void)stopSession
{
	[mSession stopRunning];
	[mPreviewLayer removeFromSuperlayer];
	[mPreviewLayer release];
	mPreviewLayer = nil;
	[mPhotoOutput release];
	mPhotoOutput = nil;
	[mMovieOutput release];
	mMovieOutput = nil;
	[mSession release];
	mSession = nil;
}

-(void)update
{
	if (mMovieOutput) {
		[mActionButton setTitle:NSLocalizedString(mCapturingMovie ? @"Recorder Stop Button" : @"Recorder Record Button", @"")];
		[mOKButton setEnabled:mCapturingMovie || mHasCapturedMovie];
		[mStatusField setStringValue:NSLocalizedString(mCapturingMovie ? @"Camera Recording Status" : mHasCapturedMovie ? @"Recorder Recorded Status" : @"Camera Movie Ready Status", @"")];
	} else {
		[mActionButton setTitle:NSLocalizedString(@"Camera Capture Button", @"")];
		[mStatusField setStringValue:NSLocalizedString(@"Camera Image Ready Status", @"")];
	}
}

// Image: Return (or the Capture button) takes the picture and closes the window.
// Movie: the button (or Space) starts and stops; Return stops if needed and keeps the movie.
-(IBAction)action:(id)inSender
{
	if (mPhotoOutput)
		[mPhotoOutput capturePhotoWithSettings:[AVCapturePhotoSettings photoSettings] delegate:self];
	else if (mCapturingMovie)
		[mMovieOutput stopRecording];
	else {
		[mMovieFile release];
		mMovieFile = [ProVocNewCaptureFile(@"mov") retain];
		mHasCapturedMovie = NO;
		mCapturingMovie = YES;
		[mMovieOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:mMovieFile] recordingDelegate:self];
		[self update];
	}
}

-(IBAction)close:(id)inSender
{
	if ([inSender tag] != OK)
		[NSApp stopModalWithCode:CANCEL];
	else if (mPhotoOutput)
		[self action:inSender];
	else if (mCapturingMovie) {
		// the delegate ends the modal session once the file is complete
		mCloseWhenRecorded = YES;
		[mMovieOutput stopRecording];
	} else
		[NSApp stopModalWithCode:mHasCapturedMovie ? OK : CANCEL];
}

-(void)captureOutput:(AVCapturePhotoOutput *)inOutput didFinishProcessingPhoto:(AVCapturePhoto *)inPhoto error:(NSError *)inError
{
	NSData *data = [inPhoto fileDataRepresentation];
	dispatch_async(dispatch_get_main_queue(), ^{
		[mCapturedImage release];
		mCapturedImage = data ? [[NSImage alloc] initWithData:data] : nil;
		if (!mCapturedImage)
			NSLog(@"ProVoc: no picture captured: %@", inError);
		[NSApp stopModalWithCode:mCapturedImage ? OK : CANCEL];
	});
}

-(void)captureOutput:(AVCaptureFileOutput *)inOutput didFinishRecordingToOutputFileAtURL:(NSURL *)inURL fromConnections:(NSArray *)inConnections error:(NSError *)inError
{
	BOOL recorded = [[NSFileManager defaultManager] fileExistsAtPath:[inURL path]] && (!inError || [[[inError userInfo] objectForKey:AVErrorRecordingSuccessfullyFinishedKey] boolValue]);
	dispatch_async(dispatch_get_main_queue(), ^{
		mCapturingMovie = NO;
		mHasCapturedMovie = recorded;
		if (!recorded)
			NSLog(@"ProVoc: no movie recorded: %@", inError);
		[self update];
		if (mCloseWhenRecorded)
			[NSApp stopModalWithCode:recorded ? OK : CANCEL];
	});
}

-(NSInteger)runForMovie:(BOOL)inMovie
{
	if (![self startSessionForMovie:inMovie])
		return CANCEL;
	[mCapturedImage release];
	mCapturedImage = nil;
	mCapturingMovie = NO;
	mHasCapturedMovie = NO;
	mCloseWhenRecorded = NO;
	[mOKButton setHidden:!inMovie];
	[mActionButton setKeyEquivalent:inMovie ? @" " : @"\r"];
	[[self window] setTitle:NSLocalizedString(inMovie ? @"Camera Movie Window Title" : @"Camera Image Window Title", @"")];
	[[self window] center];
	[self update];
	NSInteger result = [NSApp runModalForWindow:[self window]];
	[[self window] orderOut:nil];
	[self stopSession];
	return result;
}

-(NSImage *)captureImage
{
	return [self runForMovie:NO] == OK ? [[mCapturedImage retain] autorelease] : nil;
}

-(NSString *)captureMovie
{
	if ([self runForMovie:YES] == OK)
		return mMovieFile;
	if (mMovieFile)
		[[NSFileManager defaultManager] removeItemAtPath:mMovieFile error:NULL];
	return nil;
}

@end
