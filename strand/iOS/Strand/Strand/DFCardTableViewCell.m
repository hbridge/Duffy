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
#import "DFImageManager.h"

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
    self.fixedItemSize = 78;
    self.maxPhotosToShow = 5;
  } else {
    self.maxPhotosToShow = LargeCardMaxPhotosPerCell;
  }
  
  if (style & DFCardCellStyleInvite) {
    self.solidBackgroundView.backgroundColor = [DFStrandConstants inviteCellBackgroundColor];
    [self.peoplePrefixLabel removeFromSuperview];
    self.badgeAccessoryImageView.image = [[UIImage imageNamed:@"Assets/Icons/InboxInviteBadge"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];;
    self.badgeAccessoryImageView.tintColor = [DFStrandConstants defaultBackgroundColor];
  }
  
  if (style & DFCardCellStyleShared) {
    [self.peoplePrefixLabel removeFromSuperview];
    [self.peopleSuffixLabel removeFromSuperview];
  }
  
  if (style & DFCardCellStyleSuggestionNoPeople) {
    [self.peopleLabel removeFromSuperview];
    [self.peoplePrefixLabel removeFromSuperview];
    self.contextLabel.font = [self.contextLabel.font fontWithSize:14.0];
    self.contextLabel.textColor = [UIColor darkGrayColor];
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
    [self setPhotosWithStrandPost:firstPost];
  } else if ([feedObject.type isEqual:DFFeedObjectSection]) {
    return [self setPhotosWithStrandPost:feedObject];
  } else if ([feedObject.type isEqual:DFFeedObjectInviteStrand]) {
    // Invite will always have only remote photos
    // Do same as strand posts and use only first post for now
    DFPeanutFeedObject *strandPosts = feedObject.objects.firstObject;
    DFPeanutFeedObject *firstPost = strandPosts.objects.firstObject;
    return [self setPhotosWithStrandPost:firstPost];
  }
}


- (void)setPhotosWithStrandPost:(DFPeanutFeedObject *)strandPost
{
  // Get the IDs of all the photos we want to show
  NSMutableArray *idsToShow = [NSMutableArray new];
  for (NSUInteger i = 0; i < MIN(self.maxPhotosToShow, strandPost.objects.count); i++) {
    DFPeanutFeedObject *object = strandPost.objects[i];
    DFPhotoIDType repPhotoID = 0;
    if ([object.type isEqual:DFFeedObjectPhoto]) {
      repPhotoID = object.id;
    } else if ([object.type isEqual:DFFeedObjectCluster]) {
      DFPeanutFeedObject *repObject = object.objects.firstObject;
      repPhotoID = repObject.id;
    }
    [idsToShow addObject:@(repPhotoID)];
  }
  self.objects = idsToShow;
  
  for (NSUInteger i = 0; i < self.objects.count; i++) {
    UICollectionViewLayoutAttributes *attributes =
    [self.collectionView layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:i inSection:0]];
    DFPhotoIDType photoID = [(NSNumber *)self.objects[i] longLongValue];
  
    DFCardTableViewCell __weak *weakSelf = self;
    [[DFImageManager sharedManager]
     imageForID:photoID
     size:attributes.size
     contentMode:DFImageRequestContentModeAspectFill
     deliveryMode:DFImageRequestOptionsDeliveryModeFastFormat
     completion:^(UIImage *image) {
       [weakSelf setImage:image forObject:@(photoID)];
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
  
  self.peopleLabel.attributedText = [strandPosts peopleSummaryString];
  
  // context label "Date in Location"
  NSMutableString *contextString = [NSMutableString new];
  [contextString appendString:[NSDateFormatter relativeTimeStringSinceDate:strandPosts.time_taken
                                                                abbreviate:NO]];
  
  if (strandPosts.location) {
    [contextString appendFormat:@" in %@", strandPosts.location];
  }
  
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
