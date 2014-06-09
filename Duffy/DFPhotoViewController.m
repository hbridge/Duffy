//
//  DFPhotoViewController.m
//  Duffy
//
//  Created by Henry Bridge on 3/25/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotoViewController.h"
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#import "DFBoundingBoxView.h"
#import "UIImage+DFHelpers.h"
#import "DFPhoto.h"
#import "DFPhoto+FaceDetection.h"
#import "NSDictionary+DFJSON.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "DFMultiPhotoViewController.h"

@interface DFPhotoViewController ()

@property (nonatomic) BOOL hideStatusBar;

@end

@implementation DFPhotoViewController

@synthesize theatreModeEnabled;

- (id)init
{
    self = [super initWithNibName:@"DFPhotoViewController" bundle:nil];
    if (self) {
        UINavigationItem *n = [self navigationItem];
        [n setTitle:@"Photo"];
        
        
        self.automaticallyAdjustsScrollViewInsets = NO;
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (void)viewDidLoad
{
    if (self.photoView && self.photo) {
        self.photoView.image = self.photo.fullScreenImage;
    }
}


- (void)logPhotoMetadata
{
  DDLogVerbose(@"\n*** photo_id:%lld user:%lld, photo creation hash:%@, \n***current hash:%@",
               self.photo.photoID,
               self.photo.userID,
               self.photo.creationHashData.description,
               self.photo.currentHashData.description);

  DDLogVerbose(@"photo metadata: %@", [[self.photo.metadataDictionary dictionaryWithNonJSONRemoved]
                                       JSONStringPrettyPrinted:YES]);
  [self.photo fetchReverseGeocodeDictionary:^(NSDictionary *locationDict) {
    DDLogVerbose(@"photo reverse Geocode: %@", locationDict.description);
  }];
  NSSet *faceFeatures = self.photo.faceFeatures;
  DDLogVerbose(@"DFFaceFeatures sources:%du count:%lu", self.photo.faceFeatureSources,
               (unsigned long)faceFeatures.count);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setPhoto:(DFPhoto *)photo
{
    _photo = photo;
    
    if (self.photoView) {
        self.photoView.image = photo.fullScreenImage;
    }
}

- (void)showShareActivity
{
  NSURL *assetURL = [NSURL URLWithString:self.photo.alAssetURLString];
  UIActivityViewController *activityViewController = [[UIActivityViewController alloc]
                                                      initWithActivityItems:@[assetURL]
                                                      applicationActivities:nil];
  [self presentViewController:activityViewController animated:YES completion:nil];
}

- (IBAction)imageTapped:(id)sender {
  if (self.parentViewController && [self.parentViewController.class isSubclassOfClass:[DFMultiPhotoViewController class]]) {
    DFMultiPhotoViewController *mpvc = (DFMultiPhotoViewController *)self.parentViewController;
    [mpvc setTheatreModeEnabled:!mpvc.theatreModeEnabled animated:YES];
  } else {
    self.theatreModeEnabled = !self.theatreModeEnabled;
    
    [self.navigationController setNavigationBarHidden:self.theatreModeEnabled animated:YES];
    [self setHideStatusBar:self.theatreModeEnabled];
    if (self.theatreModeEnabled) {
      self.view.backgroundColor = [UIColor blackColor];
    } else {
      self.view.backgroundColor = [UIColor whiteColor];
    }
  }
}

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
