//
//  DFPhotosPermissionViewController.h
//  Strand
//
//  Created by Henry Bridge on 9/5/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFPhotosPermissionViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIButton *learnMoreButtonPressed;
- (IBAction)grantPhotosAccessPressed:(id)sender;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@end
