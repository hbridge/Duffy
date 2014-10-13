//
//  DFCollectionTableViewCell.h
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFCollectionViewTableViewCell.h"
#import "DFCircleBadge.h"

@interface DFLargeCardTableViewCell : DFCollectionViewTableViewCell <UICollectionViewDelegateFlowLayout>

typedef NS_OPTIONS(NSInteger, DFCreateStrandCellStyle) {
  DFCreateStrandCellStyleInvite,
  DFCreateStrandCellStyleSuggestionWithPeople,
  DFCreateStrandCellStyleSuggestionNoPeople,
};

@property (weak, nonatomic) IBOutlet UILabel *contextLabel;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UICollectionViewFlowLayout *flowLayout;
@property (weak, nonatomic) IBOutlet UILabel *peopleLabel;
@property (weak, nonatomic) IBOutlet UILabel *peopleExplanationLabel;
@property (weak, nonatomic) IBOutlet UIView *solidBackgroundView;
@property (weak, nonatomic) IBOutlet DFCircleBadge *countBadge;


+ (DFLargeCardTableViewCell *)cellWithStyle:(DFCreateStrandCellStyle)style;
- (void)configureWithStyle:(DFCreateStrandCellStyle)style;

@end
