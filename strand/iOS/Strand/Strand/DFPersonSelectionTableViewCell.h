//
//  DFPersonSelectionTableViewCell.h
//  Strand
//
//  Created by Henry Bridge on 10/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Strand-Swift.h"

@interface DFPersonSelectionTableViewCell : UITableViewCell
@property (weak, nonatomic) IBOutlet DFProfilePhotoStackView *profilePhotoStackView;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *subtitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *rightLabel;
@property (nonatomic) BOOL showsTickMarkWhenSelected;

typedef enum {
  DFPersonSelectionTableViewCellStyleStrandUser,
  DFPersonSelectionTableViewCellStyleStrandUserWithSubtitle,
  DFPersonSelectionTableViewCellStyleNonUser,
} DFPersonSelectionTableViewCellStyle;
- (void)configureWithCellStyle:(DFPersonSelectionTableViewCellStyle)style;

@end
