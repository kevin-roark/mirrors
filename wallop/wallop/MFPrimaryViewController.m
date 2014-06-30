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
@property (nonatomic, strong) NSMutableArray *imageViews;

@property (nonatomic, strong) MFAudioCapturer *audioCapturer;

@end

@implementation MFPrimaryViewController

- (id)init
{
    self = [super init];
    if (self) {

    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.imageCapturer = [MFImageCapturer new];
    self.imageCapturer.delegate = self;
    self.imageViews = [NSMutableArray new];
    
    self.audioCapturer = [MFAudioCapturer new];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.imageCapturer start];
    
    [self.audioCapturer start];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self.imageCapturer stop];
    
    for (UIImageView *imageView in self.imageViews) {
        [imageView removeFromSuperview];
    }
    self.imageViews = nil;
    
    [self.audioCapturer stop];
}

- (void)imageCaptured:(UIImage *)image
{
    if (!image) return;
    
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.alpha = [self imageAlpha];
    imageView.frame = [self imageFrameForImage:image];
    [self.view addSubview:imageView];
    
    [self.imageViews addObject:imageView];
    
    if ([self.imageViews count] > ACTIVE_IMAGES) {
        UIImageView *deadImageView = [self.imageViews firstObject];
        [deadImageView removeFromSuperview];
        [self.imageViews removeObjectAtIndex:0];
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

@end
