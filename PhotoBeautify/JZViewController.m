//
//  JZViewController.m
//  PhotoBeautify
//
//  Created by Johnny Xu(徐景周) on 7/23/14.
//  Copyright (c) 2014 Future Studio. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "JZViewController.h"
#import "CommonDefine.h"
#import "VideoEffect.h"
#import "ThemeScrollView.h"
#import "PBJVideoPlayerController.h"
#import "MMProgressHUD.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "UzysAssetsPickerController.h"
#import "CMPopTipView.h"

@interface JZViewController ()<PBJVideoPlayerControllerDelegate, UzysAssetsPickerControllerDelegate, ThemeScrollViewDelegate, CMPopTipViewDelegate>
{
    NSString* _mp4OutputPath;
    
    BOOL _hasPhotos;
    BOOL _hasMp4;
    
    VideoEffect *_videoEffects;
    
    PBJVideoPlayerController *_videoPlayerController;
UIImageView *_playButton;
    
    NSMutableArray *_selectedPhotos;
    UzysAssetsPickerController *_imagePicker;
    
    CMPopTipView *_popTipView;
    UIActivityIndicatorView * _activityIndicatorView;
    UIView *_videoBg;
}

@property (copy, nonatomic) NSString* mp4OutputPath;
@property (assign, nonatomic) BOOL hasPhotos;
@property (assign, nonatomic) BOOL hasMp4;

@property (retain, nonatomic) VideoEffect *videoEffects;

@property (retain, nonatomic) UIView *viewToolbar;
@property (retain, nonatomic) UIImageView *imageViewToolbarBG;
@property (retain, nonatomic) UIButton *toggleEffects;
@property (retain, nonatomic) UIButton *openCameraRoll;
@property (retain, nonatomic) UIButton *saveVideo;
@property (retain, nonatomic) UIButton *more;
@property (retain, nonatomic) UIButton *titleEffects;
@property (retain, nonatomic) UIButton *titleCameraRoll;
@property (retain, nonatomic) UIButton *titleSaveVideo;
@property (retain, nonatomic) UIButton *titleMore;
@property (retain, nonatomic) UIImageView *imageViewPreview;
@property (retain, nonatomic) ThemeScrollView *frameScrollView;

@property (retain ,nonatomic) NSMutableArray *selectedPhotos;

@end

@implementation JZViewController

@synthesize mp4OutputPath = _mp4OutputPath;
@synthesize hasPhotos = _hasPhotos;
@synthesize hasMp4 = _hasMp4;
@synthesize videoEffects = _videoEffects;
@synthesize selectedPhotos = _selectedPhotos;

#pragma mark - Video effects status
- (void)AVAssetExportMP4SessionStatusFailed:(id)object
{
    NSString *failed = NSLocalizedString(@"failed", nil);
    [self dismissProgressBar:failed];
    
    // Dispose memory
    [self.videoEffects clearAll];
    
//    NSString *ok = NSLocalizedString(@"ok", nil);
//    NSString *msgFailed =  NSLocalizedString(@"msgConvertFailed", nil);
//    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:failed message:msgFailed
//                                                   delegate:self
//                                          cancelButtonTitle:nil
//                                          otherButtonTitles:ok, nil];
//    [alert show];
}

- (void)AVAssetExportMP4SessionStatusCompleted:(id)object
{
    // Dispose memory
    [self.videoEffects clearAll];
    self.hasMp4 = YES;

    NSString *success = NSLocalizedString(@"success", nil);
    [self dismissProgressBar:success];
    [self removeActivityView];
    [self playMp4Video];
}

- (void)AVAssetExportMP4ToAlbumStatusCompleted:(id)object
{
    NSString *success = NSLocalizedString(@"success", nil);
    NSString *msgSuccess =  NSLocalizedString(@"msgSuccess", nil);
    NSString *ok = NSLocalizedString(@"ok", nil);
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:success message:msgSuccess
                                                   delegate:self
                                          cancelButtonTitle:nil
                                          otherButtonTitles:ok, nil];
    [alert show];
    
    // Enable "Save" button
    [self enableSaveButton:YES];
}

- (void)AVAssetExportMP4ToAlbumStatusFailed:(id)object
{
    NSString *failed = NSLocalizedString(@"failed", nil);
    NSString *msgFailed =  NSLocalizedString(@"msgFailed", nil);
    NSString *ok = NSLocalizedString(@"ok", nil);
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: failed message:msgFailed
                                                   delegate:self
                                          cancelButtonTitle:nil
                                          otherButtonTitles:ok, nil];
    [alert show];
    
    // Enable "Save" button
    [self enableSaveButton:YES];
}

#pragma mark - Progress callback
- (void)retrievingProgressMP4:(id)progress
{
    //[_videoPlayerController.view bringSubviewToFront:_activityIndicatorView];
    //[_activityIndicatorView startAnimating];
    return;
    if (progress && [progress isKindOfClass:[NSNumber class]])
    {
        NSString *title = NSLocalizedString(@"正在处理", nil);
        [self updateProgressBarTitle:title status:[NSString stringWithFormat:@"%d%%", (int)([progress floatValue] * 100)]];
    }
}

#pragma mark - Progress Bar
- (void) setProgressBarDefaultStyle
{
    if (arc4random()%(int)2)
    {
        [MMProgressHUD setPresentationStyle:MMProgressHUDPresentationStyleSwingLeft];
    }
    else
    {
        [MMProgressHUD setPresentationStyle:MMProgressHUDPresentationStyleSwingRight];
    }
}

- (void) updateProgress:(CGFloat)value
{
    [MMProgressHUD updateProgress:value];
}

- (void) updateProgressBarTitle:(NSString*)title status:(NSString*)status
{
    [MMProgressHUD updateTitle:title status:status];
}

- (void) dismissProgressBarbyDelay:(NSTimeInterval)delay
{
    [MMProgressHUD dismissAfterDelay:delay];
}

- (void) dismissProgressBar:(NSString*)status
{
    [MMProgressHUD dismissWithSuccess:status];
}

#pragma mark - private Method
- (void) createAssetsAlbumGroupWithName:(NSString*)name
                          assertLibrary:(ALAssetsLibrary*)assertLibrary
            enumerateGroupsFailureBlock:(void (^) (NSError *error))enumerateGroupsFailureBlock
                    hasTheNewGroupBlock:(void (^) (ALAssetsGroup *group))hasGroup
                   createSuccessedBlock:(void (^) (ALAssetsGroup *group))createSuccessedBlock
                      createFaieldBlock:(void (^) (NSError *error))createFaieldBlock
{
    
    __block BOOL hasTheNewGroup = NO;
    
    [assertLibrary enumerateGroupsWithTypes:ALAssetsGroupAlbum usingBlock:^(ALAssetsGroup *group, BOOL *stop)
     {
         hasTheNewGroup = [name isEqualToString:[group valueForProperty:ALAssetsGroupPropertyName]];
         if (hasTheNewGroup)
         {
             hasGroup(group);
             *stop = YES;
         }
         
         if (!group && !hasTheNewGroup && !*stop)
         {
             [assertLibrary addAssetsGroupAlbumWithName:name resultBlock:^(ALAssetsGroup *agroup)
              {
                  createSuccessedBlock(agroup);
              } failureBlock:^(NSError *error)
              {
                  
                  createFaieldBlock(error);
              }];
         }
     } failureBlock:^(NSError *error)
     {
         
         enumerateGroupsFailureBlock(error);
     }];
}

- (void) addVideoToAssetGroupWithAssetUrl:(NSURL*)assetURL
                            assertLibrary:(ALAssetsLibrary*)assertLibrary
                                  toAlbum:(NSString*)name
                          addSuccessBlock:(void (^) (ALAssetsGroup *targetGroup, NSURL *currentAssetUrl, ALAsset *currentAsset))addSuccessBlock
                           addFaieldBlock:(void (^) (NSError *error))addFaieldBlock
{
    
    [self createAssetsAlbumGroupWithName:name
                           assertLibrary:assertLibrary
             enumerateGroupsFailureBlock:^(NSError *error)
     {
         if (error)
         {
             addFaieldBlock(error);
             return ;
         }
     } hasTheNewGroupBlock:^(ALAssetsGroup *group)
     {
         [assertLibrary assetForURL:assetURL resultBlock:^(ALAsset *asset)
          {
              [group addAsset:asset];
              addSuccessBlock(group,assetURL,asset);
              
          } failureBlock:^(NSError *error)
          {
              if (error)
              {
                  addFaieldBlock(error);
                  return ;
              }
          }];
     } createSuccessedBlock:^(ALAssetsGroup *group)
     {
         
         [assertLibrary assetForURL:assetURL resultBlock:^(ALAsset *asset)
          {
              [group addAsset:asset];
              addSuccessBlock(group,assetURL,asset);
              
          } failureBlock:^(NSError *error)
          {
              if (error)
              {
                  addFaieldBlock(error);
                  return ;
              }
          }];
     } createFaieldBlock:^(NSError *error)
     {
         if (error)
         {
             addFaieldBlock(error);
             return ;
         }
     }];
}

- (void) writeExportedVideoToAssetsLibrary:(NSString *)outputURL
{
    __unsafe_unretained typeof(self) weakSelf = self;
	NSURL *exportURL = [NSURL fileURLWithPath:outputURL];
	ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
	if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:exportURL])
    {
		[library writeVideoAtPathToSavedPhotosAlbum:exportURL completionBlock:^(NSURL *assetURL, NSError *error)
         {
             if (error)
             {
                 [weakSelf AVAssetExportMP4ToAlbumStatusFailed:error];
             }
             else
             {
                 NSString *albumGroupName = @"PhotoBeautify";
                 [weakSelf addVideoToAssetGroupWithAssetUrl:assetURL
                                              assertLibrary:library
                                                    toAlbum:albumGroupName
                                            addSuccessBlock:^(ALAssetsGroup *targetGroup, NSURL *currentAssetUrl, ALAsset *currentAsset)
                  {
                      [weakSelf AVAssetExportMP4ToAlbumStatusCompleted:error];
                      
                  } addFaieldBlock:^(NSError *error)
                  {
//                    [weakSelf AVAssetExportMP4ToAlbumStatusFailed:error];
                  }];
             }
         }];
	}
    else
    {
		NSLog(@"Video could not be exported to camera roll.");
        
        // Enable "Save" button
        [self enableSaveButton:YES];
	}
    
    library = nil;
}

- (NSInteger)getFileSize:(NSString*)path
{
    NSFileManager * filemanager = [[NSFileManager alloc]init];
    if([filemanager fileExistsAtPath:path])
    {
        NSDictionary * attributes = [filemanager attributesOfItemAtPath:path error:nil];
        NSNumber *theFileSize;
        if ( (theFileSize = [attributes objectForKey:NSFileSize]) )
            return  [theFileSize intValue]/1024;
        else
            return -1;
    }
    else
    {
        return -1;
    }
}

- (CGFloat)getVideoDuration:(NSURL*)URL
{
    NSDictionary *opts = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO]
                                                     forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
    AVURLAsset *urlAsset = [AVURLAsset URLAssetWithURL:URL options:opts];
    float second = 0;
    second = urlAsset.duration.value/urlAsset.duration.timescale;
    
    return second;
}

- (NSString*)getOutputFilePath
{
    NSString *path = @"outputMovie.mp4";
    NSString* mp4OutputFile = [NSTemporaryDirectory() stringByAppendingPathComponent:path];
    
    return mp4OutputFile;
}

- (void) buildVideoEffect:(ThemesType)curThemeType
{
    if (_videoEffects)
    {
        _videoEffects = nil;
    }
    
    BOOL highestQuality = TRUE;
    self.videoEffects = [[VideoEffect alloc] initWithDelegate:self];
    self.videoEffects.themeCurrentType = curThemeType;
    [self.videoEffects image2Video:self.selectedPhotos exportVideoFile:_mp4OutputPath highestQuality:highestQuality];
}

- (void) playMp4Video
{
    if (!_hasMp4)
    {
        NSLog(@"Mp4 file not found!");
        return;
    }
    
    NSLog(@"%@",[NSString stringWithFormat:@"Play file is %@", _mp4OutputPath]);
    
    [self showVideoPlayView:TRUE];
    _videoPlayerController.videoPath = _mp4OutputPath;
    [_videoPlayerController playFromBeginning];
}

-(void)pickVideoFromCameraRoll
{
	[self initImagePicker];
}

- (void) initImagePicker
{
    _imagePicker = [[UzysAssetsPickerController alloc] init];
    _imagePicker.delegate = self;
    _imagePicker.maximumNumberOfSelectionVideo = 0;
    _imagePicker.maximumNumberOfSelectionPhoto = 15;
    
    [self presentViewController:_imagePicker animated:YES completion:^{
        NSLog(@"_imagePicker present");
    }];
}

#pragma mark - UzysAssetsPickerControllerDelegate methods
- (void)UzysAssetsPickerController:(UzysAssetsPickerController *)picker didFinishPickingAssets:(NSArray *)assets
{
    NSLog(@"%ld asset selected",(unsigned long)assets.count);
    NSLog(@"assets %@",assets);
    
    if (self.selectedPhotos && [self.selectedPhotos count]>0)
    {
        NSLog(@"Clear original photos");
        [self.selectedPhotos removeAllObjects];
    }
    [self.selectedPhotos setArray:assets];
    
    if (self.selectedPhotos && [self.selectedPhotos count]>0)
    {
        // Get ready
        self.mp4OutputPath = [self getOutputFilePath];
        self.hasPhotos = YES;
        
        [self showVideoPlayView:FALSE];
        self.toggleEffects.enabled = TRUE;
        self.frameScrollView.hidden = FALSE;
    }
}

- (void)UzysAssetsPickerControllerDidExceedMaximumNumberOfSelection:(UzysAssetsPickerController *)picker
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                    message:@"Exceed Maximum Number Of Selection"
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

- (void)UzysAssetsPickerControllerDidCancel:(UzysAssetsPickerController *)picker
{
    NSLog(@"AssetsPickerControllerDidCancel");
}

#pragma mark - PBJVideoPlayerControllerDelegate
- (void)videoPlayerReady:(PBJVideoPlayerController *)videoPlayer
{
    //NSLog(@"Max duration of the video: %f", videoPlayer.maxDuration);
}

- (void)videoPlayerPlaybackStateDidChange:(PBJVideoPlayerController *)videoPlayer
{
}

- (void)videoPlayerPlaybackWillStartFromBeginning:(PBJVideoPlayerController *)videoPlayer
{
    _playButton.alpha = 1.0f;
    _playButton.hidden = NO;
    
    [UIView animateWithDuration:0.1f animations:^{
        _playButton.alpha = 0.0f;
    } completion:^(BOOL finished)
     {
         _playButton.hidden = YES;
         
         // Hide themes
         if (!self.frameScrollView.hidden)
         {
             //self.frameScrollView.hidden = YES;
         }
     }];
}

- (void)videoPlayerPlaybackDidEnd:(PBJVideoPlayerController *)videoPlayer
{
    _playButton.hidden = NO;
    
    [UIView animateWithDuration:0.1f animations:^{
        _playButton.alpha = 1.0f;
    } completion:^(BOOL finished)
     {
         // Show themes
         if (self.frameScrollView.hidden)
         {
             self.frameScrollView.hidden = NO;
         }
     }];
}

#pragma mark - IBAction Methods
- (void)handleActionTakeEffects
{
    NSLog(@"handleActionToggleEffects");
    
    if (_hasPhotos)
    {
        self.frameScrollView.hidden = !self.frameScrollView.hidden;
    }
}

- (void)handleActionOpenCameraRoll
{
    NSLog(@"handleActionOpenCameraRoll");
    
    // Pick a video from camera roll
    [self pickVideoFromCameraRoll];
}

- (void) handleActionSavetoAlbums
{
    NSLog(@"handleActionSavetoAlbums");
    
    if (_hasMp4)
    {
        // Disable "Save" button
        [self enableSaveButton:NO];
        
        [self writeExportedVideoToAssetsLibrary:_mp4OutputPath];
    }
}

- (void) enableSaveButton:(BOOL)enable
{
    if (enable)
    {
        _saveVideo.enabled = YES;
        _titleSaveVideo.enabled = YES;
    }
    else
    {
        _saveVideo.enabled = NO;
        _titleSaveVideo.enabled = NO;
    }
}

#pragma mark - CMPopTipViewDelegate methods
- (void)popTipViewWasDismissedByUser:(CMPopTipView *)popTipView
{
   
}

#pragma mark - ThemeScrollView Delegate
- (void)themeScrollView:(ThemeScrollView *)themeScrollView didSelectMaterial:(VideoThemes *)videoTheme
{
    if (!_hasPhotos)
    {
        NSLog(@"There haven't any photos now.");
        return;
    }
    
    ThemesType curThemeType = kThemeNone;
    if ((NSNull*)videoTheme != [NSNull null])
    {
        curThemeType = (ThemesType)videoTheme.ID;
    }
    
    if (curThemeType == kThemeNone)
    {
        NSLog(@"curThemeType is empty.");
        return;
    }
    
    // Progress bar
//    [self setProgressBarDefaultStyle];
//    NSString *title = NSLocalizedString(@"Z", nil);
//    [self updateProgressBarTitle:title status:@""];
    
    // Pause play
    if (_videoPlayerController.playbackState == PBJVideoPlayerPlaybackStatePlaying)
    {
        [_videoPlayerController pause];
    }
    
    //self.frameScrollView.hidden = YES;
    _videoBg.hidden = NO;
    [self.view bringSubviewToFront:_videoBg];
    [self.view bringSubviewToFront:_activityIndicatorView];
    [_videoPlayerController stop];
    _videoPlayerController.view.hidden = YES;
    [_activityIndicatorView startAnimating];
    [self.videoEffects clearAll];
    // Build video effect
    double delayInSeconds = 0.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void)
       {
           [self buildVideoEffect:curThemeType];
       });
}

#pragma mark - App NSNotifications
- (void)_applicationWillEnterForeground:(NSNotification *)notification
{
    NSLog(@"applicationWillEnterForeground");
    
    [self.videoEffects resume];
    
    // Resume play
    if (_videoPlayerController.playbackState == PBJVideoPlayerPlaybackStatePaused)
    {
        [_videoPlayerController playFromCurrentTime];
    }
    
    [self dismissProgressBar:@"Failed!"];
    
    // Show themes
    if (_hasPhotos)
    {
        if (self.frameScrollView.hidden)
        {
            self.frameScrollView.hidden = NO;
        }
    }
}

- (void)_applicationDidEnterBackground:(NSNotification *)notification
{
    NSLog(@"applicationDidEnterBackground");
    
    [self.videoEffects pause];
    
    // Pause play
    if (_videoPlayerController.playbackState == PBJVideoPlayerPlaybackStatePlaying)
    {
        [_videoPlayerController pause];
    }
}

#pragma mark - View LifeCycle
- (void) deleteTempDirectory
{
    NSString *dir = NSTemporaryDirectory();
    deleteFilesAt(dir, @"mp4");
}

- (id) init
{
    if (self = [super init])
    {
        self.hasPhotos = NO;
        self.hasMp4 = NO;
        self.mp4OutputPath = nil;
        self.selectedPhotos = [NSMutableArray array];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationWillEnterForeground:) name:@"UIApplicationWillEnterForegroundNotification" object:[UIApplication sharedApplication]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationDidEnterBackground:) name:@"UIApplicationDidEnterBackgroundNotification" object:[UIApplication sharedApplication]];
        
        [self deleteTempDirectory];
    }
    
	return self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.navigationController setNavigationBarHidden:NO];
//    self.navigationController.title = @"创建光影秀";
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
}

- (void)initToolbarView
{
    CGFloat  width = [UIScreen mainScreen].bounds.size.width;
    CGFloat height = [UIScreen mainScreen].bounds.size.height;
    CGFloat height9 = height/9;
    CGFloat pictureSize = height9*1/3;
    CGFloat orginHeight = self.view.frame.size.width - toolbarHeight;
    if (iOS6 || iOS5)
    {
        orginHeight += 20;
    }
    
    _viewToolbar = [[UIView alloc] initWithFrame:CGRectMake(0, height*9.0/10, self.view.frame.size.width, height*9.0/10)];
    _viewToolbar.backgroundColor = [UIColor whiteColor];
    
    _imageViewToolbarBG = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"toolbar_bkg"]];
    _imageViewToolbarBG.frame = CGRectMake(0, 0, _viewToolbar.frame.size.width, _viewToolbar.frame.size.height);
    _imageViewToolbarBG.alpha = 0.2;
    [_imageViewToolbarBG setUserInteractionEnabled:NO];

    UIImage *imageEffectsUp = [UIImage imageNamed:@"drawerOpen_up"];
    _toggleEffects = [[UIButton alloc] initWithFrame:CGRectMake(width/4/4,height9/6,pictureSize, pictureSize)];
    [_toggleEffects setImage:imageEffectsUp forState:(UIControlStateNormal)];
    [_toggleEffects setImage:[UIImage imageNamed:@"drawerOpen_down"] forState:(UIControlStateSelected)];
    [_toggleEffects addTarget:self action:@selector(handleActionTakeEffects) forControlEvents:UIControlEventTouchUpInside];
    
    CGRect rectEffects = CGRectMake(width/4/4, height9/2.5, pictureSize, pictureSize);
    NSString *textEffects = NSLocalizedString(@"主题", nil);
    _titleEffects = [[UIButton alloc] initWithFrame:rectEffects];
//    [_titleEffects setBackgroundColor:[UIColor clearColor]];
    [_titleEffects setTitleColor:lightBlue forState:UIControlStateNormal];
    _titleEffects.titleLabel.adjustsFontSizeToFitWidth = YES;

    _titleEffects.titleLabel.textAlignment = NSTextAlignmentCenter;
    [_titleEffects setTitle:textEffects forState: UIControlStateNormal];
    [_titleEffects addTarget:self action:@selector(handleActionTakeEffects) forControlEvents:UIControlEventTouchUpInside];
    
    UIImage *imageAlbum = [UIImage imageNamed:@"cameraRoll_up"];
    _openCameraRoll = [[UIButton alloc] initWithFrame: CGRectMake(width/4+width/4/4,height9/6,pictureSize, pictureSize)];
    [_openCameraRoll setImage:imageAlbum forState:(UIControlStateNormal)];
    [_openCameraRoll setImage:[UIImage imageNamed:@"cameraRoll_down"] forState:(UIControlStateSelected)];
    [_openCameraRoll addTarget:self action:@selector(handleActionOpenCameraRoll) forControlEvents:UIControlEventTouchUpInside];
    
    CGRect rectCameraRoll = CGRectMake(width/4+width/4/4, height9/2.5, pictureSize, pictureSize);
    NSString *textCameraRoll = NSLocalizedString(@" 库 ", nil);
    _titleCameraRoll = [[UIButton alloc] initWithFrame:rectCameraRoll];
//    [_titleCameraRoll setBackgroundColor:[UIColor clearColor]];
    [_titleCameraRoll setTitleColor:lightBlue forState:UIControlStateNormal];
    //_titleCameraRoll.titleLabel.font = [UIFont systemFontOfSize: 14.0];
    _titleCameraRoll.titleLabel.adjustsFontSizeToFitWidth = YES;
    _titleCameraRoll.titleLabel.textAlignment = NSTextAlignmentCenter;
    [_titleCameraRoll setTitle:textCameraRoll forState: UIControlStateNormal];
    [_titleCameraRoll addTarget:self action:@selector(handleActionOpenCameraRoll) forControlEvents:UIControlEventTouchUpInside];

    //三
    UIImage *imageCameraRollUp = [UIImage imageNamed:@"saveCameraRoll_up"];
    _saveVideo = [[UIButton alloc] initWithFrame:CGRectMake(width/4*2+width/4/4, height9/6, pictureSize, pictureSize)];
    [_saveVideo setImage:imageCameraRollUp forState:(UIControlStateNormal)];
    [_saveVideo setImage:[UIImage imageNamed:@"saveCameraRoll_down"] forState:(UIControlStateSelected)];
    [_saveVideo addTarget:self action:@selector(handleActionSavetoAlbums) forControlEvents:UIControlEventTouchUpInside];
    CGRect rectSave = CGRectMake(width/4*2+width/4/4, height9/2.5, pictureSize, pictureSize);
    NSString *textSave = NSLocalizedString(@"zzjf", nil);
    _titleSaveVideo = [[UIButton alloc] initWithFrame:rectSave];
    [_titleSaveVideo setBackgroundColor:[UIColor clearColor]];
    [_titleSaveVideo setTitleColor:lightBlue forState:UIControlStateNormal];
    //_titleSaveVideo.titleLabel.font = [UIFont systemFontOfSize: 14.0];
    _titleSaveVideo.titleLabel.adjustsFontSizeToFitWidth = YES;
    _titleSaveVideo.titleLabel.textAlignment = NSTextAlignmentCenter;
    [_titleSaveVideo setTitle:textSave forState: UIControlStateNormal];
    [_titleSaveVideo addTarget:self action:@selector(handleActionSavetoAlbums) forControlEvents:UIControlEventTouchUpInside];

    //4
    UIImage *imageMore = [UIImage imageNamed:@"saveCameraRoll_up"];
    _more = [[UIButton alloc] initWithFrame:CGRectMake(width/4*3+width/4/4, height9/6, pictureSize, pictureSize)];
    [_more setImage:imageMore forState:(UIControlStateNormal)];
    [_more setImage:[UIImage imageNamed:@"saveCameraRoll_down"] forState:(UIControlStateSelected)];
    [_more addTarget:self action:@selector(handleActionSavetoAlbums) forControlEvents:UIControlEventTouchUpInside];
    CGRect rectMore = CGRectMake(width/4*3+width/4/4, height9/2.5, pictureSize, pictureSize);
    NSString *textMore = NSLocalizedString(@"跟多", nil);
    _titleMore = [[UIButton alloc] initWithFrame:rectMore];
    [_titleMore setBackgroundColor:[UIColor clearColor]];
    [_titleMore setTitleColor:lightBlue forState:UIControlStateNormal];
    //_titleMore.titleLabel.font = [UIFont systemFontOfSize: 14.0];
    _titleMore.titleLabel.adjustsFontSizeToFitWidth = YES;
    _titleMore.titleLabel.textAlignment = NSTextAlignmentCenter;
    [_titleMore setTitle:textSave forState: UIControlStateNormal];
    [_titleMore addTarget:self action:@selector(handleActionSavetoAlbums) forControlEvents:UIControlEventTouchUpInside];
    
    [_viewToolbar addSubview:_imageViewToolbarBG];
    [_viewToolbar addSubview:_toggleEffects];
    [_viewToolbar addSubview:_titleEffects];
    [_viewToolbar addSubview:_saveVideo];
    [_viewToolbar addSubview:_titleSaveVideo];
    [_viewToolbar addSubview:_openCameraRoll];
    [_viewToolbar addSubview:_titleCameraRoll];
    [_viewToolbar addSubview:_more];
    [_viewToolbar addSubview:_titleMore];
    [self.view addSubview:_viewToolbar];
}

- (void) initVideoPlayView
{
    CGFloat orginHeight = self.view.frame.size.height;
    CGFloat originWidth = self.view.frame.size.width;
    if (iOS6 || iOS5)
    {
        orginHeight += 20;
    }
    
    _videoPlayerController = [[PBJVideoPlayerController alloc] init];
    _videoPlayerController.delegate = self;
    CGFloat statusHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
    CGFloat navigationHeight = self.navigationController.navigationBar.frame.size.height;
    _videoPlayerController.view.frame = CGRectMake(0, statusHeight+navigationHeight, originWidth,originWidth);
    
//    NSLog(@"VideoPlay view: x=%f, y=%f, width=%f, height=%f", _videoPlayerController.view.frame.origin.x, _videoPlayerController.view.frame.origin.y, _videoPlayerController.view.frame.size.width, _videoPlayerController.view.frame.size.height);
    
    [self addChildViewController:_videoPlayerController];
    [self.view addSubview:_videoPlayerController.view];
    
    _playButton = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"play_button"]];
    _playButton.center = CGPointMake(originWidth/2,_videoPlayerController.view.frame.size.height/2);
    [_videoPlayerController.view addSubview:_playButton];
    _videoBg = [[UIView alloc] initWithFrame:CGRectMake(0, statusHeight+navigationHeight, originWidth,originWidth)];
    _videoBg.backgroundColor = [UIColor grayColor];
    [self.view addSubview:_videoBg];
}

- (void) initThemeScrollView
{
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    CGFloat screenWidht = [UIScreen mainScreen].bounds.size.width;
    CGFloat height = screenHeight/5;
    _frameScrollView = [[ThemeScrollView alloc] initWithFrame:CGRectMake(_viewToolbar.frame.origin.x, _viewToolbar.frame.origin.y - height-height/6, _viewToolbar.frame.size.width, height)];
//    _frameScrollView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_frameScrollView];
    
    [self.frameScrollView setDelegate:self];
    [self.frameScrollView setCurrentSelectedItem:0];
    [self.frameScrollView scrollToItemAtIndex:0];
    self.frameScrollView.hidden = NO;
}

- (void)initPreviewView
{
    CGFloat orginHeight = self.view.frame.size.height;
    CGFloat originWidth = self.view.frame.size.width;
    if (iOS6 || iOS5)
    {
        orginHeight += 20;
    }

    _videoPlayerController.delegate = self;
    CGFloat statusHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
    CGFloat navigationHeight = self.navigationController.navigationBar.frame.size.height;
    if (iOS6 || iOS5)
    {
        orginHeight += 20;
    }
    
    _imageViewPreview = [[UIImageView alloc] initWithFrame:CGRectMake(0,statusHeight+navigationHeight, originWidth,originWidth)];
//    _imageViewPreview.image = [UIImage imageNamed:@"Background"];
    _imageViewPreview.clipsToBounds = TRUE;
    _imageViewPreview.backgroundColor = [UIColor grayColor];
    [self.view addSubview:_imageViewPreview];
}

- (void)initPopView
{
    NSArray *colorSchemes = [NSArray arrayWithObjects:
                    [NSArray arrayWithObjects:[NSNull null], [NSNull null], nil],
                    [NSArray arrayWithObjects:[UIColor colorWithRed:134.0/255.0 green:74.0/255.0 blue:110.0/255.0 alpha:1.0], [NSNull null], nil],
                    [NSArray arrayWithObjects:[UIColor darkGrayColor], [NSNull null], nil],
                    [NSArray arrayWithObjects:[UIColor lightGrayColor], [UIColor darkTextColor], nil],
                    [NSArray arrayWithObjects:[UIColor colorWithRed:220.0/255.0 green:0.0/255.0 blue:0.0/255.0 alpha:1.0], [NSNull null], nil],
                    nil];
    NSArray *colorScheme = [colorSchemes objectAtIndex:foo4random()*[colorSchemes count]];
    UIColor *backgroundColor = [colorScheme objectAtIndex:0];
    UIColor *textColor = [colorScheme objectAtIndex:1];
    
    NSString *hint = NSLocalizedString(@"UsageHint", nil);
    _popTipView = [[CMPopTipView alloc] initWithMessage:hint];
    _popTipView.delegate = self;
    if (backgroundColor && ![backgroundColor isEqual:[NSNull null]])
    {
        _popTipView.backgroundColor = backgroundColor;
    }
    if (textColor && ![textColor isEqual:[NSNull null]])
    {
        _popTipView.textColor = textColor;
    }
    
    if (iOS7)
    {
        _popTipView.preferredPointDirection = PointDirectionDown;
    }
    _popTipView.animation = arc4random() % 2;
//    _popTipView.has3DStyle = (BOOL)(arc4random() % 2);
    _popTipView.has3DStyle = FALSE;
    _popTipView.dismissTapAnywhere = YES;
    [_popTipView autoDismissAnimated:YES atTimeInterval:3.0];
    
    [_popTipView presentPointingAtView:_openCameraRoll inView:self.view animated:YES];
}

- (void) showVideoPlayView:(BOOL)show
{
    if (show)
    {
        _playButton.hidden = NO;
        _videoPlayerController.view.hidden = NO;
        
        _saveVideo.enabled = YES;
    }
    else
    {
        _playButton.hidden = YES;
        _videoPlayerController.view.hidden = YES;
        
        _saveVideo.enabled = NO;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"创建光影秀";
    UIBarButtonItem *barButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStylePlain target:nil action:nil];
    self.navigationItem.leftBarButtonItem = barButtonItem;

    UIBarButtonItem *CompletedBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"完成" style:UIBarButtonItemStylePlain target:nil action:nil];
    self.navigationItem.rightBarButtonItem = CompletedBarButtonItem;

    self.view.backgroundColor = [UIColor whiteColor];

    [self initPreviewView];
    [self initVideoPlayView];
    [self initToolbarView];
    [self initThemeScrollView];
    [self initPopView];
    
    self.toggleEffects.enabled = FALSE;
    [self showVideoPlayView:FALSE];

    _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [_activityIndicatorView setHidesWhenStopped:YES];
    CGFloat statusHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
    CGFloat navigationHeight = self.navigationController.navigationBar.frame.size.height;
    _activityIndicatorView.center = CGPointMake(self.view.frame.size.width/2,_videoPlayerController.view.center.y);
    [self.view addSubview:_activityIndicatorView];
}
- (void)removeActivityView
{
    if (_activityIndicatorView)
    {
        _activityIndicatorView.hidden = YES;
        [_activityIndicatorView stopAnimating]; // 结束旋转
        _videoBg.hidden = YES;
        //[_activityIndicatorView removeFromSuperview];
    }
}
- (void)viewDidUnload
{
    _videoEffects = nil;
    _videoPlayerController = nil;
    [_selectedPhotos removeAllObjects];
    _selectedPhotos = nil;
    
    _playButton = nil;
    _viewToolbar = nil;
    _imageViewToolbarBG = nil;
    _toggleEffects = nil;
    _openCameraRoll = nil;
    _saveVideo = nil;
    _titleEffects = nil;
    _titleCameraRoll = nil;
    _titleSaveVideo = nil;
    
    _imageViewPreview = nil;
    _frameScrollView = nil;
    _imagePicker = nil;
    _popTipView = nil;
    
    [super viewDidUnload];
}

- (void) dealloc
{
    
//    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationLandscapeRight);
}

-(BOOL)shouldAutorotate
{
    return NO;
}

/*
 -(NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscape;
}
 */

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationLandscapeRight;
}

@end
