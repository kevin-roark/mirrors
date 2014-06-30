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

@end
