//
//  DFFriendProfileViewController.h
//  Strand
//
//  Created by Henry Bridge on 10/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GBFlatButton/GBFlatButton.h>
#import "DFPeanutUserObject.h"
#import "DFProfileStackView.h"


@interface DFFriendProfileViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIView *headerView;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *subtitleLabel;
@property (nonatomic, retain) DFPeanutUserObject *peanutUser;
@property (weak, nonatomic) IBOutlet DFProfileStackView *profilePhotoStackView;
@property (weak, nonatomic) IBOutlet UIButton *backButton;
@property (weak, nonatomic) IBOutlet GBFlatButton *friendButton;

- (instancetype)initWithPeanutUser:(DFPeanutUserObject *)peanutUser;
- (IBAction)friendButtonPressed:(id)sender;



@end
