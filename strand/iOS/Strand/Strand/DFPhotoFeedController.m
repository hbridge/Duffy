//
//  DFPhotoFeedController.m
//  Strand
//
//  Created by Henry Bridge on 7/4/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPhotoFeedController.h"
#import "DFAnalytics.h"
#import "DFDefaultsStore.h"
#import "DFErrorScreen.h"
#import "DFFeedSectionHeaderView.h"
#import "DFImageStore.h"
#import "DFLockedStrandCell.h"
#import "DFNavigationController.h"
#import "DFNotificationSharedConstants.h"
#import "DFPeanutActionAdapter.h"
#import "DFPeanutPhoto.h"
#import "DFPeanutSearchObject.h"
#import "DFPhotoFeedCell.h"
#import "DFPhotoMetadataAdapter.h"
#import "DFPhotoStore.h"
#import "DFStrandConstants.h"
#import "DFToastNotificationManager.h"
#import "DFUploadController.h"
#import "DFUploadingFeedCell.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "NSString+DFHelpers.h"
#import "RootViewController.h"
#import "UIAlertView+DFHelpers.h"

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

@interface DFPhotoFeedController ()

@property (readonly, nonatomic, retain) DFPhotoMetadataAdapter *photoAdapter;

@property (nonatomic, retain) UIView *nuxPlaceholder;
@property (nonatomic, retain) UIView *connectionErrorPlaceholder;

@property (nonatomic) DFPhotoIDType actionSheetPhotoID;
@property (nonatomic) DFPhotoIDType requestedPhotoIDToJumpTo;

@property (nonatomic) CGFloat previousScrollViewYOffset;
@property (nonatomic) BOOL isViewTransitioning;

@end

@implementation DFPhotoFeedController

@synthesize photoAdapter = _photoAdapter;

- (instancetype)init
{
  self = [super init];
  if (self) {
    self.delegate = self;

    UIBarButtonItem *backToGalleryItem = [[UIBarButtonItem alloc]
                                          initWithImage:[UIImage imageNamed:@"Assets/Icons/GridBarButton"]
                                          style:UIBarButtonItemStylePlain
                                          target:self
                                          action:@selector(backPressed:)];
    self.navigationItem.backBarButtonItem = backToGalleryItem;
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  self.tableView = [[UITableView alloc] initWithFrame:self.view.frame
                                                style:UITableViewStylePlain];
  [self.view addSubview:self.tableView];
  self.tableView.dataSource = self;
  self.tableView.delegate = self;
  self.tableView.scrollsToTop = YES;
  
  self.automaticallyAdjustsScrollViewInsets = NO;
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

  
  self.refreshControl = [[UIRefreshControl alloc] init];
  [self.refreshControl addTarget:self action:@selector(reloadFeed)
                forControlEvents:UIControlEventValueChanged];

  UITableViewController *tableViewController = [[UITableViewController alloc] init];
  tableViewController.tableView = self.tableView;
  tableViewController.refreshControl = self.refreshControl;
}

- (void)viewWillAppear:(BOOL)animated
{
  self.isViewTransitioning = YES;
  [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
  if (self.sectionObjects.count == 0) [self.refreshControl beginRefreshing];
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

#pragma mark - Jump to a specific photo

- (void)showPhoto:(DFPhotoIDType)photoId
{
  dispatch_async(dispatch_get_main_queue(), ^{
    NSIndexPath *indexPath = self.indexPathsByID[@(self.requestedPhotoIDToJumpTo)];
    if (indexPath) {
      [self.tableView scrollToRowAtIndexPath:indexPath
                            atScrollPosition:UITableViewScrollPositionTop
                                    animated:NO];
      self.requestedPhotoIDToJumpTo = 0;
    } else {
      DDLogWarn(@"%@ showPhoto:%llu no indexPath for photoId found.",
                [self.class description],
                self.requestedPhotoIDToJumpTo);
    }
  });
}

- (void)jumpToPhoto:(DFPhotoIDType)photoID
{
  self.requestedPhotoIDToJumpTo = photoID;
  [self reloadFeed];
}

#pragma mark - DFStrandsViewControllerDelegate

- (void)strandsViewController:(DFStrandsViewController *)strandsViewController
  didFinishRefreshWithNewData:(BOOL)newData
                     isSilent:(BOOL)isSilent
                        error:(NSError *)error

{
  [self.refreshControl endRefreshing];
  
  if (self.sectionObjects.count > 0 && newData) {
    // Normal case, reload the table view
    [self.tableView reloadData];
  } else if (self.sectionObjects.count == 0 && newData) {
    // Eligible to replace feed with placeholder
    if (!error || [DFDefaultsStore actionCountForAction:DFUserActionTakePhoto] == 0) {
      [self setShowNuxPlaceholder:YES];
      [self showConnectionError:nil];
    } else if (error) {
      [self setShowNuxPlaceholder:NO];
      [self showConnectionError:error];
    }
  } else {
    // Error but there are objects in the feed we shouldn't wipe
    [self setShowNuxPlaceholder:NO];
    [self showConnectionError:nil];
    if (error && !isSilent) {
      [[DFToastNotificationManager sharedInstance]
       showErrorWithTitle:@"Couldn't Reload Feed" subTitle:error.localizedDescription];
    }
  }
  
  if (self.requestedPhotoIDToJumpTo != 0) {
    [self showPhoto:self.requestedPhotoIDToJumpTo];
  }
}

- (void)setShowNuxPlaceholder:(BOOL)isShown
{
  if (isShown) {
    if (self.nuxPlaceholder) return;
    self.nuxPlaceholder = [[[UINib nibWithNibName:@"FeedViewNuxPlaceholder" bundle:nil]
                          instantiateWithOwner:self options:nil] firstObject];
    [self.view addSubview:self.nuxPlaceholder];
  } else {
    [self.nuxPlaceholder removeFromSuperview];
    self.nuxPlaceholder = nil;
  }
}

- (void)showConnectionError:(NSError *)error
{
  [self.connectionErrorPlaceholder removeFromSuperview];
  if (error) {
    DFErrorScreen *errorScreen = [[[UINib nibWithNibName:@"DFErrorScreen" bundle:nil]
                                   instantiateWithOwner:self options:nil] firstObject];
    errorScreen.textView.text = error.localizedDescription;
    self.connectionErrorPlaceholder = errorScreen;
    [self.view addSubview:self.connectionErrorPlaceholder];
  } else {
    self.connectionErrorPlaceholder = nil;
  }
}

#pragma mark - Table view data source: sections

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
  if (self.uploadingPhotos.count > 0 && section == 0) {
    return nil;
  }
  
  DFFeedSectionHeaderView *headerView =
  [self.tableView dequeueReusableHeaderFooterViewWithIdentifier:@"sectionHeader"];
 
  DFPeanutSearchObject *sectionObject = [self sectionObjectForTableSection:section];
  headerView.titleLabel.text = sectionObject.title;
  headerView.subtitleLabel.text = sectionObject.subtitle;
  
  return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
  if (self.uploadingPhotos.count > 0 && section == 0) return 0.0;
  return SectionHeaderHeight;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return self.sectionObjects.count + (self.uploadingPhotos.count > 0 ? 1 : 0);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  if (self.uploadingPhotos.count > 0 && section == 0) {
    return 1;
  }
  
  DFPeanutSearchObject *sectionObject = [self sectionObjectForTableSection:section];
  
  if ([sectionObject isLockedSection]) {
    return 1;
  }
  
  NSArray *items = sectionObject.objects;
  return items.count;
}

- (DFPeanutSearchObject *)sectionObjectForTableSection:(NSUInteger)tableSection
{
  if (self.uploadingPhotos.count > 0) return self.sectionObjects[tableSection - 1];
  
  return self.sectionObjects[tableSection];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell;
  
  if (self.uploadingPhotos.count > 0 && indexPath.section == 0) {
    cell = [self cellForUploadAtIndexPath:indexPath];
  } else {
    DFPeanutSearchObject *section = [self sectionObjectForTableSection:indexPath.section];
    NSArray *itemsForSection = section.objects;
    DFPeanutSearchObject *object = itemsForSection[indexPath.row];
    
    if ([section isLockedSection]) {
      cell = [self cellForLockedSection:section indexPath:indexPath];
    } else if ([object.type isEqual:DFSearchObjectPhoto]) {
      cell = [self cellForPhoto:object indexPath:indexPath];
    } else if ([object.type isEqual:DFSearchObjectCluster]) {
      cell = [self cellForCluster:object indexPath:indexPath];
    }
  }

  cell.selectionStyle = UITableViewCellSelectionStyleNone;
  [cell setNeedsLayout];
  return cell;
}

- (DFUploadingFeedCell *)cellForUploadAtIndexPath:(NSIndexPath *)indexPath
{
  DFUploadingFeedCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"uploadingCell"];
  
  cell.images = @[];
  if (indexPath.row == 0) {
    if (!self.uploadError) {
      cell.statusTextLabel.text = @"Uploading";
      [cell.activityIndicator startAnimating];
    } else {
      cell.statusTextLabel.text = @"Retry Pending";
      [cell.activityIndicator stopAnimating];
    }
  }
  
  for (DFPhoto *photo in self.uploadingPhotos) {
    [photo.asset loadUIImageForThumbnail:^(UIImage *image) {
      dispatch_async(dispatch_get_main_queue(), ^{
        if (![self.tableView.visibleCells containsObject:cell]) return;
        [cell addImage:image];
      });
    } failureBlock:^(NSError *error) {
      DDLogError(@"Error loading thumbnail for uploading asset.");
    }];
  }
  
  return cell;
}

- (DFLockedStrandCell *)cellForLockedSection:(DFPeanutSearchObject *)section
                                   indexPath:(NSIndexPath *)indexPath
{
  DFLockedStrandCell *lockedCell = [self.tableView dequeueReusableCellWithIdentifier:@"lockedCell"
                                                                   forIndexPath:indexPath];
  
  NSMutableArray *objectIDs = [NSMutableArray new];
  for (DFPeanutSearchObject *object in section.objects) {
    [objectIDs addObject:@(object.id)];
  }
  lockedCell.objects = objectIDs;
  
  for (DFPeanutSearchObject *object in section.objects) {
    [[DFImageStore sharedStore]
     imageForID:object.id
     preferredType:DFImageThumbnail
     thumbnailPath:object.thumb_image_path
     fullPath:object.full_image_path
     completion:^(UIImage *image) {
       dispatch_async(dispatch_get_main_queue(), ^{
         if (![self.tableView.visibleCells containsObject:lockedCell]) return;
         [lockedCell setImage:image forObject:@(object.id)];
         [lockedCell setNeedsLayout];
       });
     }];
  }
  return lockedCell;
}

- (DFPhotoFeedCell *)cellForPhoto:(DFPeanutSearchObject *)photoObject
                           indexPath:(NSIndexPath *)indexPath
{
  DFPhotoFeedCell *photoFeedCell = [self.tableView dequeueReusableCellWithIdentifier:@"photoCell"
                                                                   forIndexPath:indexPath];
  photoFeedCell.delegate = self;
  [photoFeedCell setObjects:@[@(photoObject.id)]];
  [photoFeedCell setClusterViewHidden:YES];
  [DFPhotoFeedController configureNonImageAttributesForCell:photoFeedCell
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

- (DFPhotoFeedCell *)cellForCluster:(DFPeanutSearchObject *)cluster
                        indexPath:(NSIndexPath *)indexPath
{
  DFPhotoFeedCell *clusterFeedCell = [self.tableView dequeueReusableCellWithIdentifier:@"clusterCell"
                                                                   forIndexPath:indexPath];
  clusterFeedCell.delegate = self;
  [clusterFeedCell setClusterViewHidden:NO];
  [clusterFeedCell setObjects:[DFPhotoFeedController objectIDNumbers:cluster.objects]];
  [DFPhotoFeedController configureNonImageAttributesForCell:clusterFeedCell
                                               searchObject:[cluster.objects firstObject]];
  for (DFPeanutSearchObject *subObject in cluster.objects) {
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
  for (DFPeanutSearchObject *object in objects) {
    [result addObject:@(object.id)];
  }
  return result;
}

+ (void)configureNonImageAttributesForCell:(DFPhotoFeedCell *)cell
                              searchObject:(DFPeanutSearchObject *)searchObject
{
  cell.titleLabel.text = searchObject.user == [[DFUser currentUser] userID] ?
    @"You" : searchObject.user_display_name;
  cell.photoDateLabel.text = [NSDateFormatter relativeTimeStringSinceDate:searchObject.time_taken];
  
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

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return MinRowHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (self.uploadingPhotos.count > 0 && indexPath.section == 0) {
    return UploadingCellVerticalMargin + UploadingCellTitleArea
     + (self.uploadingPhotos.count / UploadingCellImagesPerRow + 1) * UploadingCellImageRowHeight
     + (self.uploadingPhotos.count / UploadingCellImagesPerRow) * UploadingCellImageRowSpacing
    + UploadingCellVerticalMargin;
  }
  
  CGFloat rowHeight = MinRowHeight;
  
  
  DFPeanutSearchObject *sectionObject = [self sectionObjectForTableSection:indexPath.section];
  if ([sectionObject isLockedSection]) {
    // If it's a section object, its height is fixed
    return LockedCellHeight;
  }
  
  DFPeanutSearchObject *rowObject = sectionObject.objects[indexPath.row];
  if (rowObject.actions.count > 0) {
    rowHeight += FavoritersListHeight;
  }
  if ([rowObject.type isEqual:DFSearchObjectCluster]) {
    rowHeight += CollectionViewHeight;
  }
  
  return rowHeight;
}

#pragma mark - Actions

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  id object;
  if (self.uploadingPhotos.count > 0 && indexPath.section == 0) {
    object = self.uploadingPhotos[indexPath.row];
  } else {
    DFPeanutSearchObject *section = [self sectionObjectForTableSection:indexPath.section];
    if ([section isLockedSection]) {
      object = section;
    } else {
      object = section.objects[indexPath.row];
    }
  }
  
  DDLogVerbose(@"Row tapped for object: %@", object);
               
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - DFPhotoFeedCell Delegates

- (void)favoriteButtonPressedForObject:(NSNumber *)objectIDNumber sender:(id)sender
{
  DDLogVerbose(@"Favorite button pressed");
  DFPhotoIDType photoID = [objectIDNumber longLongValue];
  DFPeanutSearchObject *object = self.objectsByID[objectIDNumber];
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
       actionType:wasGesture ? DFActionDoubleTap : DFActionButtonPress
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
                                        actionType:wasGesture ? DFActionDoubleTap : DFActionButtonPress
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
  DFPeanutSearchObject *object = self.objectsByID[objectIDNumber];
  self.actionSheetPhotoID = objectId;
  
  NSString *deleteTitle = [self isObjectDeletableByUser:object] ? @"Delete" : nil;

  UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                           delegate:self
                                                  cancelButtonTitle:@"Cancel"
                                             destructiveButtonTitle:deleteTitle
                                                  otherButtonTitles:@"Save", nil];
  
 
  [actionSheet showInView:self.view.superview];
}


- (void)feedCell:(DFPhotoFeedCell *)feedCell
selectedObjectChanged:(id)newObject
      fromObject:(id)oldObject
{
  DDLogVerbose(@"feedCell object changed from: %@ to %@", oldObject, newObject);
  DFPeanutSearchObject *searchObject = self.objectsByID[newObject];
  [DFPhotoFeedController configureNonImageAttributesForCell:feedCell searchObject:searchObject];
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

- (BOOL)isObjectDeletableByUser:(DFPeanutSearchObject *)object
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
  DFPeanutSearchObject *object = self.objectsByID[@(self.actionSheetPhotoID)];
  [self.photoAdapter deletePhoto:self.actionSheetPhotoID completionBlock:^(NSError *error) {
    if (!error) {
      [self reloadFeed];
      
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
          completion:^(NSError *error) {
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
  NSIndexPath *indexPath = self.indexPathsByID[@(photoID)];
  if (indexPath) {
    [self.tableView reloadData];
  }
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
