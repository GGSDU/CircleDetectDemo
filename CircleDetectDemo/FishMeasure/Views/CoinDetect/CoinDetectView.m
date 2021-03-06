//
//  CoinDetectView.m
//  AVFoundationDemo
//
//  Created by Story5 on 4/10/17.
//  Copyright © 2017 Story5. All rights reserved.
//

#import "CoinDetectView.h"

#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>

#import "AVCamPreviewView.h"
#import "CameraControlView.h"

#import "UseGuideView.h"
#import "CaptureImageView.h"

#import "CoinDetectModel.h"
#import "UIImage+Rotate_Flip.h"
#import "CGGeometryConvertTool.h"
#import "DetectCircleTool.h"


@interface CoinDetectView ()<AVCaptureVideoDataOutputSampleBufferDelegate,CameraControlViewDelegate>

@property (nonatomic,strong) AVCaptureSession *session;
@property (nonatomic,strong) AVCaptureDevice *device;
@property (nonatomic,strong) AVCaptureDeviceInput *input;
// 可以逐帧处理捕获的视频
@property (nonatomic,strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic,strong) AVCamPreviewView *previewView;



@property (nonatomic,strong) CameraControlView *cameraControlView;
@property (nonatomic,strong) UseGuideView *guideView;

@property (nonatomic,strong) CaptureImageView *drawCircleView;

@property (nonatomic,strong) CGGeometryConvertTool *covertTool;
@property (nonatomic,strong) DetectCircleTool *detectCircleTool;

@property (nonatomic,strong) CoinDetectModel *coinDetectModel;

@end

@implementation CoinDetectView
- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.size = 9;
        self.dp = 1.0;
        self.minDist = 8.0;
        self.param1 = 200.0;
        self.param2 = 100.0;
        self.minRadius = 0;
        self.maxRadius = 0;
        [self createUI];
//        [self configOtherView];
//        
//        UIImage *image = [UIImage imageNamed:@"coin"];
//        [self detectCoinWithImage:image];
    }
    return self;
}

#pragma mark - CameraControlViewDelegate
- (void)cameraControlView:(CameraControlView *)cameraControleView clickTakePictureButton:(UIButton *)aSender
{
    [self stopRunning];
    
    if ([self.delegate respondsToSelector:@selector(coinDetectView:captureFishWithModel:)]) {
        [self.delegate coinDetectView:self captureFishWithModel:self.coinDetectModel];
    }
}

- (void)cameraControlView:(CameraControlView *)cameraControleView clickGuideButton:(UIButton *)aSender
{    
    [self addSubview:self.guideView];
}

- (void)cameraControlView:(CameraControlView *)cameraControleView clickFlashLightButton:(UIButton *)aSender
{
    NSLog(@"%s __ %d",__func__,aSender.selected);
    [self setFlashLightMode:aSender.selected];
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
// output
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    // Create a UIImage from the sample buffer data
    //    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    //    CIImage *image = [[CIImage alloc] initWithCVImageBuffer:pixelBuffer];
    UIImage *sourceImage = [self imageFromSampleBuffer:sampleBuffer];
    UIImage *image = [sourceImage rotateImageWithRadian:M_PI_2 cropMode:enSvCropExpand];
    [self detectCoinWithImage:image];
}

// drop
- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    
}

#pragma mark - detect Coin
- (void)detectCoinWithImage:(UIImage *)image
{
    self.covertTool.sourceSize = image.size;
    
    NSDictionary *params = @{@"size"        :[NSNumber numberWithDouble:self.size],
                             @"dp"          :[NSNumber numberWithDouble:self.dp],
                             @"minDist"     :[NSNumber numberWithDouble:self.minDist],
                             @"param1"      :[NSNumber numberWithDouble:self.param1],
                             @"param2"      :[NSNumber numberWithDouble:self.param2],
                             @"minRadius"   :[NSNumber numberWithInt:self.minRadius],
                             @"maxRadius"   :[NSNumber numberWithInt:self.maxRadius]};
    
    BOOL detected = [self.detectCircleTool detectCircleInImage:image params:params];
    int radius = [self.covertTool covertIntLength:self.detectCircleTool.radius];
    CGPoint center = [self.covertTool convertPoint:self.detectCircleTool.center];
    
    self.coinDetectModel.circleCenter = center;
    self.coinDetectModel.circleRadius = radius;
    self.coinDetectModel.captureImage = image;
    self.coinDetectModel.detectStatus = detected;
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self.cameraControlView enableTakePicture:detected];
        self.drawCircleView.coinDetectModel = self.coinDetectModel;
        [self.drawCircleView setNeedsDisplay];
    });
}

#pragma mark - set AVCapturete
- (void)createUI
{
    [self setAVCapture];
    [self configOtherView];
}

- (void)setAVCapture
{
    //  **********   步骤 - 1   **********
    [self createSession];
    //  **********   步骤 - 2   **********
    [self configDevice];
    //  **********   步骤 - 3   **********
    [self configInput];
    //  **********   步骤 - 4   **********
//    [self configStillImageOutput];
    [self configVideoDataOutput];
    //  **********   步骤 - 5   **********
    [self configPreview];
    //  **********   步骤 - 6   **********
    [self startRunning];
    
    // Assign session to an ivar.
    [self setSession:self.session];
}

- (void)configOtherView
{
    // 配置画圆视图
    [self configCircleImageView];
    // 配置拍照按钮控件
    [self configCameraControlView];
}

// Create the session
- (void)createSession
{
    self.session = [[AVCaptureSession alloc] init];
    // Configure the session to produce lower resolution video frames, if your
    // processing algorithm can cope. We'll specify medium quality for the
    // chosen device.
    self.session.sessionPreset = AVCaptureSessionPresetHigh;
}

// Find a suitable AVCaptureDevice
- (void)configDevice
{
    self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    NSError *error = nil;
    [self.device lockForConfiguration:&error];
    // If you wish to cap the frame rate to a known value, such as 30 fps, set
    // minFrameDuration.
    self.device.activeVideoMinFrameDuration = CMTimeMake(1, 30);
}

// Create a device input with the device and add it to the session
- (void)configInput
{
    NSError *error = nil;
    self.input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:&error];
    if (!self.input) {
        // Handling the error appropriately.
    }
    [self.session addInput:self.input];
}

//- (void)configStillImageOutput
//{
//    self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
//    NSDictionary *outputSettings = @{ AVVideoCodecKey : AVVideoCodecJPEG};
//    [self.stillImageOutput setOutputSettings:outputSettings];
//    [self.session addInput:self.input];
//}

// Create a VideoDataOutput and add it to the session
- (void)configVideoDataOutput
{
    self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [self.session addOutput:self.videoDataOutput];
    
    // Configure your output.
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    [self.videoDataOutput setSampleBufferDelegate:self queue:queue];
    
    // Specify the pixel format
    self.videoDataOutput.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                                                            forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    // If you wish to cap the frame rate to a known value, such as 15 fps, set
    // minFrameDuration.
//    self.output.minFrameDuration = CMTimeMake(1, 15);
}

- (void)configPreview
{
    // Set up the preview view.
    self.previewView.session = self.session;
}

- (void)configCameraControlView
{
    self.cameraControlView.backgroundColor = [UIColor clearColor];
}

- (void)configCircleImageView
{
    self.drawCircleView.backgroundColor = [UIColor clearColor];
}

// Start the session running to start the flow of data
- (void)startRunning
{
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
      [self.session startRunning];
    });
}

// Stop
- (void)stopRunning
{
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self.session stopRunning];
    });
}

// open or close torch
- (void)setFlashLightMode:(BOOL)mode
{
    if ([self.device hasTorch]) {
        
        [self.device lockForConfiguration:nil];
        if (mode) {
            // 打开闪光灯
            [self.device setTorchMode:AVCaptureTorchModeOn];
        } else {
            // 关闭闪光灯
            [self.device setTorchMode:AVCaptureTorchModeOff];
        }
        
        [self.device unlockForConfiguration];
    }
}

//- (AVCaptureConnection *)getConnection
//{
//    AVCaptureConnection *videoConnection = nil;
//    for (AVCaptureConnection *connection in self.stillImageOutput.connections) {
//        for (AVCaptureInputPort *port in [connection inputPorts]) {
//            if ([[port mediaType] isEqual:AVMediaTypeVideo] ) {
//                videoConnection = connection;
//                break;
//            }
//        }
//        if (videoConnection) break;
//    }
//    return videoConnection;
//}

// Create a UIImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    
    return (image);
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    NSLog(@"%s",__func__);
//    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Tips" message:@"save image failure" preferredStyle:UIAlertControllerStyleAlert];
//    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
//        
//    }];
//    [alert addAction:cancel];
//    [self presentViewController:alert animated:true completion:nil];
}

#pragma mark - setter
- (void)setSize:(double)size
{
    _size = size;
    self.detectCircleTool.size = size;
}

- (void)setDp:(double)dp
{
    _dp = dp;
    self.detectCircleTool.dp = dp;
}

- (void)setMinDist:(double)minDist
{
    _minDist = minDist;
    self.detectCircleTool.minDist = minDist;
}

- (void)setParam1:(double)param1
{
    _param1 = param1;
    self.detectCircleTool.param1 = param1;
}

- (void)setParam2:(double)param2
{
    _param2 = param2;
    self.detectCircleTool.param2 = param2;
}

- (void)setMinRadius:(int)minRadius
{
    _minRadius = minRadius;
    self.detectCircleTool.minRadius = minRadius;
}

- (void)setMaxRadius:(int)maxRadius
{
    _maxRadius = maxRadius;
    self.detectCircleTool.maxRadius = maxRadius;
}

#pragma mark - getter
- (AVCaptureVideoPreviewLayer *)videoPreviewLayer
{
    return (AVCaptureVideoPreviewLayer *)self.layer;
}

- (AVCamPreviewView *)previewView
{
    if (_previewView == nil) {
        _previewView = [[AVCamPreviewView alloc] initWithFrame:self.bounds];
        [self addSubview:_previewView];
    }
    return _previewView;
}

- (CameraControlView *)cameraControlView
{
    if (_cameraControlView == nil) {
        NSInteger height = 110;
        NSInteger bottomGap = 20;
        _cameraControlView = [[CameraControlView alloc] initWithFrame:CGRectMake(0, self.bounds.size.height - height - bottomGap, self.bounds.size.width, height)];
        _cameraControlView.delegate = self;
        [self addSubview:_cameraControlView];
    }
    return _cameraControlView;
}

- (UseGuideView *)guideView
{
    if (_guideView == nil) {
        _guideView = [[UseGuideView alloc] initWithFrame:self.bounds];
    }
    return _guideView;
}

- (CaptureImageView *)drawCircleView
{
    if (_drawCircleView == nil) {
        _drawCircleView = [[CaptureImageView alloc] initWithFrame:self.bounds];
        _drawCircleView.detectingMode = true;
        [self addSubview:_drawCircleView];
    }
    return _drawCircleView;
}

- (CGGeometryConvertTool *)covertTool
{
    if (_covertTool == nil) {
        _covertTool = [[CGGeometryConvertTool alloc] init];
        _covertTool.covertSize = self.bounds.size;
    }
    return _covertTool;
}

- (DetectCircleTool *)detectCircleTool
{
    if (_detectCircleTool == nil) {
        _detectCircleTool = [[DetectCircleTool alloc] init];
    }
    return _detectCircleTool;
}

- (CoinDetectModel *)coinDetectModel
{
    if (_coinDetectModel == nil) {
        _coinDetectModel = [[CoinDetectModel alloc] init];
    }
    return _coinDetectModel;
}

@end
