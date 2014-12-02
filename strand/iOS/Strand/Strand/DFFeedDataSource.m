//
//  DFFeedDataSource.m
//  Strand
//
//  Created by Henry Bridge on 11/19/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFFeedDataSource.h"
#import "DFPeanutFeedObject.h"
#import "DFPeanutUserObject.h"
#import "DFFeedSectionHeaderView.h"
#import "DFPhotoFeedImageCell.h"
#import "DFImageManager.h"
#import "DFPeanutFeedDataManager.h"
#import "DFCollectionViewTableViewCell.h"
#import "DFPhotoFeedActionCell.h"
#import "DFPhotoFeedFooterCell.h"

@interface DFFeedDataSource()

@property (readonly, nonatomic, retain) NSDictionary *photoIndexPathsById;
@property (readonly, nonatomic, retain) NSDictionary *photoObjectsById;
@property (readonly, nonatomic, retain) NSMutableDictionary *rowHeights;
@property (nonatomic, retain) DFPhotoFeedActionCell *actionTemplateCell;

@end

@implementation DFFeedDataSource

static int ImagePrefetchRange = 3;


- (instancetype)init
{
  self = [super init];
  if (self) {
    _rowHeights = [NSMutableDictionary new];
    _actionTemplateCell = [UINib instantiateViewWithClass:[DFPhotoFeedActionCell class]];
  }
  return self;
}


- (void)setTableView:(UITableView *)tableView
{
  _tableView = tableView;
  tableView.dataSource = self;
  tableView.delegate = self;
  tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  
  [self.tableView
   registerNib:[UINib nibForClass:[DFFeedSectionHeaderView class]]
   forHeaderFooterViewReuseIdentifier:@"header"];
  [self.tableView
   registerNib:[UINib nibForClass:[DFPhotoFeedImageCell class]]
   forCellReuseIdentifier:@"imageCell"];
  [self.tableView
   registerNib:[UINib nibForClass:[DFCollectionViewTableViewCell class]]
   forCellReuseIdentifier:@"selectorCell"];
  [self.tableView
   registerNib:[UINib nibForClass:[DFPhotoFeedActionCell class]]
   forCellReuseIdentifier:@"actionCell"];
  [self.tableView
   registerNib:[UINib nibForClass:[DFPhotoFeedFooterCell class]]
   forCellReuseIdentifier:@"footer"];

  
  [self.tableView reloadData];
}


- (void)setPhotosAndClusters:(NSArray *)photosAndClusters
{
  _photosAndClusters = photosAndClusters;
  _rowHeights = [NSMutableDictionary new];
  
  NSMutableDictionary *objectsByID = [NSMutableDictionary new];
  NSMutableDictionary *indexPathsByID = [NSMutableDictionary new];
  
  for (NSUInteger sectionIndex = 0; sectionIndex < photosAndClusters.count; sectionIndex++) {
    DFPeanutFeedObject *object = photosAndClusters[sectionIndex];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:sectionIndex];
    if ([object.type isEqual:DFFeedObjectPhoto]) {
      objectsByID[@(object.id)] = object;
      indexPathsByID[@(object.id)] = indexPath;
    } else if ([object.type isEqual:DFFeedObjectCluster]) {
      for (DFPeanutFeedObject *subObject in object.objects) {
        objectsByID[@(subObject.id)] = subObject;
        indexPathsByID[@(subObject.id)] = indexPath;
      }
    }
  }
  
  _photoObjectsById = objectsByID;
  _photoIndexPathsById = indexPathsByID;
  [self.tableView reloadData];
}


- (NSIndexPath *)indexPathForPhotoID:(DFPhotoIDType)photoID
{
  return self.photoIndexPathsById[@(photoID)];
}

- (DFPeanutFeedObject *)objectAtIndexPath:(NSIndexPath *)indexPath
{
  return self.photosAndClusters[indexPath.section];
}

- (DFPeanutFeedObject *)photoWithID:(DFPhotoIDType)photoID
{
  return self.photoObjectsById[@(photoID)];
}

- (void)reloadRowForPhotoID:(DFPhotoIDType)photoID
{
  NSIndexPath *photoIndexPath = [self indexPathForPhotoID:photoID];
  for (NSInteger i = 0; i < [self tableView:self.tableView numberOfRowsInSection:photoIndexPath.section]; i++) {
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:photoIndexPath.section];
    [self.rowHeights removeObjectForKey:[indexPath dictKey]];
  }

  [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:photoIndexPath.section]
                withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)removePhoto:(DFPeanutFeedObject *)photoObject
{
  dispatch_async(dispatch_get_main_queue(), ^{
    NSIndexPath *indexPath = [self indexPathForPhotoID:photoObject.id];
    DFPeanutFeedObject *objectInStrand = self.photosAndClusters[indexPath.section];
    if ([objectInStrand.type isEqual:DFFeedObjectCluster]) {
      // the object is in a cluster row
      NSMutableArray *newObjects = objectInStrand.objects.mutableCopy;
      [newObjects removeObject:photoObject];
      objectInStrand.objects = newObjects;
      [self.tableView reloadData];
    } else {
      NSMutableArray *newPhotos = self.photosAndClusters.mutableCopy;
      [newPhotos removeObject:objectInStrand];
      self.photosAndClusters = newPhotos;
    }
  });
}

#pragma mark - UITableViewDatasource Header

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return self.photosAndClusters.count;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
  DFFeedSectionHeaderView *headerView =
  [self.tableView dequeueReusableHeaderFooterViewWithIdentifier:@"header"];
  
  DFPeanutFeedObject *object = [self feedObjectForSection:section];
  DFPeanutUserObject *user = [[DFPeanutFeedDataManager sharedManager] userWithID:object.user];
  headerView.actorLabel.text = [user fullName];
  headerView.profilePhotoStackView.peanutUser = user;
  
  headerView.representativeObject = object;
  
  return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
  return [DFFeedSectionHeaderView height];
}

#pragma mark - UITableViewDatasource Cell

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  DFPeanutFeedObject *feedObject = [self feedObjectForSection:section];
  NSUInteger numRows = 2; // every photo has an image and an action bar
  if ([feedObject.type isEqual:DFFeedObjectCluster]) numRows++;
  if ([[feedObject actionsOfType:DFPeanutActionFavorite forUser:0] count] > 0) numRows++;
  numRows += [[feedObject actionsOfType:DFPeanutActionComment forUser:0] count];
  
  return numRows;
}

- (DFPeanutFeedObject *)feedObjectForSection:(NSUInteger)tableSection
{
  return self.photosAndClusters[tableSection];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell = nil;
  
  DFPeanutFeedObject *object = [self feedObjectForSection:indexPath.section];
  Class cellClass = [self classOfCellForObject:object indexPath:indexPath];
  
  if (cellClass == [DFPhotoFeedImageCell class]) {
    cell = [self imageCellForObject:object];
  } else if (cellClass == [DFCollectionViewTableViewCell class]) {
    cell = [self photoSelectorCellForObject:object indexPath:indexPath];
  } else if (cellClass == [DFPhotoFeedActionCell class]) {
    cell = [self actionCellForObject:object indexPath:indexPath];
  } else if (cellClass == [DFPhotoFeedFooterCell class]) {
    cell = [self footerForObject:object indexPath:indexPath];
  }
  
  if (!cell) {
    [NSException raise:@"nil cell" format:@"nil cell for object: %@", object];
  }
  
  cell.selectionStyle = UITableViewCellSelectionStyleNone;
  [cell setNeedsLayout];
  
  [self prefetchImagesAroundIndexPath:indexPath];
  return cell;
}

- (Class)classOfCellForObject:(DFPeanutFeedObject *)object indexPath:(NSIndexPath *)indexPath
{
  if (indexPath.row == 0) {
    return [DFPhotoFeedImageCell class];
  }
  if ([object.type isEqual:DFFeedObjectCluster] && indexPath.row == 1) {
    return [DFCollectionViewTableViewCell class];
  }
  if (indexPath.row == [self tableView:self.tableView numberOfRowsInSection:indexPath.section] - 1) {
    return [DFPhotoFeedFooterCell class];
  }
  
  return [DFPhotoFeedActionCell class];
}

#pragma mark - Image Cells

- (DFPhotoFeedImageCell *)imageCellForObject:(DFPeanutFeedObject *)object
{
  DFPhotoFeedImageCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"imageCell"];
  DFPeanutFeedObject *photoObject = [[object leafNodesFromObjectOfType:DFFeedObjectPhoto] firstObject];
  DFFeedDataSource __weak *weakSelf = self;
  cell.doubleTapBlock = ^{
    [weakSelf.delegate feedDataSource:self likeButtonPressedForPhoto:photoObject];
  };
  [self setPhoto:photoObject.id forImageCell:cell];
  
  return cell;
}

- (void)setPhoto:(DFPhotoIDType)photoID forImageCell:(DFPhotoFeedImageCell *)cell
{
  
  [[DFImageManager sharedManager]
   imageForID:photoID
   size:[self imageSizeToFetch]
   contentMode:DFImageRequestContentModeAspectFit
   deliveryMode:DFImageRequestOptionsDeliveryModeOpportunistic
   completion:^(UIImage *image) {
     dispatch_async(dispatch_get_main_queue(), ^{
       if (![self.tableView.visibleCells containsObject:cell]) return;
       cell.photoImageView.image = image;
       [cell setNeedsLayout];
     });
   }];

}

- (DFPhotoFeedImageCellAspect)aspectForIndexPath:(NSIndexPath *)indexPath
{
  DFPhotoFeedImageCellAspect aspect = DFPhotoFeedImageCellAspectSquare;
  DFPeanutFeedObject *object = [self feedObjectForSection:indexPath.section];
  DFPeanutFeedObject *photoObject = object;
  if (photoObject.full_height.intValue > photoObject.full_width.intValue) {
    aspect = DFPhotoFeedImageCellAspectPortrait;
  } else if (photoObject.full_height.intValue < photoObject.full_width.intValue) {
    aspect = DFPhotoFeedImageCellAspectLandscape;
  } else {
    aspect = DFPhotoFeedImageCellAspectSquare;
  }
  return aspect;
}

- (CGSize)imageSizeToFetch
{
  CGFloat imageViewHeight = [DFPhotoFeedImageCell
                             imageViewHeightForReferenceWidth:[[UIScreen mainScreen] bounds].size.width
                             aspect:DFPhotoFeedImageCellAspectPortrait];
  CGFloat scale = [[UIScreen mainScreen] scale];
  return CGSizeMake(imageViewHeight * scale, imageViewHeight * scale);
}

#pragma mark - Selector Cells

- (DFCollectionViewTableViewCell *)photoSelectorCellForObject:(DFPeanutFeedObject *)feedObject
                                                    indexPath:(NSIndexPath *)indexPath
{
  DFCollectionViewTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"selectorCell"];
  cell.flowLayout.itemSize = CGSizeMake(78, 78);
  cell.flowLayout.minimumInteritemSpacing = 0.5;
  cell.flowLayout.minimumLineSpacing = 0.5;
  cell.collectionView.delegate = self;
  cell.collectionView.bounces = YES;
  cell.collectionView.alwaysBounceHorizontal = YES;
  cell.flowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
  cell.objects = [feedObject.objects arrayByMappingObjectsWithBlock:^id(DFPeanutFeedObject *photo) {
    return @(photo.id);
  }];
  for (DFPeanutFeedObject *photo in feedObject.objects) {
    [[DFImageManager sharedManager]
     imageForID:photo.id pointSize:CGSizeMake(78, 78)
     contentMode:DFImageRequestContentModeAspectFill
     deliveryMode:DFImageRequestOptionsDeliveryModeFastFormat
     completion:^(UIImage *image) {
       [cell setImage:image forObject:@(photo.id)];
     }];
    [cell setObject:@(photo.id) tappedHandler:^(id tappedObject) {
      [self setSelectedPhoto:photo.id forClusterInSection:indexPath.section];
    }];
  }
  return cell;
}

- (void)setSelectedPhoto:(DFPhotoIDType)photoID forClusterInSection:(NSInteger)section
{
  DFPhotoFeedImageCell *imageCell = (DFPhotoFeedImageCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath
                                                                           indexPathForRow:0
                                                                           inSection:section]];
  [self setPhoto:photoID forImageCell:imageCell];
}

#pragma mark - Action Cell

- (DFPhotoFeedActionCell *)actionCellForObject:(DFPeanutFeedObject *)object indexPath:(NSIndexPath *)indexPath
{
  DFPhotoFeedActionCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"actionCell"];
  [self configureActionCell:cell forObject:object indexPath:indexPath];
  
  return cell;
}

- (void)configureActionCell:(DFPhotoFeedActionCell *)cell
                  forObject:(DFPeanutFeedObject *)object
                  indexPath:(NSIndexPath *)indexPath
{
  NSInteger actionIndex = indexPath.row - 1 - ([[object type] isEqual:DFFeedObjectCluster]);
  NSArray *likes = [object actionsOfType:DFPeanutActionFavorite forUser:0];
  if (actionIndex == 0 && [likes count] > 0) {
    cell.iconImageView.hidden = NO;
    [cell setLikes:likes];
  } else {
    NSInteger commentIndex = actionIndex - ([likes count] > 0);
    cell.iconImageView.hidden = (commentIndex != 0);
    DFPeanutAction *comment = [[object actionsOfType:DFPeanutActionComment forUser:0]
                               objectAtIndex:commentIndex];
    [cell setComment:comment];
  }
}


#pragma mark - Row Height

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSNumber *cachedHeight = self.rowHeights[[indexPath dictKey]];
  if (cachedHeight) return cachedHeight.floatValue;
  
  CGFloat height = 0.0;
  DFPeanutFeedObject *object = [self feedObjectForSection:indexPath.section];
  Class cellClass = [self classOfCellForObject:object indexPath:indexPath];
  if (cellClass == [DFPhotoFeedImageCell class]) {
    DFPhotoFeedImageCellAspect aspect = [self aspectForIndexPath:indexPath];
    height = [DFPhotoFeedImageCell imageViewHeightForReferenceWidth:self.tableView.frame.size.width
                                                           aspect:aspect];
  } else if (cellClass == [DFCollectionViewTableViewCell class]) {
    height = 78 + 2 + 2;
  } else if (cellClass == [DFPhotoFeedActionCell class]) {
    CGRect frame = self.actionTemplateCell.frame;
    frame.size.width = self.tableView.frame.size.width;
    self.actionTemplateCell.frame = frame;
    [self configureActionCell:self.actionTemplateCell forObject:object indexPath:indexPath];
    height = [self.actionTemplateCell rowHeight];
  } else if (cellClass == [DFPhotoFeedFooterCell class]) {
    return [DFPhotoFeedFooterCell height];
  }
  
  return height;
}


- (void)setHeight:(CGFloat)height forRowAtIndexPath:(NSIndexPath *)indexPath
{
  self.rowHeights[[indexPath dictKey]] = @(height);
}


#pragma mark - Action Footer

- (DFPhotoFeedFooterCell *)footerForObject:(DFPeanutFeedObject *)feedObject indexPath:(NSIndexPath *)indexPath
{
  DFPhotoFeedFooterCell *footer = [self.tableView dequeueReusableCellWithIdentifier:@"footer"];
  DFFeedDataSource __weak *weakSelf = self;
  
  DFPeanutAction *likeAction = [feedObject userFavoriteAction];
  [footer setLiked:(likeAction != nil)];
  footer.likeBlock = ^{
    [weakSelf.delegate feedDataSource:weakSelf likeButtonPressedForPhoto:feedObject];
  };
  footer.commentBlock = ^{
    [weakSelf.delegate feedDataSource:weakSelf commentButtonPressedForPhoto:feedObject];
  };
  footer.moreBlock = ^{
    [weakSelf.delegate feedDataSource:weakSelf moreButtonPressedForPhoto:feedObject];
  };
  return footer;
}

#pragma mark - Prefetching

- (void)prefetchImagesAroundIndexPath:(NSIndexPath *)indexPath
{
  NSMutableArray *idsToFetch = [NSMutableArray new];
  for (NSInteger i = indexPath.section + ImagePrefetchRange; i >= indexPath.section - ImagePrefetchRange; i--){
    if (i < 0 || i >= [self numberOfSectionsInTableView:self.tableView]) continue;
    DFPeanutFeedObject *object = [self feedObjectForSection:i];
    if (!object) continue;
    if ([object.type isEqual:DFFeedObjectCluster]) object = object.objects.firstObject;
    [idsToFetch addObject:@(object.id)];
  }
  
  [[DFImageManager sharedManager] startCachingImagesForPhotoIDs:idsToFetch
                                                     targetSize:[self imageSizeToFetch]
                                                    contentMode:DFImageRequestContentModeAspectFit];
}


@end
