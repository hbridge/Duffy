//
//  DFPhotoViewController.m
//  Duffy
//
//  Created by Henry Bridge on 3/25/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotoViewController.h"
#import "DFAnalytics.h"
#import "DFMultiPhotoViewController.h"
#import "DFPhoto.h"
#import "DFPhotoMetadataAdapter.h"
#import "DFPhotoStore.h"
#import "DFUser.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "NSDictionary+DFJSON.h"
#import "UIImage+DFHelpers.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#import "DFPeanutActionAdapter.h"
#import "DFPeanutAction.h"
#import "DFStrandConstants.h"

@interface DFPhotoViewController ()

@property (nonatomic) BOOL hideStatusBar;
@property (atomic) BOOL isPhotoLoadInProgress;
@property (nonatomic, retain) DFPhotoMetadataAdapter *photoAdapter;
@property (nonatomic, retain) DFPeanutAction *userFavoritedAction;

@end

@implementation DFPhotoViewController

- (id)init
{
    self = [super initWithNibName:@"DFPhotoViewController" bundle:nil];
    if (self) {
        UINavigationItem *n = [self navigationItem];
        [n setTitle:@"Photo"];
      self.favoritedOtherUserNames = [[NSMutableArray alloc] init];
      
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
      [self.photo.asset loadFullScreenImage:^(UIImage *image) {
        dispatch_async(dispatch_get_main_queue(), ^{
          self.photoView.image = image;
        });
      } failureBlock:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
          self.photoView.image = nil;
        });
      }];
      //[self logPhotoMetadata];
    } else if (self.photoURL && !self.photoView.image) {
      [self setImageFromPhotoURL:self.photoURL];
    }
  }
  
  [self configureToolbar];
}

- (void)configureToolbar
{
  self.favoritedOtherUserNames = [[NSMutableArray alloc] init];
  for (DFPeanutAction *action in self.photoActions) {
    if ([action.action_type isEqualToString:DFActionFavorite]) {
      if (action.user == [[DFUser currentUser] userID]) {
        self.userFavoritedAction = action;
      } else {
        [self.favoritedOtherUserNames addObject:action.user_display_name];
      }
    }
  }
  
  self.favoriteButton = [UIButton buttonWithType:UIButtonTypeCustom];
  [self.favoriteButton setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
  [self.favoriteButton addTarget:self
                          action:@selector(favoriteButtonPressed:)
                forControlEvents:UIControlEventTouchUpInside];
  self.favoriteButton.titleLabel.font = [self.favoriteButton.titleLabel.font fontWithSize:14.0];

  UIBarButtonItem *likeButton = [[UIBarButtonItem alloc] initWithCustomView:self.favoriteButton];
  UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
  self.trashButton = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                   target:self
                                   action:@selector(confirmDeletePhoto)];
  
  [self.toolbar setItems:@[likeButton, flexibleSpace, self.trashButton] animated:NO];
  self.toolbar.tintColor = [DFStrandConstants mainColor];
  
  [self updateFavoriteButton];
  if (![self isPhotoDeletableByUser]) {
    self.trashButton.enabled = NO;
  }
}

- (void)updateFavoriteButton
{
  UIImage *newImage;
  if (self.isUserFavorited) {
    newImage = [UIImage imageNamed:@"Assets/Icons/LikeOnToolbarIcon"];
  } else {
    newImage = [UIImage imageNamed:@"Assets/Icons/LikeOffToolbarIcon"];

  }
  
  if ((self.favoritedOtherUserNames.count > 0 || self.isUserFavorited)
      && self.favoritedOtherUserNames.count < 5) {
    NSMutableString *userNamesString = [[NSMutableString alloc] initWithString:@" "];
    if (self.isUserFavorited) {
      [userNamesString appendString:@"You"];
      if (self.favoritedOtherUserNames.count > 0) [userNamesString appendString:@", "];
    }
    for (NSUInteger i = 0; i < self.favoritedOtherUserNames.count; i++) {
      [userNamesString appendString:self.favoritedOtherUserNames[i]];
      if (i < self.favoritedOtherUserNames.count -1) {
        [userNamesString appendString:@", "];
      }
    }
    [self.favoriteButton setTitle:userNamesString
                         forState:UIControlStateNormal];
  } else {
    [self.favoriteButton setTitle:[NSString stringWithFormat:@" %d ",
                                   (int)self.favoritedOtherUserNames.count + (self.isUserFavorited ? 1 : 0)]
                         forState:UIControlStateNormal];
  }
  
  [self.favoriteButton setImage:newImage forState:UIControlStateNormal];
  [self.favoriteButton sizeToFit];
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
  [self setToolbarHidden:theatreModeEnabled];
}

- (void)setToolbarHidden:(BOOL)hidden
{
  CGFloat destOpacity;
  if (hidden) {
    destOpacity = 0.0;
  } else {
    destOpacity = 1.0;
  }
  [UIView animateWithDuration:0.5 animations:^{
    self.toolbar.alpha = destOpacity;
  }];

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
    [DFAnalytics logPhotoLoadWithResult:
     img ? DFAnalyticsValueResultSuccess : DFAnalyticsValueResultFailure];
    dispatch_async(dispatch_get_main_queue(), ^{
      self.photoView.image = img;
      self.isPhotoLoadInProgress = NO;
      [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    });
  });
}

- (void)logPhotoMetadata
{
  DDLogVerbose(@"photo metadata: %@", [[self.photo.asset.metadata dictionaryWithNonJSONRemoved]
                                       JSONStringPrettyPrinted:YES]);
  [self.photo fetchReverseGeocodeDictionary:^(NSDictionary *locationDict) {
    DDLogVerbose(@"photo reverse Geocode: %@", locationDict.description);
  }];
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
        self.photoView.image = photo.asset.fullScreenImage;
    }
}

- (void)setPhotoURL:(NSURL *)photoURL
{
  _photoURL = photoURL;
  [self setImageFromPhotoURL:photoURL];
}

- (DFPhotoIDType)photoID
{
  if (self.photo) return self.photo.photoID;
  if (self.photoURL) {
    NSString *photoIDString = [self.photoURL.lastPathComponent stringByDeletingPathExtension];
    return [photoIDString longLongValue];
  }
  
  return 0;
}

#pragma mark - User action handlers

- (void)showShareActivity
{
  if (self.photo) {
    NSURL *urlToShare = self.photo.asset.canonicalURL;
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc]
                                                       initWithActivityItems:@[urlToShare]
                                                       applicationActivities:nil];
    [self presentViewController:activityViewController animated:YES completion:nil];
  }
}

NSString *const CancelButtonTitle = @"Cancel";
NSString *const DeleteButtonTitle = @"Delete";
NSString *const SaveButtonTitle = @"Save to Camera Roll";

- (void)showPhotoActions:(id)sender
{
 UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                           delegate:self
                                                  cancelButtonTitle:CancelButtonTitle
                                             destructiveButtonTitle:nil
                                                  otherButtonTitles:SaveButtonTitle, nil];
  
  if ([[sender class] isSubclassOfClass:[UIBarButtonItem class]]) {
    [actionSheet showFromBarButtonItem:sender animated:YES];
  } else {
    [actionSheet showInView:self.view];
  }
}


/*
 We only want users to be able to delete photos that they uploaded.
 */

- (BOOL)isPhotoDeletableByUser
{
  DFPhoto *photo = [[DFPhotoStore sharedStore] photoWithPhotoID:self.photoID];
  DDLogVerbose(@"photo null: %d userID %llu currentUserID: %llu",
               photo == nil,
               photo.userID,
               [[DFUser currentUser] userID]);
  if (photo && [photo isDeleteableByUser:[[DFUser currentUser] userID]]) {
    return YES;
  }
  
  return NO;
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
  NSString *buttonTitle = [actionSheet buttonTitleAtIndex:buttonIndex];
  DDLogVerbose(@"The %@ button was tapped.", buttonTitle);
   if ([buttonTitle isEqualToString:DeleteButtonTitle]) {
     [self confirmDeletePhoto];
  } else if ([buttonTitle isEqualToString:SaveButtonTitle]) {
    [self savePhotoToCameraRoll];
  }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
  if (buttonIndex == 1) {
    [self deletePhoto];
  }
}


- (void)savePhotoToCameraRoll
{
  @autoreleasepool {
    [self.photoAdapter getPhotoMetadata:self.photoID completionBlock:^(NSDictionary *metadata) {
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
                                [DFAnalytics logPhotoSavedWithResult:DFAnalyticsValueResultFailure];
                              } else {
                                DDLogInfo(@"Photo saved with assetURL: %@", assetURL);
                                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil
                                                                                    message:@"Photo saved to your camera roll"
                                                                                   delegate:nil
                                                                          cancelButtonTitle:@"OK"
                                                                          otherButtonTitles:nil];
                                [alertView show];
                                [DFAnalytics logPhotoSavedWithResult:DFAnalyticsValueResultSuccess];
                              }
                            }
       ];
    }];
  }
}
- (IBAction)deleteButtonPressed:(UIBarButtonItem *)sender {
  [self confirmDeletePhoto];
}

- (void)confirmDeletePhoto
{
  UIAlertView *alertView = [[UIAlertView alloc]
                            initWithTitle:@"Delete Photo?"
                            message:@"You and other strand users will no longer be able to see it."
                            delegate:self
                            cancelButtonTitle:@"Cancel"
                            otherButtonTitles:@"Delete", nil];
  [alertView show];
}

- (void)deletePhoto
{
  DFPhotoMetadataAdapter *metadataAdapter = [[DFPhotoMetadataAdapter alloc] init];
  [metadataAdapter deletePhoto:self.photoID completionBlock:^(NSError *error) {
    if (!error) {
      // tell the multi photo view controller to select another
      DFMultiPhotoViewController *parentMPVC = (DFMultiPhotoViewController *)self.parentViewController;
      [parentMPVC activePhotoDeleted];
      
      // remove it from the db
      [[DFPhotoStore sharedStore] deletePhotoWithPhotoID:self.photoID];
      [DFAnalytics logPhotoDeletedWithResult:DFAnalyticsValueResultSuccess];
    } else {
      UIAlertView *alertView = [[UIAlertView alloc]
                                initWithTitle:@"Error"
                                message:[[NSString stringWithFormat:@"Sorry, an error occurred: %@",
                                         error.localizedRecoverySuggestion ?
                                          error.localizedRecoverySuggestion : error.localizedDescription] substringToIndex:200]
                                delegate:nil
                                cancelButtonTitle:@"OK"
                                otherButtonTitles:nil];
      [alertView show];
      [DFAnalytics logPhotoDeletedWithResult:DFAnalyticsValueResultFailure];
    }
  }];
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

- (IBAction)favoriteButtonPressed:(UIBarButtonItem *)sender {
  DDLogVerbose(@"Favorite button pressed");
  
  DFPeanutActionAdapter *adapter = [[DFPeanutActionAdapter alloc] init];
  
  DFPeanutAction *oldAction = self.userFavoritedAction;
  DFPeanutAction *newAction;
  if (!self.isUserFavorited) {
    newAction = [[DFPeanutAction alloc] init];
    newAction.user = [[DFUser currentUser] userID];
    newAction.action_type = DFActionFavorite;
    newAction.photo = self.photoID;
  } else {
    newAction = nil;
  }
  
  self.userFavoritedAction = newAction;
  [self updateFavoriteButton];
  
  DFPeanutActionResponseBlock responseBlock = ^(DFPeanutAction *action, NSError *error) {
    if (!error) {
      self.userFavoritedAction = action;
      [DFAnalytics logPhotoLikePressedWithNewValue:self.isUserFavorited result:DFAnalyticsValueResultSuccess];
    } else {
      [DFAnalytics logPhotoLikePressedWithNewValue:self.isUserFavorited result:DFAnalyticsValueResultFailure];
      self.userFavoritedAction = oldAction;
      [self updateFavoriteButton];
      UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                      message:error.localizedDescription
                                                     delegate:nil
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:nil];
      [alert show];
    }
  };
  
  if (!oldAction) {
    [adapter postAction:newAction withCompletionBlock:responseBlock];
  } else {
    [adapter deleteAction:oldAction withCompletionBlock:responseBlock];
  }
}


- (BOOL)isUserFavorited
{
  return (self.userFavoritedAction != nil);
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


#pragma mark - Adapter Getters


- (DFPhotoMetadataAdapter *)photoAdapter
{
  if (!_photoAdapter) _photoAdapter = [[DFPhotoMetadataAdapter alloc] init];
  return _photoAdapter;
}

@end
