//
//  DFCommentTableViewCell.h
//  Strand
//
//  Created by Henry Bridge on 11/10/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MCSwipeTableViewCell/MCSwipeTableViewCell.h>
#import "DFProfileStackView.h"

@interface DFCommentTableViewCell : MCSwipeTableViewCell
@property (weak, nonatomic) IBOutlet DFProfileStackView *profilePhotoStackView;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *commentLabel;
@property (weak, nonatomic) IBOutlet UILabel *timestampLabel;

+ (DFCommentTableViewCell *)templateCell;
- (CGFloat)rowHeight;
+ (UIEdgeInsets)edgeInsets;
@end
