//
//  SoundRecorderController.h
//  ProVoc
//
//  Recording sounds, and capturing images and movies with the camera, for the
//  words of a document. They replace the ARLeopardSoundRecorder and
//  ARSequenceGrabber frameworks of the original (QuickTime sequence grabber),
//  with AVFoundation.
//

#import <Cocoa/Cocoa.h>

@class AVAudioRecorder, AVCaptureSession, AVCapturePhotoOutput, AVCaptureMovieFileOutput, AVCaptureVideoPreviewLayer;

// A small modal recorder: Record / Stop, Play, OK (Return), Cancel (Esc).
@interface SoundRecorderController : NSWindowController {
	AVAudioRecorder *mRecorder;
	NSSound *mPlayingSound;
	NSString *mRecordedFile;
	BOOL mHasRecordedSound;
	NSTimer *mTimer;

	NSButton *mRecordButton;
	NSButton *mPlayButton;
	NSButton *mOKButton;
	NSTextField *mStatusField;
	NSLevelIndicator *mLevelIndicator;
}

+(SoundRecorderController *)sharedController;

// Shows the recorder; YES if a sound was recorded and accepted (see -recordedFile).
-(BOOL)runModal;
-(NSString *)recordedFile;

// Shows the recorder already recording; Return stops and keeps the sound.
// Returns the recorded file, or nil if cancelled.
-(NSString *)singleShotRecord;

-(BOOL)isRecording;

-(IBAction)record:(id)inSender;
-(IBAction)play:(id)inSender;
-(IBAction)close:(id)inSender;
-(IBAction)settings:(id)inSender;

@end

// A modal camera window: Capture (Return) for a picture, Record / Stop then OK for a movie.
@interface ProVocCameraGrabber : NSWindowController {
	AVCaptureSession *mSession;
	AVCapturePhotoOutput *mPhotoOutput;
	AVCaptureMovieFileOutput *mMovieOutput;
	AVCaptureVideoPreviewLayer *mPreviewLayer;
	NSImage *mCapturedImage;
	NSString *mMovieFile;
	BOOL mCapturingMovie;
	BOOL mHasCapturedMovie;
	BOOL mCloseWhenRecorded;

	NSView *mPreviewView;
	NSButton *mActionButton;
	NSButton *mOKButton;
	NSTextField *mStatusField;
}

+(ProVocCameraGrabber *)sharedGrabber;

// nil if cancelled or if there is no camera / no permission (the user is told why)
-(NSImage *)captureImage;
-(NSString *)captureMovie;

-(BOOL)isRecordingMovie;

@end

// YES if the microphone (AVMediaTypeAudio) or the camera (AVMediaTypeVideo) can be
// used; asks for the permission the first time, and explains what to do otherwise.
BOOL ProVocEnsureCaptureAccess(NSString *inMediaType);
