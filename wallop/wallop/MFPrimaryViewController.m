//
//  MFPrimaryViewController.m
//  wallop
//
//  Created by Kevin Roark on 6/29/14.
//  Copyright (c) 2014 Miller's Fantasy. All rights reserved.
//

#import "MFPrimaryViewController.h"
#import "MFImageCapturer.h"

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
    [self makeImage];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.imageCapturer stop];
}


- (void)makeImage
{
    [self.imageCapturer captureImage:^(NSData *jpegData) {
        if (!jpegData) return;
        
        UIImage *image = [UIImage imageWithData:jpegData];
        UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
        imageView.frame = self.view.frame;
        [self.view addSubview:imageView];
        
        [self.imageViews addObject:imageView];
    }];
}

@end
