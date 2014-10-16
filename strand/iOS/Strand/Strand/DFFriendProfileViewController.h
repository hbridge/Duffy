//
//  DFFriendProfileViewController.h
//  Strand
//
//  Created by Henry Bridge on 10/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutUserObject.h"
#import "Strand-Swift.h"

@interface DFFriendProfileViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIView *headerView;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *subtitleLabel;
@property (nonatomic, retain) DFPeanutUserObject *peanutUser;
@property (weak, nonatomic) IBOutlet UIView *tabSegmentedControlWrapper;
@property (weak, nonatomic) IBOutlet UISegmentedControl *tabSegmentedControl;
@property (weak, nonatomic) IBOutlet DFProfilePhotoStackView *profilePhotoStackView;

- (instancetype)initWithPeanutUser:(DFPeanutUserObject *)peanutUser;



@end
