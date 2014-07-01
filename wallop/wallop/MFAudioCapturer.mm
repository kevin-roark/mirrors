//
//  MFAudioCapturer.m
//  wallop
//
//  Created by Kevin Roark on 6/29/14.
//  Copyright (c) 2014 Miller's Fantasy. All rights reserved.
//

#import "MFAudioCapturer.h"
#import "Novocaine.h"
#import "RingBuffer.h"

#define MAKE_A_WEAKSELF __weak MFAudioCapturer *weakSelf = self

#define BUFFER_SIZE 32768

typedef NS_ENUM(NSUInteger, MFAudioCaptureMode) {
    MFFeedback = 0,
    MFRecording,
    MFPlaying
};

@interface MFAudioCapturer ()

@property (nonatomic, strong) Novocaine *audioManager;
@property (nonatomic, assign) RingBuffer *ringBuffer;

@property (nonatomic) MFAudioCaptureMode captureMode;
@property (nonatomic) NSUInteger framesInWait;

@end

@implementation MFAudioCapturer

- (id)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup
{
    self.audioManager = [Novocaine audioManager];
    self.ringBuffer = new RingBuffer(BUFFER_SIZE, 1);
    self.framesInWait = 0;
    self.captureMode = MFFeedback;
    
    [self setVolumeBoostingInputWithVolume:30.0f];
    
    // set 1 second delay
    MAKE_A_WEAKSELF;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [weakSelf setPlayFromBufferOutput];
    });
}

- (void)mutateAudioModes
{
    if (self.captureMode == MFFeedback) {
        // set to recording for now
        self.captureMode = MFRecording;
        [self setNoOutput];
    } else if (self.captureMode == MFRecording) {
        // set to playing for now
        self.captureMode = MFPlaying;
        [self setNoInput];
        [self setPlayFromBufferOutput];
    } else if (self.captureMode == MFPlaying) {
        // set to feedback for now
        self.captureMode = MFFeedback;
        [self setVolumeBoostingInputWithVolume:20.0f];
    }
}

- (void)start
{
    if (!self.audioManager.playing) {
        [self.audioManager play];
    }
}

- (void)stop
{
    if (self.audioManager.playing) {
        [self.audioManager pause];
    }
}

- (BOOL)running
{
    return self.audioManager.playing;
}

- (void)setNoInput
{
    [self.audioManager setSessionCategory:kAudioSessionCategory_MediaPlayback];
    //[self.audioManager setInputBlock:nil];
}

- (void)someInputSet
{
    [self.audioManager setSessionCategory:kAudioSessionCategory_PlayAndRecord];
}

- (void)setVolumeBoostingInputWithVolume:(float)volume
{
    [self someInputSet];
    
    MAKE_A_WEAKSELF;
    [self.audioManager setInputBlock:^(float *newAudio, UInt32 numFrames, UInt32 numChannels) {
        vDSP_vsmul(newAudio, 1, &volume, newAudio, 1, numFrames * numChannels);
        if (weakSelf.framesInWait + numFrames < BUFFER_SIZE) {
            weakSelf.ringBuffer->AddNewInterleavedFloatData(newAudio, numFrames, numChannels);
            weakSelf.framesInWait += numFrames;
        }
    }];
}

- (void)setNoOutput
{
    [self.audioManager setOutputBlock:nil];
}

- (void)setPlayFromBufferOutput
{
    MAKE_A_WEAKSELF;
    [self.audioManager setOutputBlock:^(float *audioToPlay, UInt32 numFrames, UInt32 numChannels) {
        if (weakSelf.framesInWait >= numFrames) {
            weakSelf.ringBuffer->FetchInterleavedData(audioToPlay, numFrames, numChannels);
            weakSelf.framesInWait -= numFrames;
        }
    }];
}

@end
