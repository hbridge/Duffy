//
//  DFStrandsViewController.m
//  Strand
//
//  Created by Henry Bridge on 8/15/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "WYPopoverController.h"
#import "RootViewController.h"

#import "DFBadgeButton.h"
#import "DFErrorScreen.h"
#import "DFNavigationController.h"
#import "DFNotificationSharedConstants.h"
#import "DFPeanutStrandFeedAdapter.h"
#import "DFPeanutNotificationsManager.h"
#import "DFPeanutFeedObject.h"
#import "DFPhotoStore.h"
#import "DFSettingsViewController.h"
#import "DFStrandsViewController.h"
#import "DFPushNotificationsManager.h"
#import "DFStrandConstants.h"
#import "DFToastNotificationManager.h"
#import "DFUploadController.h"
#import "DFStrandSuggestionsViewController.h"
#import "AppDelegate.h"


const NSTimeInterval FeedChangePollFrequency = 60.0;

@interface DFStrandsViewController ()

@property (readonly, nonatomic, retain) DFPeanutStrandFeedAdapter *feedAdapter;
@property (nonatomic, retain) NSData *lastResponseHash;
@property (nonatomic, retain) NSTimer *autoRefreshTimer;

@property (nonatomic, retain) DFBadgeButton *notificationsBadgeButton;
@property (nonatomic, retain) WYPopoverController *notificationsPopupController;

@property (nonatomic, retain) UIView *connectionErrorPlaceholder;
@property (nonatomic, retain) UIView *nuxPlaceholder;

@property (nonatomic) DFFeedType feedType;

@end

@implementation DFStrandsViewController

@synthesize feedAdapter = _feedAdapter;


- (instancetype)initWithFeedType:(DFFeedType)feedType
{
  self = [super init];
  if (self) {
    _feedType = feedType;
    [self configureView];
    [self observeNotifications];
  }
  return self;
}

- (instancetype)init
{
  self = [self initWithFeedType:strandsFeed];
  if (self) {
   
  }
  return self;
}

- (void)configureView
{
  [self configureNavigationItem];
}

- (void)configureNavigationItem
{
  UILabel *titleLabel = [[UILabel alloc] init];
  titleLabel.text = @"Strand";
  titleLabel.font = [UIFont boldSystemFontOfSize:17.0];
  titleLabel.textColor = [UIColor whiteColor];
  [titleLabel sizeToFit];
  self.navigationItem.titleView = titleLabel;
  
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                            initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                            target:self
                                            action:@selector(createStrandButtonPressed:)];
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
                                           selector:@selector(reloadFeedSilently)
                                               name:DFStrandReloadRemoteUIRequestedNotificationName
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
                                               name:DFStrandCameraPhotoSavedNotificationName
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
  [self reloadFeedSilently];
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
                                     selector:@selector(reloadFeedSilently)
                                     userInfo:nil
                                      repeats:YES];
  }
  
  // if the user has real content in their feed, prompt for push notifications
  NSString *firstSectionTitle = [(DFPeanutFeedObject *)self.strandObjects.firstObject title];
  if (self.strandObjects.count > 1 ||
      (self.strandObjects.count == 1 && ![firstSectionTitle isEqualToString:@"Locked"])) {
    [[DFPushNotificationsManager sharedManager] promptForPushNotifsIfNecessary];
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
    [self refreshView:NO];
  });
}

/*
 * Refresh the current view.  Very cheap and fast.
 * Figures out if there's any photos currently being processed, to be shown in the uploading bar
 * Then calls the child view to re-render
 */
- (void)refreshView:(BOOL)withNewServerData
{
  BOOL newData = withNewServerData;
  NSArray *unprocessedFeedPhotos = [self unprocessedFeedPhotos:self.strandObjects];
  
  if (![self.uploadingPhotos isEqualToArray:unprocessedFeedPhotos]) {
    self.uploadingPhotos = unprocessedFeedPhotos;
    DDLogDebug(@"Setting uploaded photos to count %lu", (unsigned long)self.uploadingPhotos.count);
    newData = YES;
  }
  
  if (self.delegate && newData) {
    DDLogInfo(@"Refreshing the view.");
    [self.delegate strandsViewControllerUpdatedData:self];
  }
}

#pragma mark - Strand data fetching

- (void)reloadFeed
{
  [self reloadFeedIsSilent:NO];
}

- (void)reloadFeedSilently
{
  [self reloadFeedIsSilent:YES];
}

- (void)reloadFeedIsSilent:(BOOL)isSilent
{
  if (self.feedType == strandsFeed) {
    [self.feedAdapter fetchGalleryWithCompletionBlock:[self fetchCompleteBlock:isSilent]];
  } else if (self.feedType == activityFeed) {
    [self.feedAdapter fetchStrandActivityWithCompletion:[self fetchCompleteBlock:isSilent]];
  }
  [[DFUploadController sharedUploadController] uploadPhotos];
}

- (DFPeanutObjectsCompletion)fetchCompleteBlock:(BOOL)isSilent
{
  return ^(DFPeanutObjectsResponse *response,
           NSData *hashData,
           NSError *error) {
    dispatch_async(dispatch_get_main_queue(), ^{
      BOOL newServerData = NO;
      
      if (!error) {
        // Remove error screen incase it was showing
        [self setShowConnectionError:NO withError:nil];
        
        // See if we have have existing data, if not, show the NUX screen
        if (response.objects.count == 0 && self.uploadingPhotos.count == 0) {
          [self setShowNuxPlaceholder:YES];
        } else {
          [self setShowNuxPlaceholder:NO];
        }
        
        if ((response.objects.count > 0 && ![hashData isEqual:self.lastResponseHash])) {
          DDLogInfo(@"%@ new feed data received from server", self.class);
          // We have data, so remove the NUX screen
          [self setShowNuxPlaceholder:NO];
          
          // Update the objects, the child views use this
          [self setStrandObjects:response.topLevelSectionObjects];
          self.inviteObjects = [response topLevelObjectsOfType:DFFeedObjectInviteStrand];
          self.lastResponseHash = hashData;
          newServerData = YES;
        }
      } else {
        DDLogInfo(@"Error when trying to get feed from server");
        // Upon any error, we want to hide the NUX page
        [self setShowNuxPlaceholder:NO];
        
        // If there's no data, show a nice message on the screen instead of a dropdown
        if (self.strandObjects.count == 0) {
          [self setShowConnectionError:YES withError:error];
        } else if (!isSilent) {
          // If there is data, then show a dropdown if it wasn't a silent reload
          [[DFToastNotificationManager sharedInstance]
           showErrorWithTitle:@"Couldn't Reload Feed" subTitle:error.localizedDescription];
        }
      }
      
      [self refreshView:newServerData];
      [self.delegate strandsViewController:self didFinishServerFetchWithError:error];
    });
  };
}

- (NSArray *)unprocessedFeedPhotos:(NSArray *)sectionObjects
{
  DFPhotoCollection *unprocessedCollection = [[DFPhotoStore sharedStore]
                                              photosWithUploadProcessedStatus:NO
                                              shouldUploadImage:YES];
  NSMutableSet *allPhotoIDsInFeed = [NSMutableSet new];
  for (DFPeanutFeedObject *section in sectionObjects) {
    for (DFPeanutFeedObject *object in [[section enumeratorOfDescendents] allObjects]) {
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

- (void)setStrandObjects:(NSArray *)sectionObjects
{
  NSMutableDictionary *objectsByID = [NSMutableDictionary new];
  NSMutableDictionary *indexPathsByID = [NSMutableDictionary new];
  
  for (NSUInteger sectionIndex = 0; sectionIndex < sectionObjects.count; sectionIndex++) {
    NSArray *objectsForSection = [sectionObjects[sectionIndex] objects];
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
  
  _objectsByID = objectsByID;
  _indexPathsByID = indexPathsByID;
  _strandObjects = sectionObjects;
}


- (void)setShowConnectionError:(BOOL)isShown withError:(NSError *)error
{
  [self.connectionErrorPlaceholder removeFromSuperview];
  if (isShown) {
    DFErrorScreen *errorScreen = [[[UINib nibWithNibName:@"DFErrorScreen" bundle:nil]
                                   instantiateWithOwner:self options:nil] firstObject];
    errorScreen.textView.text = error.localizedDescription;
    self.connectionErrorPlaceholder = errorScreen;
    [self.view addSubview:self.connectionErrorPlaceholder];
  } else {
    self.connectionErrorPlaceholder = nil;
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

#pragma mark - Navbar Action Handlers


- (void)createButtonPressed:(id)sender
{
  DDLogInfo(@"Create button pressed");
  DFStrandSuggestionsViewController *createController = [DFStrandSuggestionsViewController sharedViewController];
  createController.showAsFirstTimeSetup = NO;
  DFNavigationController *navController = [[DFNavigationController
                                            alloc] initWithRootViewController:createController];
  
  [self presentViewController:navController animated:YES completion:nil];
}

- (void)titleButtonPressed:(UIButton *)button
{
  DDLogVerbose(@"Title button pressed");
  DFNotificationsViewController *notifsViewController = [DFNotificationsViewController new];
  notifsViewController.delegate = self;
  UINavigationController *navController = [[UINavigationController alloc]
                                           initWithRootViewController:notifsViewController];
  
  self.notificationsPopupController = [[WYPopoverController alloc]
                                       initWithContentViewController:navController];
  [self.notificationsPopupController beginThemeUpdates];
  self.notificationsPopupController.theme.viewContentInsets = UIEdgeInsetsMake(0, 2, 0, 2);
  [self.notificationsPopupController endThemeUpdates];
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
  [self showPhoto:photoID animated:YES];
  [self.notificationsPopupController dismissPopoverAnimated:YES];
}

- (void)showPhoto:(DFPhotoIDType)photoId animated:(BOOL)animated
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
                     [self reloadFeedSilently];
                   });
  }
}

- (void)notificationsChanged:(NSNotification *)note
{
  NSNumber *unreadCount = note.userInfo[DFStrandNotificationsUnseenCountKey];
  self.notificationsBadgeButton.badgeCount = unreadCount.intValue;
}

#pragma mark - Network controllers

- (DFPeanutStrandFeedAdapter *)feedAdapter
{
  if (!_feedAdapter) {
    _feedAdapter = [[DFPeanutStrandFeedAdapter alloc] init];
  }
  
  return _feedAdapter;
}

- (void)settingsButtonPressed:(id)sender
{
  DFSettingsViewController *svc = [[DFSettingsViewController alloc] init];
  [self presentViewController:[[DFNavigationController alloc] initWithRootViewController:svc]
                     animated:YES
                   completion:nil];
}

- (IBAction)createStrandButtonPressed:(id)sender {
  DFStrandSuggestionsViewController *vc = [DFStrandSuggestionsViewController sharedViewController];
  vc.showAsFirstTimeSetup = NO;
  
  [self presentViewController:[[DFNavigationController alloc] initWithRootViewController:vc]
                     animated:YES completion:nil];
}


@end
