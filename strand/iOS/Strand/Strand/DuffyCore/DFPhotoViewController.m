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
#import "UIImage+DFHelpers.h"
#import "DFPhoto.h"
#import "NSDictionary+DFJSON.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "DFMultiPhotoViewController.h"
#import "DFPhotoMetadataAdapter.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "UIImage+DFHelpers.h"

@interface DFPhotoViewController ()

@property (nonatomic) BOOL hideStatusBar;
@property (atomic) BOOL isPhotoLoadInProgress;
@property (nonatomic, retain) DFPhotoMetadataAdapter *photoAdapter;

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
  [super viewDidLoad];
  if (self.photoView) {
    if (self.photo) {
      self.photoView.image = self.photo.fullScreenImage;
      //[self logPhotoMetadata];
    } else if (self.photoURL && !self.photoView.image) {
      [self setImageFromPhotoURL:self.photoURL];
    }
  }
}

- (void)setImageFromPhotoURL:(NSURL *)photoURL
{
  if (self.isPhotoLoadInProgress) return;
  self.isPhotoLoadInProgress = YES;
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    DDLogVerbose(@"Fetching full photo at %@", photoURL.description);
    NSData *data = [NSData dataWithContentsOfURL:self.photoURL];
    UIImage *img = [UIImage imageWithData:data];
    dispatch_async(dispatch_get_main_queue(), ^{
      self.photoView.image = img;
      self.isPhotoLoadInProgress = NO;
      [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    });
  });
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

- (void)setPhotoURL:(NSURL *)photoURL
{
  _photoURL = photoURL;
  [self setImageFromPhotoURL:photoURL];
}

- (void)showShareActivity
{
  NSURL *urlToShare;
  if (self.photo) {
    urlToShare = [NSURL URLWithString:self.photo.alAssetURLString];
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc]
                                                       initWithActivityItems:@[urlToShare]
                                                       applicationActivities:nil];
    [self presentViewController:activityViewController animated:YES completion:nil];
  } else if (self.photoURL) {
    @autoreleasepool {
      NSString *photoIDString = [self.photoURL.lastPathComponent stringByDeletingPathExtension];
      DFPhotoIDType photoID = [photoIDString longLongValue];
      [self.photoAdapter getPhotoMetadata:photoID completionBlock:^(NSDictionary *metadata) {
        DDLogVerbose(@"Photo metadata: %@", metadata[@"{Exif}"]);
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        UIImage *image = self.photoView.image;
        NSMutableDictionary *mutableMetadata = metadata.mutableCopy;
        [self addOrientationToMetadata:mutableMetadata forImage:image];
        
        [library writeImageToSavedPhotosAlbum:image.CGImage
                                     metadata:mutableMetadata
                              completionBlock:^(NSURL *assetURL, NSError *error) {
                                if (error) {
                                  DDLogError(@"Failed to save photo: %@", error.description);
                                  UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil
                                                                                      message:error.localizedDescription
                                                                                     delegate:nil
                                                                            cancelButtonTitle:@"OK"
                                                                            otherButtonTitles:nil];
                                  [alertView show];
                                } else {
                                  DDLogInfo(@"Photo saved with assetURL: %@", assetURL);
                                  UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil
                                                                                      message:@"Photo saved to your camera roll"
                                                                                     delegate:nil
                                                                            cancelButtonTitle:@"OK"
                                                                            otherButtonTitles:nil];
                                  [alertView show];
                                }
                                
                              }
         ];
      }];
    }
  }
}

  - (void)addOrientationToMetadata:(NSMutableDictionary *)metadata forImage:(UIImage *)image
  {
    metadata[@"Orientation"] = @([image CGImageOrientation]);
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


- (DFPhotoMetadataAdapter *)photoAdapter
{
  if (!_photoAdapter) _photoAdapter = [[DFPhotoMetadataAdapter alloc] init];
  return _photoAdapter;
}

@end
