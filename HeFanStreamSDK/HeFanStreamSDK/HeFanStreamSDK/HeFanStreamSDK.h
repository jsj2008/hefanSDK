//
//  HeFanStreamSDK.h
//  HeFanStreamSDK
//
//  Created by 王利军 on 24/7/2017.
//  Copyright © 2017 王利军. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

enum HFSVideoRotation
{
    kVideoRotation0      = 0,
    kVideoRotation90     = 1,
    kVideoRotation180    = 2,
    kVideoRotation270    = 3,
    kVideoRotationAuto   = 4,
};

enum HFSAudioCodec
{
    kAudioCodecUnknown      = 0,
    kAudioCodecAAC          = 1,
    kAudioCodecPCM          = 2,
    kAudioCodecFDKAAC       = 3,
    kAudioCodecIOSAAC       = 4,
    kAudioCodecANDROIDAAC   = 5,
};

enum HFSVideoCodec
{
    kVideoCodecUnknown          = 0,
    kVideoCodecPicture          = 1,
    kVideoCodecH264             = 2,
    kVideoCodecIOSH264          = 3,  //toolbox
    kVideoCodecANDROIDH264      = 4,
};


@protocol DownloadMateralResultDelegate <NSObject>
@required
-(void)OnDownloadMateralOk:(NSString*)materialID;
-(void)OnDownloadMateralFailed:(NSString*)materialID;
-(void)OnDownloadMateralProcess:(NSString*)materialID Process:(float)process;
@end

@protocol AuthorityWithAppIDAndKeyDelegate <NSObject>
@required
-(void)OnAuthorityResult:(BOOL)bResult;
@end

struct HFSBeautifyValue {
    float   redden;         //
    float   smooth;
    float   whiten;
    float   shrinkFace;
    float   enlargeEye;
    float   shrinkJaw;
};

struct HFSVideoConfig {
    enum HFSVideoCodec codecType;          //编码类型
    int imageWidth;         //图像宽
    int imageHeight;        //图像高
    int rotMode;            //翻转模式
    int bitrate;            //位速率
    int fps;                //帧率
    int iFrame;             //关键帧间隔
};

struct HFSAudioConfig {
    enum HFSAudioCodec codecType;       //编码类型
    int Channels;        //通道数
    int bitsPerSample;   //采样位数
    int bps;             //位速率
    int sampleRate;      //采样率(Hz)
};


@interface HeFanStreamSDK : NSObject


@property(nonatomic, assign)  struct HFSVideoConfig   videoCfg;         //used for video configure
@property(nonatomic, assign)  struct HFSAudioConfig   audioCfg;         //used for audio configure
@property(nonatomic, assign)  struct HFSBeautifyValue beautifyValueCfg;    //used for beautify value

@property(atomic, copy) NSString* curMateralID;              //the material id is used current view

/*
-(BOOL) initSDK:(NSString*)broadcastID Error:(NSError**)error;
-(void) authorizeWithAppID:(id<AuthorityWithAppIDAndKeyDelegate>)delegate AppID:(NSString*)appID AppKey:(NSString*)appKey;

-(void)setupPreviewAndBegin:(UIView*) currentView;

-(BOOL) createBroadcast;
-(BOOL) destoryBroadcast;
-(BOOL) startBroadcast;
-(BOOL) stopBroadcast;
-(void) downloadMateral:(id<DownloadMateralResultDelegate>)delegate MaterialID:(NSString *) materialID;
-(void) showMateral:(NSString*) materialID;
-(void) SwitchCamera;
*/


//-(BOOL) initSDK:(NSString*)broadcastID Error:(NSError**)error;
-(BOOL) initSDK:(id<AuthorityWithAppIDAndKeyDelegate>)delegate AppID:(NSString*)appID AppKey:(NSString*)appKey Error:(NSError**)error;

-(void)setupPreviewAndBegin:(UIView*) currentView;

-(BOOL) createLiving:(NSString*)broadcastID CurView:(UIView*)curView Error:(NSError**)error;
-(BOOL) destoryLiving;
-(BOOL) startLiving:(NSString*)rtmpURL;
-(void) stopLiving;
-(void) downloadMateral:(id<DownloadMateralResultDelegate>)delegate MaterialID:(NSString *) materialID;
-(void) showMateral:(NSString*) materialID;
-(void) switchCamera;
-(void) flashLight;
-(void) validateBeautifyValue;



@end
