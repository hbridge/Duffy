//
//  DFPhotoViewController.m
//  Duffy
//
//  Created by Henry Bridge on 3/25/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotoViewController.h"
#import "DFAnalytics.h"
#import "DFImageManager.h"
#import "DFMultiPhotoViewController.h"


@interface DFPhotoViewController ()

@property (nonatomic) BOOL hideStatusBar;
@property (atomic) BOOL isPhotoLoadInProgress;
@property (nonatomic, retain) DFPeanutAction *userFavoritedAction;

@end

@implementation DFPhotoViewController

- (id)init
{
  self = [super initWithNibName:@"DFPhotoViewController" bundle:nil];
  if (self) {
    UINavigationItem *n = [self navigationItem];
    [n setTitle:@"Preview"];
    
    self.automaticallyAdjustsScrollViewInsets = NO;
    self.hidesBottomBarWhenPushed = YES;
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  if (self.photoView) {
    if (self.photo) {
      [self setPhoto:self.photo];
    }
  }
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [DFAnalytics logViewController:self disappearedWithParameters:nil];
}

- (void)setTheatreModeEnabled:(BOOL)theatreModeEnabled
{
  _theatreModeEnabled = theatreModeEnabled;
  self.view.backgroundColor = [DFMultiPhotoViewController
                               colorForTheatreModeEnabled:theatreModeEnabled];
}

- (void)setPhoto:(DFPeanutFeedObject *)photo
{
  _photo = photo;
  if (!self.photoView) return;
  DFPhotoViewController __weak *weakSelf = self;
  [[DFImageManager sharedManager]
   imageForID:photo.id
   size:self.photoView.frame.size
   contentMode:DFImageRequestContentModeAspectFit
   deliveryMode:DFImageRequestOptionsDeliveryModeHighQualityFormat
   completion:^(UIImage *image) {
     dispatch_async(dispatch_get_main_queue(), ^{
       weakSelf.photoView.image = image;
     });
   }];
}

- (void)imageTapped:(id)sender
{
  
}

#pragma mark - Status bar

- (BOOL)prefersStatusBarHidden
{
  return self.hideStatusBar;
}

- (void)setHideStatusBar:(BOOL)hideStatusBar
{
  if (hideStatusBar != _hideStatusBar) {
    _hideStatusBar = hideStatusBar;
    [self setNeedsStatusBarAppearanceUpdate];
  }
}


@end
