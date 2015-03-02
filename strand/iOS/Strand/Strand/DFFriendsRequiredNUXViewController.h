//
//  DFFriendsRequiredNUXViewController.h
//  Strand
//
//  Created by Henry Bridge on 3/2/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFNUXViewController.h"
#import <SAMGradientView/SAMGradientView.h>
#import "DFProfileStackView.h"

@interface DFFriendsRequiredNUXViewController : DFNUXViewController
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *explanationLabel;
@property (weak, nonatomic) IBOutlet DFProfileStackView *profileStackView;
@property (weak, nonatomic) IBOutlet UIButton *button;
@property (strong, nonatomic) IBOutlet SAMGradientView *backgroundGradientView;

@end
