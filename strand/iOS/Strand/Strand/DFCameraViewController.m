//
//  DFCameraViewController.m
//  Strand
//
//  Created by Henry Bridge on 6/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCameraViewController.h"
#import "DFCameraOverlayView.h"
#import "RootViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "DFPhoto.h"
#import "DFPhotoStore.h"
#import "DFDataHasher.h"
#import "DFUploadController.h"

@interface DFCameraViewController ()

@end

@implementation DFCameraViewController

@synthesize customCameraOverlayView = _customCameraOverlayView;

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    
  }
  return self;
}


- (void)viewDidLoad
{
  [super viewDidLoad];
  if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
    self.sourceType = UIImagePickerControllerSourceTypeCamera;
    self.showsCameraControls = NO;
    self.cameraOverlayView = self.cameraOverlayView;
  } else {
    self.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
  }
  
  self.delegate = self;
}


- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}



- (UIView *)cameraOverlayView
{
  if (!_customCameraOverlayView) {
    _customCameraOverlayView = [[[UINib nibWithNibName:@"DFCameraOverlayView" bundle:nil]
                           instantiateWithOwner:self options:nil]
                          firstObject];
    [_customCameraOverlayView.takePhotoButton addTarget:self action:@selector(takePhotoButtonPressed:)
                                       forControlEvents:UIControlEventTouchUpInside];
    [_customCameraOverlayView.galleryButton addTarget:self action:@selector(galleryButtonPressed:)
                                     forControlEvents:UIControlEventTouchUpInside];
  }

  return _customCameraOverlayView;
}

- (void)takePhotoButtonPressed:(UIButton *)sender
{
  DDLogVerbose(@"takePhotoButtonPressed");
  [self takePicture];
}

- (void)galleryButtonPressed:(UIButton *)sender
{
  [(RootViewController *)self.view.window.rootViewController showGallery];
}


#pragma mark - Image Picker Controller delegate methods

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary *)info {
  DDLogInfo(@"Image picked, info: %@", info.description);
  if (self.sourceType == UIImagePickerControllerSourceTypeCamera) {
    NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
    UIImage *originalImage, *editedImage, *imageToSave;
    
    // Handle a still image capture
    if (CFStringCompare ((CFStringRef) mediaType, kUTTypeImage, 0)
        == kCFCompareEqualTo) {
      
      editedImage = (UIImage *) [info objectForKey:
                                 UIImagePickerControllerEditedImage];
      originalImage = (UIImage *) [info objectForKey:
                                   UIImagePickerControllerOriginalImage];
      
      if (editedImage) {
        imageToSave = editedImage;
      } else {
        imageToSave = originalImage;
      }
      
      // Save the new image (original or edited) to the Camera Roll
      ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
      [library writeImageToSavedPhotosAlbum:imageToSave.CGImage
                                   metadata:info[UIImagePickerControllerMediaMetadata]
                            completionBlock:[self writeImageCompletionBlock]
       ];
    }
  }
}
       
- (ALAssetsLibraryWriteImageCompletionBlock)writeImageCompletionBlock
{
  return ^(NSURL *assetURL, NSError *error) {
    NSManagedObjectContext *context = [DFPhotoStore createBackgroundManagedObjectContext];
    
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library assetForURL:assetURL resultBlock:^(ALAsset *asset) {
      NSData *hashData = [DFDataHasher hashDataForALAsset:asset];
      [DFPhoto insertNewDFPhotoForALAsset:asset withHashData:hashData inContext:context];
      
      NSError *error;
      [context save:&error];
      if (error) {
        [NSException raise:@"Could not save DB" format:@"%@", error.description];
      }
      [[DFUploadController sharedUploadController] uploadPhotos];
      
      
    } failureBlock:^(NSError *error) {
      [NSException raise:@"Could not get asset just created." format:@"%@", error.description];
    }];
  };
}


- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
  
}


@end
