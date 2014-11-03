//
//  DFPhotoViewController.h
//  Duffy
//
//  Created by Henry Bridge on 3/25/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPhotoView.h"
#import "DFPeanutFeedObject.h"

@interface DFPhotoViewController : UIViewController <UIActionSheetDelegate, UIAlertViewDelegate>

@property (strong, nonatomic) DFPeanutFeedObject *photo;
@property (strong, nonatomic) NSIndexPath *indexPathInParent;
@property (weak, nonatomic) IBOutlet DFPhotoView *photoView;

@property (nonatomic) BOOL theatreModeEnabled;

- (IBAction)imageTapped:(id)sender;

@end
