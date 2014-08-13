//
//  DFPhotoFeedController.m
//  Strand
//
//  Created by Henry Bridge on 7/4/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPhotoFeedController.h"
#import "DFPeanutGalleryAdapter.h"
#import "DFPhoto.h"
#import "DFPhotoCollection.h"
#import "DFMultiPhotoViewController.h"
#import "RootViewController.h"
#import "DFCGRectHelpers.h"
#import "DFStrandConstants.h"
#import "DFAnalytics.h"
#import "DFImageStore.h"
#import "DFPeanutPhoto.h"
#import "DFPhotoFeedCell.h"
#import "DFPeanutSearchResponse.h"
#import "DFPeanutSearchObject.h"
#import "NSString+DFHelpers.h"
#import "DFPeanutActionAdapter.h"
#import "DFSettingsViewController.h"
#import "DFFeedSectionHeaderView.h"
#import "DFNavigationController.h"
#import "DFPhotoStore.h"
#import "DFPhotoMetadataAdapter.h"
#import "UIAlertView+DFHelpers.h"
#import "DFToastNotificationManager.h"
#import "DFInviteUserViewController.h"
#import "DFErrorScreen.h"
#import "DFDefaultsStore.h"
#import "DFLockedStrandCell.h"
#import "DFUploadController.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "DFUploadingFeedCell.h"
#import "DFNotificationSharedConstants.h"

const NSTimeInterval FeedChangePollFrequency = 60.0;

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

@property (nonatomic, retain) NSArray *sectionObjects;
@property (nonatomic, retain) NSDictionary *indexPathsByID;
@property (nonatomic, retain) NSDictionary *objectsByID;
@property (nonatomic, retain) NSArray *uploadingPhotos;
@property (nonatomic, retain) NSError *uploadError;

@property (nonatomic) DFPhotoIDType actionSheetPhotoID;

@property (readonly, nonatomic, retain) DFPeanutGalleryAdapter *galleryAdapter;
@property (readonly, nonatomic, retain) DFPhotoMetadataAdapter *photoAdapter;

@property (nonatomic, retain) NSData *lastResponseHash;
@property (nonatomic, retain) NSTimer *autoRefreshTimer;

@property (nonatomic, retain) UIView *nuxPlaceholder;
@property (nonatomic, retain) UIView *connectionErrorPlaceholder;

@property (nonatomic) DFPhotoIDType requestedPhotoIDToJumpTo;

@end

@implementation DFPhotoFeedController

@synthesize galleryAdapter = _galleryAdapter;
@synthesize photoAdapter = _photoAdapter;

- (id)init
{
  self = [super init];
  if (self) {
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.font = [UIFont boldSystemFontOfSize:17.0];
    titleLabel.textColor = [DFStrandConstants defaultBarForegroundColor];
    titleLabel.text = @"Strand";
    self.navigationItem.titleView = titleLabel;
    [titleLabel sizeToFit];
    
    [self setNavigationButtons];
    [self observeNotifications];
    
  }
  return self;
}

- (void)setNavigationButtons
{
  if (!(self.navigationItem.rightBarButtonItems.count > 0)) {
    UIBarButtonItem *settingsButton =
    [[UIBarButtonItem alloc]
     initWithImage:[[UIImage imageNamed:@"Assets/Icons/SettingsBarButton"]
                    imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
     style:UIBarButtonItemStylePlain
     target:self
     action:@selector(settingsButtonPressed:)];
    UIBarButtonItem *cameraButton =
    [[UIBarButtonItem alloc]
     initWithImage:[[UIImage imageNamed:@"Assets/Icons/CameraBarButton"]
                    imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
     style:UIBarButtonItemStylePlain
     target:self
     action:@selector(cameraButtonPressed:)];
    UIBarButtonItem *inviteButton =
    [[UIBarButtonItem alloc]
     initWithImage:[[UIImage imageNamed:@"Assets/Icons/InviteBarButton"]
                    imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
     style:UIBarButtonItemStylePlain
     target:self
     action:@selector(inviteButtonPressed:)];
    
    self.navigationItem.leftBarButtonItems = @[settingsButton];
    self.navigationItem.rightBarButtonItems = @[cameraButton, inviteButton];
  }
}

- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(applicationDidBecomeActive:)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(viewDidBecomeInactive)
                                               name:UIApplicationWillResignActiveNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(applicationDidEnterBackground:)
                                               name:UIApplicationDidEnterBackgroundNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadFeed)
                                               name:DFStrandRefreshRemoteUIRequestedNotificationName
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(uploadStatusChanged:)
                                               name:DFUploadStatusNotificationName
                                             object:nil];
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  self.tableView = [[UITableView alloc] initWithFrame:self.contentView.frame
                                                style:UITableViewStyleGrouped];
  self.contentView = self.tableView;
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
  [self.tableView addSubview:self.refreshControl];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self reloadFeedIsSilent:NO];
}


- (void)jumpToPhoto:(DFPhotoIDType)photoID
{
  self.requestedPhotoIDToJumpTo = photoID;
}

- (void)reloadFeed
{
  [self reloadFeedIsSilent:NO];
  [[DFUploadController sharedUploadController] uploadPhotos];
}

- (void)autoReloadFeed
{
  [self reloadFeedIsSilent:YES];
}

- (void)reloadFeedIsSilent:(BOOL)isSilent
{
  if (!isSilent)
    [self.refreshControl beginRefreshing];
  [self.galleryAdapter fetchGalleryWithCompletionBlock:^(DFPeanutSearchResponse *response,
                                                         NSData *hashData,
                                                         NSError *error) {
    if (!isSilent)
      [self.refreshControl endRefreshing];
    if (!error) {
      dispatch_async(dispatch_get_main_queue(), ^{
        NSArray *unprocessedFeedPhotos = [self unprocessedFeedPhotos:response.objects];
        
        if ((response.objects.count > 0 && ![hashData isEqual:self.lastResponseHash])
            || ![self.uploadingPhotos isEqualToArray:unprocessedFeedPhotos]) {
          DDLogInfo(@"New feed data detected. Re-rendering feed.");
          [self setSectionObjects:response.topLevelSectionObjects
                  uploadingPhotos:unprocessedFeedPhotos];
          
          self.lastResponseHash = hashData;
        }
        if (self.requestedPhotoIDToJumpTo) {
          dispatch_async(dispatch_get_main_queue(), ^{
            NSIndexPath *indexPath = self.indexPathsByID[@(self.requestedPhotoIDToJumpTo)];
            [self.tableView scrollToRowAtIndexPath:indexPath
                                  atScrollPosition:UITableViewScrollPositionBottom
                                          animated:NO];
            self.requestedPhotoIDToJumpTo = 0;
          });
        }});
    }
    
    // Evaluate whether and how to show error messages or NUX screens
    if (self.sectionObjects.count == 0 && response.objects.count == 0) {
      // Eligible to replace feed with placeholder
      if (!error || [DFDefaultsStore actionCountForAction:DFUserActionTakePhoto] == 0) {
        [self setShowNuxPlaceholder:YES];
        [self showConnectionError:nil];
      } else if (error) {
        [self setShowNuxPlaceholder:NO];
        [self showConnectionError:error];
      }
    } else {
      // Not eligible to replace feed with placeholder
      [self setShowNuxPlaceholder:NO];
      [self showConnectionError:nil];
      if (error && !isSilent) {
        [[DFToastNotificationManager sharedInstance]
         showErrorWithTitle:@"Couldn't Reload Feed" subTitle:error.localizedDescription];
      }
    }
  }];
}

- (NSArray *)unprocessedFeedPhotos:(NSArray *)sectionObjects
{
  DFPhotoCollection *unprocessedCollection = [[DFPhotoStore sharedStore]
                               photosWithUploadProcessedStatus:NO];
  NSMutableSet *allPhotoIDsInFeed = [NSMutableSet new];
  for (DFPeanutSearchObject *section in sectionObjects) {
    for (DFPeanutSearchObject *object in [[section enumeratorOfDescendents] allObjects]) {
      if (object.id) [allPhotoIDsInFeed addObject:@(object.id)];
    }
  }
  
  NSMutableArray *result = [[unprocessedCollection photosByDateAscending:NO] mutableCopy];
  for (DFPhoto *photo in unprocessedCollection.photoSet) {
    if ([allPhotoIDsInFeed containsObject:@(photo.photoID)]) {
      [result removeObject:photo];
      photo.isUploadProcessed = YES;
    }
  }
  
  return result;
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [[NSNotificationCenter defaultCenter] postNotificationName:DFStrandGalleryAppearedNotificationName
                                                      object:self
                                                    userInfo:nil];
  if (!self.autoRefreshTimer)
    self.autoRefreshTimer =
    [NSTimer scheduledTimerWithTimeInterval:FeedChangePollFrequency
                                     target:self
                                   selector:@selector(autoReloadFeed)
                                   userInfo:nil
                                    repeats:YES];
  
  [[DFUploadController sharedUploadController] uploadPhotos];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}


- (void)viewWillDisappear:(BOOL)animated
{
  [super viewWillDisappear:animated];
  // take a snapshot
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];

  [self viewDidBecomeInactive];
}

- (void)viewDidBecomeInactive
{
  [self.autoRefreshTimer invalidate];
  self.autoRefreshTimer = nil;
}

- (void)setTableViewFrame
{
  self.tableView.frame = CGRectMake(self.tableView.frame.origin.x,
                                    self.navigationBar.frame.size.height,
                                    self.tableView.frame.size.width,
                                    self.tableView.frame.size.height);
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
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

#pragma mark - Table view data source: rows

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
  
  if ([self isSectionLocked:sectionObject]) {
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

- (BOOL)prefersStatusBarHidden
{
  return NO;
}

-(UIStatusBarStyle)preferredStatusBarStyle{
  return UIStatusBarStyleLightContent;
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
    
    if ([self isSectionLocked:section]) {
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
  if ([self isSectionLocked:sectionObject]) {
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

- (BOOL)isSectionLocked:(DFPeanutSearchObject *)sectionObject
{
  return [sectionObject.title isEqualToString:@"Locked"];
}

- (void)setSectionObjects:(NSArray *)sectionObjects
         uploadingPhotos:(NSArray *)uploadingPhotos
{
  NSMutableDictionary *objectsByID = [NSMutableDictionary new];
  NSMutableDictionary *indexPathsByID = [NSMutableDictionary new];
  
  for (NSUInteger sectionIndex = 0; sectionIndex < sectionObjects.count; sectionIndex++) {
    NSArray *objectsForSection = [sectionObjects[sectionIndex] objects];
    for (NSUInteger objectIndex = 0; objectIndex < objectsForSection.count; objectIndex++) {
      DFPeanutSearchObject *object = objectsForSection[objectIndex];
      NSIndexPath *indexPath = [NSIndexPath indexPathForRow:objectIndex inSection:sectionIndex];
      if ([object.type isEqual:DFSearchObjectPhoto]) {
        objectsByID[@(object.id)] = object;
        indexPathsByID[@(object.id)] = indexPath;
      } else if ([object.type isEqual:DFSearchObjectCluster]) {
        for (DFPeanutSearchObject *subObject in object.objects) {
          objectsByID[@(subObject.id)] = subObject;
          indexPathsByID[@(subObject.id)] = indexPath;
        }
      }
    }
  }
  
  _objectsByID = objectsByID;
  _indexPathsByID = indexPathsByID;
  _sectionObjects = sectionObjects;
  _uploadingPhotos = uploadingPhotos;
  
  [self.tableView reloadData];
}

#pragma mark - Actions

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  id object;
  if (self.uploadingPhotos.count > 0 && indexPath.section == 0) {
    object = self.uploadingPhotos[indexPath.row];
  } else {
    DFPeanutSearchObject *section = [self sectionObjectForTableSection:indexPath.section];
    if ([self isSectionLocked:section]) {
      object = section;
    } else {
      object = section.objects[indexPath.row];
    }
  }
  
  DDLogVerbose(@"Row tapped for object: %@", object);
               
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)cameraButtonPressed:(id)sender
{
  [(RootViewController *)self.view.window.rootViewController showCamera];
}

- (void)settingsButtonPressed:(id)sender
{
  DFSettingsViewController *svc = [[DFSettingsViewController alloc] init];
  [self presentViewController:[[DFNavigationController alloc] initWithRootViewController:svc]
                     animated:YES
                   completion:nil];
}


- (void)inviteButtonPressed:(id)sender
{
  DDLogInfo(@"Invite button pressed");
  DFInviteUserViewController *inviteController = [[DFInviteUserViewController alloc] init];
  [self presentViewController:inviteController animated:YES completion:nil];
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

#pragma mark - Adapters

- (DFPeanutGalleryAdapter *)galleryAdapter
{
  if (!_galleryAdapter) {
    _galleryAdapter = [[DFPeanutGalleryAdapter alloc] init];
  }
  
  return _galleryAdapter;
}

- (DFPhotoMetadataAdapter *)photoAdapter
{
  if (!_photoAdapter) {
    _photoAdapter = [[DFPhotoMetadataAdapter alloc] init];
  }
  
  return _photoAdapter;
}


#pragma mark - Notification handlers

- (void)applicationDidBecomeActive:(NSNotification *)note
{
  if (self.isViewLoaded && self.view.window) {
    [self viewDidAppear:YES];
  }
}

- (void)applicationDidEnterBackground:(NSNotification *)note
{
  if (self.isViewLoaded && self.view.window) {
    [self viewDidDisappear:YES];
  }
}

- (void)uploadStatusChanged:(NSNotification *)note
{
  DFUploadSessionStats *uploadStats = note.userInfo[DFUploadStatusUpdateSessionUserInfoKey];
  if (uploadStats.fatalError) {
    [self.tableView reloadData];
    self.uploadError = uploadStats.fatalError;
  } else {
    self.uploadError = nil;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      [self reloadFeedIsSilent:YES];
    });
  }
}


@end
