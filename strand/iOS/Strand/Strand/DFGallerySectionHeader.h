//
//  DFGallerySectionHeader.h
//  Strand
//
//  Created by Henry Bridge on 8/18/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Strand-Swift.h"
static const CGFloat SectionHeaderWidth = 320;
static const CGFloat SectionHeaderHeight = 70;
static const CGFloat SectionFooterHeight = 54;

@interface DFGallerySectionHeader : UICollectionReusableView
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (weak, nonatomic) IBOutlet DFProfilePhotoStackView *profilePhotoStackView;

@end
