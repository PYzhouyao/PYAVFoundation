//
//  ViewController.m
//  PYAVFoundation
//
//  Created by Yao.zhou on 16/2/16.
//  Copyright © 2016年 Yao.zhou. All rights reserved.
//

#import "ViewController.h"

typedef void (^PropertyChangeBlock)(AVCaptureDevice *captureDevice);

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self.captureSession startRunning];//这里很重要。刚开始做就是忘记startRunning导致预览和拍照功能无法实现
}

-(void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [self.captureSession stopRunning];
}

-(void)dealloc{
    [self removeNotification];
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    //初始化会话
    _captureSession = [[AVCaptureSession alloc]init];
    if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720]) {//设置分辨率
        _captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
    }
    
    /***********************设备********************/
    //获得输入设备
    AVCaptureDevice *captureDevice = [self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];//取得后置摄像头
    if (!captureDevice) {
        NSLog(@"取得后置摄像头时出现问题.");
        return;
    }
    //添加一个音频输入设备
    AVCaptureDevice *audioCaptureDevice = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    
    /***********************设备对象********************/
    NSError *error = nil;
    //根据输入设备初始化设备输入对象，用于获得输入数据
    _captureDeviceInput = [[AVCaptureDeviceInput alloc]initWithDevice:captureDevice error:&error];
     AVCaptureDeviceInput *audioCaptureDeviceInput = [[AVCaptureDeviceInput alloc]initWithDevice:audioCaptureDevice error:&error];
    if (error) {
        NSLog(@"取得设备输入对象时出错，错误原因：%@",error.localizedDescription);
        return;
    }
   
    //初始化设备输出对象，用于获得输出数据
    _captureStillImageOutput = [[AVCaptureStillImageOutput alloc]init];
    NSDictionary *outputSettings = @{AVVideoCodecKey:AVVideoCodecJPEG};
    [_captureStillImageOutput setOutputSettings:outputSettings];
    
    _captureMovieFileOutput = [[AVCaptureMovieFileOutput alloc]init];
    
    /***********************设备对象添加到会话********************/
    //将设备输入添加到会话中
    if ([_captureSession canAddInput:_captureDeviceInput]) {
        [_captureSession addInput:_captureDeviceInput];
    }
    if ([_captureSession canAddInput:audioCaptureDeviceInput]) {
        [_captureSession addInput:audioCaptureDeviceInput];
        AVCaptureConnection *captureConnection = [_captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([captureConnection isVideoStabilizationSupported]) {
            captureConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
        }

    }
    //将设备输出添加到会话中
    if ([_captureSession canAddOutput:_captureStillImageOutput]) {
        [_captureSession addOutput:_captureStillImageOutput];
    }
    if ([_captureSession canAddOutput:_captureMovieFileOutput]) {
        [_captureSession addOutput:_captureMovieFileOutput];
    }
    
    
    //创建视频预览层，用于实时展示摄像头状态
    _captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc]initWithSession:_captureSession];
    
    CALayer *layer = self.viewContainer.layer;
    layer.masksToBounds = YES;
    
    _captureVideoPreviewLayer.frame = layer.bounds;
    _captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;//填充模式
    //将视频预览层添加到界面中
    [layer insertSublayer:_captureVideoPreviewLayer below:self.focusCursor.layer];
    
    [self addNotificationToCaptureDevice:captureDevice];
    [self addGenstureRecognizer];
    [self setFlashModeButtonStatus];
}

#pragma mark - UI方法
#pragma mark 拍照
- (IBAction)takeButtonClick:(UIButton *)sender {
    //根据设备输出获得连接
    AVCaptureConnection *captureConnection = [self.captureStillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    //根据连接取得设备输出的数据
    [self.captureStillImageOutput captureStillImageAsynchronouslyFromConnection:captureConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        if (imageDataSampleBuffer) {
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            UIImage *image = [UIImage imageWithData:imageData];
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
        }
    }];
    
}
#pragma mark 切换前后摄像头
- (IBAction)toggleButtonClick:(UIButton *)sender {
    AVCaptureDevice *currentDevice = [self.captureDeviceInput device];
    AVCaptureDevicePosition currentPosition = [currentDevice position];
    [self removeNotificationFromCaptureDevice:currentDevice];
    AVCaptureDevice *toChangeDevice;
    AVCaptureDevicePosition toChangePosition = AVCaptureDevicePositionFront;//变化的摄像头初始化为前
    if (currentPosition == AVCaptureDevicePositionUnspecified || currentPosition == AVCaptureDevicePositionFront) {
        toChangePosition = AVCaptureDevicePositionBack;//未指明或为前,设为后置摄像头
    }
    toChangeDevice = [self getCameraDeviceWithPosition:toChangePosition];
    //获得要调整的设备输入对象
    AVCaptureDeviceInput *toChangeDeviceInput = [[AVCaptureDeviceInput alloc]initWithDevice:toChangeDevice error:nil];
    
    //改变会话的配置前一定要先开启配置，配置完成后提交配置改变
    [self.captureSession beginConfiguration];
    //移除原有输入对象
    [self.captureSession removeInput:self.captureDeviceInput];
    //添加新的输入对象
    if ([self.captureSession canAddInput:toChangeDeviceInput]) {
        [self.captureSession addInput:toChangeDeviceInput];
        self.captureDeviceInput = toChangeDeviceInput;
    }
    //提交会话配置
    [self.captureSession commitConfiguration];
    
    [self setFlashModeButtonStatus];
}
#pragma mark 自动闪光灯开启
- (IBAction)flashAutoClick:(UIButton *)sender {
    [self setFlashMode:AVCaptureFlashModeAuto];
    [self setFlashModeButtonStatus];
}
#pragma mark 打开闪光灯
- (IBAction)flashOnClick:(UIButton *)sender {
    [self setFlashMode:AVCaptureFlashModeOn];
    [self setFlashModeButtonStatus];
}
#pragma mark 关闭闪光灯
- (IBAction)flashOffClick:(UIButton *)sender {
    [self setFlashMode:AVCaptureFlashModeOff];
    [self setFlashModeButtonStatus];
}

#pragma mark 录制视频
- (IBAction)takeVedioButtonClick:(UIButton *)sender {
    
    //根据设备输出获得连接
    AVCaptureConnection *CaptureConnection = [self.captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    
    //根据连接取得设备输出的数据
    if (![self.captureMovieFileOutput isRecording]) {
        self.enableRotation = NO;
        //如果支持多任务则则开始多任务
        if ([[UIDevice currentDevice] isMultitaskingSupported]) {
            self.backgroundTaskIdentifier = [[UIApplication sharedApplication]beginBackgroundTaskWithExpirationHandler:nil];
        }
        
        //预览图层和视频方向保持一致
        CaptureConnection.videoOrientation = [self.captureVideoPreviewLayer connection].videoOrientation;
        NSString *outputFilePath = [NSTemporaryDirectory() stringByAppendingString:@"myMovie.mov"];
        NSLog(@"save path is :%@",outputFilePath);
        NSURL *fileUrl = [NSURL fileURLWithPath:outputFilePath];
        [self.captureMovieFileOutput startRecordingToOutputFileURL:fileUrl recordingDelegate:self];
    }
    
}

#pragma mark 停止录制视频
- (IBAction)stopVedioButtonClick:(UIButton *)sender {
    if ([self.captureMovieFileOutput isRecording]) {
        [self.captureMovieFileOutput stopRecording];
    }
}



#pragma mark - 视频输出代理
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections{
     NSLog(@"开始录制...");
}
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error{
     NSLog(@"视频录制完成.");
     //视频录入完成之后在后台将视频存储到相簿
    self.enableRotation = YES;
    UIBackgroundTaskIdentifier lastBackgroundTaskIdentifier = self.backgroundTaskIdentifier;
    self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    ALAssetsLibrary *assetsLibrary=[[ALAssetsLibrary alloc]init];
    [assetsLibrary writeVideoAtPathToSavedPhotosAlbum:outputFileURL completionBlock:^(NSURL *assetURL, NSError *error) {
        if (error) {
            NSLog(@"保存视频到相簿过程中发生错误，错误信息：%@",error.localizedDescription);
        }
        if (lastBackgroundTaskIdentifier != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication]endBackgroundTask:lastBackgroundTaskIdentifier];
        }
         NSLog(@"成功保存视频到相簿.");
    }];
    
}
#pragma mark - 通知
/**
 *  给输入设备添加通知
 */
-(void)addNotificationToCaptureDevice:(AVCaptureDevice *)captureDevice{
    //注意添加区域改变捕获通知必须首先设置设备允许捕获
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        captureDevice.subjectAreaChangeMonitoringEnabled = YES;
    }];
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    //捕获区域发生改变
    [notificationCenter addObserver:self selector:@selector(areaChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
}
-(void)removeNotificationFromCaptureDevice:(AVCaptureDevice *)captureDevice{
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
}
/**
 *  移除所有通知
 */
-(void)removeNotification{
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self];
}
-(void)addNotificationToCaptureSession:(AVCaptureSession *)captureSession{
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    //会话出错
    [notificationCenter addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:captureSession];
}

/**
 *  设备连接成功
 *
 *  @param notification 通知对象
 */
-(void)deviceConnected:(NSNotification *)notification{
    NSLog(@"设备已连接...");
}
/**
 *  设备连接断开
 *
 *  @param notification 通知对象
 */
-(void)deviceDisconnected:(NSNotification *)notification{
    NSLog(@"设备已断开.");
}
/**
 *  捕获区域改变
 *
 *  @param notification 通知对象
 */
-(void)areaChange:(NSNotification *)notification{
    NSLog(@"捕获区域改变...");
}
/**
 *  会话出错
 *
 *  @param notification 通知对象
 */
-(void)sessionRuntimeError:(NSNotification *)notification{
    NSLog(@"会话发生错误.");
}

#pragma mark - 私有方法
/**
 *  取得指定位置的摄像头
 *
 *  @param position 摄像头位置
 *
 *  @return 摄像头设备
 */
-(AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position
{
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position] == position) {
            return camera;
        }
    }
    return nil;
}

/**
 *  改变设备属性的统一操作方法
 *
 *  @param propertyChange 属性改变操作
 */
-(void)changeDeviceProperty:(PropertyChangeBlock)propertyChange{
    AVCaptureDevice *captureDevice = [self.captureDeviceInput device];
    NSError *error;
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
    if ([captureDevice lockForConfiguration:&error]) {
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    }else{
        NSLog(@"设置设备属性过程发生错误，错误信息：%@",error.localizedDescription);
    }
}

/**
 *  设置闪光灯模式
 *
 *  @param flashMode 闪光灯模式
 */
-(void)setFlashMode:(AVCaptureFlashMode )flashMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFlashModeSupported:flashMode]) {
            [captureDevice setFlashMode:flashMode];
        }
    }];
}
/**
 *  设置聚焦模式
 *
 *  @param focusMode 聚焦模式
 */
-(void)setFocusMode:(AVCaptureFocusMode )focusMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:focusMode];
        }
    }];
}
/**
 *  设置曝光模式
 *
 *  @param exposureMode 曝光模式
 */
-(void)setExposureMode:(AVCaptureExposureMode)exposureMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:exposureMode];
        }
    }];
}

/**
 *  添加点按手势，点按时聚焦
 */
-(void)addGenstureRecognizer{
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapScreen:)];
    [self.viewContainer addGestureRecognizer:tapGesture];
}
-(void)tapScreen:(UITapGestureRecognizer *)tapGesture{
    CGPoint point = [tapGesture locationInView:self.viewContainer];
    //将UI坐标转化为摄像头坐标
    CGPoint cameraPoint = [self.captureVideoPreviewLayer captureDevicePointOfInterestForPoint:point];
    [self setFocusCursorWithPoint:point];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose atPoint:cameraPoint];
}

/**
 *  设置聚焦光标位置
 *
 *  @param point 光标位置
 */
-(void)setFocusCursorWithPoint:(CGPoint)point{
    self.focusCursor.center = point;
    self.focusCursor.transform = CGAffineTransformMakeScale(2.5, 2.5);//设置缩放比例
    self.focusCursor.alpha = 1.0;
    [UIView animateWithDuration:1.0 animations:^{
        self.focusCursor.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        self.focusCursor.alpha = 0;
    }];
}
/**
 *  设置聚焦点
 *
 *  @param point 聚焦点
 */
-(void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:focusMode];
        }
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:exposureMode];
        }
        if ([captureDevice isFocusPointOfInterestSupported]) {
            [captureDevice setFocusPointOfInterest:point];
        }
        if ([captureDevice isExposurePointOfInterestSupported]) {
            [captureDevice setExposurePointOfInterest:point];
        }
        
    }];
}
/**
 *  设置闪光灯按钮状态
 */
-(void)setFlashModeButtonStatus{
    AVCaptureDevice *captureDevice = [self.captureDeviceInput device];
    AVCaptureFlashMode flashMode = captureDevice.flashMode;
    if ([captureDevice isFlashAvailable]) {
        self.flashAutoButton.hidden=NO;
        self.flashOnButton.hidden=NO;
        self.flashOffButton.hidden=NO;
        self.flashAutoButton.enabled=YES;
        self.flashOnButton.enabled=YES;
        self.flashOffButton.enabled=YES;
        switch (flashMode) {
            case AVCaptureFlashModeAuto:
                self.flashAutoButton.enabled=NO;
                break;
            case AVCaptureFlashModeOn:
                self.flashOnButton.enabled=NO;
                break;
            case AVCaptureFlashModeOff:
                self.flashOffButton.enabled=NO;
                break;
            default:
                break;
        }
    }else{
        self.flashAutoButton.hidden=YES;
        self.flashOnButton.hidden=YES;
        self.flashOffButton.hidden=YES;
    }
    
}
@end
