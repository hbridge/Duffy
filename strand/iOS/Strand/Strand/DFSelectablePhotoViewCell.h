//
//  DFSelectablePhotoViewCell.h
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPhotoViewCell.h"
#import "LKBadgeView.h"

@class DFSelectablePhotoViewCell;

@protocol DFSelectablePhotoViewCellDelegate <NSObject>

- (void)cell:(DFSelectablePhotoViewCell *)cell selectPhotoButtonPressed:(UIButton *)selectPhotoButton;

@end


@interface DFSelectablePhotoViewCell : DFPhotoViewCell
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIButton *selectPhotoButton;
@property (nonatomic, weak) id<DFSelectablePhotoViewCellDelegate> delegate;
@property (nonatomic) BOOL showTickMark;
@property (nonatomic) NSUInteger count;
@property (weak, nonatomic) IBOutlet LKBadgeView *countView;


- (IBAction)selectPhotoButtonPressed:(UIButton *)sender;

@end
