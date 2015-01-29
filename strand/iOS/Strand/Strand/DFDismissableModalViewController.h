//
//  DFDismissableModalViewController.h
//  Strand
//
//  Created by Henry Bridge on 12/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFDismissableModalViewController : UIViewController
- (IBAction)closeButtonPressed:(id)sender;
@property (weak, nonatomic) IBOutlet UIImageView *backgroundImageView;
@property (weak, nonatomic) IBOutlet UIButton *closeButton;
@property (nonatomic, retain) UIView *contentView;
@property (nonatomic, retain) UIImage *backgroundImage;


+ (void)presentWithRootController:(UIViewController *)rootController
                         inParent:(UIViewController *)parent;
+ (void)presentWithRootController:(UIViewController *)rootController
                         inParent:(UIViewController *)parent
                         animated:(BOOL)animated;

@end
