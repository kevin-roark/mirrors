//
//  MFImageCapturer.h
//  wallop
//
//  Created by Kevin Roark on 6/29/14.
//  Copyright (c) 2014 Miller's Fantasy. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MFImageCapturerDelegate <NSObject>

- (void)imageCaptured:(UIImage *)image;

@end

@interface MFImageCapturer : NSObject

@property (nonatomic, weak) id<MFImageCapturerDelegate> delegate;

- (void)start;
- (void)stop;
- (BOOL)running;

- (void)swapCameras;

@end
