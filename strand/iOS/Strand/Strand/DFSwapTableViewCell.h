//
//  DFSwapTableViewCell.h
//  Strand
//
//  Created by Henry Bridge on 10/30/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Strand-Swift.h"
#import <MCSwipeTableViewCell/MCSwipeTableViewCell.h>

@interface DFSwapTableViewCell : MCSwipeTableViewCell
@property (weak, nonatomic) IBOutlet DFProfilePhotoStackView *profilePhotoStackView;
@property (weak, nonatomic) IBOutlet UILabel *peopleLabel;
@property (weak, nonatomic) IBOutlet UILabel *subTitleLabel;
@property (weak, nonatomic) IBOutlet UIImageView *previewImageView;

+ (CGFloat)height;
+ (UIEdgeInsets)edgeInsets;

@end
