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

@interface MFAudioCapturer ()<MFAudioLooperDelegate>

@property (nonatomic, strong) Novocaine *audioManager;
@property (nonatomic, assign) RingBuffer *mainRingBuffer;

@property (nonatomic) BOOL currentlyRecording;

@property (nonatomic, strong) NSMutableArray *loopers;

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
    
    self.loopers = [NSMutableArray arrayWithCapacity:5];
    
    self.framesInWait = 0;
    self.captureMode = MFFeedback;
    self.currentlyRecording = YES;
    
    [self setVolumeBoostingInputWithVolume:DEFAULT_VOL_GAIN];
    [self setNoOutput];
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
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
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
    // set 1 -> 2second delay
    MAKE_A_WEAKSELF;
    CGFloat seconds = (arc4random() % 2) + 1.25;
    NSLog(@"loop capture time %f", seconds);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, seconds * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [weakSelf createLooper];
    });
}

- (void)createLooper
{
    NSLog(@"creating looper");
    [self.delegate startedMakingLoop];
    
    if (self.currentlyRecording) {
        MFAudioLooper *currentLooper = [MFAudioLooper audioLooperWithRandomFramesWithChannels:self.audioManager.numInputChannels];
        currentLooper.loopsDeserved = arc4random() % 10 + 3;
        currentLooper.delegate = self;
        
        [self.loopers addObject:currentLooper];
    }
    
    // only keep the good Loopers
    NSMutableArray *goodLoopers = [NSMutableArray arrayWithCapacity:[self.loopers count]];
    for (MFAudioLooper *looper in self.loopers) {
        if (looper.timesLooped <= looper.loopsDeserved) {
            [goodLoopers addObject:looper];
        }
    }
    
    [self.loopers setArray:goodLoopers];
}

- (void)filledLoooper:(MFAudioLooper *)looper
{
    [self.delegate stoppedMakingLoop];
    [self beginLoopCapture];
}

#pragma mark -> Input

- (void)setNoInput
{
    [self.audioManager setInputBlock:nil];
    self.currentlyRecording = NO;
    
    for (MFAudioLooper *looper in self.loopers) {
        looper.loopsDeserved = 10000;
    }
}

- (void)setNoInputAndDeleteLoops
{
    [self.audioManager setInputBlock:nil];
    self.currentlyRecording = NO;
    
    self.loopers = [NSMutableArray new];
}

- (void)someInputSet
{
    for (MFAudioLooper *looper in self.loopers) {
        looper.loopsDeserved = 5;
    }
    
    self.currentlyRecording = YES;
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
    
    for (MFAudioLooper *looper in self.loopers) {
        if (!looper.readyToPlay) {
            [looper addAudio:data numFrames:numFrames];
        }
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
        } else {
            memset(audioToPlay, 0, numChannels * numFrames * sizeof(float));
        }
        
        [weakSelf addAudioFromLoopers:audioToPlay numFrames:numFrames numChannels:numChannels];
    }];
}

- (void)addAudioFromLoopers:(float *)audioToPlay numFrames:(UInt32)numFrames numChannels:(UInt32)numChannels
{
    for (MFAudioLooper *looper in self.loopers) {
        if (looper.readyToPlay) {
            float freshAudioBuffer[numFrames * numChannels];
            if (looper.timesLooped <= looper.loopsDeserved) {
                [looper fillAudio:freshAudioBuffer numFrames:numFrames numChannels:numChannels];
                
                // combine audio from loop and main buffer
                vDSP_vadd(audioToPlay, 1, freshAudioBuffer, 1, audioToPlay, 1, numFrames * numChannels);
            }
        }
    }
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
