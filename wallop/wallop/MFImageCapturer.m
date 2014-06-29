//
//  MFImageCapturer.m
//  wallop
//
//  Created by Kevin Roark on 6/29/14.
//  Copyright (c) 2014 Miller's Fantasy. All rights reserved.
//

#import "MFImageCapturer.h"
#import <AVFoundation/AVFoundation.h>

@interface MFImageCapturer ()

@property (strong, nonatomic) AVCaptureSession *captureSession;

@property (strong, nonatomic) AVCaptureDeviceInput *frontFacingCameraInput;
@property (strong, nonatomic) AVCaptureDeviceInput *rearFacingCameraInput;

@property (strong, nonatomic) AVCaptureStillImageOutput *stillImageOutput;

@end

@implementation MFImageCapturer

- (id)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup
{
    NSError *err;
    
    AVCaptureDevice *frontCamera, *rearCamera;
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if (!frontCamera && camera.position == AVCaptureDevicePositionFront) {
            frontCamera = camera;
        }
        if (!rearCamera && camera.position == AVCaptureDevicePositionBack) {
            rearCamera = camera;
        }
    }
    
    self.frontFacingCameraInput = [[AVCaptureDeviceInput alloc] initWithDevice:frontCamera error:&err];
    if (err) {
        NSLog(@"FAILED FRONT CAMERA INPUT");
    }
    
    self.rearFacingCameraInput = [[AVCaptureDeviceInput alloc] initWithDevice:rearCamera error:&err];
    if (err) {
        NSLog(@"FAILED REAR CAMERA INPUT");
    }
    
    self.stillImageOutput = [AVCaptureStillImageOutput new];
    self.stillImageOutput.outputSettings = @{AVVideoCodecKey: AVVideoCodecJPEG};
    
    self.captureSession = [AVCaptureSession new];
    self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto;
    [self.captureSession addOutput:self.stillImageOutput];
    if ([self.captureSession canAddInput:self.rearFacingCameraInput]) {
        [self.captureSession addInput:self.rearFacingCameraInput];
    }
}

- (void)start
{
    if (!self.captureSession.running) {
        [self.captureSession startRunning];
    }
}

- (void)stop
{
    if (self.captureSession.running) {
        [self.captureSession stopRunning];
    }
}

- (void)swapCameras
{
    [self.captureSession beginConfiguration];
    
    if ([self.captureSession.inputs containsObject:self.frontFacingCameraInput]) {
        [self.captureSession removeInput:self.frontFacingCameraInput];
        [self.captureSession addInput:self.rearFacingCameraInput];
    } else {
        [self.captureSession removeInput:self.rearFacingCameraInput];
        [self.captureSession addInput:self.frontFacingCameraInput];
    }
    
    [self.captureSession commitConfiguration];
}

- (void)captureImage:(void (^)(NSData *jpegData))completion
{
    AVCaptureConnection *stillImageConnection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    if (!stillImageConnection) {
        completion(nil);
    }
    
    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:stillImageConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        if (!imageDataSampleBuffer) return;
        
        NSData *jpeg = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        completion(jpeg);
    }];
}

@end
