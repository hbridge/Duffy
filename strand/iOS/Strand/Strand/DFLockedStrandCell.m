//
//  DFLockedStrandCell.m
//  Strand
//
//  Created by Henry Bridge on 7/23/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFLockedStrandCell.h"
#import "DFPhotoViewCell.h"
#import <LiveFrost/LiveFrost.h>

@interface DFLockedStrandCell()

@property (atomic, retain) NSMutableDictionary *imagesForObjects;

@end

@implementation DFLockedStrandCell

- (void)awakeFromNib
{
  self.collectionView.backgroundColor = [UIColor clearColor];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
  [super setSelected:selected animated:animated];
  
  // Configure the view for the selected state
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{

  DFPhotoViewCell *cell = (DFPhotoViewCell *)[super collectionView:collectionView
                                            cellForItemAtIndexPath:indexPath];
  BOOL hasBlurView = NO;
  for (UIView *view in cell.subviews) {
    if ([view.class isSubclassOfClass:[LFGlassView class]]) {
      hasBlurView = YES;
      break;
    }
  }
  
  if (!hasBlurView) {
    LFGlassView *glassView = [[LFGlassView alloc] initWithFrame:cell.bounds];
    glassView.liveBlurring = NO;
    glassView.blurRadius = 1;
    [cell addSubview:glassView];
    dispatch_async(dispatch_get_main_queue(), ^{
      [glassView blurOnceIfPossible];
    });
  }
  
  return cell;
}


@end
