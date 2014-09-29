//
//  DFActivityFeedTableViewCell.m
//  Strand
//
//  Created by Henry Bridge on 9/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFInboxTableViewCell.h"
#import "DFStrandConstants.h"
#import "DFLabelCollectionViewCell.h"

CGFloat const ActivityFeedTableViewCellNoCollectionViewHeight = 51;
CGFloat const ActivtyFeedTableViewCellCollectionViewRowHeight = 148;
CGFloat const ActivtyFeedTableViewCellCollectionViewRowSeparatorHeight = 8;
NSUInteger const InboxCellMaxPhotos = 6;


@implementation DFInboxTableViewCell


- (void)awakeFromNib
{
  [super awakeFromNib];
  self.collectionView.backgroundColor = [UIColor clearColor];
  [self.collectionView registerNib:[UINib nibWithNibName:NSStringFromClass([DFLabelCollectionViewCell class])
                                                  bundle:nil]
        forCellWithReuseIdentifier:@"labelCell"];
}

- (UIEdgeInsets)layoutMargins
{
  return UIEdgeInsetsZero;
}


- (void)configureForInboxCellStyle:(DFInboxCellStyle)style
{
  if (style == DFInboxCellStyleInvite) {
    self.contentView.backgroundColor = [DFStrandConstants inviteCellBackgroundColor];

  }
  if (style == DFInboxCellStyleStrand) {
    [self.actorLabel removeFromSuperview];
    [self.actionTextLabel removeFromSuperview];
  }
}

+ (DFInboxTableViewCell *)createWithStyle:(DFInboxCellStyle)style {
  DFInboxTableViewCell *cell = [[[UINib nibWithNibName:NSStringFromClass([self class])
                                                bundle:nil]
                                 instantiateWithOwner:nil options:nil]
                                firstObject];
  [cell configureForInboxCellStyle:style];
  return cell;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  if (indexPath.row < InboxCellMaxPhotos - 1 || self.objects.count <= InboxCellMaxPhotos)
    return [super collectionView:collectionView cellForItemAtIndexPath:indexPath];
  
  DFLabelCollectionViewCell *cell = [self.collectionView
                                     dequeueReusableCellWithReuseIdentifier:@"labelCell"
                                     forIndexPath:indexPath];
  cell.abbreviationSquare.elementAbbreviation = [NSString stringWithFormat:@"+%d", (int)(self.objects.count - InboxCellMaxPhotos)];
  cell.abbreviationSquare.displayMode = OFElementSquareDisplayAbbreviation;
  return cell;
}

@end
