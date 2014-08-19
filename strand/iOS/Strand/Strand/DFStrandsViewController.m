//
//  DFStrandsViewController.m
//  Strand
//
//  Created by Henry Bridge on 8/15/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFStrandsViewController.h"
#import "DFStrandConstants.h"
#import "DFBadgeButton.h"
#import "DFPeanutNotificationsManager.h"
#import "WYPopoverController.h"
#import "RootViewController.h"
#import "DFSettingsViewController.h"
#import "DFNavigationController.h"
#import "DFInviteUserViewController.h"
#import "DFPeanutGalleryAdapter.h"
#import "DFPhotoStore.h"
#import "DFPeanutSearchObject.h"
#import "DFUploadController.h"
#import "DFNotificationSharedConstants.h"
#import "DFStrandsViewController.h"

const NSTimeInterval FeedChangePollFrequency = 60.0;

@interface DFStrandsViewController ()

@property (readonly, nonatomic, retain) DFPeanutGalleryAdapter *galleryAdapter;
@property (nonatomic, retain) NSData *lastResponseHash;
@property (nonatomic, retain) NSTimer *autoRefreshTimer;

@property (nonatomic, retain) DFBadgeButton *notificationsBadgeButton;
@property (nonatomic, retain) WYPopoverController *notificationsPopupController;

@end

@implementation DFStrandsViewController

@synthesize galleryAdapter = _galleryAdapter;

- (instancetype)init
{
  self = [super init];
  if (self) {
    [self configureView];
    [self observeNotifications];
  }
  return self;
}

- (void)configureView
{
  [self configureNavigationItem];
}

- (void)configureNavigationItem
{
  // notification button
  self.notificationsBadgeButton = [[DFBadgeButton alloc] init];
  UIImage *image = [[UIImage imageNamed:@"Assets/Icons/NotificationsBarButton"]
                    imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  [self.notificationsBadgeButton setImage:image
                                 forState:UIControlStateNormal];
  self.notificationsBadgeButton.badgeEdgeInsets = UIEdgeInsetsMake(2, 0, 0, 6);
  self.notificationsBadgeButton.badgeColor = [UIColor colorWithRed:74/255.0 green:144/255.0 blue:226/255.0 alpha:1.0];
  self.notificationsBadgeButton.badgeTextColor = [DFStrandConstants defaultBarForegroundColor];
  self.notificationsBadgeButton.badgeCount = (int)[[[DFPeanutNotificationsManager sharedManager]
                                                    unreadNotifications] count];
  [self.notificationsBadgeButton addTarget:self
                                    action:@selector(titleButtonPressed:)
                          forControlEvents:UIControlEventTouchUpInside];
  
  self.navigationItem.titleView = self.notificationsBadgeButton;
  [self.notificationsBadgeButton sizeToFit];
  
  // other buttons
  if (!(self.navigationItem.rightBarButtonItems.count > 0)) {
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
    
    self.navigationItem.rightBarButtonItems = @[cameraButton, inviteButton];
  }
}

- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(viewDidBecomeActive)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(viewDidBecomeInactive)
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
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(notificationsChanged:)
                                               name:DFStrandNotificationsUpdatedNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(refreshView)
                                               name:DFStrandPhotoSavedNotificationName
                                             object:nil];
}

#pragma mark - View Controller lifetime methods


- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self reloadFeed];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [[DFUploadController sharedUploadController] uploadPhotos];
  [self viewDidBecomeActive];
}

- (void)viewDidBecomeActive
{
  if (self.isViewLoaded && self.view.window) {
    if (!self.autoRefreshTimer)
      self.autoRefreshTimer =
      [NSTimer scheduledTimerWithTimeInterval:FeedChangePollFrequency
                                       target:self
                                     selector:@selector(autoReloadFeed)
                                     userInfo:nil
                                      repeats:YES];
  }
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

/*
 * Refresh the view without a network call.  Cheap and fast but this always redraws the view
 * This should be called after a photo is taken for instance since we don't need to refresh the feed
 *
 * For methods that fetch the feed from the server, call reloadFeed
 */
- (void)refreshView
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [self refreshView:YES isSlient:YES error:nil];
  });
}

/*
 * Refresh the current view.  Very cheap and fast.
 * Only calls the child view to re-render
 */
- (void)refreshView:(BOOL)withNewData
           isSlient:(BOOL)isSilent
              error:(NSError *)error
{
  BOOL newData = withNewData;
  NSArray *unprocessedFeedPhotos = [self unprocessedFeedPhotos:self.sectionObjects];
  
  if (![self.uploadingPhotos isEqualToArray:unprocessedFeedPhotos]) {
    self.uploadingPhotos = unprocessedFeedPhotos;
    NSLog(@"Setting uploaded photos to count %d", self.uploadingPhotos.count);
    newData = YES;
  }
  
  if (self.delegate) {
    DDLogInfo(@"Refreshing the view.");
    [self.delegate strandsViewController:self
             didFinishRefreshWithNewData:newData
                                isSilent:isSilent
                                   error:error];
  }
}

#pragma mark - Strand data fetching

- (void)reloadFeed
{
  [self reloadFeedIsSilent:NO];
}

- (void)reloadFeedIsSilent:(BOOL)isSilent
{
  [self.galleryAdapter fetchGalleryWithCompletionBlock:^(DFPeanutSearchResponse *response,
                                                         NSData *hashData,
                                                         NSError *error) {
    dispatch_async(dispatch_get_main_queue(), ^{
      BOOL newData = NO;
      if (!error) {
        if ((response.objects.count > 0 && ![hashData isEqual:self.lastResponseHash])) {
          DDLogInfo(@"New feed data detected.");
          [self setSectionObjects:response.topLevelSectionObjects];
          self.lastResponseHash = hashData;
          newData = YES;
        }
      }
      [self refreshView:newData isSlient:isSilent error:error];
    });
  }];
  
  [[DFUploadController sharedUploadController] uploadPhotos];
}

- (void)autoReloadFeed
{
  [self reloadFeedIsSilent:YES];
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
}


#pragma mark - Navbar Action Handlers

- (void)cameraButtonPressed:(id)sender
{
  [(RootViewController *)self.view.window.rootViewController showCamera];
}

- (void)inviteButtonPressed:(id)sender
{
  DDLogInfo(@"Invite button pressed");
  DFInviteUserViewController *inviteController = [[DFInviteUserViewController alloc] init];
  [self presentViewController:inviteController animated:YES completion:nil];
}

- (void)titleButtonPressed:(UIButton *)button
{
  DDLogVerbose(@"Title button pressed");
  DFNotificationsViewController *notifsViewController = [DFNotificationsViewController new];
  notifsViewController.delegate = self;
  
  self.notificationsPopupController = [[WYPopoverController alloc] initWithContentViewController:notifsViewController];
  self.notificationsPopupController.delegate = self;
  [self.notificationsPopupController presentPopoverFromRect:button.bounds
                                                     inView:button
                                   permittedArrowDirections:WYPopoverArrowDirectionAny
                                                   animated:YES];
}


- (BOOL)popoverControllerShouldDismissPopover:(WYPopoverController *)controller
{
  return YES;
}

- (void)popoverControllerDidDismissPopover:(WYPopoverController *)controller
{
  self.notificationsPopupController.delegate = nil;
  self.notificationsPopupController = nil;
}

- (void)notificationViewController:(DFNotificationsViewController *)notificationViewController
  didSelectNotificationWithPhotoID:(DFPhotoIDType)photoID
{
  [self showPhoto:photoID];
//  NSIndexPath *indexPath = self.indexPathsByID[@(photoID)];
//  [self.tableView scrollToRowAtIndexPath:indexPath
//                        atScrollPosition:UITableViewScrollPositionTop
//                                animated:YES];
//  [self.notificationsPopupController dismissPopoverAnimated:YES];
}

- (void)showPhoto:(DFPhotoIDType)photoId
{
  // abstract method
}

#pragma mark - Notification Center handlers

- (void)uploadStatusChanged:(NSNotification *)note
{
  DFUploadSessionStats *uploadStats = note.userInfo[DFUploadStatusUpdateSessionUserInfoKey];
  if (!uploadStats.fatalError) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                     [self reloadFeed];
                   });
  }
}

- (void)notificationsChanged:(NSNotification *)note
{
  NSNumber *unreadCount = note.userInfo[DFStrandNotificationsUnseenCountKey];
  self.notificationsBadgeButton.badgeCount = unreadCount.intValue;
}

#pragma mark - Network controllers

- (DFPeanutGalleryAdapter *)galleryAdapter
{
  if (!_galleryAdapter) {
    _galleryAdapter = [[DFPeanutGalleryAdapter alloc] init];
  }
  
  return _galleryAdapter;
}

- (void)settingsButtonPressed:(id)sender
{
  DFSettingsViewController *svc = [[DFSettingsViewController alloc] init];
  [self presentViewController:[[DFNavigationController alloc] initWithRootViewController:svc]
                     animated:YES
                   completion:nil];
}


@end
