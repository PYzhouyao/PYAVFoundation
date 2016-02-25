//
//  ViewController.h
//  PYAVFoundation
//
//  Created by Yao.zhou on 16/2/16.
//  Copyright © 2016年 Yao.zhou. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
@interface ViewController : UIViewController<AVCaptureFileOutputRecordingDelegate>

@property (strong, nonatomic) AVCaptureSession *captureSession;//负责输入和输出设备之间的数据传递
@property (strong, nonatomic) AVCaptureDeviceInput *captureDeviceInput;//负责从AVCaptureDevice获得输入数据
@property (strong, nonatomic) AVCaptureStillImageOutput *captureStillImageOutput;//照片输出流
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;//相机拍摄预览图层

@property (weak, nonatomic) IBOutlet UIView *viewContainer;
@property (weak, nonatomic) IBOutlet UIButton *takeButton;//拍照按钮
@property (weak, nonatomic) IBOutlet UIButton *flashAutoButton;//自动闪光灯按钮
@property (weak, nonatomic) IBOutlet UIButton *flashOnButton;//打开闪光灯按钮
@property (weak, nonatomic) IBOutlet UIButton *flashOffButton;//关闭闪光灯按钮
@property (weak, nonatomic) IBOutlet UIImageView *focusCursor;//聚焦光标

@property (strong, nonatomic) AVCaptureMovieFileOutput *captureMovieFileOutput;//视频输出流
@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;//后台任务标识
@property (assign, nonatomic) BOOL enableRotation;//是否允许旋转（注意在视频录制过程中禁止屏幕旋转）
@property (assign, nonatomic) CGRect *lastBounds;//旋转的前大小

@property (weak, nonatomic) IBOutlet UIButton *takeVideo;//录制按钮
@property (weak, nonatomic) IBOutlet UIButton *stopVideo;//停止录制按钮
@end

