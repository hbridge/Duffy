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

#import "DFPeanutFeedObject.h"

@interface DFCardTableViewCell : DFCollectionViewTableViewCell <UICollectionViewDelegateFlowLayout>

typedef NS_OPTIONS(NSInteger, DFCardCellStyle) {
  DFCardCellStyleInvite = 1 << 0,
  DFCardCellStyleSuggestionWithPeople = 1 << 1,
  DFCardCellStyleSuggestionNoPeople = 1 << 2,
  DFCardCellStyleSmall = 1 << 3,
};

@property (weak, nonatomic) IBOutlet UILabel *contextLabel;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UICollectionViewFlowLayout *flowLayout;
@property (weak, nonatomic) IBOutlet UILabel *peopleLabel;
@property (weak, nonatomic) IBOutlet UILabel *peoplePrefixLabel;
@property (weak, nonatomic) IBOutlet UILabel *peopleSuffixLabel;
@property (weak, nonatomic) IBOutlet UIView *solidBackgroundView;
@property (weak, nonatomic) IBOutlet DFCircleBadge *countBadge;


+ (DFCardTableViewCell *)cellWithStyle:(DFCardCellStyle)style;
- (void)configureWithStyle:(DFCardCellStyle)style;
- (void)configureWithFeedObject:(DFPeanutFeedObject *)feedObject;

@end
