//
//  DFActivityFeedTableViewCell.h
//  Strand
//
//  Created by Henry Bridge on 9/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCollectionViewTableViewCell.h"
#import "Strand-Swift.h"

extern CGFloat const ActivityFeedTableViewCellHeight;
extern CGFloat const ActivityFeedTableViewCellNoCollectionViewHeight;
extern CGFloat const ActivtyFeedTableViewCellCollectionViewRowHeight;
extern CGFloat const ActivtyFeedTableViewCellCollectionViewRowSeparatorHeight;


@interface DFInboxTableViewCell : DFCollectionViewTableViewCell

@property (weak, nonatomic) IBOutlet UILabel *actorLabel;
@property (weak, nonatomic) IBOutlet UILabel *actionTextLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UICollectionViewFlowLayout *flowLayout;
@property (weak, nonatomic) IBOutlet UILabel *peopleLabel;


typedef NS_OPTIONS(NSInteger, DFInboxCellStyle) {
  DFInboxCellStyleInvite,
  DFInboxCellStyleStrand,
};

+ (DFInboxTableViewCell *)createWithStyle:(DFInboxCellStyle)style;
- (void)configureForInboxCellStyle:(DFInboxCellStyle)style;

@end
