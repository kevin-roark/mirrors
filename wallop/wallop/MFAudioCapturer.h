//
//  MFAudioCapturer.h
//  wallop
//
//  Created by Kevin Roark on 6/29/14.
//  Copyright (c) 2014 Miller's Fantasy. All rights reserved.
//

#import <Foundation/Foundation.h>

#define DEFAULT_VOL_GAIN 1.1f

@protocol MFAudioCapturerDelegate <NSObject>

- (void)startedMakingLoop;
- (void)stoppedMakingLoop;

@end

@interface MFAudioCapturer : NSObject

@property (nonatomic, weak) id<MFAudioCapturerDelegate> delegate;

- (void)start;
- (void)stop;
- (BOOL)running;

- (void)mutateAudioModes;

- (void)createLooper;

// input options
- (void)setNoInput;
- (void)setNoInputAndDeleteLoops;
- (void)setVolumeBoostingInputWithVolume:(float)volume;

// output options
- (void)setNoOutput;
- (void)setPlayFromBufferOutput;
- (void)setRingModulatorOutput;

@end
