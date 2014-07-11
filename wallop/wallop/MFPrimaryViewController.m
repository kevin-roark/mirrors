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
#import "MFImageProcessor.h"

#define ARC4RANDOM_MAX 0x100000000
#define ACTIVE_IMAGES 25

@interface MFPrimaryViewController ()<MFImageCapturerDelegate, MFAudioCapturerDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, strong) MFImageCapturer *imageCapturer;
@property (nonatomic, strong) NSMutableArray *imageLayers;
@property (nonatomic) BOOL acceptingImages;

@property (nonatomic, strong) MFAudioCapturer *audioCapturer;
@property (nonatomic, strong) NSTimer *audioMutationTimer;

@property (nonatomic, strong) UIView *loopMakingIndicator;

@property (nonatomic, strong) UITapGestureRecognizer *singleFingerTapRecognizer;
@property (nonatomic, strong) UITapGestureRecognizer *doubleFingerTapRecognizer;

@end

@implementation MFPrimaryViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.imageCapturer = [MFImageCapturer new];
    self.imageCapturer.delegate = self;
    self.imageLayers = [NSMutableArray new];
    
    self.audioCapturer = [MFAudioCapturer new];
    self.audioCapturer.delegate = self;

    CGFloat loopSize = 40;
    CGFloat padding = 15;
    self.loopMakingIndicator = [[UIView alloc] initWithFrame:CGRectMake(self.view.frame.size.width - loopSize - padding, padding, loopSize, loopSize)];
    self.loopMakingIndicator.backgroundColor = [UIColor clearColor];
    self.loopMakingIndicator.layer.cornerRadius = loopSize / 2.0f;
    self.loopMakingIndicator.layer.borderColor = [UIColor redColor].CGColor;
    self.loopMakingIndicator.layer.borderWidth = 7.0f;
    self.loopMakingIndicator.layer.opacity = 0.0f;
    [self.view addSubview:self.loopMakingIndicator];
    
    self.singleFingerTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleFingerTap)];
    self.singleFingerTapRecognizer.numberOfTouchesRequired = 1;
    self.singleFingerTapRecognizer.numberOfTapsRequired = 1;
    self.singleFingerTapRecognizer.delaysTouchesBegan = NO;
    self.singleFingerTapRecognizer.delaysTouchesEnded = NO;
    self.singleFingerTapRecognizer.delegate = self;
    [self.view addGestureRecognizer:self.singleFingerTapRecognizer];
    
    self.doubleFingerTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(twoFingerTap)];
    self.doubleFingerTapRecognizer.numberOfTouchesRequired = 2;
    self.doubleFingerTapRecognizer.numberOfTapsRequired = 1;
    self.doubleFingerTapRecognizer.delegate = self;
    [self.view addGestureRecognizer:self.doubleFingerTapRecognizer];
    
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

- (void)singleFingerTap
{
    [self startRecording];
}

- (void)twoFingerTap
{
    [self revive];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if ([[event allTouches] count] == 1) {
        [self stopRecording];
    } else if ([[event allTouches] count] == 2) {
        [self silence];
    }
}

- (void)silence
{
    NSLog(@"doing silence");
    [self.audioCapturer setNoInputAndDeleteLoops];
}

- (void)revive
{
    NSLog(@"doing revive");
    [self.audioCapturer setVolumeBoostingInputWithVolume:DEFAULT_VOL_GAIN];
}

- (void)stopRecording
{
    NSLog(@"stopping recording");
    [self.audioCapturer setNoInput];
    self.acceptingImages = NO;
    [self stoppedMakingLoop];
}

- (void)startRecording
{
    NSLog(@"starting recording");
    [self.audioCapturer setVolumeBoostingInputWithVolume:DEFAULT_VOL_GAIN];
    self.acceptingImages = YES;
}

- (void)imageCaptured:(UIImage *)image
{
    if (!image || !self.acceptingImages) return;
    
    image = [self processImage:image];
    
    CALayer *imageLayer = [CALayer layer];
    imageLayer.contents = (id) image.CGImage;
    imageLayer.frame = [self imageFrameForImage:image];
    imageLayer.opacity = [self imageAlpha];
    imageLayer.transform = [self imageTransform];
    [self.view.layer insertSublayer:imageLayer below:self.loopMakingIndicator.layer];
    
    [self.imageLayers addObject:imageLayer];
    
    if ([self.imageLayers count] > ACTIVE_IMAGES) {
        CALayer *deadImageLayer = [self.imageLayers firstObject];
        [deadImageLayer removeFromSuperlayer];
        [self.imageLayers removeObjectAtIndex:0];
    }
    
    double val = ((double) arc4random() / ARC4RANDOM_MAX);
    if (val > 0.5) {
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

- (UIImage *)processImage:(UIImage *)image
{
    double val;
    
    val = ((double) arc4random() / ARC4RANDOM_MAX);
    if (val > 0.67) {
        image = [MFImageProcessor imageWithRandomTint:image];
    }
    
    val = ((double) arc4random() / ARC4RANDOM_MAX);
    if (val > 0.57) {
        image = [MFImageProcessor imageWithRandomBrightness:image];
    }
    
    return image;
}

#pragma -> MFAudioCapturerDelegate

- (void)startedMakingLoop
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
        [UIView animateWithDuration:0.4f animations:^{
            self.loopMakingIndicator.layer.opacity = 1.0f;
        }];
    }];
}

- (void)stoppedMakingLoop
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
        [UIView animateWithDuration:0.4f animations:^{
            self.loopMakingIndicator.layer.opacity = 0.0f;
        }];
    }];
}

@end
