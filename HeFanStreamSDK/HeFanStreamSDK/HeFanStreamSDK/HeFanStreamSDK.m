//
//  HeFanStreamSDK.m
//  HeFanStreamSDK
//
//  Created by 王利军 on 24/7/2017.
//  Copyright © 2017 王利军. All rights reserved.
//

#import "HeFanStreamSDK.h"

#import "SenseAr.h"
#import <CommonCrypto/CommonDigest.h>
#import <AVFoundation/AVFoundation.h>
#import <OpenGLES/ES2/glext.h>

#import "STGLView.h"
#import "STFrameBuffer.h"
#import "STMobileLog.h"
#import "STMaterialDisplayConfig.h"

#import "cam_live.h"

#define CHECK_LICENSE_WITH_PATH 1
//#define KENCODE_FPS     20
#define kACTION_TIP_STAY_TIME 2.0f


@interface HeFanStreamSDK () <AVCaptureVideoDataOutputSampleBufferDelegate> {
    enum HFSSDKStatus {
        kHFSSDKStatusUnknow=0,
        kHFSSDKStatusInited,
        kHFSSDKStatusActived,
        kHFSSDKStatusActiveFailed,
        kHFSSDKStatusAuthorized,
        kHFSSDKStatusAuthorizeFailed,
        kHFSSDKStatusCreateLiving,
        kHFSSDKStatusDestroyLiving,
    };
    
    enum HFSSDKStatus _status;
    CVOpenGLESTextureRef        _cvOriginalTexutre;
    CVOpenGLESTextureCacheRef   _cvTextureCache;
    GLuint _textureOriginalIn;
    GLuint _textureBeautifyOut;
    GLuint _textureStickerOut;
    
}



@property(nonatomic, copy) NSString* broadcastID;               //the broadcast id is used current view

@property (nonatomic, assign) BOOL isAppActive;

@property (nonatomic, strong) SenseArMaterialService *service;

@property (nonatomic, strong) STGLView *preview;
@property (nonatomic, strong) EAGLContext *glRenderContext;
@property (nonatomic, strong) SenseArMaterialRender *render;

@property (nonatomic, strong) dispatch_queue_t bufferQueue;
@property (nonatomic, strong) dispatch_queue_t streamingQueue;
@property (nonatomic, strong) dispatch_queue_t setMaterialQueue;

@property (nonatomic, strong) NSCondition *encodeCondition;

//camera
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureDevice *videoDevice;
@property (nonatomic, strong) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic, strong) AVCaptureConnection *videoConnection;

@property (nonatomic, assign) BOOL isTorched;

//encoding &streaming
@property (nonatomic) st_live_context_t *stLiveContet;
@property (nonatomic, assign) BOOL isStreaming;

@property (nonatomic, strong) STFrameBuffer *frameBuffer;
@property (nonatomic, strong) NSThread *encodingThread;

@property (nonatomic, copy) NSString *lastMaterialID;

@property (nonatomic, strong) NSDictionary *dicMaterialDisplayConfig;
@property (nonatomic, strong) NSArray *arrLastMaterialParts;

@property (nonatomic, assign) BOOL isLastFrameTriggered;



@end

@implementation HeFanStreamSDK

-(void)appWillResignAction {
    self.isAppActive = NO;
}

-(void)appWillEnterForeground{
    self.isAppActive = YES;
}
-(void)appDidBecomeActive{
    self.isAppActive = YES;
}

-(BOOL) initSDK:(id<AuthorityWithAppIDAndKeyDelegate>)delegate AppID:(NSString*)appID AppKey:(NSString*)appKey Error:(NSError**)error {
    NSLog(@"HeFanStreamSDK:initSDK is called. appid:%@ appkey:%@", appID, appKey);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignAction) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    self.isAppActive = YES;
 
    if (!self.bufferQueue) {
        self.bufferQueue = dispatch_queue_create("com.hefantvstreamsdk.sensear.buffer", NULL);
    }
    if (!self.streamingQueue) {
        self.streamingQueue = dispatch_queue_create("com.hefantvstreamsdk.sensear.streaming", NULL);
    }
    
    if (!self.setMaterialQueue) {
        self.setMaterialQueue = dispatch_queue_create("com.hefantvstreamsdk.sensear.setMaterial", NULL);
    }
    
    _status = kHFSSDKStatusUnknow;
    BOOL rtn = NO;
    
    //默认的素材展示序列及子素材展示配置
    STMaterialDisplayConfig *config1 = [[STMaterialDisplayConfig alloc] init];
    config1.iTriggerType = SENSEAR_HAND_LOVE;
    config1.arrMaterialPartsSequence = @[@[@"ear", @"face", @"pink"],
                                         @[@"ear", @"face", @"yellow"],
                                         @[@"ear", @"face", @"purple"]];
    
    STMaterialDisplayConfig *config2 = [[STMaterialDisplayConfig alloc] init];
    config2.iTriggerType = SENSEAR_HAND_PALM;
    config2.arrMaterialPartsSequence = @[@[@"head", @"face", @"cocacolab"],
                                         @[@"head", @"face", @"jdba"],
                                         @[@"head", @"face", @"milk"]];
    
    self.dicMaterialDisplayConfig = @{
                                      @"20170109124245233850861" : config1,
                                      @"20170109124355279333705" : config2
                                      };
    
    self.isTorched = NO;
    
    struct HFSBeautifyValue bv;
    bv.redden = 0.36f;
    bv.smooth = 0.74f;
    bv.whiten = 0.02f;
    bv.shrinkFace = 0.11f;
    bv.enlargeEye = 0.13f;
    bv.shrinkJaw  = 0.10f;
    self.beautifyValueCfg = bv;
    
    struct HFSVideoConfig vc;
    vc.codecType = kVideoCodecIOSH264;
    vc.imageWidth = 720;
    vc.imageHeight = 1280;
    vc.rotMode = kVideoRotation0;
    vc.bitrate = 800000;
    vc.fps      = 16;
    vc.iFrame   = 1000;
    self.videoCfg = vc;
    
    struct HFSAudioConfig av;
    av.codecType = kAudioCodecIOSAAC;
    av.Channels = 2;
    av.bitsPerSample = 16;
    av.bps = 20;
    av.sampleRate = 44100;
    
    //test for camera
    [self CameraTest];
 
    //test for microphone
    [self MicrophoneTest];
   
    self.service = [SenseArMaterialService shareInstnce];
    

    _status = kHFSSDKStatusInited;
    
    //check active code
    rtn = [self checkActiveCode];
    if (rtn) {
        _status = kHFSSDKStatusActived;
    } else {
        _status = kHFSSDKStatusActiveFailed;
        *error = [NSError errorWithDomain:@"com.HeFanStreamSDK.ErrorCode" code:-1 userInfo:[[NSDictionary alloc] initWithObjectsAndKeys:@"active code is wrong.", @"NSLocalizedDescriptionKey", NULL]];
        return rtn;
    }
    
    [self authorizeWithAppID:delegate AppID:appID AppKey:appKey];
    
    rtn = YES;
    return rtn;
}

-(BOOL) createLiving:(NSString*)broadcastID CurView:(UIView*)curView Error:(NSError**)error{
    __block BOOL rtn = NO;
    
    if (_status != kHFSSDKStatusAuthorized) {
        if (error) {
             *error = [NSError errorWithDomain:@"com.HeFanStreamSDK.ErrorCode" code:_status userInfo:[[NSDictionary alloc] initWithObjectsAndKeys:@"the status is sdk is wrong.", @"NSLocalizedDescriptionKey", NULL]];
        }
        return rtn;
    }
    
    self.broadcastID = broadcastID;
    self.isAppActive = YES;
    
    if (!self.preview) {
        CGRect displayRect = [self getZoomedRectWithImageWidth:self.videoCfg.imageWidth ImageHeight:self.videoCfg.imageHeight InRect:curView.bounds ScaleToFit:NO];
        self.preview = [[STGLView alloc] initWithFrame:displayRect];
    }
    [curView insertSubview:self.preview atIndex:0];
   
    
    [self setupMaterialRender];
    
    //configure camera
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        // 设置 AVCaptureSession .
        if ([self setupCaptureSession]) {
            
            [self startCaptureSession];
           
            usleep(10);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.preview setHidden:NO];
            });
        }else{
            NSLog(@"setup capture failed");
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"AVCapture 设置失败请查看摄像机权限" delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil, nil];
            dispatch_sync(dispatch_get_main_queue(), ^{
                [alert show];
            });
        }
    });
    
    _status = kHFSSDKStatusCreateLiving;
    return rtn=YES;
}

-(BOOL) destoryLiving {
    BOOL rtn = NO;
    if (_status != kHFSSDKStatusCreateLiving) {
        return rtn;
    }
    
    if (self.isStreaming) {
        [self stopLiving];
    }
    
    self.isAppActive = NO;
    
    [self stopCaptureSession];
    
    [self.preview setHidden:YES];
    self.broadcastID = nil;
    
    
    _status = kHFSSDKStatusAuthorized;
    return rtn;
}

-(BOOL) startLiving:(NSString*)rtmpURL{
    
    NSLog(@"startLiving...........");
    return [self setupAndStartStreaming:rtmpURL];
}

-(void) stopLiving{
    NSLog(@"stopLiving...........");
    [self stopAndDestroyStreaming];
}

-(BOOL)setupAndStartStreaming:(NSString*)rtmpURL {
    if (self.isStreaming) {
        return YES;
    }
    
    [self.encodingThread = [NSThread alloc] initWithTarget:self selector:@selector(encodeAndSendFrame) object:nil];
    [self.encodingThread setName:@"com.hefantv.sensear.encodeThread"];
    
    //设置缓存帧数， 保证预览的流畅度
    self.frameBuffer = [[STFrameBuffer alloc] initWithCapacity:10];
    st_live_context_t *stLiveContext = NULL;
    st_live_config_t stConfig;
    memset(&stConfig, 0, sizeof(stConfig));
    
    NSInteger iSysVersion = [[[UIDevice currentDevice] systemVersion] integerValue];
    
    //可以根据实际情况设置软编码或硬编码，这里根据版本自动切换
    stConfig.codec = iSysVersion >= 8.0 ? ST_LIVE_CODEC_VIDEOTOOLBOX : ST_LIVE_CODEC_X264;
    stConfig.mode = "faster";
    
    //可以根据实际情况调整
    stConfig.video_bit_rate = self.videoCfg.bitrate;
    
    int iRet = st_live_create_context(ST_LIVE_SINK_RTMP, [rtmpURL UTF8String], &stConfig, &stLiveContext);
    if (iRet || !stLiveContext) {
        NSLog(@"fail to init live streaming.");
        return NO;
    }
    self.stLiveContet = stLiveContext;
    BOOL bStart = [self startStreamingAndEncoding];
    return bStart;
}

-(BOOL)startStreamingAndEncoding{
    int iRet = st_live_start_streaming(self.stLiveContet, self.videoCfg.imageWidth, self.videoCfg.imageHeight, self.videoCfg.fps, ST_LIVE_FMT_NV12);
    if (![self.encodingThread isExecuting]) {
        [self.encodingThread start];
    }
    
    self.isStreaming = 0==iRet;
    return self.isStreaming;
}

-(void)stopAndDestroyStreaming {
    [self.frameBuffer removeAllFrames];
    
    [self.encodingThread cancel];
    
    [self.encodeCondition lock];
    [self.encodeCondition signal];
    [self.encodeCondition unlock];
    
    if (self.isStreaming) {
        self.isStreaming = NO;
        dispatch_sync(self.streamingQueue, ^{
            int iRet = st_live_stop_streaming(self.stLiveContet);
            if (0 != iRet) {
                NSLog(@"st_live_stop_streamoing failed. ");
            }
        });
    }
    [self destroyStreaming];
}

-(void)destroyStreaming{
    if (self.stLiveContet) {
        dispatch_sync(self.streamingQueue, ^{
            st_live_destroy_context(self.stLiveContet);
            self.stLiveContet = NULL;
        });
    }
}
-(BOOL) initSDK:(NSString*)broadcastID Error:(NSError**)error{
    NSLog(@"HeFanStreamSDK:initSDK is called.");
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignAction) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
   
    self.broadcastID = broadcastID;
    self.isAppActive = YES;
    
    _status = kHFSSDKStatusUnknow;
    BOOL rtn = NO;
    
    //默认的素材展示序列及子素材展示配置
    STMaterialDisplayConfig *config1 = [[STMaterialDisplayConfig alloc] init];
    config1.iTriggerType = SENSEAR_HAND_LOVE;
    config1.arrMaterialPartsSequence = @[@[@"ear", @"face", @"pink"],
                                         @[@"ear", @"face", @"yellow"],
                                         @[@"ear", @"face", @"purple"]];
    
    STMaterialDisplayConfig *config2 = [[STMaterialDisplayConfig alloc] init];
    config2.iTriggerType = SENSEAR_HAND_PALM;
    config2.arrMaterialPartsSequence = @[@[@"head", @"face", @"cocacolab"],
                                         @[@"head", @"face", @"jdba"],
                                         @[@"head", @"face", @"milk"]];
    
    self.dicMaterialDisplayConfig = @{
                                      @"20170109124245233850861" : config1,
                                      @"20170109124355279333705" : config2
                                      };
    
    
    struct HFSBeautifyValue bv;
    bv.redden = 0.36f;
    bv.smooth = 0.74f;
    bv.whiten = 0.02f;
    bv.shrinkFace = 0.11f;
    bv.enlargeEye = 0.13f;
    bv.shrinkJaw  = 0.10f;
    self.beautifyValueCfg = bv;
    
    struct HFSVideoConfig vc;
    vc.codecType = kVideoCodecIOSH264;
    vc.imageWidth = 720;
    vc.imageHeight = 1280;
    vc.rotMode = kVideoRotation0;
    vc.bitrate = 800;
    vc.fps      = 16;
    vc.iFrame   = 1000;
    self.videoCfg = vc;
    
    struct HFSAudioConfig av;
    av.codecType = kAudioCodecIOSAAC;
    av.Channels = 2;
    av.bitsPerSample = 16;
    av.bps = 20;
    av.sampleRate = 44100;
    
    //test for camera
    rtn = [self CameraTest];
    if (!rtn) {
        *error = [NSError errorWithDomain:@"com.HeFanStreamSDK.ErrorCode" code:-1 userInfo:[[NSDictionary alloc] initWithObjectsAndKeys:@"camera must be authorized.", @"NSLocalizedDescriptionKey", NULL]];
        return rtn;
    }
    
    //test for microphone
    rtn = [self MicrophoneTest];
    if (!rtn) {
        *error = [NSError errorWithDomain:@"com.HeFanStreamSDK.ErrorCode" code:-1 userInfo:[[NSDictionary alloc] initWithObjectsAndKeys:@"Microphone must be authorized.", @"NSLocalizedDescriptionKey", NULL]];
        return rtn;
    }
    
    self.service = [SenseArMaterialService shareInstnce];
    
    self.bufferQueue = dispatch_queue_create("com.hefantvstreamsdk.sensear.buffer", NULL);
    self.streamingQueue = dispatch_queue_create("com.hefantvstreamsdk.sensear.streaming", NULL);
    self.setMaterialQueue = dispatch_queue_create("com.hefantvstreamsdk.sensear.setMaterial", NULL);
    
    _status = kHFSSDKStatusInited;
    
    //check active code
    rtn = [self checkActiveCode];
    if (rtn) {
        _status = kHFSSDKStatusActived;
    } else {
        *error = [NSError errorWithDomain:@"com.HeFanStreamSDK.ErrorCode" code:-1 userInfo:[[NSDictionary alloc] initWithObjectsAndKeys:@"active code is wrong.", @"NSLocalizedDescriptionKey", NULL]];
    }
    
    return rtn;
}

-(void) authorizeWithAppID:(id<AuthorityWithAppIDAndKeyDelegate>)delegate AppID:(NSString*)appID AppKey:(NSString*)appKey {
    [self.service authorizeWithAppID:appID appKey:appKey onSuccess:^{
        _status = kHFSSDKStatusAuthorized;
        if (delegate) {
            [delegate OnAuthorityResult:YES];
        }
        NSLog(@"authorizeWithAppID successed.");
    } onFailure:^(SenseArAuthorizeError iErrorCode) {
        _status = kHFSSDKStatusAuthorizeFailed;
        if (delegate) {
            [delegate OnAuthorityResult:NO];
        }
        NSLog(@"authorizeWithAppID failed. errorCode:%d", iErrorCode);
    }];
}

-(CGRect)getZoomedRectWithImageWidth:(int)width ImageHeight:(int)height InRect:(CGRect)rect ScaleToFit:(BOOL)bScaleToFit {
    CGRect rectRet = rect;
    
    float scaleX = width/CGRectGetWidth(rect);
    float scaleY = height/CGRectGetHeight(rect);
    float fScale = bScaleToFit ? fmaxf(scaleX, scaleY) : fminf(scaleX, scaleY);
    
    width /= fScale;
    height /= fScale;
    
    CGFloat fX = rect.origin.x - (width - rect.size.width) / 2.0f;
    CGFloat fY = rect.origin.y - (height - rect.size.height) / 2.0f;
    rectRet.origin.x = fX;
    rectRet.origin.y = fY;
    rectRet.size.width = width;
    rectRet.size.height = height;
    
    return rectRet;
}

-(void)setupPreviewAndBegin:(UIView*) currentView {
    NSLog(@"HeFanStreamSDK:setPreview is called.");
    CGRect displayRect = [self getZoomedRectWithImageWidth:self.videoCfg.imageWidth ImageHeight:self.videoCfg.imageHeight InRect:currentView.bounds ScaleToFit:NO];
    self.preview = [[STGLView alloc] initWithFrame:displayRect];
    [currentView insertSubview:self.preview atIndex:0];
    
    [self setupMaterialRender];
    
    //configure camera
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        // 设置 AVCaptureSession .
        if ([self setupCaptureSession]) {
            
            [self startCaptureSession];
        }else{
            
            NSLog(@"setup capture failed");
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"AVCapture 设置失败" delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil, nil];
            
            dispatch_sync(dispatch_get_main_queue(), ^{
                
                [alert show];
            });
        }
    });
    
}

-(BOOL) createBroadcast {
    BOOL rtn = NO;
    NSLog(@"HeFanStreamSDK:beginPreview is called.");

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self startCaptureSession];
    });
    [self.preview setHidden:NO];
    
    return rtn;
}

-(BOOL) destoryBroadcast {
    BOOL rtn = NO;
    NSLog(@"HeFanStreamSDK:endPreview is called.");
    
    [self.preview setHidden:YES];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self stopCaptureSession];
    });
    
    return rtn;
}

-(void)startShowingMaterial:(NSString*)materialID {
    if (self.setMaterialQueue) {
        dispatch_async(self.setMaterialQueue, ^{
            SenseArRenderStatus iStatus = [self.render setMaterial:materialID ];
            if (RENDER_SUCCESS == iStatus) {
                self.curMateralID = materialID;
            } else {
                if (RENDER_UNSUPPORTED_MATERIAL == iStatus) {
                    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"information" message:@"not support the material." delegate:nil cancelButtonTitle:@"cancel" otherButtonTitles:nil, nil];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [alert show];
                    });
                }
            }
        });
    }
}

-(void) downloadMateral:(id<DownloadMateralResultDelegate>)delegate MaterialID:(NSString *) materialID {
    NSLog(@"HeFanStreamSDK:DownloadMateral is called.");

    //download material
    BOOL isMaterialDownloaded = [self.service isMaterialDownloaded:materialID];
    
    if (!isMaterialDownloaded) {
        [self.service fetchMaterialWithUserID:self.broadcastID materialID:materialID onSuccess:^(SenseArMaterial *material) {
            [self.service downloadMaterial:material onSuccess:^(SenseArMaterial *materialNew) {
                if (delegate) {
                    [delegate OnDownloadMateralOk:materialID];
                }
                [self startShowingMaterial:materialID];
                
                NSLog(@"download material ok.  name:%@ id:%@ triggeraction:%d %x:%x" , materialNew.strName, materialNew.strID, materialNew.iTriggerAction,  material, materialNew);
            } onFailure:^(SenseArMaterial *material, int iErrorCode, NSString *strMessage) {
                if (delegate) {
                    [delegate OnDownloadMateralFailed:materialID];
                }
                NSLog(@"download material failed. name:%@ id:%@ errcode:%d msg:%@", material.strName, material.strID, iErrorCode, strMessage);
            } onProgress:^(SenseArMaterial *material, float fProgress, int64_t iSize) {
                if (delegate) {
                    [delegate OnDownloadMateralProcess:materialID Process:fProgress];
                }
                NSLog(@"download material progress. name:%@ id:%@ progress:%f size:%d", material.strName, material.strID, fProgress, iSize);
            }];
            
        } onFailure:^(int iErrorCode, NSString *strMessage) {
            UIAlertView* alter = [[UIAlertView alloc] initWithTitle:@"information" message:[NSString stringWithFormat:@"fetch material failed. id:", materialID] delegate:nil cancelButtonTitle:@"cancel" otherButtonTitles:nil, nil];
            [alter show];
        }];
    } else {
        [self startShowingMaterial:materialID];
    }
}

-(void) showMateral:(NSString*) materialID {
    [self startShowingMaterial:materialID];
}
-(void) switchCamera{
    NSLog(@"HeFanStreamSDK:SwitchCamera is called.");
    
    self.isAppActive = NO;
    
    AVCaptureDevice *currentDevice = [self.videoDeviceInput device];
    AVCaptureDevicePosition currentPosition = [currentDevice position];
    
    AVCaptureDevicePosition toChangeDevicePosition=AVCaptureDevicePositionFront;
    if (currentPosition == AVCaptureDevicePositionFront) {
        toChangeDevicePosition = AVCaptureDevicePositionBack;
    }
    AVCaptureDevice *toChangeDevice;
    
    NSArray *devices = [AVCaptureDevice devices];
    for (AVCaptureDevice *device in devices) {
        NSLog(@"device info type:%@", device.deviceType);
        
        if ([device hasMediaType:AVMediaTypeVideo]) {
            NSLog(@"video device postion:%d", [device position]);
            if ([device position] == toChangeDevicePosition) {
                toChangeDevice = device;
                break;
            }
        }
    }
    
    NSError *error = nil;
    AVCaptureDeviceInput *toChangeDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:toChangeDevice error:&error];
    if (!toChangeDeviceInput || error) {
        NSLog(@"create toChangeDeviceInput device input failed.");
        return;
    }
    
    [self.captureSession beginConfiguration];
    [self.captureSession removeInput:self.videoDeviceInput];
    if ([self.captureSession canAddInput:toChangeDeviceInput]) {
        [self.captureSession addInput:toChangeDeviceInput];
        self.videoDeviceInput = toChangeDeviceInput;
        self.videoDevice = toChangeDevice;
        NSLog(@"add deviceinput successed. preposition:%d switch camera to position:%d", currentPosition, toChangeDevicePosition);
    } else {
        NSLog(@"add add deviceinput failed.");
    }
    CMTime frameDuration = CMTimeMake(1, self.videoCfg.fps);
    
    if ([self.videoDevice lockForConfiguration:&error]) {
        self.videoDevice.activeVideoMinFrameDuration = frameDuration;
        self.videoDevice.activeVideoMaxFrameDuration = frameDuration;
        [self.videoDevice unlockForConfiguration];
    }
    
    [self.captureSession commitConfiguration];
    
    self.videoConnection = [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    if ([self.videoConnection isVideoOrientationSupported]) {
        [self.videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    }
    if ([self.videoConnection isVideoMirroringSupported]) {
        [self.videoConnection setVideoMirrored:self.videoDevice.position==AVCaptureDevicePositionFront];
    }
    self.isAppActive = YES;
    
}

-(void) flashLight {
    NSError *error = nil;
    
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if ([captureDevice hasTorch]) {
        BOOL locked = [captureDevice lockForConfiguration:&error];
        
        if (locked) {
            if (self.isTorched) {
                captureDevice.torchMode = AVCaptureTorchModeOff;
                self.isTorched = NO;
            } else {
                captureDevice.torchMode = AVCaptureTorchModeOn;
                self.isTorched = YES;
            }
            [captureDevice unlockForConfiguration];
        }
        
    }
}

-(void) validateBeautifyValue {
    if (self.render) {
        if (![self.render setBeautifyValue:self.beautifyValueCfg.redden forBeautifyType:BEAUTIFY_REDDEN_STRENGTH]) {
            NSLog(@"set BEAUTIFY_REDDEN_STRENGTH failed");
        }
        if (![self.render setBeautifyValue:self.beautifyValueCfg.smooth forBeautifyType:BEAUTIFY_SMOOTH_STRENGTH]) {
            NSLog(@"set BEAUTIFY_SMOOTH_STRENGTH failed");
        }
        if (![self.render setBeautifyValue:self.beautifyValueCfg.whiten forBeautifyType:BEAUTIFY_WHITEN_STRENGTH]) {
            NSLog(@"set BEAUTIFY_WHITEN_STRENGTH failed");
        }
        if (![self.render setBeautifyValue:self.beautifyValueCfg.shrinkFace forBeautifyType:BEAUTIFY_SHRINK_FACE_RATIO]) {
            NSLog(@"set BEAUTIFY_SHRINK_FACE_RATIO failed");
        }
        if (![self.render setBeautifyValue:self.beautifyValueCfg.enlargeEye forBeautifyType:BEAUTIFY_ENLARGE_EYE_RATIO]) {
            NSLog(@"set BEAUTIFY_ENLARGE_EYE_RATIO failed");
        }
        if (![self.render setBeautifyValue:self.beautifyValueCfg.shrinkJaw forBeautifyType:BEAUTIFY_SHRINK_JAW_RATIO]) {
            NSLog(@"set BEAUTIFY_SHRINK_JAW_RATIO failed");
        }
    }
}

//local license need to be active, if not the sdk will not work well.
-(BOOL)checkActiveCode {
    
    NSString* strLicensePath = [[NSBundle mainBundle] pathForResource:@"SENSEME" ofType:@"lic"];
    NSData* dataLicense = [NSData dataWithContentsOfFile:strLicensePath];
    
    NSString *strKeySHA1 = @"SENSEME";
    NSString *strKeyActiveCode = @"ACTIVE_CODE";
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSString *strStoredSHA1 = [userDefaults objectForKey:strKeySHA1];
    NSString *strLicenseSHA1 = [self getSHA1StringWithData:dataLicense];
    NSString *strActiveCode = nil;
    
    NSError *error = nil;
    BOOL bSuccess = NO;
    
    if (strStoredSHA1.length > 0 && [strStoredSHA1 isEqualToString:strLicenseSHA1]) {
        
        strActiveCode = [userDefaults objectForKey:strKeyActiveCode];
        
#if CHECK_LICENSE_WITH_PATH
        //use file
        bSuccess = [SenseArMaterialService checkActiveCode:strActiveCode licensePath:strLicensePath error:&error];
#else
        //use buffer
        bSuccess = [SenseArMaterialService checkActiveCode:strActiveCode licenseData:dataLicense error:&error];
#endif
        
        if (bSuccess && !error) {
            return YES;
        }
    }
    //
    //check failed
    //new once
    //update
#if CHECK_LICENSE_WITH_PATH
    strActiveCode = [SenseArMaterialService generateActiveCodeWithLicensePath:strLicensePath error:&error];
#else
    strActiveCode = [SenseArMaterialService generateActiveCodeWithLicenseData:dataLicense error:&error];
#endif
    if (strActiveCode.length <= 0 && error) {
        UIAlertView* alter = [[UIAlertView alloc] initWithTitle:@"information" message:@"use license make active code failed. maybe the authorize is expired" delegate:nil cancelButtonTitle:@"cancel" otherButtonTitles:nil, nil];
        [alter show];
        return NO;
    } else {
        [userDefaults setObject:strActiveCode forKey:strKeyActiveCode];
        [userDefaults setObject:strLicenseSHA1 forKey:strKeySHA1];
        [userDefaults synchronize];
    }
    
    return YES;
}

-(NSString *)getSHA1StringWithData:(NSData*)data {
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(data.bytes, (unsigned int)data.length, digest);
    
    NSMutableString *strSHA1 = [NSMutableString string];
    for (int i=0; i<CC_SHA1_DIGEST_LENGTH; i++) {
        [strSHA1 appendFormat:@"%02x", digest[i]];
    }
    return strSHA1;
}

-(BOOL)CameraTest {
   __block BOOL rtn = NO;

    AVAuthorizationStatus videoAuthStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (videoAuthStatus == AVAuthorizationStatusNotDetermined) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            rtn = granted;
        }];
    } else if (videoAuthStatus == AVAuthorizationStatusRestricted || videoAuthStatus == AVAuthorizationStatusDenied) {
        return rtn;
    } else {
        rtn = YES;
    }
    
    return rtn;
}

-(BOOL)MicrophoneTest {
    __block BOOL rtn = NO;
    
    AVAuthorizationStatus videoAuthStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if (videoAuthStatus == AVAuthorizationStatusNotDetermined) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
            rtn = granted;
        }];
    } else if (videoAuthStatus == AVAuthorizationStatusRestricted || videoAuthStatus == AVAuthorizationStatusDenied) {
        return rtn;
    } else {
        rtn = YES;
    }
    
    return rtn;
}


-(BOOL)setupCaptureSession {
    if (!self.captureSession) {
        self.captureSession = [[AVCaptureSession alloc] init];
    }
    
    //根据实际需要修改 sessionPreset
    self.captureSession.sessionPreset = AVCaptureSessionPresetiFrame1280x720;
    
    NSArray *devices = [AVCaptureDevice devices];
    for (AVCaptureDevice *device in devices) {
        if ([device hasMediaType:AVMediaTypeVideo]) {
            if ([device position] == AVCaptureDevicePositionFront) {
                self.videoDevice = device;
            }
        }
    }
    
    NSError *error = nil;
    self.videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.videoDevice error:&error];
    if (!self.videoDeviceInput || error) {
        NSLog(@"create video device input failed.");
        return NO;
    }
    
    if (!self.videoDataOutput) {
        self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    }
    
    [self.videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
    
    [self.videoDataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    if (!self.videoDataOutput) {
        return NO;
    }
    
    [self.videoDataOutput setSampleBufferDelegate:self queue:self.bufferQueue];
    
    [self.captureSession beginConfiguration];
    if ([self.captureSession canAddInput:self.videoDeviceInput]) {
        [self.captureSession addInput:self.videoDeviceInput];
    }
    if ([self.captureSession canAddOutput:self.videoDataOutput]) {
        [self.captureSession addOutput:self.videoDataOutput];
    }
    CMTime frameDuration = CMTimeMake(1,  self.videoCfg.fps);
    
    if ([self.videoDevice lockForConfiguration:&error]) {
        self.videoDevice.activeVideoMaxFrameDuration = frameDuration;
        self.videoDevice.activeVideoMinFrameDuration = frameDuration;
        [self.videoDevice unlockForConfiguration];
    }
    [self.captureSession commitConfiguration];
    
    self.videoConnection = [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    if ([self.videoConnection isVideoOrientationSupported]) {
        [self.videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    }
    if ([self.videoConnection isVideoMirroringSupported]) {
        [self.videoConnection setVideoMirrored:self.videoDevice.position==AVCaptureDevicePositionFront];
    }
    return YES;
}

-(void)startCaptureSession {
    if (self.captureSession && ![self.captureSession isRunning]) {
        [self.captureSession startRunning];
    }
}

-(void)stopCaptureSession {
    if (self.captureSession && [self.captureSession isRunning]) {
        [self.captureSession stopRunning];
    }
}

-(EAGLContext*) getPreContext {
    return [EAGLContext currentContext];
}

-(void)setCurrentContext:(EAGLContext*)context {
    if([EAGLContext currentContext] != context) {
        [EAGLContext setCurrentContext:context];
    }
}

void activeAndBindTexture(GLenum textureActive,
                          GLuint *textureBind,
                          Byte *sourceImage,
                          GLenum sourceFormat,
                          GLsizei iWidth,
                          GLsizei iHeight) {
    
    glActiveTexture(textureActive);
    glBindTexture(GL_TEXTURE_2D, *textureBind);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, iWidth, iHeight, 0, sourceFormat, GL_UNSIGNED_BYTE, sourceImage);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);
    
    glFlush();
}

-(void)setupMaterialRender{
    //记录调用SDK之前的渲染环境以便在调用SDK之后设置回来
    EAGLContext *preContext = [self getPreContext];
    
    //创建OpenGL上下文，根据实际情况与预览使用同一个context或shareGroup
    self.glRenderContext = self.preview.context;
    
    //调用SDK之前需要切换到SDK的渲染环境
    [self setCurrentContext:self.glRenderContext];
    
    CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, self.glRenderContext, NULL, &_cvTextureCache);
    if(err) {
        NSLog(@"CVOpenGLESTextureCacheCreate %d", err);
    }
    
    //创建美颜和贴纸的结果纹理
    glGenTextures(1, &_textureBeautifyOut);
    activeAndBindTexture(GL_TEXTURE1, &_textureBeautifyOut, NULL, GL_RGBA, self.videoCfg.imageWidth, self.videoCfg.imageHeight);
    
    glGenTextures(1, &_textureStickerOut);
    activeAndBindTexture(GL_TEXTURE1, &_textureStickerOut, NULL, GL_RGBA, self.videoCfg.imageWidth, self.videoCfg.imageHeight);
    
    //获取模型路径
    NSString *strModelPath = [[NSBundle mainBundle] pathForResource:@"action3.4.0" ofType:@"model"];
    
    //根据实际需求决定是否开启美颜和动作检测
    self.render = [SenseArMaterialRender instanceWithModelPath:strModelPath config:SENSEAR_ENABLE_HUMAN_ACTION | SENSEAR_ENABLE_BEAUTIFY context:self.glRenderContext];
    if (self.render) {
        //初始化渲染模块使用的OpenGL资源
        [self.render initGLResource];
        
        //根据需求设置美颜参数
        [self validateBeautifyValue];
        
        //render callback
        self.render.renderBegin = ^(NSString *materialID) {
            NSLog(@"%@ begin render.", materialID);
        };
        self.render.renderEnd = ^(NSString *materialID) {
            NSLog(@"%@ end redner.", materialID);
        };
        NSLog(@"setupMaterialRender ok.");
    } else {
        NSLog(@"setupMaterialRender failed.");
    }
    
    //需要设为之前的渲染环境防止与其他需要GPU资源的模块冲突
    [self setCurrentContext:preContext];
}

-(void)changeToNextPartsWithMaterialID:(NSString*)strMaterialID materialParts:(NSArray <SenseArMaterialPart*>*) arrMaterialParts {
    STMaterialDisplayConfig *config = [self.dicMaterialDisplayConfig objectForKey:strMaterialID];
    NSArray <NSArray*> *arrNextParts = [config nextParts];
    if (arrNextParts.count) {
        for (SenseArMaterialPart *materialPart in arrMaterialParts) {
            for (NSString *strPartName in arrNextParts) {
                if ([materialPart.strPartName isEqualToString:strPartName]) {
                    materialPart.isEnable = YES;
                    break;
                } else {
                    materialPart.isEnable = NO;
                }
            }
        }
        [self.render enableMaterialParts:arrMaterialParts];
    }
}

-(void)resetCurrentPartsIndexWithID:(NSString*)strID{
    STMaterialDisplayConfig *config = [self.dicMaterialDisplayConfig objectForKey:strID];
    config.iCurrentPartsIndex = -1;
}

-(SenseArRotateType)getRotateType {
    BOOL isFrontCamera = self.videoDevice.position == AVCaptureDevicePositionFront;
    BOOL isVideoMirrored = self.videoConnection.isVideoMirrored;
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    
    switch (deviceOrientation) {
        case UIDeviceOrientationPortrait:
            return CLOCKWISE_ROTATE_0;
        case UIDeviceOrientationPortraitUpsideDown:
            return CLOCKWISE_ROTATE_180;
        case UIDeviceOrientationLandscapeLeft:
            return ((isFrontCamera && isVideoMirrored) || (!isFrontCamera && !isVideoMirrored)) ? CLOCKWISE_ROTATE_270 : CLOCKWISE_ROTATE_90;
        case UIDeviceOrientationLandscapeRight:
            return ((isFrontCamera && isVideoMirrored) || (!isFrontCamera && !isVideoMirrored)) ? CLOCKWISE_ROTATE_90 : CLOCKWISE_ROTATE_270;
            
        default:
            return CLOCKWISE_ROTATE_0;
    }
}

-(BOOL)isMaterialTriggered:(NSString*)strMaterialID frameActionInfo:(SenseArFrameActionInfo*)frameActionInfo{
    STMaterialDisplayConfig *config = [self.dicMaterialDisplayConfig objectForKey:strMaterialID];
    
    if (!config) {
        return NO;
    }
    if (!frameActionInfo) {
        return NO;
    }
    for (SenseArFace *arFace in frameActionInfo.arrFaces) {
        if ((arFace.iAction & config.iTriggerType) > 0) {
            return YES;
        }
    }
    for (SenseArHand *arHand in frameActionInfo.arrHands) {
        if ((arHand.iAction & config.iTriggerType) > 0) {
            return YES;
        }
    }
    return NO;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    // NSLog(@"capture output .........");
    //if the application is not active, we do not anything
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        NSLog(@"application is not active");
        return;
    }
    if (!self.isAppActive) {
        NSLog(@"appactive is not active");
        return;
    }
    //get pts
    CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    long lPTS = (long)(timestamp.value/(timestamp.timescale/1000));
    
    //NSLog(@"capture output ......... connection:%x myconnection:%x", connection, self.videoConnection);
    
    //video
    if (connection == self.videoConnection) {
        TIMELOG(totalCost);
        
        CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        unsigned char* pBGRAImageInput = CVPixelBufferGetBaseAddress(pixelBuffer);
        int iBytesPerRow = (int)CVPixelBufferGetBytesPerRow(pixelBuffer);
        
        int iWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
        int iHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
        size_t iTop, iLeft, iBottom, iRight = 0;
        CVPixelBufferGetExtendedPixels(pixelBuffer, &iLeft, &iRight, &iTop, &iBottom);
        
        iWidth += ((int)iLeft + (int)iRight);
        iHeight += ((int)iTop + (int)iBottom);
        iBytesPerRow += (iLeft+iRight);
        
        //record the environment of render before
        EAGLContext *preContext = [self getPreContext];
        //set the environment of render of sdk
        [self setCurrentContext:self.glRenderContext];
        GLuint textureResult = 0;
        
        //原图纹理
        CVReturn cvRet = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                      _cvTextureCache,
                                                                      pixelBuffer,
                                                                      NULL,
                                                                      GL_TEXTURE_2D,
                                                                      GL_RGBA,
                                                                      iWidth,
                                                                      iHeight,
                                                                      GL_BGRA,
                                                                      GL_UNSIGNED_BYTE,
                                                                      0,
                                                                      &_cvOriginalTexutre);
        
        if (!_cvOriginalTexutre || kCVReturnSuccess != cvRet) {
            NSLog(@"CVOpenGLESTextureCacheCreateTextureFromImage %d", cvRet);
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            [self setCurrentContext:preContext];
            return;
        }
        
        _textureOriginalIn = CVOpenGLESTextureGetName(_cvOriginalTexutre);
        glBindTexture(GL_TEXTURE_2D, _textureOriginalIn);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glBindTexture(GL_TEXTURE_2D, 0);
        
        /*
        textureResult = _textureOriginalIn;
        [self setCurrentContext:preContext];
        
        [self.preview renderWithTexture:textureResult
                                   size:CGSizeMake(iWidth, iHeight)
                                flipped:YES
                    applyingOrientation:1];
        glFlush();
        */
        
        //用于推流的图像数据
        Byte *pNV12ImageOut = NULL;
        int iImageNV12Length = sizeof(Byte)*iWidth*iHeight*3/2;
        
        //分配渲染信息的内存空间
        Byte *pFrameInfo = (Byte*)malloc(sizeof(Byte)*10000);
        memset(pFrameInfo, 0, sizeof(Byte)*10000);
        int iInfoLength = 10000;
        
        SenseArRenderStatus iRenderStatus = RENDER_UNKNOWN;
        NSString *strCurrentMaterialID = self.curMateralID;
        
        if (!self.render || ![SenseArMaterialService isAuthorized]) {
            iRenderStatus = RENDER_NOT_AUTHORIZED;
            textureResult = _textureOriginalIn;
        } else {
            if (self.isStreaming) {
                pNV12ImageOut = (Byte*)malloc(iImageNV12Length);
                memset(pNV12ImageOut, 0, iImageNV12Length);
            }
            
            //美颜输出
            [self.render setFrameWidth:iWidth height:iHeight stride:iBytesPerRow];
            SenseArRotateType iRotate = [self getRotateType];
            
            TIMELOG(beautifyCost);
            iRenderStatus = [self.render beautifyAndGenerateFrameInfo:pFrameInfo
                                                      frameInfoLength:&iInfoLength
                                                    withPixelFormatIn:PIX_FMT_BGRA8888
                                                              imageIn:pBGRAImageInput
                                                            textureIn:_textureOriginalIn
                                                           rotateType:iRotate
                                                       needsMirroring:NO
                                                       pixelFormatOut:PIX_FMT_NV12
                             //imageOut:pNV12ImageOut
                                                             imageOut:NULL
                                                           textureOut:_textureBeautifyOut];
            glFlush();
            TIMEPRINT(beautifyCost, "美颜");
            SenseArFrameActionInfo *currentFrameActionInfo = nil;
            
            if (RENDER_SUCCESS != iRenderStatus) {
                textureResult = _textureOriginalIn;
                //美颜异常时，输出不可用
                if (pNV12ImageOut) {
                    free(pNV12ImageOut);
                    pNV12ImageOut = NULL;
                }
            } else {
                currentFrameActionInfo = [self.render getCurrentFrameActionInfo];
                
                //贴纸输出
                TIMELOG(stickerCost);
                //如果需要直接推流贴纸后的效果，imageOut 需要传入有效的内容
                iRenderStatus = [self.render renderMaterialWithFrameInfo:pFrameInfo
                                                         frameInfoLength:iInfoLength
                                                               textureIn:_textureBeautifyOut
                                                              textureOut:_textureStickerOut
                                                             pixelFormat:PIX_FMT_NV12
                                                                imageOut:pNV12ImageOut
                                 //imageOut:NULL
                                 ];
                glFlush();
                TIMEPRINT(stickerCost, "贴纸");
                
                //当贴纸异常时可以渲染操作成功的结果以保证主播端不会黑屏，这里渲染美颜的输出纹理
                textureResult = RENDER_SUCCESS == iRenderStatus ? _textureStickerOut : _textureBeautifyOut;
                
                if(self.curMateralID && [self.dicMaterialDisplayConfig objectForKey:strCurrentMaterialID] ) {
                    
                    if (![strCurrentMaterialID isEqualToString:self.lastMaterialID]) {
                        NSArray *arrCurrentMaterialParts = [self.render getMaterialParts];
                        
                        if (arrCurrentMaterialParts.count && currentFrameActionInfo) {
                            [self resetCurrentPartsIndexWithID:strCurrentMaterialID];
                            [self changeToNextPartsWithMaterialID:strCurrentMaterialID materialParts:arrCurrentMaterialParts];
                        }
                        self.arrLastMaterialParts = arrCurrentMaterialParts;
                        self.isLastFrameTriggered = NO;
                    } else {
                        if (self.arrLastMaterialParts.count && currentFrameActionInfo) {
                            BOOL isTriggered = [self isMaterialTriggered:strCurrentMaterialID frameActionInfo:currentFrameActionInfo];
                            if (!isTriggered && self.isLastFrameTriggered) {
                                [self changeToNextPartsWithMaterialID:strCurrentMaterialID materialParts:_arrLastMaterialParts];
                            }
                            self.isLastFrameTriggered = isTriggered;
                        }
                    }
                }
            }
        }
        self.lastMaterialID = strCurrentMaterialID;
        
        //恢复之前的渲染环境
        [self setCurrentContext:preContext];
        [self.preview renderWithTexture:textureResult size:CGSizeMake(iWidth, iHeight) flipped:YES applyingOrientation:1];
        glFlush();
        
        //可以在异常的情况下将原图编码推流以保证粉丝端不会因为异常而黑屏，需要根据具体的推流方案实现，这里在异常情况下不做推流
        if (self.isStreaming && self.streamingQueue && pNV12ImageOut && iInfoLength > 0) {
            dispatch_async(self.streamingQueue, ^{
                STFrame *frame = [[STFrame alloc] init];
                frame.width = iWidth;
                frame.height = iHeight;
                frame.stride = iWidth;
                frame.imageData = [NSData dataWithBytes:pNV12ImageOut length:iImageNV12Length];
                frame.extraData = [NSData dataWithBytes:pFrameInfo length:iInfoLength];
                frame.pts = lPTS;
                free(pFrameInfo);
                free(pNV12ImageOut);
                
                [self.frameBuffer enqueueFrameToBuffer:frame];
                [self.encodeCondition lock];
                [self.encodeCondition signal];
                [self.encodeCondition unlock];
            });
        } else {
            free(pFrameInfo);
            free(pNV12ImageOut);
        }
        
       // [self showActionTipsIfNeed];
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        CVOpenGLESTextureCacheFlush(_cvTextureCache, 0);
        if (_cvOriginalTexutre) {
            CFRelease(_cvOriginalTexutre);
            _cvOriginalTexutre = NULL;
        }
        TIMEPRINT(totalCost, "总耗时");
        
        /* only for test
         textureResult = _textureOriginalIn;
         [self setCurrentContext:preContext];
         
         [self.preview renderWithTexture:textureResult
         size:CGSizeMake(iWidth, iHeight)
         flipped:YES
         applyingOrientation:1];
         glFlush();
         */
    }
}

-(void)encodeAndSendFrame{
    while (1) {
        [self.encodeCondition lock];
        [self.encodeCondition wait];
        [self.encodeCondition unlock];
        
        if ([[NSThread currentThread] isCancelled]) {
            [NSThread exit];
        } else {
            @autoreleasepool {
                STFrame *frame = [self.frameBuffer readFrameFromBuffer];
                
                dispatch_sync(self.streamingQueue, ^{
                    
                    if (frame && self.stLiveContet) {
                        st_nv12_descriptor_t desc;
                        memset(&desc, 0, sizeof(st_nv12_descriptor_t));
                        
                        desc.Y_base = (unsigned char*)[frame.imageData bytes];
                        desc.Y_stride = frame.stride;
                        desc.CrBr_base = ((unsigned char*)[frame.imageData bytes] + (sizeof(unsigned char) * frame.stride*frame.height));
                        desc.CrBr_stride = frame.stride;
                        
                        TIMELOG(enqueueAndSendFrame)
                        int iPublishRet = st_live_enqueue_frame(self.stLiveContet, &desc, frame.pts, (void*)[frame.extraData bytes], (unsigned int)[frame.extraData length] );
                        TIMEPRINT(enqueueAndSendFrame, "编码+推流")
                        if (0!=iPublishRet) {
                            NSLog(@"st_live_enqueue_frame %d", iPublishRet);
                        }
                    }
                    
                });
                
            }
        }
        
    }
}


@end
