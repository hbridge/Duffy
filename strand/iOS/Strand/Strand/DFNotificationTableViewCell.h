//
//  DFNotificationTableViewCell.h
//  Strand
//
//  Created by Henry Bridge on 8/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Strand-Swift.h"

@interface DFNotificationTableViewCell : UITableViewCell
@property (weak, nonatomic) IBOutlet DFProfilePhotoStackView *profilePhotoStackView;
@property (weak, nonatomic) IBOutlet UIImageView *previewImageView;
@property (weak, nonatomic) IBOutlet UILabel *detailLabel;


+ (DFNotificationTableViewCell *)templateCell;
- (CGFloat)rowHeight;

@end
