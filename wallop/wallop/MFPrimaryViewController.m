//
//  MFPrimaryViewController.m
//  wallop
//
//  Created by Kevin Roark on 6/29/14.
//  Copyright (c) 2014 Miller's Fantasy. All rights reserved.
//

#import "MFPrimaryViewController.h"
#import "MFImageCapturer.h"

#define ACTIVE_IMAGES 18

@interface MFPrimaryViewController ()

@property (nonatomic, strong) MFImageCapturer *imageCapturer;

@property (nonatomic, strong) NSMutableArray *imageViews;

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
    self.imageViews = [NSMutableArray new];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.imageCapturer start];
    
    [self startImageDisplay];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.imageCapturer stop];
}

- (void)startImageDisplay
{
    [self makeImage];

    [self performSelector:@selector(startImageDisplay) withObject:self afterDelay:0.3f];
}

- (void)makeImage
{
    [self.imageCapturer captureImage:^(NSData *jpegData) {
        if (!jpegData) return;
        UIImage *image = [UIImage imageWithData:jpegData];
        
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
    }];
}

- (CGRect)imageFrameForImage:(UIImage *)image
{
    int width = (arc4random() % (int) (self.view.frame.size.width / 2)) + self.view.frame.size.width / 2;
    int height = width * image.size.height / image.size.width;

    int x = arc4random() % (int) (self.view.frame.size.width * 0.2);
    int y = arc4random() % (int) (self.view.frame.size.height - height / 2);
    
    return CGRectMake(x, y, width, height);
}

- (CGFloat)imageAlpha
{
    return 0.9;
}

@end
