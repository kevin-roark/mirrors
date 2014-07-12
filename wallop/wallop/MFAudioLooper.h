//
//  MFAudioLooper.h
//  wallop
//
//  Created by Kevin Roark on 7/2/14.
//  Copyright (c) 2014 Miller's Fantasy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RingBuffer.h"

@protocol MFAudioLooperDelegate;

@interface MFAudioLooper : NSObject

@property (nonatomic, assign) RingBuffer *ringBuffer;

@property (nonatomic, assign) id<MFAudioLooperDelegate> delegate;

@property (nonatomic) NSUInteger framesWanted;
@property (nonatomic) NSUInteger numChannels;
@property (nonatomic) BOOL readyToPlay;
@property (nonatomic) NSUInteger timesLooped;

@property (nonatomic) BOOL currentlyCountingLoops;
@property (nonatomic) NSUInteger loopsDeserved;

- (instancetype)initWithFramesWanted:(NSUInteger)framesWanted andChannels:(NSUInteger)numChannels;

- (BOOL)addAudio:(float *)data numFrames:(UInt32)numFrames;

- (void)fillAudio:(float *)audioToPlay numFrames:(UInt32)numFrames numChannels:(UInt32)numChannels;

+ (MFAudioLooper *)audioLooperWithRandomFramesWithChannels:(NSUInteger)numChannels;

@end

@protocol MFAudioLooperDelegate <NSObject>

- (void)filledLoooper:(MFAudioLooper *)looper;

@end