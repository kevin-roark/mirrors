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
@property (nonatomic, strong) UIView *loopModeIndicator;

@property (nonatomic, strong) UITapGestureRecognizer *singleFingerSingleTapRecognizer;
@property (nonatomic, strong) UITapGestureRecognizer *doubleFingerSingleTapRecognizer;

@property (nonatomic) BOOL recording;
@property (nonatomic) BOOL zombieMode;

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
    
    self.loopModeIndicator = [[UIView alloc] initWithFrame:CGRectMake(padding, padding, loopSize, loopSize)];
    self.loopModeIndicator.backgroundColor = [UIColor colorWithRed:0.8 green:0.0 blue:1.0 alpha:1.0f];
    self.loopModeIndicator.layer.opacity = 0.0f;
    [self.view addSubview:self.loopModeIndicator];
    
    self.singleFingerSingleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleFingerSingleTap)];
    self.singleFingerSingleTapRecognizer.numberOfTouchesRequired = 1;
    self.singleFingerSingleTapRecognizer.numberOfTapsRequired = 1;
    self.singleFingerSingleTapRecognizer.delaysTouchesBegan = NO;
    self.singleFingerSingleTapRecognizer.delaysTouchesEnded = NO;
    self.singleFingerSingleTapRecognizer.delegate = self;
    [self.view addGestureRecognizer:self.singleFingerSingleTapRecognizer];
    
    self.doubleFingerSingleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(twoFingerSingleTap)];
    self.doubleFingerSingleTapRecognizer.numberOfTouchesRequired = 2;
    self.doubleFingerSingleTapRecognizer.numberOfTapsRequired = 1;
    self.doubleFingerSingleTapRecognizer.delegate = self;
    [self.view addGestureRecognizer:self.doubleFingerSingleTapRecognizer];
    
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
    
    self.recording = YES;
    self.zombieMode = NO;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self.imageCapturer stop];
    
    [self removeImages];
    
    [self.audioCapturer stop];
    
    [self.audioMutationTimer invalidate];
    self.audioMutationTimer = nil;
}

- (void)singleFingerSingleTap
{
    if (self.recording) {
        [self stopRecording];
        [self showLoopModeIndicator];
    } else {
        [self startRecordingWithDelay:0.2];
        [self hideLoopModeIndicator];
    }
    
    self.recording = !self.recording;
}

- (void)twoFingerSingleTap
{
    if (self.zombieMode) {
        [self revive];
    } else {
        [self silence];
    }
    
    self.zombieMode = !self.zombieMode;
}

- (void)silence
{
    NSLog(@"doing silence");
    [self.audioCapturer setNoInputAndDeleteLoops];
    self.acceptingImages = NO;
}

- (void)revive
{
    NSLog(@"doing revive");
    [self startRecordingWithDelay:0.15f];
}

- (void)removeImages
{
    for (CALayer *layer in self.imageLayers) {
        [layer removeFromSuperlayer];
    }
    [self.imageLayers removeAllObjects];
}

- (void)stopRecording
{
    [self.audioCapturer setNoInput];
    self.acceptingImages = NO;
    [self stoppedMakingLoop];
}

- (void)startRecordingWithDelay:(CGFloat)delayInSeconds;
{
    [self.audioCapturer setNoOutput];
    
    [self.audioCapturer setVolumeBoostingInputWithVolume:DEFAULT_VOL_GAIN];
    
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * delayInSeconds);
    dispatch_after(delay, dispatch_get_main_queue(), ^(void){
        [self.audioCapturer setPlayFromBufferOutput];
    });
    
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
    if (!self.recording || self.zombieMode) {
        [self stoppedMakingLoop];
        return;
    }
    
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

- (void)showLoopModeIndicator
{
    self.loopModeIndicator.layer.opacity = 1.0f;
    
    CABasicAnimation *rotation = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
    rotation.fromValue = [NSNumber numberWithFloat:0];
    rotation.toValue = [NSNumber numberWithFloat:(2*M_PI)];
    rotation.duration = 1.4;
    rotation.repeatCount = HUGE_VALF; // Repeat forever. Can be a finite number.
    
    [self.loopModeIndicator.layer addAnimation:rotation forKey:@"Spin"];
}

- (void)hideLoopModeIndicator
{
    self.loopModeIndicator.layer.opacity = 0.0f;
    
    [self.loopModeIndicator.layer removeAnimationForKey:@"Spin"];
}

@end
