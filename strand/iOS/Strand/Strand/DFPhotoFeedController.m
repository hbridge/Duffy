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

const NSTimeInterval FeedChangePollFrequency = 60.0;

const CGFloat HeaderHeight = 48.0;
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
@property (atomic, retain) NSMutableDictionary *imageCache;
@property (atomic, retain) NSMutableDictionary *rowHeightCache;
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

- (id)initWithStyle:(UITableViewStyle)style
{
  self = [super initWithStyle:style];
  if (self) {
    self.navigationItem.title = @"Strand";
    [self setNavigationButtons];
    self.imageCache = [[NSMutableDictionary alloc] init];
    self.rowHeightCache = [[NSMutableDictionary alloc] init];
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
                                           selector:@selector(applicationDidEnterBackground:)
                                               name:UIApplicationDidEnterBackgroundNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadFeed)
                                               name:DFStrandRefreshRemoteUIRequestedNotificationName
                                             object:nil];
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  // we observe changes to the table view's frame to prevent it from moving when the status bar
  // is hidden
  [self.tableView addObserver:self forKeyPath:@"frame" options:NSKeyValueObservingOptionOld context:nil];
  
  self.automaticallyAdjustsScrollViewInsets = NO;
  [self.tableView registerNib:[UINib nibWithNibName:@"DFPhotoFeedCell" bundle:nil]
       forCellReuseIdentifier:@"photoCell"];
  [self.tableView registerNib:[UINib nibWithNibName:@"DFPhotoFeedCell" bundle:nil]
       forCellReuseIdentifier:@"clusterCell"];
  [self.tableView registerNib:[UINib nibWithNibName:@"DFLockedStrandCell" bundle:nil]
       forCellReuseIdentifier:@"lockedCell"];
  
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
      if (response.objects.count > 0 && ![hashData isEqual:self.lastResponseHash]) {
        DDLogInfo(@"New feed data detected. Re-rendering feed.");
        dispatch_async(dispatch_get_main_queue(), ^{
          [self setSectionObjects:response.topLevelSectionObjects];
        });
        self.lastResponseHash = hashData;
      }
      if (self.requestedPhotoIDToJumpTo) {
        dispatch_async(dispatch_get_main_queue(), ^{
          NSIndexPath *indexPath = self.indexPathsByID[@(self.requestedPhotoIDToJumpTo)];
          [self.tableView scrollToRowAtIndexPath:indexPath
                                atScrollPosition:UITableViewScrollPositionBottom animated:NO];
          self.requestedPhotoIDToJumpTo = 0;
        });
      }
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

  [self.autoRefreshTimer invalidate];
  self.autoRefreshTimer = nil;
}

- (void)setTableViewFrame
{
  self.tableView.frame = CGRectMake(self.tableView.frame.origin.x,
                                    self.navigationController.navigationBar.frame.size.height,
                                    self.tableView.frame.size.width,
                                    self.tableView.frame.size.height);
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
  self.imageCache = [[NSMutableDictionary alloc] init];
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
  DFFeedSectionHeaderView *headerView =
  [self.tableView dequeueReusableHeaderFooterViewWithIdentifier:@"sectionHeader"];
 
  DFPeanutSearchObject *sectionObject = self.sectionObjects[section];
  headerView.titleLabel.text = sectionObject.title;
  headerView.subtitleLabel.text = sectionObject.subtitle;
  
  return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
  return HeaderHeight;
}

#pragma mark - Table view data source: rows

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return self.sectionObjects.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  if ([self isSectionLocked:self.sectionObjects[section]]) {
    return 1;
  }
  
  NSArray *items = [self itemsForSectionIndex:section];
  return items.count;
}

- (NSArray *)itemsForSectionIndex:(NSInteger)index
{
  if (index >= self.sectionObjects.count) return nil;
  DFPeanutSearchObject *sectionObject = self.sectionObjects[index];
  NSArray *items = sectionObject.objects;
  return items;
}

- (DFPeanutSearchObject *)representativePhotoForIndexPath:(NSIndexPath *)indexPath
{
  NSArray *itemsForSection = [self itemsForSectionIndex:indexPath.section];
  DFPeanutSearchObject *object = itemsForSection[indexPath.row];
  
  if ([object.type isEqual:DFSearchObjectPhoto]) {
    return object;
  } else if ([object.type isEqual:DFSearchObjectCluster]) {
    return [object.objects firstObject];
  }
  
  return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell;

  DFPeanutSearchObject *section = self.sectionObjects[indexPath.section];
  NSArray *itemsForSection = section.objects;
  DFPeanutSearchObject *object = itemsForSection[indexPath.row];
  
  if ([self isSectionLocked:section]) {
    DFLockedStrandCell *lockedCell = [tableView dequeueReusableCellWithIdentifier:@"lockedCell"
                                                                     forIndexPath:indexPath];
    cell = lockedCell;
    [lockedCell setImages:@[]];
    for (DFPeanutSearchObject *object in section.objects) {
      [[DFImageStore sharedStore]
       imageForID:object.id
       preferredType:DFImageThumbnail
       thumbnailPath:object.thumb_image_path
       fullPath:object.full_image_path
       completion:^(UIImage *image) {
         dispatch_async(dispatch_get_main_queue(), ^{
           if (![tableView.visibleCells containsObject:lockedCell]) return;
           [lockedCell addImage:image];
           [lockedCell setNeedsLayout];
         });
       }];
    }
  } else if ([object.type isEqual:DFSearchObjectPhoto]) {
    DFPhotoFeedCell *photoFeedCell = [tableView dequeueReusableCellWithIdentifier:@"photoCell"
                                           forIndexPath:indexPath];
    cell = photoFeedCell;
    photoFeedCell.delegate = self;
    [photoFeedCell setObjects:@[@(object.id)]];
    [photoFeedCell setClusterViewHidden:YES];
    [DFPhotoFeedController configureNonImageAttributesForCell:photoFeedCell
                                                 searchObject:object];
    UIImage *image = self.imageCache[indexPath];
    if (image) {
      [photoFeedCell setImage:image forObject:@(object.id)];
    } else {
      photoFeedCell.imageView.image = nil;
      [photoFeedCell.loadingActivityIndicator startAnimating];
      
      if (object) {
        [[DFImageStore sharedStore]
         imageForID:object.id
         preferredType:DFImageFull
         thumbnailPath:object.thumb_image_path
         fullPath:object.full_image_path
         completion:^(UIImage *image) {
           if (image) {
             self.imageCache[indexPath] = image;
           }
           dispatch_async(dispatch_get_main_queue(), ^{
             if (![tableView.visibleCells containsObject:photoFeedCell]) return;
             [photoFeedCell setImage:image forObject:@(object.id)];
             [photoFeedCell.loadingActivityIndicator stopAnimating];
             [photoFeedCell setNeedsLayout];
           });
         }];
      }
    }
  } else if ([object.type isEqual:DFSearchObjectCluster]) {
    DFPhotoFeedCell *photoFeedCell = [tableView dequeueReusableCellWithIdentifier:@"clusterCell"
                                    forIndexPath:indexPath];
    cell = photoFeedCell;
    photoFeedCell.delegate = self;
    [photoFeedCell setClusterViewHidden:NO];
    [photoFeedCell setObjects:[DFPhotoFeedController objectIDNumbers:object.objects]];
    [DFPhotoFeedController configureNonImageAttributesForCell:photoFeedCell
                                                 searchObject:[object.objects firstObject]];
    for (DFPeanutSearchObject *subObject in object.objects) {
      [[DFImageStore sharedStore]
       imageForID:subObject.id
       preferredType:DFImageFull
       thumbnailPath:subObject.thumb_image_path
       fullPath:subObject.full_image_path
       completion:^(UIImage *image) {
         dispatch_async(dispatch_get_main_queue(), ^{
           if (![tableView.visibleCells containsObject:photoFeedCell]) return;
           [photoFeedCell setImage:image forObject:@(subObject.id)];
           [photoFeedCell setNeedsLayout];
         });
       }];
    }
  }

  cell.selectionStyle = UITableViewCellSelectionStyleNone;
  [cell setNeedsLayout];
  return cell;
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
  CGFloat rowHeight = MinRowHeight;
  
  DFPeanutSearchObject *sectionObject = self.sectionObjects[indexPath.section];
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
  _imageCache = [NSMutableDictionary new];
  
  [self.tableView reloadData];
}

#pragma mark - Actions

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutSearchObject *object = [[self.sectionObjects[indexPath.section] objects] objectAtIndex:indexPath.row];
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
      
      [DFAnalytics logPhotoLikePressedWithNewValue:(newAction != nil)
                                            result:DFAnalyticsValueResultSuccess
                                        actionType:wasGesture ? DFActionDoubleTap : DFActionButtonPress];
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
                                        actionType:wasGesture ? DFActionDoubleTap : DFActionButtonPress];
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
  [self.photoAdapter deletePhoto:self.actionSheetPhotoID completionBlock:^(NSError *error) {
    if (!error) {
      [self reloadFeed];
      
      // remove it from the db
      [[DFPhotoStore sharedStore] deletePhotoWithPhotoID:self.actionSheetPhotoID];
      [DFAnalytics logPhotoDeletedWithResult:DFAnalyticsValueResultSuccess];
    } else {
      dispatch_async(dispatch_get_main_queue(), ^{
        [UIAlertView
         showSimpleAlertWithTitle:@"Error"
         message:[[NSString stringWithFormat:@"Sorry, an error occurred: %@",
                   error.localizedRecoverySuggestion ?
                   error.localizedRecoverySuggestion : error.localizedDescription] substringToIndex:200]];
        [DFAnalytics logPhotoDeletedWithResult:DFAnalyticsValueResultFailure];
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

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  // This is a hack to prevent the table view from shifting when the Status bar is hidden and shown
  if (object == self.tableView) {
    if (self.tableView.frame.origin.y == 44.0) {
      self.tableView.frame = CGRectMake(self.tableView.frame.origin.x,
                                        64.0,
                                        self.tableView.frame.size.width,
                                        self.tableView.frame.size.height);
    }
  }
}

@end
