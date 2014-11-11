//
//  DFCommentTableViewCell.h
//  Strand
//
//  Created by Henry Bridge on 11/10/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Strand-Swift.h"

@interface DFCommentTableViewCell : UITableViewCell
@property (weak, nonatomic) IBOutlet DFProfilePhotoStackView *profilePhotoStackView;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *commentLabel;
@property (weak, nonatomic) IBOutlet UILabel *timestampLabel;

+ (DFCommentTableViewCell *)templateCell;
- (CGFloat)rowHeight;
+ (UIEdgeInsets)edgeInsets;
@end
