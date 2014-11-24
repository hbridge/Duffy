//
//  DFSwapTableViewCell.h
//  Strand
//
//  Created by Henry Bridge on 10/30/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFProfileStackView.h"
#import <MCSwipeTableViewCell/MCSwipeTableViewCell.h>

@interface DFSwapTableViewCell : MCSwipeTableViewCell
@property (weak, nonatomic) IBOutlet DFProfileStackView *profilePhotoStackView;
@property (weak, nonatomic) IBOutlet UILabel *topLabel;
@property (weak, nonatomic) IBOutlet UILabel *subTitleLabel;
@property (weak, nonatomic) IBOutlet UIImageView *previewImageView;
@property (weak, nonatomic) IBOutlet UIImageView *profileReplacementImageView;

+ (CGFloat)height;
+ (UIEdgeInsets)edgeInsets;

@end
