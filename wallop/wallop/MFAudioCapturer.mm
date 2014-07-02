//
//  MFAudioCapturer.m
//  wallop
//
//  Created by Kevin Roark on 6/29/14.
//  Copyright (c) 2014 Miller's Fantasy. All rights reserved.
//

#import "MFAudioCapturer.h"
#import "Novocaine.h"
#import "RingBuffer.h"
#import "AudioFileWriter.h"
#import "AudioFileReader.h"

#define MAKE_A_WEAKSELF __weak MFAudioCapturer *weakSelf = self

#define BUFFER_SIZE 32768

#define ECHO_WRITE_COUNTER 150

typedef NS_ENUM(NSUInteger, MFAudioCaptureMode) {
    MFFeedback = 0,
    MFRecording,
    MFPlaying
};

@interface MFAudioCapturer ()

@property (nonatomic, strong) Novocaine *audioManager;
@property (nonatomic, assign) RingBuffer *mainRingBuffer;

@property (nonatomic) NSUInteger numEchos;
@property (nonatomic, strong) AudioFileWriter *fileWriter;
@property (nonatomic, strong) AudioFileReader *fileReader;
@property (nonatomic) int currentWriteCounter;
@property (nonatomic) int currentReadCounter;
@property (nonatomic) int currentLoops;

@property (nonatomic) MFAudioCaptureMode captureMode;
@property (nonatomic) NSUInteger framesInWait;

@end

@implementation MFAudioCapturer

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
    self.audioManager = [Novocaine audioManager];
    self.mainRingBuffer = new RingBuffer(BUFFER_SIZE, 1);
    self.framesInWait = 0;
    self.captureMode = MFFeedback;
    
    [self setVolumeBoostingInputWithVolume:1.4f];
    [self setNoOutput];

    self.numEchos = 0;
}

- (void)mutateAudioModes
{
    if (self.captureMode == MFFeedback) {
        // set to recording for now
        self.captureMode = MFRecording;
        [self setNoOutput];
    } else if (self.captureMode == MFRecording) {
        // set to playing for now
        self.captureMode = MFPlaying;
        [self setNoInput];
        [self setPlayFromBufferOutput];
    } else if (self.captureMode == MFPlaying) {
        // set to feedback for now
        self.captureMode = MFFeedback;
        [self setVolumeBoostingInputWithVolume:20.0f];
    }
}

- (void)start
{
    if (!self.audioManager.playing) {
        [self.audioManager setForceOutputToSpeaker:YES];
        [self.audioManager play];
        
        // set 1 second delay
        MAKE_A_WEAKSELF;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            NSLog(@"beginning playback");
            [weakSelf setPlayFromBufferOutput];
            [weakSelf beginLoopCapture];
        });
    }
}

- (void)stop
{
    if (self.audioManager.playing) {
        [self.audioManager pause];
        self.fileReader = nil;
        self.fileWriter = nil;
    }
}

- (BOOL)running
{
    return self.audioManager.playing;
}

- (void)beginLoopCapture
{
    // set 3 second delay
    MAKE_A_WEAKSELF;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        NSLog(@"dispatching echo");
        NSURL *echoUrl = [self urlForFileNumber:weakSelf.numEchos];
        weakSelf.fileWriter = [self fileWriterForUrl:echoUrl];
        weakSelf.currentWriteCounter = 0;
    });
}

#pragma mark -> Input

- (void)setNoInput
{
    [self.audioManager setSessionCategory:kAudioSessionCategory_MediaPlayback];
    //[self.audioManager setInputBlock:nil];
}

- (void)someInputSet
{
    [self.audioManager setSessionCategory:kAudioSessionCategory_PlayAndRecord];
}

- (void)setVolumeBoostingInputWithVolume:(float)volume
{
    [self someInputSet];
    
    MAKE_A_WEAKSELF;
    [self.audioManager setInputBlock:^(float *newAudio, UInt32 numFrames, UInt32 numChannels) {
        vDSP_vsmul(newAudio, 1, &volume, newAudio, 1, numFrames * numChannels);
        if (weakSelf.framesInWait + numFrames < BUFFER_SIZE) {
            weakSelf.mainRingBuffer->AddNewInterleavedFloatData(newAudio, numFrames, numChannels);
            weakSelf.framesInWait += numFrames;
        }
        
        if (weakSelf.fileWriter && ++weakSelf.currentWriteCounter < ECHO_WRITE_COUNTER) {
            [weakSelf.fileWriter writeNewAudio:newAudio numFrames:numFrames numChannels:numChannels];
        } else if (weakSelf.fileWriter) {
            weakSelf.fileWriter = nil;
            
            NSLog(@"beginning echo read");
            NSURL *echoUrl = [weakSelf urlForFileNumber:weakSelf.numEchos];
            weakSelf.fileReader = [weakSelf fileReaderForUrl:echoUrl];
            weakSelf.currentReadCounter = 0;
            weakSelf.currentLoops = 0;
            [weakSelf.fileReader play];
        }
    }];
}

#pragma mark -> Output

- (void)setNoOutput
{
    [self.audioManager setOutputBlock:nil];
}

- (void)setPlayFromBufferOutput
{
    MAKE_A_WEAKSELF;
    [self.audioManager setOutputBlock:^(float *audioToPlay, UInt32 numFrames, UInt32 numChannels) {
        if (weakSelf.framesInWait >= numFrames) {
            weakSelf.mainRingBuffer->FetchInterleavedData(audioToPlay, numFrames, numChannels);
            weakSelf.framesInWait -= numFrames;
            if (weakSelf.fileReader && ++weakSelf.currentReadCounter < weakSelf.currentWriteCounter) {
                // mix with the main ring buffer
                float *readingAudio = (float *) malloc(numFrames * numChannels * sizeof(float));
                [weakSelf.fileReader retrieveFreshAudio:readingAudio numFrames:numFrames numChannels:numChannels];

                vDSP_vadd(audioToPlay, 1, readingAudio, 1, audioToPlay, 1, numFrames * numChannels);
            }
            else if (weakSelf.fileReader && ++weakSelf.currentLoops <= 5) {
                weakSelf.fileReader.currentTime = 0.0f;
                weakSelf.currentReadCounter = 0;
                [weakSelf.fileReader play];
            }
            else {
                weakSelf.fileReader = nil;
            }
        }
    }];
}

- (void)setRingModulatorOutput
{
    MAKE_A_WEAKSELF;
    __block float frequency = 100.0;
    __block float phase = 0.0;
    [self.audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
         if (weakSelf.framesInWait < numFrames) return;
         
         weakSelf.mainRingBuffer->FetchInterleavedData(data, numFrames, numChannels);
         
         float samplingRate = weakSelf.audioManager.samplingRate;
        
         for (int i=0; i < numFrames; ++i) {
             for (int iChannel = 0; iChannel < numChannels; ++iChannel) {
                 float theta = phase * M_PI * 2;
                 data[i*numChannels + iChannel] *= sin(theta);
             }
             phase += 1.0 / (samplingRate / frequency);
             if (phase > 1.0) phase = -1;
         }
     }];
}

#pragma mark -> Helpers

- (NSURL *)urlForFileNumber:(NSUInteger)fileNumber
{
    return [NSURL fileURLWithPathComponents:@[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject],
                                              [NSString stringWithFormat:@"mfecho-%lu", fileNumber]]];
}

- (AudioFileReader *)fileReaderForUrl:(NSURL *)url
{
    return [[AudioFileReader alloc] initWithAudioFileURL:url samplingRate:self.audioManager.samplingRate numChannels:self.audioManager.numOutputChannels];
}

- (AudioFileWriter *)fileWriterForUrl:(NSURL *)url
{
    return [[AudioFileWriter alloc] initWithAudioFileURL:url samplingRate:self.audioManager.samplingRate numChannels:self.audioManager.numInputChannels];
}

@end
