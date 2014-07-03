//
//  MFPrimaryViewController.m
//  wallop
//
//  Created by Kevin Roark on 6/29/14.
//  Copyright (c) 2014 Miller's Fantasy. All rights reserved.
//

#import "MFPrimaryViewController.h"
#import "MFImageCapturer.h"
#import "MFAudioCapturer.h"

#define ARC4RANDOM_MAX 0x100000000
#define ACTIVE_IMAGES 25

@interface MFPrimaryViewController ()<MFImageCapturerDelegate>

@property (nonatomic, strong) MFImageCapturer *imageCapturer;
@property (nonatomic, strong) NSMutableArray *imageLayers;
@property (nonatomic) BOOL acceptingImages;

@property (nonatomic, strong) MFAudioCapturer *audioCapturer;
@property (nonatomic, strong) NSTimer *audioMutationTimer;

@property (nonatomic, strong) UIButton *stopRecordingButton;

@end

@implementation MFPrimaryViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.imageCapturer = [MFImageCapturer new];
    self.imageCapturer.delegate = self;
    self.imageLayers = [NSMutableArray new];
    
    self.audioCapturer = [MFAudioCapturer new];
    
    self.stopRecordingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.stopRecordingButton.backgroundColor = [UIColor clearColor];
    self.stopRecordingButton.frame = self.view.frame;
    [self.view addSubview:self.stopRecordingButton];
    
    [self.stopRecordingButton addTarget:self action:@selector(stopRecordingPressedDown) forControlEvents:UIControlEventTouchDown];
    [self.stopRecordingButton addTarget:self action:@selector(stopRecordingReleased) forControlEvents:UIControlEventTouchUpInside];
    [self.stopRecordingButton addTarget:self action:@selector(stopRecordingReleased) forControlEvents:UIControlEventTouchUpOutside];
    
    self.acceptingImages = YES;
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.imageCapturer start];
    
    [self.audioCapturer start];
    //self.audioMutationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self.audioCapturer selector:@selector(mutateAudioModes) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self.imageCapturer stop];
    
    for (CALayer *layer in self.imageLayers) {
        [layer removeFromSuperlayer];
    }
    self.imageLayers = nil;
    
    [self.audioCapturer stop];
    
    [self.audioMutationTimer invalidate];
    self.audioMutationTimer = nil;
}

- (void)stopRecordingPressedDown
{
    NSLog(@"stopping recording");
    [self.audioCapturer setNoInput];
    self.acceptingImages = NO;
}

- (void)stopRecordingReleased
{
    NSLog(@"starting recording");
    [self.audioCapturer setVolumeBoostingInputWithVolume:1.4f];
    self.acceptingImages = YES;
}

- (void)imageCaptured:(UIImage *)image
{
    if (!image || !self.acceptingImages) return;
    
    CALayer *imageLayer = [CALayer layer];
    imageLayer.contents = (id) image.CGImage;
    imageLayer.frame = [self imageFrameForImage:image];
    imageLayer.opacity = [self imageAlpha];
    imageLayer.transform = [self imageTransform];
    //[self.view.layer addSublayer:imageLayer];
    [self.view.layer insertSublayer:imageLayer below:self.stopRecordingButton.layer];
    
    [self.imageLayers addObject:imageLayer];
    
    if ([self.imageLayers count] > ACTIVE_IMAGES) {
        CALayer *deadImageLayer = [self.imageLayers firstObject];
        [deadImageLayer removeFromSuperlayer];
        [self.imageLayers removeObjectAtIndex:0];
    }
    
    double val = ((double) arc4random() / ARC4RANDOM_MAX);
    if (val > 0.7) {
        [self.imageCapturer swapCameras];
    }
}

- (CGRect)imageFrameForImage:(UIImage *)image
{
    int width = (arc4random() % (int) (self.view.frame.size.width * 0.25)) + self.view.frame.size.width * 0.75;
    int height = width * image.size.height / image.size.width;

    int x = arc4random() % (int) (self.view.frame.size.width * 0.2);
    int y = arc4random() % (int) (self.view.frame.size.height * 0.6);
    
    return CGRectMake(x, y, width, height);
}

- (CGFloat)imageAlpha
{
    double val = ((double) arc4random() / ARC4RANDOM_MAX);
    return 0.5 * val + 0.5;
}

- (CATransform3D)imageTransform
{
    NSInteger degrees = (arc4random() % (360));
    CGFloat radians = degrees / 180.0f * M_PI;
    return CATransform3DMakeAffineTransform(CGAffineTransformMakeRotation(radians));
}

@end
