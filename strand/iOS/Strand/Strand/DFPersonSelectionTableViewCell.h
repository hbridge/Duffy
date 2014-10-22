//
//  DFPersonSelectionTableViewCell.h
//  Strand
//
//  Created by Henry Bridge on 10/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MCSwipeTableViewCell/MCSwipeTableViewCell.h>
#import "Strand-Swift.h"


@interface DFPersonSelectionTableViewCell : MCSwipeTableViewCell
@property (weak, nonatomic) IBOutlet DFProfilePhotoStackView *profilePhotoStackView;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *subtitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *rightLabel;
@property (nonatomic) BOOL showsTickMarkWhenSelected;


extern const CGFloat DFPersonSelectionTableViewCellHeight;

typedef NS_OPTIONS(NSInteger, DFPersonSelectionTableViewCellStyle) {
  DFPersonSelectionTableViewCellStyleStrandUser = 1 << 1,
  DFPersonSelectionTableViewCellStyleSubtitle = 1 << 2,
  DFPersonSelectionTableViewCellStyleRightLabel = 1 << 3,
};

- (void)configureWithCellStyle:(DFPersonSelectionTableViewCellStyle)style;

@end
