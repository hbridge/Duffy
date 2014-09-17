//
//  DFPhotoFeedController.m
//  Strand
//
//  Created by Henry Bridge on 7/4/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFFeedViewController.h"
#import "DFAnalytics.h"
#import "DFDefaultsStore.h"
#import "DFFeedSectionHeaderView.h"
#import "DFImageStore.h"
#import "DFLockedStrandCell.h"
#import "DFNavigationController.h"
#import "DFNotificationSharedConstants.h"
#import "DFPeanutActionAdapter.h"
#import "DFPeanutPhoto.h"
#import "DFPeanutFeedObject.h"
#import "DFPhotoFeedCell.h"
#import "DFPhotoMetadataAdapter.h"
#import "DFPhotoStore.h"
#import "DFStrandConstants.h"
#import "DFUploadController.h"
#import "DFUploadingFeedCell.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "NSString+DFHelpers.h"
#import "RootViewController.h"
#import "UIAlertView+DFHelpers.h"
#import "DFInviteStrandViewController.h"

// Uploading cell
const CGFloat UploadingCellVerticalMargin = 10.0;
const CGFloat UploadingCellTitleArea = 21 + 8;
const CGFloat UploadingCellImageRowHeight = 45.0;
const CGFloat UploadingCellImageRowSpacing = 6.0;
const int UploadingCellImagesPerRow = 6;
// Section Header
const CGFloat SectionHeaderHeight = 48.0;
// constants used for row height calculations
const CGFloat TitleAreaHeight = 32; // height plus spacing around
const CGFloat ImageViewHeight = 320; // height plus spacing around
const CGFloat CollectionViewHeight = 79;
const CGFloat FavoritersListHeight = 17 + 8; //height + spacing to collection view or image view
const CGFloat ActionBarHeight = 29 + 8; // height + spacing
const CGFloat FooterPadding = 2;
const CGFloat MinRowHeight = TitleAreaHeight + ImageViewHeight + ActionBarHeight + FavoritersListHeight + FooterPadding;

const CGFloat LockedCellHeight = 157.0;

@interface DFFeedViewController ()

@property (readonly, nonatomic, retain) DFPhotoMetadataAdapter *photoAdapter;

@property (nonatomic) DFPhotoIDType actionSheetPhotoID;
@property (nonatomic) DFPhotoIDType requestedPhotoIDToJumpTo;

@property (nonatomic) CGFloat previousScrollViewYOffset;
@property (nonatomic) BOOL isViewTransitioning;

@property (readonly, nonatomic, retain) NSDictionary *photoIndexPathsById;
@property (readonly, nonatomic, retain) NSDictionary *photoObjectsById;

@end

@implementation DFFeedViewController

@synthesize photoAdapter = _photoAdapter;

- (instancetype)init
{
  self = [super init];
  if (self) {
    [self initTabBarItem];
  }
  return self;
}

- (void)initTabBarItem
{
  self.tabBarItem.selectedImage = [[UIImage imageNamed:@"Assets/Icons/FeedBarButton"]
                                   imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  self.tabBarItem.image = [[UIImage imageNamed:@"Assets/Icons/FeedBarButton"]
                           imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  self.tableView.contentInset = UIEdgeInsetsMake(0, 0, self.tabBarController.tabBar.frame.size.height * 2.0, 0);
  self.tableView.scrollsToTop = YES;
  
  [self.tableView registerNib:[UINib nibWithNibName:@"DFPhotoFeedCell" bundle:nil]
       forCellReuseIdentifier:@"photoCell"];
  [self.tableView registerNib:[UINib nibWithNibName:@"DFPhotoFeedCell" bundle:nil]
       forCellReuseIdentifier:@"clusterCell"];
  [self.tableView registerNib:[UINib nibWithNibName:@"DFLockedStrandCell" bundle:nil]
       forCellReuseIdentifier:@"lockedCell"];
  [self.tableView registerNib:[UINib nibWithNibName:@"DFUploadingFeedCell" bundle:nil]
       forCellReuseIdentifier:@"uploadingCell"];
  
  [self.tableView
   registerNib:[UINib nibWithNibName:@"DFFeedSectionHeaderView"
                              bundle:nil]
   forHeaderFooterViewReuseIdentifier:@"sectionHeader"];
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  self.tableView.rowHeight = MinRowHeight;

}

- (void)viewWillAppear:(BOOL)animated
{
  self.isViewTransitioning = YES;
  [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
  self.isViewTransitioning = NO;
  [super viewDidAppear:animated];
  [[NSNotificationCenter defaultCenter] postNotificationName:DFStrandGalleryAppearedNotificationName
                                                      object:self
                                                    userInfo:nil];
  
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
  self.isViewTransitioning = YES;
  [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
  self.isViewTransitioning = NO;
  [super viewDidDisappear:animated];
}

- (void)setStrandObjects:(NSArray *)strandObjects
{
  dispatch_async(dispatch_get_main_queue(), ^{
    NSMutableDictionary *objectsByID = [NSMutableDictionary new];
    NSMutableDictionary *indexPathsByID = [NSMutableDictionary new];
    
    for (NSUInteger sectionIndex = 0; sectionIndex < strandObjects.count; sectionIndex++) {
      NSArray *objectsForSection = [strandObjects[sectionIndex] objects];
      for (NSUInteger objectIndex = 0; objectIndex < objectsForSection.count; objectIndex++) {
        DFPeanutFeedObject *object = objectsForSection[objectIndex];
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:objectIndex inSection:sectionIndex];
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
    }
    
    _photoObjectsById = objectsByID;
    _photoIndexPathsById = indexPathsByID;
    _strandObjects = strandObjects;
    
    [self.tableView reloadData];
  });
}


#pragma mark - Jump to a specific photo

- (void)showPhoto:(DFPhotoIDType)photoId animated:(BOOL)animated
{
  dispatch_async(dispatch_get_main_queue(), ^{
    NSIndexPath *indexPath = self.photoIndexPathsById[@(photoId)];
   
    if (indexPath) {
      if ([[self sectionObjectForTableSection:indexPath.section] isLockedSection]) {
        indexPath = [NSIndexPath indexPathForRow:0 inSection:indexPath.section];
      }
      
      // set isViewTransitioning to prevent the nav bar from disappearing from the scroll
      self.isViewTransitioning = YES;
      [self.tableView scrollToRowAtIndexPath:indexPath
                            atScrollPosition:UITableViewScrollPositionTop
                                    animated:animated];
      
      // this tweak is gross but makes for less text from the last section overlapped under the header
      self.tableView.contentOffset = CGPointMake(self.tableView.contentOffset.x,
                                                 self.tableView.contentOffset.y + 10);
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.isViewTransitioning = NO;
      });
    } else {
      DDLogWarn(@"%@ showPhoto:%llu no indexPath for photoId found.",
                [self.class description],
                photoId);
    }
  });
}

- (void)jumpToPhoto:(DFPhotoIDType)photoID
{
  self.requestedPhotoIDToJumpTo = photoID;
}

#pragma mark - DFStrandsViewControllerDelegate

- (void)strandsViewControllerUpdatedData:(DFStrandsViewController *)strandsViewController
{
  [self.tableView reloadData];
}

- (void)strandsViewController:(DFStrandsViewController *)strandsViewController didFinishServerFetchWithError:(NSError *)error
{
  // Turn off spinner since we successfully did a server fetch
  [self.refreshControl endRefreshing];
  
  if (self.requestedPhotoIDToJumpTo != 0) {
    [self showPhoto:self.requestedPhotoIDToJumpTo animated:NO];
    self.requestedPhotoIDToJumpTo = 0;
  }
}

#pragma mark - Table view data source: sections

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return self.strandObjects.count;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
  DFFeedSectionHeaderView *headerView =
  [self.tableView dequeueReusableHeaderFooterViewWithIdentifier:@"sectionHeader"];
 
  DFPeanutFeedObject *sectionObject = [self sectionObjectForTableSection:section];
  headerView.titleLabel.text = sectionObject.title;
  headerView.subtitleLabel.text = sectionObject.subtitle;
  headerView.representativeObject = sectionObject;
  headerView.delegate = self;
  
  return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
  return SectionHeaderHeight;
}

#pragma mark - Table view data source


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  DFPeanutFeedObject *sectionObject = [self sectionObjectForTableSection:section];
  
  NSArray *items = sectionObject.objects;
  return items.count;
}

- (DFPeanutFeedObject *)sectionObjectForTableSection:(NSUInteger)tableSection
{
  return self.strandObjects[tableSection];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell;
  
  DFPeanutFeedObject *section = [self sectionObjectForTableSection:indexPath.section];
  NSArray *itemsForSection = section.objects;
  DFPeanutFeedObject *object = itemsForSection[indexPath.row];
  
  if ([object.type isEqual:DFFeedObjectPhoto]) {
    cell = [self cellForPhoto:object indexPath:indexPath];
  } else if ([object.type isEqual:DFFeedObjectCluster]) {
    cell = [self cellForCluster:object indexPath:indexPath];
  }
  
  cell.selectionStyle = UITableViewCellSelectionStyleNone;
  [cell setNeedsLayout];
  return cell;
}

- (DFPhotoFeedCell *)cellForPhoto:(DFPeanutFeedObject *)photoObject
                           indexPath:(NSIndexPath *)indexPath
{
  DFPhotoFeedCell *photoFeedCell = [self.tableView dequeueReusableCellWithIdentifier:@"photoCell"
                                                                   forIndexPath:indexPath];
  photoFeedCell.delegate = self;
  [photoFeedCell setObjects:@[@(photoObject.id)]];
  [photoFeedCell setClusterViewHidden:YES];
  [DFFeedViewController configureNonImageAttributesForCell:photoFeedCell
                                               searchObject:photoObject];
  photoFeedCell.imageView.image = nil;
  //[photoFeedCell.loadingActivityIndicator startAnimating];
  
  if (photoObject) {
    [[DFImageStore sharedStore]
     imageForID:photoObject.id
     preferredType:DFImageFull
     thumbnailPath:photoObject.thumb_image_path
     fullPath:photoObject.full_image_path
     completion:^(UIImage *image) {
       dispatch_async(dispatch_get_main_queue(), ^{
         if (![self.tableView.visibleCells containsObject:photoFeedCell]) return;
         [photoFeedCell setImage:image forObject:@(photoObject.id)];
         [photoFeedCell setNeedsLayout];
       });
     }];
  }

  return photoFeedCell;
}

- (DFPhotoFeedCell *)cellForCluster:(DFPeanutFeedObject *)cluster
                        indexPath:(NSIndexPath *)indexPath
{
  DFPhotoFeedCell *clusterFeedCell = [self.tableView dequeueReusableCellWithIdentifier:@"clusterCell"
                                                                   forIndexPath:indexPath];
  clusterFeedCell.delegate = self;
  [clusterFeedCell setClusterViewHidden:NO];
  [clusterFeedCell setObjects:[DFFeedViewController objectIDNumbers:cluster.objects]];
  [DFFeedViewController configureNonImageAttributesForCell:clusterFeedCell
                                               searchObject:[cluster.objects firstObject]];
  for (DFPeanutFeedObject *subObject in cluster.objects) {
    [[DFImageStore sharedStore]
     imageForID:subObject.id
     preferredType:DFImageFull
     thumbnailPath:subObject.thumb_image_path
     fullPath:subObject.full_image_path
     completion:^(UIImage *image) {
       dispatch_async(dispatch_get_main_queue(), ^{
         if (![self.tableView.visibleCells containsObject:clusterFeedCell]) return;
         [clusterFeedCell setImage:image forObject:@(subObject.id)];
         [clusterFeedCell setNeedsLayout];
       });
     }];
  }

  return clusterFeedCell;
}

+ (NSArray *)objectIDNumbers:(NSArray *)objects
{
  NSMutableArray *result = [NSMutableArray new];
  for (DFPeanutFeedObject *object in objects) {
    [result addObject:@(object.id)];
  }
  return result;
}

+ (void)configureNonImageAttributesForCell:(DFPhotoFeedCell *)cell
                              searchObject:(DFPeanutFeedObject *)searchObject
{
  cell.titleLabel.text = searchObject.user == [[DFUser currentUser] userID] ?
    @"You" : searchObject.user_display_name;
  cell.photoDateLabel.text = [NSDateFormatter relativeTimeStringSinceDate:searchObject.time_taken
                              abbreviate:YES];
  
  if (searchObject.actions.count > 0) {
    [cell setFavoritersListHidden:NO];
    NSArray *likerNames = [DFPeanutAction arrayOfLikerNamesFromActions:searchObject.actions];
    NSString *likerNamesString = [NSString stringWithCommaSeparatedStrings:likerNames];
    [cell.favoritersButton setTitle:likerNamesString forState:UIControlStateNormal];
    cell.favoriteButton.selected = (searchObject.userFavoriteAction != nil);
  } else {
    cell.favoriteButton.selected = NO;
    [cell setFavoritersListHidden:YES];
  }
}


- (id)keyForIndexPath:(NSIndexPath *)indexPath
{
  if ([indexPath class] == [NSIndexPath class]) {
    return indexPath;
  }
  return [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
   CGFloat rowHeight = MinRowHeight;
  
  
  DFPeanutFeedObject *sectionObject = [self sectionObjectForTableSection:indexPath.section];
  if ([sectionObject isLockedSection]) {
    // If it's a section object, its height is fixed
    return LockedCellHeight;
  }
  
  DFPeanutFeedObject *rowObject = sectionObject.objects[indexPath.row];
  if (rowObject.actions.count > 0) {
    rowHeight += FavoritersListHeight;
  }
  if ([rowObject.type isEqual:DFFeedObjectCluster]) {
    rowHeight += CollectionViewHeight;
  }
  
  return rowHeight;
}

#pragma mark - Actions

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  id object;
  DFPeanutFeedObject *section = [self sectionObjectForTableSection:indexPath.section];
  object = section.objects[indexPath.row];
  
  DDLogVerbose(@"Row tapped for object: %@", object);
               
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - DFFeedSectionHeaderView Delegate

- (void)inviteButtonPressedForHeaderView:(DFFeedSectionHeaderView *)headerView
{
  DFPeanutFeedObject *section = (DFPeanutFeedObject *)headerView.representativeObject;
  DFInviteStrandViewController *vc = [[DFInviteStrandViewController alloc] init];
  vc.sectionObject = section;
  [self presentViewController:[[DFNavigationController alloc] initWithRootViewController:vc]
                     animated:YES
                   completion:nil];
}

#pragma mark - DFPhotoFeedCell Delegates

- (void)favoriteButtonPressedForObject:(NSNumber *)objectIDNumber sender:(id)sender
{
  DDLogVerbose(@"Favorite button pressed");
  DFPhotoIDType photoID = [objectIDNumber longLongValue];
  DFPeanutFeedObject *object = self.photoObjectsById[objectIDNumber];
  DFPeanutAction *oldFavoriteAction = [[object actionsOfType:DFPeanutActionFavorite
                                             forUser:[[DFUser currentUser] userID]]
                               firstObject];
  BOOL wasGesture = [sender isKindOfClass:[UIGestureRecognizer class]];
  DFPeanutAction *newAction;
  if (!oldFavoriteAction) {
    newAction = [[DFPeanutAction alloc] init];
    newAction.user = [[DFUser currentUser] userID];
    newAction.action_type = DFPeanutActionFavorite;
    newAction.photo = photoID;
  } else {
    newAction = nil;
  }
  
  [object setUserFavoriteAction:newAction];
  
  [self reloadRowForPhotoID:photoID];
  
  DFPeanutActionResponseBlock responseBlock = ^(DFPeanutAction *action, NSError *error) {
    if (!error) {
      if (action) {
        [object setUserFavoriteAction:action];
      } // no need for the else case, it was already removed optimistically
      
      [DFAnalytics
       logPhotoLikePressedWithNewValue:(newAction != nil)
       result:DFAnalyticsValueResultSuccess
       actionType:wasGesture ? DFUIActionDoubleTap : DFUIActionButtonPress
       timeIntervalSinceTaken:[[NSDate date] timeIntervalSinceDate:object.time_taken]];
    } else {
      [object setUserFavoriteAction:oldFavoriteAction];
      [self reloadRowForPhotoID:photoID];
      UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                      message:error.localizedDescription
                                                     delegate:nil
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:nil];
      [alert show];
      [DFAnalytics logPhotoLikePressedWithNewValue:(newAction != nil)
                                            result:DFAnalyticsValueResultFailure
                                        actionType:wasGesture ? DFUIActionDoubleTap : DFUIActionButtonPress
                            timeIntervalSinceTaken:[[NSDate date] timeIntervalSinceDate:object.time_taken]];
    }
  };
  
  DFPeanutActionAdapter *adapter = [[DFPeanutActionAdapter alloc] init];
  if (!oldFavoriteAction) {
    [adapter postAction:newAction withCompletionBlock:responseBlock];
  } else {
    [adapter deleteAction:oldFavoriteAction withCompletionBlock:responseBlock];
  }
}

- (void)moreOptionsButtonPressedForObject:(NSNumber *)objectIDNumber sender:(id)sender
{
  DDLogVerbose(@"More options button pressed");
  DFPhotoIDType objectId = [objectIDNumber longLongValue];
  DFPeanutFeedObject *object = self.photoObjectsById[objectIDNumber];
  self.actionSheetPhotoID = objectId;
  
  NSString *deleteTitle = [self isObjectDeletableByUser:object] ? @"Delete" : nil;

  UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                           delegate:self
                                                  cancelButtonTitle:@"Cancel"
                                             destructiveButtonTitle:deleteTitle
                                                  otherButtonTitles:@"Save", nil];
  
 
  [actionSheet showInView:self.tableView];
}


- (void)feedCell:(DFPhotoFeedCell *)feedCell
selectedObjectChanged:(id)newObject
      fromObject:(id)oldObject
{
  DDLogVerbose(@"feedCell object changed from: %@ to %@", oldObject, newObject);
  DFPeanutFeedObject *searchObject = self.photoObjectsById[newObject];
  [DFFeedViewController configureNonImageAttributesForCell:feedCell searchObject:searchObject];
  [feedCell setNeedsLayout];
}


#pragma mark - Action Handler Helpers

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
  NSString *buttonTitle = [actionSheet buttonTitleAtIndex:buttonIndex];
  DDLogVerbose(@"The %@ button was tapped.", buttonTitle);
  if ([buttonTitle isEqualToString:@"Delete"]) {
    [self confirmDeletePhoto];
  } else if ([buttonTitle isEqualToString:@"Save"]) {
    [self savePhotoToCameraRoll];
  }
}

- (BOOL)isObjectDeletableByUser:(DFPeanutFeedObject *)object
{
  return object.user == [[DFUser currentUser] userID];
}


- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
  if (buttonIndex == 1) {
    [self deletePhoto];
  }
}

- (void)confirmDeletePhoto
{
  UIAlertView *alertView = [[UIAlertView alloc]
                            initWithTitle:@"Delete Photo?"
                            message:@"You and other strand users will no longer be able to see it."
                            delegate:self
                            cancelButtonTitle:@"Cancel"
                            otherButtonTitles:@"Delete", nil];
  [alertView show];
}

- (void)deletePhoto
{
  DFPeanutFeedObject *object = self.photoObjectsById[@(self.actionSheetPhotoID)];
  [self.photoAdapter deletePhoto:self.actionSheetPhotoID completionBlock:^(NSError *error) {
    if (!error) {
      [self removePhotoObjectFromView:object];
      
      // remove it from the db
      [[DFPhotoStore sharedStore] deletePhotoWithPhotoID:self.actionSheetPhotoID];
      [DFAnalytics logPhotoDeletedWithResult:DFAnalyticsValueResultSuccess
                      timeIntervalSinceTaken:[[NSDate date] timeIntervalSinceDate:object.time_taken]];
    } else {
      dispatch_async(dispatch_get_main_queue(), ^{
        [UIAlertView
         showSimpleAlertWithTitle:@"Error"
         message:[[NSString stringWithFormat:@"Sorry, an error occurred: %@",
                   error.localizedRecoverySuggestion ?
                   error.localizedRecoverySuggestion : error.localizedDescription] substringToIndex:200]];
        [DFAnalytics logPhotoDeletedWithResult:DFAnalyticsValueResultFailure
                        timeIntervalSinceTaken:[[NSDate date] timeIntervalSinceDate:object.time_taken]];
      });
    }
  }];
}

// Removes a photo object from the local cache of strand objects and updates the view
- (void)removePhotoObjectFromView:(DFPeanutFeedObject *)photoObject
{
  NSIndexPath *indexPath = self.photoIndexPathsById[@(self.actionSheetPhotoID)];
  DFPeanutFeedObject *containingStrand = self.strandObjects[indexPath.section];
  DFPeanutFeedObject *objectInStrand = containingStrand.objects[indexPath.row];
  DFPeanutFeedObject *containingObject;
  if ([objectInStrand.type isEqual:DFFeedObjectCluster]) {
    // the object is in a cluster row
    containingObject = objectInStrand;
  } else {
    containingObject = containingStrand;
  }
  
  NSMutableArray *newObjects = containingObject.objects.mutableCopy;
  [newObjects removeObject:photoObject];
  containingObject.objects = newObjects;

  dispatch_async(dispatch_get_main_queue(), ^{
    if (containingObject == containingStrand) {
      // if the containing object was the strand, the entire row disappears.  animate it
      [self.tableView deleteRowsAtIndexPaths:@[indexPath]
                            withRowAnimation:UITableViewRowAnimationFade];
    } else {
      [self.tableView reloadData];
    }
  });
}

- (void)savePhotoToCameraRoll
{
  @autoreleasepool {
    [self.photoAdapter
     getPhoto:self.actionSheetPhotoID
     withImageDataTypes:DFImageFull
     completionBlock:^(DFPeanutPhoto *peanutPhoto, NSDictionary *imageData, NSError *error) {
       NSData *fullImageData = imageData[@(DFImageFull)];
       if (!error && fullImageData) {
         UIImage *image = [UIImage imageWithData:fullImageData];
         [[DFPhotoStore sharedStore]
          saveImageToCameraRoll:image
          withMetadata:peanutPhoto.metadataDictionary
          completion:^(NSURL *assetURL, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
              if (error) {
                [UIAlertView showSimpleAlertWithTitle:@"Error"
                                              message:error.localizedDescription];
                DDLogError(@"Saving photo to camera roll failed: %@", error.description);
                [DFAnalytics logPhotoSavedWithResult:DFAnalyticsValueResultFailure];
              } else {
                DDLogInfo(@"Photo saved.");
                
                [UIAlertView showSimpleAlertWithTitle:nil
                                              message:@"Photo saved to your camera roll"];
                [DFAnalytics logPhotoSavedWithResult:DFAnalyticsValueResultSuccess];
              }});
          }];
       } else {
         dispatch_async(dispatch_get_main_queue(), ^{
           NSString *errorMessage = error ? error.localizedDescription : @"Could not download photo.";
           [UIAlertView showSimpleAlertWithTitle:@"Error" message:errorMessage];
           DDLogError(@"Failed to save photo.  Error: %@ imageData.length:%lu",
                      error.description, (unsigned long)fullImageData.length);
         });
       }
     }];
  }
}

- (void)reloadRowForPhotoID:(DFPhotoIDType)photoID
{
  [self.tableView reloadData];
}


#pragma mark - Bar Actions

- (void)backPressed:(id)sender
{
  [self.topBarController popViewControllerAnimated:YES];
}


#pragma mark - Adapters

- (DFPhotoMetadataAdapter *)photoAdapter
{
  if (!_photoAdapter) {
    _photoAdapter = [[DFPhotoMetadataAdapter alloc] init];
  }
  
  return _photoAdapter;
}


#pragma mark - UIScrollViewDelegate methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  if (![self shouldHandleScrollChange]) return;
  CGFloat scrollOffset = scrollView.contentOffset.y;
  CGFloat dy = scrollOffset - self.previousScrollViewYOffset;
  
  if (scrollOffset <= -scrollView.contentInset.top) {
    [self.topBarController mainScrollViewScrolledToTop:YES dy:dy];
  } else {
    [self.topBarController mainScrollViewScrolledToTop:NO dy:dy];
  }
  
  // store the scrollOffset for calculations next time around
  self.previousScrollViewYOffset = scrollOffset;
}

- (BOOL)shouldHandleScrollChange
{
  if (self.isViewTransitioning || !self.view.window) return NO;
  
  return YES;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
  [self.topBarController mainScrollViewStoppedScrolling];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView
                  willDecelerate:(BOOL)decelerate
{
  if (!decelerate) {
    [self.topBarController mainScrollViewStoppedScrolling];
  }
}

- (DFTopBarController *)topBarController
{
  if ([[self.parentViewController class] isSubclassOfClass:[DFTopBarController class]]) {
    return (DFTopBarController *)self.parentViewController;
  }
  
  return nil;
}


@end
