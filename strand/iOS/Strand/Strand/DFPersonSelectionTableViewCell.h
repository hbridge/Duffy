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
@property (weak, nonatomic) IBOutlet UIImageView *checkedImageView;
@property (weak, nonatomic) IBOutlet UILabel *subtitleLabel;

typedef enum {
  DFPersonSelectionTableViewCellStyleStrandUser,
  DFPersonSelectionTableViewCellStyleNonUser,
} DFPersonSelectionTableViewCellStyle;
- (void)configureWithCellStyle:(DFPersonSelectionTableViewCellStyle)style;

@end
