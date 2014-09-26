//
//  DFFeedSectionHeaderView.h
//  Strand
//
//  Created by Henry Bridge on 7/21/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Strand-Swift.h"

@class DFFeedSectionHeaderView;

@protocol DFFeedSectionHeaderViewDelegate <NSObject>

@optional
- (void)inviteButtonPressedForHeaderView:(DFFeedSectionHeaderView *)headerView;

@end

@interface DFFeedSectionHeaderView : UITableViewHeaderFooterView
@property (weak, nonatomic) IBOutlet DFProfilePhotoStackView *profilePhotoStackView;
@property (weak, nonatomic) IBOutlet UILabel *actorLabel;
@property (weak, nonatomic) IBOutlet UILabel *actionTextLabel;
@property (weak, nonatomic) IBOutlet UILabel *subtitleLabel;
@property (strong, nonatomic) IBOutlet UIView *backgroundView;

@property (weak, nonatomic) id<DFFeedSectionHeaderViewDelegate> delegate;

@property (nonatomic, retain) NSObject *representativeObject;

- (IBAction)inviteButtonPressed:(id)sender;

@end
