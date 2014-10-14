//
//  DFCollectionTableViewCell.m
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFLargeCardTableViewCell.h"

#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "UIDevice+DFHelpers.h"

#import "DFPeanutFeedObject.h"
#import "DFPeanutUserObject.h"
#import "DFPhotoStore.h"
#import "DFPhotoViewCell.h"
#import "DFStrandConstants.h"
#import "DFImageStore.h"

@implementation DFLargeCardTableViewCell

- (void)awakeFromNib
{
  [super awakeFromNib];
  
  
  self.selectionStyle = UITableViewCellSelectionStyleNone;
  self.solidBackgroundView.layer.cornerRadius = 4.0;
  self.solidBackgroundView.layer.masksToBounds = YES;
}

+ (DFLargeCardTableViewCell *)cellWithStyle:(DFCreateStrandCellStyle)style
{
  DFLargeCardTableViewCell *cell = [[[UINib nibWithNibName:[self description] bundle:nil] instantiateWithOwner:nil options:nil] firstObject];
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


/*
 * Set the photos for this cell.  Right now only look at the photos in the first strand post
 * Strand posts have both public and private content, so must figure that out.
 * Sections only have private photos, so just do local
 */
- (void)configureWithFeedObject:(DFPeanutFeedObject *)feedObject
{
  [self configureTextWithStrand:feedObject];
  if ([feedObject.type isEqual:DFFeedObjectStrandPosts]) {
    DFPeanutUserObject *user = feedObject.actors[0];
    DFPeanutFeedObject *firstPost = feedObject.objects.firstObject;
    
    if (user.id == [[DFUser currentUser] userID]) {
      return [self setLocalPhotosWithStrandPost:firstPost];
    } else {
      return [self setRemotePhotosWithStrandPost:firstPost];
    }
  } else if ([feedObject.type isEqual:DFFeedObjectSection]) {
    return [self setLocalPhotosWithStrandPost:feedObject];
  }
}


const NSUInteger LargeCardMaxPhotosPerCell = 3;

- (void)setLocalPhotosWithStrandPost:(DFPeanutFeedObject *)strandPost
{
  // Get the IDs of all the photos we want to show
  NSMutableArray *idsToShow = [NSMutableArray new];
  for (NSUInteger i = 0; i < MIN(LargeCardMaxPhotosPerCell, strandPost.objects.count); i++) {
    DFPeanutFeedObject *object = strandPost.objects[i];
    if ([object.type isEqual:DFFeedObjectPhoto]) {
      [idsToShow addObject:@(object.id)];
      
    } else if ([object.type isEqual:DFFeedObjectCluster]) {
      DFPeanutFeedObject *repObject = object.objects.firstObject;
      [idsToShow addObject:@(repObject.id)];
    }
  }
  
  // Set the images for the collection view
  self.objects = idsToShow;
  for (NSNumber *photoID in idsToShow) {
    DFPhoto *photo = [[DFPhotoStore sharedStore] photoWithPhotoID:photoID.longLongValue];
    if (photo) {
      CGFloat thumbnailSize;
      if ([UIDevice majorVersionNumber] >= 8) {
        // only use the larger thumbnails on iOS 8+, the scaling will kill perf on iOS7
        thumbnailSize = self.collectionView.frame.size.height * [[UIScreen mainScreen] scale];
      } else {
        thumbnailSize = DFPhotoAssetDefaultThumbnailSize;
      }
      [photo.asset
       loadUIImageForThumbnailOfSize:thumbnailSize
       successBlock:^(UIImage *image) {
         [self setImage:image forObject:photoID];
       } failureBlock:^(NSError *error) {
         DDLogError(@"%@ couldn't load image for asset: %@", self.class, error);
       }];
    }
  }
}


- (void)setRemotePhotosWithStrandPost:(DFPeanutFeedObject *)strandPost
{
  NSMutableArray *photoIDs = [NSMutableArray new];
  NSMutableArray *photos = [NSMutableArray new];
  
  for (DFPeanutFeedObject *object in strandPost.objects) {
    DFPeanutFeedObject *photoObject;
    if ([object.type isEqual:DFFeedObjectCluster]) {
      photoObject = object.objects.firstObject;
    } else if ([object.type isEqual:DFFeedObjectPhoto]) {
      photoObject = object;
    }
    if (photoObject) {
      [photoIDs addObject:@(photoObject.id)];
      [photos addObject:photoObject];
    }
  }
  
  self.objects = photoIDs;
  for (DFPeanutFeedObject *photoObject in photos) {
    [[DFImageStore sharedStore]
     imageForID:photoObject.id
     preferredType:DFImageThumbnail
     thumbnailPath:photoObject.thumb_image_path
     fullPath:photoObject.full_image_path
     completion:^(UIImage *image) {
       [self setImage:image forObject:@(photoObject.id)];
     }];
  }
}

- (void)configureTextWithStrand:(DFPeanutFeedObject *)strandObject
{
  // Set the header attributes
  NSMutableString *actorString = [NSMutableString new];
  for (DFPeanutUserObject *user in strandObject.actors) {
    if (user != strandObject.actors.firstObject) [actorString appendString:@", "];
    [actorString appendString:user.display_name];
  }
  
  self.peopleLabel.text = actorString;
  
  // context label "Date in Location"
  NSMutableString *contextString = [NSMutableString new];
  [contextString appendString:[NSDateFormatter relativeTimeStringSinceDate:strandObject.time_taken
                                                                abbreviate:NO]];
  [contextString appendFormat:@" in %@", strandObject.location];
  self.contextLabel.text = contextString;
  
  // Bit of a hack.  Sections are private so we go with default text of "Swap with"
  //   But Strand Posts are public so change wording
  if ([strandObject.type isEqual:DFFeedObjectStrandPosts]) {
    self.peopleExplanationLabel.text = @"Swapped with";
  }
  
  NSInteger count = strandObject.objects.count - LargeCardMaxPhotosPerCell;
  if (count > 0) {
    self.countBadge.hidden = NO;
    self.countBadge.text = [NSString stringWithFormat:@"+%d", (int)count];
  } else {
    self.countBadge.hidden = YES;
  }
}



@end
