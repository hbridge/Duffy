//
//  DFCollectionTableViewCell.h
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFCollectionViewTableViewCell.h"

@interface DFCreateStrandTableViewCell : DFCollectionViewTableViewCell

typedef NS_OPTIONS(NSInteger, DFCreateStrandCellStyle) {
  DFCreateStrandCellStyleInvite,
  DFCreateStrandCellStyleSuggestionWithPeople,
  DFCreateStrandCellStyleSuggestionNoPeople,
};

@property (weak, nonatomic) IBOutlet UIView *solidBackground;
@property (weak, nonatomic) IBOutlet UILabel *inviterLabel;
@property (weak, nonatomic) IBOutlet UILabel *invitedText;

@property (weak, nonatomic) IBOutlet UILabel *locationLabel;
@property (weak, nonatomic) IBOutlet UILabel *peopleLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;


+ (DFCreateStrandTableViewCell *)cellWithStyle:(DFCreateStrandCellStyle)style;
- (void)configureWithStyle:(DFCreateStrandCellStyle)style;

@end
