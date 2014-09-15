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

@interface DFActivityFeedTableViewCell : DFCollectionViewTableViewCell

@property (weak, nonatomic) IBOutlet DFProfilePhotoStackView *profilePhotoStackView;
@property (weak, nonatomic) IBOutlet UILabel *actorLabel;
@property (weak, nonatomic) IBOutlet UILabel *actionTextLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (weak, nonatomic) IBOutlet UIImageView *previewImageView;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;

@end
