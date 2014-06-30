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

@interface MFAudioCapturer ()

@property (nonatomic, strong) Novocaine *audioManager;
@property (nonatomic, assign) RingBuffer *ringBuffer;

@property (nonatomic) BOOL playTurn;
@property (nonatomic) int playTimes;

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
    self.ringBuffer = new RingBuffer(32768, 1);
    self.playTurn = YES;
    
    __weak MFAudioCapturer *weakSelf = self;
    
   [self.audioManager setInputBlock:^(float *newAudio, UInt32 numFrames, UInt32 numChannels) {

       if (weakSelf.playTurn) {
           float volume = 20.0;
           vDSP_vsmul(newAudio, 1, &volume, newAudio, 1, numFrames * numChannels);
           weakSelf.ringBuffer->AddNewInterleavedFloatData(newAudio, numFrames, numChannels);
       }
    }];
    
    [self.audioManager setOutputBlock:^(float *audioToPlay, UInt32 numFrames, UInt32 numChannels) {
            weakSelf.ringBuffer->FetchInterleavedData(audioToPlay, numFrames, numChannels);
    }];
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

@end
