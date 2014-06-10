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
  self.sourceType = UIImagePickerControllerSourceTypeCamera;
  self.delegate = self;
  
  self.showsCameraControls = NO;
  self.cameraOverlayView = self.cameraOverlayView;
}


- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

#pragma mark - Image Picker Controller delegate methods

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
  
  //UIImage *chosenImage = info[UIImagePickerControllerEditedImage];
  
  [picker dismissViewControllerAnimated:YES completion:NULL];
  
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
  
  [picker dismissViewControllerAnimated:YES completion:NULL];
  
}

- (UIView *)cameraOverlayView
{
  if (!_customCameraOverlayView) {
    _customCameraOverlayView = [[[UINib nibWithNibName:@"DFCameraOverlayView" bundle:nil]
                           instantiateWithOwner:self options:nil]
                          firstObject];
  }
  
  [_customCameraOverlayView.takePhotoButton addTarget:self action:@selector(takePhotoButtonPressed:)
                             forControlEvents:UIControlEventTouchUpInside];
  [_customCameraOverlayView.galleryButton addTarget:self action:@selector(galleryButtonPressed:)
                                     forControlEvents:UIControlEventTouchUpInside];
  
  return _customCameraOverlayView;
}

- (void)takePhotoButtonPressed:(UIButton *)sender {
  
}

- (void)galleryButtonPressed:(UIButton *)sender {
  [(RootViewController *)self.view.window.rootViewController showGallery];
}



@end
