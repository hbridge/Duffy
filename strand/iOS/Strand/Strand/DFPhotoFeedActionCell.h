//
//  DFPhotoFeedActionCell.h
//  Strand
//
//  Created by Henry Bridge on 11/19/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutAction.h"

@interface DFPhotoFeedActionCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *iconImageView;
@property (weak, nonatomic) IBOutlet UILabel *actionLabel;

- (void)setLikes:(NSArray *)likeActions;
- (void)setComment:(DFPeanutAction *)commentAction;
- (CGFloat)rowHeight;

@end
