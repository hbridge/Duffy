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
    if (self.imageView && self.photo) {
        self.imageView.image = self.photo.fullScreenImage;
    }
  
  UIBarButtonItem *actionItem = [[UIBarButtonItem alloc]
                                 initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                 target:self
                                 action:@selector(actionButtonClicked:)];
  
  if (self.parentViewController) {
    // if this is part of a multi-photo view, set the action for the parent
    self.parentViewController.navigationItem.rightBarButtonItem = actionItem;
  } else {
    self.navigationItem.rightBarButtonItem = actionItem;
  }
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  DDLogVerbose(@"\n*** photo_id:%lld user:%lld, photo creation hash:%@, \n***current hash:%@",
               self.photo.photoID,
               self.photo.userID,
               self.photo.creationHashData.description,
               self.photo.currentHashData.description);
  
  DDLogVerbose(@"photo metadata: %@", [[self.photo.metadataDictionary dictionaryWithNonJSONRemoved]
                                       JSONStringPrettyPrinted:YES]);
//  [self.photo fetchReverseGeocodeDictionary:^(NSDictionary *locationDict) {
//    DDLogVerbose(@"photo reverse Geocode: %@", locationDict.description);
//  }];
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
    
    if (self.imageView) {
        self.imageView.image = photo.fullScreenImage;
    }
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)sv
{
    if (sv == self.scrollView) return self.imageView;
    
    return nil;
}


- (void)addFaceBoundingBoxes
{
//    // if there are already bounding boxes in the image view, we've already
//    // done recognition, skip it
//    if (self.imageView.boundingBoxesInImageCoordinates) return;
//
//    [self.photo faceFeaturesWithQuality:YES successBlock:^(NSArray *features) {
//        NSMutableArray *boundingBoxes = [[NSMutableArray alloc] init];
//    
//        for (CIFaceFeature *f in features)
//        {
//            DDLogVerbose(@"face found at %@", NSStringFromCGRect(f.bounds));
//            [boundingBoxes addObject:[NSValue valueWithCGRect:f.bounds]];
//        }
//        
//        dispatch_async(dispatch_get_main_queue(), ^{
//            self.imageView.boundingBoxesInImageCoordinates = boundingBoxes;
//        });
//    }];
}

- (void)actionButtonClicked:(id)sender
{
  [self showShareActivity];
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
  DDLogVerbose(@"image tapped");
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
