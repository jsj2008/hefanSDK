//
//  ViewController.m
//  HeFanStreamSDKDemo
//
//  Created by 王利军 on 24/7/2017.
//  Copyright © 2017 王利军. All rights reserved.
//

#import "ViewController.h"

#import "HeFanStreamSDK.h"

@interface ViewController () <AuthorityWithAppIDAndKeyDelegate, DownloadMateralResultDelegate> {
    
    //UILabel *_lbTips;
    UILabel *_lbInitSDK;
    UILabel *_lbCreateLiving;
    
    UILabel *_lbStartLiving;
    UILabel *_lbStopLiving;
    
    UILabel *_lbDownAndShowMaterial;
    UILabel *_lbDownAndShowMaterial2;
    UILabel *_lbHideMaterial;
    
    UILabel *_lbDestroyLiving;
    
    UILabel *_lbSwitchCamera;
    UILabel *_lbFlashLight;
    
    UILabel *_lbSetBeautifyValue;
    HeFanStreamSDK *_sdk;
}

@end

@implementation ViewController

-(void)OnAuthorityResult:(BOOL)bResult {
    NSLog(@"ViewController:OnAuthorityResult authority result:%@", bResult?@"YES":@"NO");
}

-(void)OnDownloadMateralOk:(NSString*)materialID {
    NSLog(@"Demo:OnDownloadMateralOk id:%@", materialID);
}

-(void)OnDownloadMateralFailed:(NSString*)materialID {
    NSLog(@"Demo:OnDownloadMateralFailed id:%@", materialID);
}

-(void)OnDownloadMateralProcess:(NSString*)materialID Process:(float)process {
    NSLog(@"Demo:OnDownloadMateralProcess id:%@ process:%f", materialID, process);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    int posY = 20;
    int btnW = 80;
    int btnH = 40;
    int posSpace = 10;
    /*
    _lbTips = [[UILabel alloc] init];
    _lbTips.backgroundColor = [UIColor blueColor];
    _lbTips.frame = CGRectMake(0, posY, self.view.bounds.size.width, btnH);
    _lbTips.text = @"SomeTipsInfo";
    _lbTips.textAlignment = NSTextAlignmentCenter;
    _lbTips.userInteractionEnabled = NO;
    [self.view addSubview:_lbTips];
    posY += posSpace;
    posY += btnH;
     */
    
    _lbInitSDK = [[UILabel alloc] init];
    _lbInitSDK.backgroundColor = [UIColor redColor];
    _lbInitSDK.frame = CGRectMake(20, posY, btnW, btnH);
    _lbInitSDK.text = @"InitSDK";
    _lbInitSDK.textAlignment = NSTextAlignmentCenter;
    _lbInitSDK.userInteractionEnabled = YES;
    [_lbInitSDK addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onInitSDK:)]];
    [self.view addSubview:_lbInitSDK];
    posY += posSpace;
    posY += btnH;
    
    _lbCreateLiving = [[UILabel alloc] init];
    _lbCreateLiving.backgroundColor = [UIColor redColor];
    _lbCreateLiving.frame = CGRectMake(20, posY, btnW, btnH);
    _lbCreateLiving.text = @"CreateL";
    _lbCreateLiving.textAlignment = NSTextAlignmentCenter;
    _lbCreateLiving.userInteractionEnabled = YES;
    [_lbCreateLiving addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(CreateLiving:)]];
    [self.view addSubview:_lbCreateLiving];
    posY += posSpace;
    posY += btnH;
    
    _lbStartLiving = [[UILabel alloc] init];
    _lbStartLiving.backgroundColor = [UIColor redColor];
    _lbStartLiving.frame = CGRectMake(20, posY, btnW, btnH);
    _lbStartLiving.text = @"StartL";
    _lbStartLiving.textAlignment = NSTextAlignmentCenter;
    _lbStartLiving.userInteractionEnabled = YES;
    [_lbStartLiving addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onStartLiving:)]];
    [self.view addSubview:_lbStartLiving];
    posY += posSpace;
    posY += btnH;
    
    
    _lbStopLiving = [[UILabel alloc] init];
    _lbStopLiving.backgroundColor = [UIColor redColor];
    _lbStopLiving.frame = CGRectMake(20, posY, btnW, btnH);
    _lbStopLiving.text = @"StopL";
    _lbStopLiving.textAlignment = NSTextAlignmentCenter;
    _lbStopLiving.userInteractionEnabled = YES;
    [_lbStopLiving addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onStopLiving:)]];
    [self.view addSubview:_lbStopLiving];
    posY += posSpace;
    posY += btnH;
    
    
    _lbSwitchCamera = [[UILabel alloc] init];
    _lbSwitchCamera.backgroundColor = [UIColor redColor];
    _lbSwitchCamera.frame = CGRectMake(20, posY, btnW, btnH);
    _lbSwitchCamera.text = @"SwitchC";
    _lbSwitchCamera.textAlignment = NSTextAlignmentCenter;
    _lbSwitchCamera.userInteractionEnabled = YES;
    [_lbSwitchCamera addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onSwitchCamera:)]];
    [self.view addSubview:_lbSwitchCamera];
    posY += posSpace;
    posY += btnH;
    
    _lbFlashLight = [[UILabel alloc] init];
    _lbFlashLight.backgroundColor = [UIColor redColor];
    _lbFlashLight.frame = CGRectMake(20, posY, btnW, btnH);
    _lbFlashLight.text = @"FlashLight";
    _lbFlashLight.textAlignment = NSTextAlignmentCenter;
    _lbFlashLight.userInteractionEnabled = YES;
    [_lbFlashLight addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onFlashLight:)]];
    [self.view addSubview:_lbFlashLight];
    posY += posSpace;
    posY += btnH;
    
    _lbDownAndShowMaterial = [[UILabel alloc] init];
    _lbDownAndShowMaterial.backgroundColor = [UIColor redColor];
    _lbDownAndShowMaterial.frame = CGRectMake(20, posY, btnW, btnH);
    _lbDownAndShowMaterial.text = @"ShowM";
    _lbDownAndShowMaterial.textAlignment = NSTextAlignmentCenter;
    _lbDownAndShowMaterial.userInteractionEnabled = YES;
    [_lbDownAndShowMaterial addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onDownloadAndShowMaterial:)]];
    [self.view addSubview:_lbDownAndShowMaterial];
    posY += posSpace;
    posY += btnH;
    
    _lbDownAndShowMaterial2 = [[UILabel alloc] init];
    _lbDownAndShowMaterial2.backgroundColor = [UIColor redColor];
    _lbDownAndShowMaterial2.frame = CGRectMake(20, posY, btnW, btnH);
    _lbDownAndShowMaterial2.text = @"ShowM";
    _lbDownAndShowMaterial2.textAlignment = NSTextAlignmentCenter;
    _lbDownAndShowMaterial2.userInteractionEnabled = YES;
    [_lbDownAndShowMaterial2 addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onDownloadAndShowMaterial2:)]];
    [self.view addSubview:_lbDownAndShowMaterial2];
    posY += posSpace;
    posY += btnH;

    
    _lbHideMaterial = [[UILabel alloc] init];
    _lbHideMaterial.backgroundColor = [UIColor redColor];
    _lbHideMaterial.frame = CGRectMake(20, posY, btnW, btnH);
    _lbHideMaterial.text = @"HideM";
    _lbHideMaterial.textAlignment = NSTextAlignmentCenter;
    _lbHideMaterial.userInteractionEnabled = YES;
    [_lbHideMaterial addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onHideMaterial:)]];
    [self.view addSubview:_lbHideMaterial];
    posY += posSpace;
    posY += btnH;
    
    _lbDestroyLiving = [[UILabel alloc] init];
    _lbDestroyLiving.backgroundColor = [UIColor redColor];
    _lbDestroyLiving.frame = CGRectMake(20, posY, btnW, btnH);
    _lbDestroyLiving.text = @"DestroyL";
    _lbDestroyLiving.textAlignment = NSTextAlignmentCenter;
    _lbDestroyLiving.userInteractionEnabled = YES;
    [_lbDestroyLiving addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onDestroyLiving:)]];
    [self.view addSubview:_lbDestroyLiving];
    posY += posSpace;
    posY += btnH;
    
    
    _lbSetBeautifyValue = [[UILabel alloc] init];
    _lbSetBeautifyValue.backgroundColor = [UIColor redColor];
    _lbSetBeautifyValue.frame = CGRectMake(20, posY, btnW, btnH);
    _lbSetBeautifyValue.text = @"BeautifyV";
    _lbSetBeautifyValue.textAlignment = NSTextAlignmentCenter;
    _lbSetBeautifyValue.userInteractionEnabled = YES;
    [_lbSetBeautifyValue addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onSetBeautifyValue:)]];
    [self.view addSubview:_lbSetBeautifyValue];
    posY += posSpace;
    posY += btnH;
    
}


-(void)onSetupPreview:(id)gesture{
    if (_sdk) {
        [_sdk setupPreviewAndBegin:self.view];
    }
}

-(void)CreateLiving:(id)gesture{
    if (_sdk) {
        NSError *error;
        BOOL rtn = [_sdk createLiving:@"livingid111111111" CurView:self.view Error:&error];
        if (!rtn) {
            NSLog(@"sdk createLiving failed.");
        }
    }
}


-(void)onStartLiving:(id)gesture{
    if (_sdk) {
        [_sdk startLiving:@"rtmp://pili-publish.sara.sensetime.com/sara/7000000?key=0da678cb-06ac-4750-b7bf-2678ca388ad2"];
    }
}

-(void)onStopLiving:(id)gesture{
    if (_sdk) {
        [_sdk stopLiving];
    }
}

-(void)onSwitchCamera:(id)gesture{
    if (_sdk) {
        [_sdk switchCamera];
    }
}

-(void)onFlashLight:(id)gesture{
    if (_sdk) {
        [_sdk flashLight];
    }
}


-(void)onDownloadAndShowMaterial:(id)gesture{
    if (_sdk) {
        [_sdk downloadMateral:self MaterialID:@"20170110124456877415311"];
    }
}

-(void)onDownloadAndShowMaterial2:(id)gesture{
    if (_sdk) {
        [_sdk downloadMateral:self MaterialID:@"20161201193448259252113"];
    }
}

-(void)onHideMaterial:(id)gesture{
    if (_sdk) {
        [_sdk showMateral:nil];
    }
}

-(void)onDestroyLiving:(id)gesture{
    if (_sdk) {
        [_sdk destoryLiving];
    }
}

-(void)onSetBeautifyValue:(id)gesture{
    if (_sdk) {
        //modify beautify value
        struct HFSBeautifyValue bv = [_sdk beautifyValueCfg];
        if (bv.redden>1.0) {
            bv.redden = 0.0;
        }
        bv.redden += 0.1;
        
        if (bv.enlargeEye>1.0) {
            bv.enlargeEye = 0.0;
        }
        bv.enlargeEye += 0.1;
        
        if (bv.shrinkJaw>1.0) {
            bv.shrinkJaw = 0.0;
        }
        bv.shrinkJaw += 0.1;
        
        if (bv.shrinkFace>1.0) {
            bv.shrinkFace = 0.0;
        }
        bv.shrinkFace += 0.1;
        
        if (bv.smooth>1.0) {
            bv.smooth = 0.0;
        }
        bv.smooth += 0.1;
        
        if (bv.whiten>1.0) {
            bv.whiten = 0.0;
        }
        bv.whiten += 0.1;
        
        [_sdk setBeautifyValueCfg:bv];
        [_sdk validateBeautifyValue];
    }
}



-(void)onInitSDK:(id)gesture{
    NSLog(@"onInitSDK............");
    
    _sdk = [[HeFanStreamSDK alloc ] init];
    NSError *error;

    BOOL rst = [_sdk initSDK:self AppID:@"b5d6aedc1e72487e9aa757801f4fd93c" AppKey:@"9e5d42c9b685417db22a8908c2ebe2ed" Error:&error];
 
    if (!rst && error) {
        NSLog(@"error description:%@", error);
        return;
    }
 
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
