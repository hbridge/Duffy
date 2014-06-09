//
//  DFCameraViewController.m
//  Strand
//
//  Created by Henry Bridge on 6/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCameraViewController.h"
#import "DFCameraOverlayView.h"

@interface DFCameraViewController ()

@end

@implementation DFCameraViewController

@synthesize imagePickerController = _imagePickerController;
@synthesize cameraOverlayView = _cameraOverlayView;

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    // Custom initialization
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
}


- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
 {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

#pragma mark - Image Picker Controller delegate methods

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
  
  //UIImage *chosenImage = info[UIImagePickerControllerEditedImage];
  
  [picker dismissViewControllerAnimated:YES completion:NULL];
  
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
  
  [picker dismissViewControllerAnimated:YES completion:NULL];
  
}


- (IBAction)cameraButtonPressed:(UIButton *)sender {
  [self presentViewController:self.imagePickerController animated:YES completion:NULL];
}
                              
- (UIImagePickerController *)imagePickerController
{
  if (!_imagePickerController) {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    picker.showsCameraControls = NO;
    picker.cameraOverlayView = self.cameraOverlayView;
    _imagePickerController = picker;
  }
  
  return _imagePickerController;
}

- (UIView *)cameraOverlayView
{
  if (!_cameraOverlayView) {
    _cameraOverlayView = [[[UINib nibWithNibName:@"DFCameraOverlayView" bundle:nil]
                           instantiateWithOwner:self options:nil]
                          firstObject];
  }
  
  [_cameraOverlayView.dismissButton addTarget:self action:@selector(dismissButtonPressed:)
                             forControlEvents:UIControlEventTouchUpInside];
  [_cameraOverlayView.dismissButton addTarget:self action:@selector(takePhotoButtonPressed:)
                             forControlEvents:UIControlEventTouchUpInside];
  
  return _cameraOverlayView;
}

- (void)takePhotoButtonPressed:(UIButton *)sender {
  
}

- (void)dismissButtonPressed:(UIButton *)sender {
  [self.imagePickerController dismissViewControllerAnimated:YES completion:nil];
}


@end
