//
//  DFCameraViewController.h
//  Strand
//
//  Created by Henry Bridge on 6/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DFCameraOverlayView;

@interface DFCameraViewController : UIImagePickerController <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, readonly, retain) DFCameraOverlayView *customCameraOverlayView;

@end
