//
//  MFAudioCapturer.h
//  wallop
//
//  Created by Kevin Roark on 6/29/14.
//  Copyright (c) 2014 Miller's Fantasy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MFAudioCapturer : NSObject

- (void)start;
- (void)stop;
- (BOOL)running;

- (void)mutateAudioModes;

// input options
- (void)setNoInput;
- (void)setVolumeBoostingInputWithVolume:(float)volume;

// output options
- (void)setNoOutput;
- (void)setPlayFromBufferOutput;

@end
