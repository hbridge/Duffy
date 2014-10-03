//
//  DFCollectionTableViewCell.m
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCreateStrandTableViewCell.h"
#import "DFStrandConstants.h"
#import "DFPhotoViewCell.h"

@implementation DFCreateStrandTableViewCell

- (void)awakeFromNib
{
  [super awakeFromNib];
  
  
  self.selectionStyle = UITableViewCellSelectionStyleNone;
  self.solidBackgroundView.layer.cornerRadius = 4.0;
  self.solidBackgroundView.layer.masksToBounds = YES;
  self.countBadgeBackground.layer.cornerRadius = self.countBadgeBackground.frame.size.width/2.0;
  self.countBadgeBackground.layer.masksToBounds = YES;
  self.countBadgeBackground.layer.opacity = 0.9;
}

+ (DFCreateStrandTableViewCell *)cellWithStyle:(DFCreateStrandCellStyle)style
{
  DFCreateStrandTableViewCell *cell = [[[UINib nibWithNibName:[self description] bundle:nil] instantiateWithOwner:nil options:nil] firstObject];
  [cell configureWithStyle:style];
  return cell;
}

- (void)configureWithStyle:(DFCreateStrandCellStyle)style
{
  
  if (style == DFCreateStrandCellStyleInvite) {
    self.solidBackgroundView.backgroundColor = [DFStrandConstants inviteCellBackgroundColor];
  }
  
  if (style == DFCreateStrandCellStyleSuggestionNoPeople) {
    [self.peopleLabel removeFromSuperview];
    [self.peopleExplanationLabel removeFromSuperview];
    self.contextLabel.font = [self.contextLabel.font fontWithSize:14.0];
  }
  
  [self layoutSubviews];
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  if (self.objects.count == 1) return self.collectionView.frame.size;
  else if (self.objects.count == 2) {
    return CGSizeMake(self.collectionView.frame.size.width / 2.0,
                      self.collectionView.frame.size.height);
  } else {
    CGFloat spacing = self.flowLayout.minimumInteritemSpacing / 2.0;
    CGFloat largeImageWidth = self.collectionView.frame.size.height - spacing;
    if (indexPath.row == 0) {
      return CGSizeMake(largeImageWidth,
                        self.collectionView.frame.size.height);
    } else {
      return CGSizeMake(self.collectionView.frame.size.width - largeImageWidth - spacing,
                        self.collectionView.frame.size.height/2.0 - spacing);
    }
  }
  
  return CGSizeZero;
}

@end
