//
//  DFCollectionTableViewCell.m
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCardTableViewCell.h"

#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "UIDevice+DFHelpers.h"

#import "DFPeanutFeedObject.h"
#import "DFPeanutUserObject.h"
#import "DFPhotoStore.h"
#import "DFPhotoViewCell.h"
#import "DFStrandConstants.h"
#import "DFImageStore.h"

const NSUInteger LargeCardMaxPhotosPerCell = 3;


@interface DFCardTableViewCell()

@property (nonatomic) CGFloat fixedItemSize;

@end

@implementation DFCardTableViewCell

- (void)awakeFromNib
{
  [super awakeFromNib];
  
  
  self.selectionStyle = UITableViewCellSelectionStyleNone;
  self.solidBackgroundView.layer.cornerRadius = 4.0;
  self.solidBackgroundView.layer.masksToBounds = YES;
}

+ (DFCardTableViewCell *)cellWithStyle:(DFCardCellStyle)style
{
  DFCardTableViewCell *cell;
  if (style & DFCardCellStyleSmall) {
    cell = [[[UINib nibWithNibName:@"DFSmallCardTableViewCell" bundle:nil]
             instantiateWithOwner:nil
             options:nil] firstObject];
  } else {
    cell = [[[UINib nibWithNibName:@"DFCardTableViewCell" bundle:nil]
                                       instantiateWithOwner:nil
                                       options:nil] firstObject];
  }
  
  [cell configureWithStyle:style];
  return cell;
}

- (void)configureWithStyle:(DFCardCellStyle)style
{
  if (style & DFCardCellStyleSmall) {
    self.fixedItemSize = 157/2.0;
    self.maxPhotosToShow = 5;
  } else {
    self.maxPhotosToShow = LargeCardMaxPhotosPerCell;
  }
  
  if (style & DFCardCellStyleInvite) {
    self.solidBackgroundView.backgroundColor = [DFStrandConstants inviteCellBackgroundColor];
    [self.peoplePrefixLabel removeFromSuperview];
  }
  
  if (style & DFCardCellStyleSuggestionNoPeople) {
    [self.peopleLabel removeFromSuperview];
    [self.peoplePrefixLabel removeFromSuperview];
    self.contextLabel.font = [self.contextLabel.font fontWithSize:14.0];
  }
  
  if (style & (DFCardCellStyleSuggestionNoPeople | DFCardCellStyleSuggestionWithPeople)) {
    [self.peopleSuffixLabel removeFromSuperview];
  }
  
  [self layoutSubviews];
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  if (self.fixedItemSize > 0.0) {
    return CGSizeMake(self.fixedItemSize, self.fixedItemSize);
  }
  
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
 *
 * TODO(Derek): This can get cleaned up once we know what we want.
 * TODO(Derek): Support strands that have multiple people and first post might not have 3 photos
 */
- (void)configureWithFeedObject:(DFPeanutFeedObject *)feedObject
{
  [self configureTextWithFeedObject:feedObject];
  

  if ([feedObject.type isEqual:DFFeedObjectStrandPosts]) {
    DFPeanutFeedObject *firstPost = feedObject.objects.firstObject;
    DFPeanutUserObject *user = firstPost.actors[0];
    
    if (user.id == [[DFUser currentUser] userID]) {
      return [self setLocalPhotosWithStrandPost:firstPost];
    } else {
      return [self setRemotePhotosWithStrandPost:firstPost];
    }
  } else if ([feedObject.type isEqual:DFFeedObjectSection]) {
    return [self setLocalPhotosWithStrandPost:feedObject];
  } else if ([feedObject.type isEqual:DFFeedObjectInviteStrand]) {
    // Invite will always have only remote photos
    // Do same as strand posts and use only first post for now
    DFPeanutFeedObject *strandPosts = feedObject.objects.firstObject;
    DFPeanutFeedObject *firstPost = strandPosts.objects.firstObject;
    return [self setRemotePhotosWithStrandPost:firstPost];
  }
}

- (void)setLocalPhotosWithStrandPost:(DFPeanutFeedObject *)strandPost
{
  // Get the IDs of all the photos we want to show
  NSMutableArray *idsToShow = [NSMutableArray new];
  for (NSUInteger i = 0; i < MIN(self.maxPhotosToShow, strandPost.objects.count); i++) {
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

- (void)configureTextWithFeedObject:(DFPeanutFeedObject *)feedObject
{
  DFPeanutFeedObject *strandPosts;
  
  // Bit hacky for now, grab the strand_posts out of the invite
  if ([feedObject.type isEqual:DFFeedObjectInviteStrand]) {
    // This is the strand posts
    strandPosts = feedObject.objects.firstObject;
  } else if ([feedObject.type isEqual:DFFeedObjectStrandPosts] || [feedObject.type isEqual:DFFeedObjectSection]) {
    strandPosts = feedObject;
  }
  
  // Set the header attributes
  NSMutableString *actorString = [NSMutableString new];
  for (DFPeanutUserObject *user in strandPosts.actors) {
    if (user != strandPosts.actors.firstObject) [actorString appendString:@", "];
    [actorString appendString:user.display_name];
  }
  
  self.peopleLabel.text = actorString;
  
  // context label "Date in Location"
  NSMutableString *contextString = [NSMutableString new];
  [contextString appendString:[NSDateFormatter relativeTimeStringSinceDate:strandPosts.time_taken
                                                                abbreviate:NO]];
  [contextString appendFormat:@" in %@", strandPosts.location];
  self.contextLabel.text = contextString;
  
  // Bit of a hack.  Sections are private so we go with default text of "Swap with"
  //   But Strand Posts are public so change wording
  if ([feedObject.type isEqual:DFFeedObjectStrandPosts]) {
    self.peoplePrefixLabel.text = @"";
  } else if ([feedObject.type isEqual:DFFeedObjectInviteStrand]) {
    self.peopleSuffixLabel.text = @"sent you photos";
  } else if ([feedObject.type isEqual:DFFeedObjectSection]) {
    self.peoplePrefixLabel.text = @"Swap with";
  }
  
  NSInteger count = strandPosts.objects.count - self.maxPhotosToShow;
  if (count > 0) {
    self.countBadge.hidden = NO;
    self.countBadge.text = [NSString stringWithFormat:@"+%d", (int)count];
  } else {
    self.countBadge.hidden = YES;
  }
}



@end
