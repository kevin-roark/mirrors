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
#import "MFAudioLooper.h"

#define MAKE_A_WEAKSELF __weak MFAudioCapturer *weakSelf = self

#define BUFFER_SIZE 32768

typedef NS_ENUM(NSUInteger, MFAudioCaptureMode) {
    MFFeedback = 0,
    MFRecording,
    MFPlaying
};

@interface MFAudioCapturer ()

@property (nonatomic, strong) Novocaine *audioManager;
@property (nonatomic, assign) RingBuffer *mainRingBuffer;
@property (nonatomic, strong) MFAudioLooper *currentLooper;

@property (nonatomic) NSUInteger numEchos;

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
    self.mainRingBuffer = new RingBuffer(BUFFER_SIZE, 1);
    self.framesInWait = 0;
    self.captureMode = MFFeedback;
    
    [self setVolumeBoostingInputWithVolume:1.4f];
    [self setNoOutput];

    self.numEchos = 0;
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
        [self.audioManager setForceOutputToSpeaker:YES];
        [self.audioManager play];
        
        // set 1 second delay
        MAKE_A_WEAKSELF;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            NSLog(@"beginning playback");
            [weakSelf setPlayFromBufferOutput];
            [weakSelf beginLoopCapture];
        });
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

- (void)beginLoopCapture
{
    // set 3 second delay
    MAKE_A_WEAKSELF;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [weakSelf createLooper];
    });
}

- (void)createLooper
{
    NSLog(@"creating looper");
    self.currentLooper = [MFAudioLooper audioLooperWithRandomFramesWithChannels:self.audioManager.numInputChannels];
    ++self.numEchos;
}

#pragma mark -> Input

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
        if (weakSelf.framesInWait + numFrames < BUFFER_SIZE / numChannels) {
            [weakSelf addDataToRingBuffers:newAudio numFrames:numFrames numChannels:numChannels];
        }
    }];
}

- (void)addDataToRingBuffers:(float *)data numFrames:(UInt32)numFrames numChannels:(UInt32)numChannels
{
    self.mainRingBuffer->AddNewInterleavedFloatData(data, numFrames, numChannels);
    self.framesInWait += numFrames;
    
    if (self.currentLooper && !self.currentLooper.readyToPlay) {
        [self.currentLooper addAudio:data numFrames:numFrames];
    }
}

#pragma mark -> Output

- (void)setNoOutput
{
    [self.audioManager setOutputBlock:nil];
}

- (void)setPlayFromBufferOutput
{
    MAKE_A_WEAKSELF;
    [self.audioManager setOutputBlock:^(float *audioToPlay, UInt32 numFrames, UInt32 numChannels) {
        if (weakSelf.framesInWait >= numFrames) {
            weakSelf.mainRingBuffer->FetchInterleavedData(audioToPlay, numFrames, numChannels);
            weakSelf.framesInWait -= numFrames;
            
            if (weakSelf.currentLooper && weakSelf.currentLooper.readyToPlay) {
                if (weakSelf.currentLooper.timesLooped <= 5) {
                    float freshAudioBuffer[numFrames * numChannels];
                    [weakSelf.currentLooper fillAudio:freshAudioBuffer numFrames:numFrames numChannels:numChannels];
                    
                    // combine audio from loop and main buffer
                    vDSP_vadd(audioToPlay, 1, freshAudioBuffer, 1, audioToPlay, 1, numFrames * numChannels);
                } else {
                    [weakSelf createLooper];
                }
            }
        }
    }];
}

- (void)setRingModulatorOutput
{
    MAKE_A_WEAKSELF;
    __block float frequency = 100.0;
    __block float phase = 0.0;
    [self.audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
         if (weakSelf.framesInWait < numFrames) return;
         
         weakSelf.mainRingBuffer->FetchInterleavedData(data, numFrames, numChannels);
         
         float samplingRate = weakSelf.audioManager.samplingRate;
        
         for (int i=0; i < numFrames; ++i) {
             for (int iChannel = 0; iChannel < numChannels; ++iChannel) {
                 float theta = phase * M_PI * 2;
                 data[i*numChannels + iChannel] *= sin(theta);
             }
             phase += 1.0 / (samplingRate / frequency);
             if (phase > 1.0) phase = -1;
         }
     }];
}

@end
