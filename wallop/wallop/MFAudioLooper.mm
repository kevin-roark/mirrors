//
//  MFAudioLooper.m
//  wallop
//
//  Created by Kevin Roark on 7/2/14.
//  Copyright (c) 2014 Miller's Fantasy. All rights reserved.
//

#import "MFAudioLooper.h"
#import "Novocaine.h"

#define MIN_FRAMES 25000
#define MORE_FRAMES 66666

@interface MFAudioLooper ()

@property (nonatomic) NSUInteger numFrames;

@property (nonatomic) NSUInteger currentBufferFrame;

@end

@implementation MFAudioLooper

- (instancetype)initWithFramesWanted:(NSUInteger)framesWanted andChannels:(NSUInteger)numChannels
{
    self = [super init];
    if (self) {
        _ringBuffer = new RingBuffer(framesWanted * numChannels, 1);
        _framesWanted = framesWanted;
        _numChannels = numChannels;
        _numFrames = 0;
        _readyToPlay = NO;
        _timesLooped = 0;
        _currentBufferFrame = 0;
    }
    return self;
}

+ (MFAudioLooper *)audioLooperWithRandomFramesWithChannels:(NSUInteger)numChannels
{
    NSUInteger numFrames = (arc4random() % MORE_FRAMES) + MIN_FRAMES;
    NSLog(@"random frame amount: %lu", numFrames);
    return [[MFAudioLooper alloc] initWithFramesWanted:numFrames andChannels:numChannels];
}

- (BOOL)addAudio:(float *)data numFrames:(UInt32)numFrames
{
    if (self.numFrames + numFrames <= self.framesWanted) {
        self.ringBuffer->AddNewInterleavedFloatData(data, numFrames, self.numChannels);
        self.numFrames += numFrames;
    } else {
        self.readyToPlay = YES;
    }
    
    return !self.readyToPlay;
}

- (void)fillAudio:(float *)audioToPlay numFrames:(UInt32)numFrames numChannels:(UInt32)numChannels
{
    // this assumes that audioToPlay is blank !!!
    
    // give audio to the taker
    self.ringBuffer->FetchInterleavedData(audioToPlay, numFrames, numChannels);
    
    // and add it back to the end of ourself
    self.ringBuffer->AddNewInterleavedFloatData(audioToPlay, numFrames, numChannels);

    self.currentBufferFrame += numFrames;
    if (self.currentBufferFrame > self.numFrames) {
        self.timesLooped += 1;
        self.currentBufferFrame = self.currentBufferFrame - self.numFrames;
    }
}

@end
