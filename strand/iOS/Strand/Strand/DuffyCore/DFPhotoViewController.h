//
//  DFPhotoViewController.h
//  Duffy
//
//  Created by Henry Bridge on 3/25/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPhotoView.h"

@class DFPhoto;

@interface DFPhotoViewController : UIViewController <UIActionSheetDelegate>

@property (strong, nonatomic) DFPhoto *photo;
@property (strong, nonatomic) NSURL *photoURL;
@property (strong, nonatomic) NSIndexPath *indexPathInParent;

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet DFPhotoView *photoView;

@property (nonatomic) BOOL theatreModeEnabled;

- (IBAction)imageTapped:(id)sender;
- (void)showShareActivity;
- (void)showPhotoActions:(id)sender;

@end
