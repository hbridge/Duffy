//
//  DFFeedSectionHeaderView.h
//  Strand
//
//  Created by Henry Bridge on 7/21/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DFFeedSectionHeaderView;

@protocol DFFeedSectionHeaderViewDelegate <NSObject>

@optional
- (void)inviteButtonPressedForHeaderView:(DFFeedSectionHeaderView *)headerView;

@end

@interface DFFeedSectionHeaderView : UITableViewHeaderFooterView
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *subtitleLabel;
@property (strong, nonatomic) IBOutlet UIView *backgroundView;
@property (weak, nonatomic) IBOutlet UIImageView *subtitleImageView;
@property (weak, nonatomic) id<DFFeedSectionHeaderViewDelegate> delegate;

@property (nonatomic, retain) NSObject *representativeObject;

- (IBAction)inviteButtonPressed:(id)sender;

@end
