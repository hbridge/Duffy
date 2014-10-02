//
//  DFCreateStrandViewController.m
//  Strand
//
//  Created by Henry Bridge on 8/28/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCreateStrandViewController.h"
#import "DFCameraRollSyncManager.h"
#import "DFPeanutStrandFeedAdapter.h"
#import "DFPhotoViewCell.h"
#import "DFPeanutFeedObject.h"
#import "DFPhotoStore.h"
#import "DFGallerySectionHeader.h"
#import "DFCreateStrandTableViewCell.h"
#import "DFPeanutFeedObject.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "DFSelectPhotosViewController.h"
#import "DFPeanutStrandInviteAdapter.h"
#import "DFPeanutStrandAdapter.h"
#import "DFImageStore.h"
#import "NSString+DFHelpers.h"
#import "DFStrandConstants.h"
#import "DFPeanutUserObject.h"
#import "DFInboxTableViewCell.h"
#import "UIDevice+DFHelpers.h"
#import "NSArray+DFHelpers.h"

const CGFloat CreateCellWithTitleHeight = 192;
const CGFloat CreateCellTitleHeight = 20;
const CGFloat CreateCellTitleSpacing = 8;


@interface DFCreateStrandViewController ()

@property (readonly, nonatomic, retain) DFPeanutStrandFeedAdapter *feedAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandInviteAdapter *inviteAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandAdapter *strandAdapter;

@property (nonatomic, retain) DFPeanutObjectsResponse *allObjectsResponse;
@property (nonatomic, retain) NSArray *inviteObjects;
@property (nonatomic, retain) NSMutableArray *suggestionObjects;
@property (nonatomic, retain) NSMutableArray *noFriendSuggestions;

@property (nonatomic, retain) NSData *lastResponseHash;
@property (nonatomic, retain) NSMutableDictionary *cellHeightsByIdentifier;
@property (nonatomic, retain) NSTimer *refreshTimer;
@property (atomic, retain) NSTimer *showReloadButtonTimer;

@end

@implementation DFCreateStrandViewController
@synthesize feedAdapter = _feedAdapter;
@synthesize inviteAdapter = _inviteAdapter;
@synthesize strandAdapter = _strandAdapter;
@synthesize showAsFirstTimeSetup = _showAsFirstTimeSetup;

static DFCreateStrandViewController *instance;
- (IBAction)reloadButtonPressed:(id)sender {
  [self.allTableView reloadData];
  [self.suggestedTableView reloadData];
  self.allTableView.contentOffset = CGPointZero;
  self.suggestedTableView.contentOffset = CGPointZero;
  [self setReloadButtonHidden:YES];
}

- (IBAction)segmentedControlValueChanged:(UISegmentedControl *)sender {
  if (sender.selectedSegmentIndex == 0) { // suggestions
    self.suggestedTableView.hidden = NO;
    self.allTableView.hidden = YES;
  } else {
    self.suggestedTableView.hidden = YES;
    self.allTableView.hidden = NO;
  }
}

+ (DFCreateStrandViewController *)sharedViewController
{
  if (!instance) {
    instance = [[DFCreateStrandViewController alloc] init];
  }
  return instance;
}

- (instancetype)init
{
  self = [super initWithNibName:[self.class description] bundle:nil];
  if (self) {
    _showAsFirstTimeSetup = NO;
    [self configureNavAndTab];
    
    [self observeNotifications];
    self.tabBarItem.selectedImage = [[UIImage imageNamed:@"Assets/Icons/CreateStrandBarButton"]
                                     imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.tabBarItem.image = [[UIImage imageNamed:@"Assets/Icons/CreateStrandBarButton"]
                             imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
  }
  return self;
}

- (void)configureNavAndTab
{
  self.navigationItem.title = @"Share Photos";
  self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]
                                           initWithTitle:@"Back"
                                           style:UIBarButtonItemStylePlain
                                           target:nil
                                           action:nil];
  self.tabBarItem.selectedImage = [[UIImage imageNamed:@"Assets/Icons/CreateBarButton"]
                                   imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  self.tabBarItem.image = [[UIImage imageNamed:@"Assets/Icons/CreateBarButton"]
                           imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];

}

NSString *const InviteId = @"invite";
NSString *const SuggestionWithPeopleId = @"suggestionWithPeople";
NSString *const SuggestionNoPeopleId = @"suggestionNoPeople";


- (void)configureTableView
{
  self.cellHeightsByIdentifier = [NSMutableDictionary new];
  
  NSMutableArray *refreshControls = [NSMutableArray new];
  
  NSArray *tableViews = @[self.suggestedTableView, self.allTableView];
  for (UITableView *tableView in tableViews) {
    [tableView registerNib:[UINib nibWithNibName:@"DFCreateStrandTableViewCell" bundle:nil]
         forCellReuseIdentifier:InviteId];
    [tableView registerNib:[UINib nibWithNibName:@"DFCreateStrandTableViewCell" bundle:nil]
         forCellReuseIdentifier:SuggestionWithPeopleId];
    [tableView registerNib:[UINib nibWithNibName:@"DFCreateStrandTableViewCell" bundle:nil]
    forCellReuseIdentifier:SuggestionNoPeopleId];
    
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self
                       action:@selector(refreshFromServer)
             forControlEvents:UIControlEventValueChanged];
    
    UITableViewController *mockTVC = [[UITableViewController alloc] init];
    mockTVC.tableView = tableView;
    mockTVC.refreshControl = refreshControl;
    [refreshControls addObject:refreshControl];
    
    tableView.sectionHeaderHeight = 0.0;
    tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, tableView.bounds.size.width, 0.01f)];

  }
  
  self.refreshControls = refreshControls;
  [self.refreshControl beginRefreshing];
}

- (UIRefreshControl *)refreshControl
{
  return self.refreshControls[self.segmentedControl.selectedSegmentIndex];
}


- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(refreshFromServer)
                                               name:DFStrandReloadRemoteUIRequestedNotificationName
                                             object:nil];
}


- (void)viewDidLoad
{
  [super viewDidLoad];
  [self configureTableView];
  [self refreshFromServer];
  [self configureReloadButton];
  [self configureSegmentView];
}

- (void)configureReloadButton
{
  self.reloadBackground.layer.cornerRadius = 5.0;
  self.reloadBackground.layer.masksToBounds = YES;
}

- (void)configureSegmentView
{
  self.segmentWrapper.backgroundColor = [DFStrandConstants defaultBackgroundColor];
  self.segmentedControl.tintColor = [DFStrandConstants defaultBarForegroundColor];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  
  UINavigationBar *navigationBar = self.navigationController.navigationBar;
  
  [navigationBar setBackgroundImage:[UIImage new]
                     forBarPosition:UIBarPositionAny
                         barMetrics:UIBarMetricsDefault];
  
  [navigationBar setShadowImage:[UIImage new]];
  
  [self.allTableView reloadData];
  [self.suggestedTableView reloadData];
  [self refreshFromServer];
  if (self.navigationController.isBeingPresented) {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                             initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                             target:self
                                             action:@selector(cancelPressed:)];
  }
}

- (void)viewDidAppear:(BOOL)animated
{
  if (self.showAsFirstTimeSetup && !self.refreshTimer && self.allObjectsResponse.objects.count == 0) {
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                         target:self
                                                       selector:@selector(refreshFromServer)
                                                       userInfo:nil
                                                        repeats:YES];
    [self.refreshControl beginRefreshing];
  }
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [self.refreshTimer invalidate];
  self.refreshTimer = nil;
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)setShowAsFirstTimeSetup:(BOOL)showAsFirstTimeSetup
{
  _showAsFirstTimeSetup = showAsFirstTimeSetup;
  
  // Fetch the invites since we may not have before
  if (showAsFirstTimeSetup) [self refreshInvitesFromServer];
  
  // Redraw the controller since we might have changed what is shown
  dispatch_async(dispatch_get_main_queue(), ^{
    [self reloadData];
  });
}


#pragma mark - UITableView Data/Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [[self sectionObjectsForSection:section tableView:tableView] count];
}

- (NSArray *)sectionObjectsForSection:(NSUInteger)section tableView:(UITableView *)tableView
{
  if (tableView == self.suggestedTableView) {
    return self.suggestionObjects;
  } else {
    return self.allObjectsResponse.objects;
  }
}

- (BOOL)shouldShowInvites
{
  if (self.showAsFirstTimeSetup && self.inviteObjects.count > 0) {
    return YES;
  }
  
  return NO;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell;
  DFPeanutFeedObject *feedObject = [self sectionObjectsForSection:indexPath.section tableView:tableView][indexPath.row];
  cell = [self cellWithSuggestedStrandObject:feedObject forTableView:tableView];
  
  return cell;
}

- (UITableViewCell *)cellWithSuggestedStrandObject:(DFPeanutFeedObject *)strandObject
                                      forTableView:(UITableView *)tableView
{
  DFCreateStrandTableViewCell *cell;
  if (strandObject.actors.count > 0) {
    cell = [tableView dequeueReusableCellWithIdentifier:SuggestionWithPeopleId];
    [cell configureWithStyle:DFCreateStrandCellStyleSuggestionWithPeople];
  } else {
    cell = [tableView dequeueReusableCellWithIdentifier:SuggestionNoPeopleId];
    [cell configureWithStyle:DFCreateStrandCellStyleSuggestionNoPeople];
  }
  
  [self configureTextForCreateStrandCell:cell withStrand:strandObject];
  [self setLocalPhotosForCell:cell section:strandObject];
  
  return cell;
}

- (void)configureTextForCreateStrandCell:(DFCreateStrandTableViewCell *)cell
                       withStrand:(DFPeanutFeedObject *)strandObject
{
  // Set the header attributes
  NSMutableString *actorString = [NSMutableString new];
    for (DFPeanutUserObject *user in strandObject.actors) {
    if (user != strandObject.actors.firstObject) [actorString appendString:@", "];
    [actorString appendString:user.display_name];
  }
  
  cell.peopleLabel.text = actorString;
  
  // context label "Date in Location"
  NSMutableString *contextString = [NSMutableString new];
  [contextString appendString:[NSDateFormatter relativeTimeStringSinceDate:strandObject.time_taken
                                                                abbreviate:NO]];
  [contextString appendFormat:@" in %@", strandObject.location];
  cell.contextLabel.text = contextString;
  
  NSInteger count = strandObject.objects.count - MaxPhotosPerCell;
  if (count > 0) {
    cell.countBadgeBackground.hidden = NO;
    cell.countBadge.elementAbbreviation = [NSString stringWithFormat:@"+%d", (int)count];
  } else {
    cell.countBadgeBackground.hidden = YES;
  }
}

- (void)setRemotePhotosForCell:(DFCreateStrandTableViewCell *)cell
                   withSection:(DFPeanutFeedObject *)section
{
  NSMutableArray *photoIDs = [NSMutableArray new];
  NSMutableArray *photos = [NSMutableArray new];
  
  for (DFPeanutFeedObject *object in section.objects) {
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
  
  cell.objects = photoIDs;
  for (DFPeanutFeedObject *photoObject in photos) {
    [[DFImageStore sharedStore]
     imageForID:photoObject.id
     preferredType:DFImageThumbnail
     thumbnailPath:photoObject.thumb_image_path
     fullPath:photoObject.full_image_path
     completion:^(UIImage *image) {
       [cell setImage:image forObject:@(photoObject.id)];
     }];
  }
}


const NSUInteger MaxPhotosPerCell = 3;

- (void)setLocalPhotosForCell:(DFCreateStrandTableViewCell *)cell
                      section:(DFPeanutFeedObject *)section
{
  // Get the IDs of all the photos we want to show
  NSMutableArray *idsToShow = [NSMutableArray new];
  for (NSUInteger i = 0; i < MIN(MaxPhotosPerCell, section.objects.count); i++) {
    DFPeanutFeedObject *object = section.objects[i];
    if ([object.type isEqual:DFFeedObjectPhoto]) {
      [idsToShow addObject:@(object.id)];
      
    } else if ([object.type isEqual:DFFeedObjectCluster]) {
      DFPeanutFeedObject *repObject = object.objects.firstObject;
      [idsToShow addObject:@(repObject.id)];
    }
  }
  
  // Set the images for the collection view
  cell.objects = idsToShow;
  for (NSNumber *photoID in idsToShow) {
    DFPhoto *photo = [[DFPhotoStore sharedStore] photoWithPhotoID:photoID.longLongValue];
    if (photo) {
      CGFloat thumbnailSize;
      if ([UIDevice majorVersionNumber] >= 8) {
        // only use the larger thumbnails on iOS 8+, the scaling will kill perf on iOS7
        thumbnailSize = cell.collectionView.frame.size.height * [[UIScreen mainScreen] scale];
      } else {
        thumbnailSize = DFPhotoAssetDefaultThumbnailSize;
      }
        [photo.asset
         loadUIImageForThumbnailOfSize:thumbnailSize
         successBlock:^(UIImage *image) {
           [cell setImage:image forObject:photoID];
         } failureBlock:^(NSError *error) {
           DDLogError(@"%@ couldn't load image for asset: %@", self.class, error);
         }];
    }
  }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *feedObject = [self sectionObjectsForSection:indexPath.section tableView:tableView][indexPath.row];
  NSString *identifier;
  DFCreateStrandCellStyle style = DFCreateStrandCellStyleSuggestionWithPeople;
  if ([feedObject.type isEqual:DFFeedObjectInviteStrand]) {
    identifier = InviteId;
    style = DFCreateStrandCellStyleInvite;
  } else if ([feedObject.type isEqual:DFFeedObjectSection]) {
    if (feedObject.actors.count > 0) {
      identifier = SuggestionWithPeopleId;
      style = DFCreateStrandCellStyleSuggestionWithPeople;
    } else {
      identifier = SuggestionNoPeopleId;
      style = DFCreateStrandCellStyleSuggestionNoPeople;
    }
  }
  
  NSNumber *cachedHeight = self.cellHeightsByIdentifier[identifier];
  if (!cachedHeight) {
    DFCreateStrandTableViewCell *templateCell = [DFCreateStrandTableViewCell cellWithStyle:style];
    CGFloat height = [templateCell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
    self.cellHeightsByIdentifier[identifier] = cachedHeight = @(height);
  }
  return cachedHeight.floatValue;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSArray *feedObjectsForSection = [self sectionObjectsForSection:indexPath.section tableView:tableView];
  DFPeanutFeedObject *feedObject = feedObjectsForSection[indexPath.row];
  DFSelectPhotosViewController *selectController;
  if ([feedObject.type isEqualToString:DFFeedObjectInviteStrand]) {
    DFPeanutFeedObject *invitedStrandPosts = [[feedObject subobjectsOfType:DFFeedObjectSection]
                                              firstObject];
    DFPeanutFeedObject *suggestedPhotos = [[feedObject subobjectsOfType:DFFeedObjectSuggestedPhotos]
                                           firstObject];
    // this is an invite, the object that user selected represenets the shared photos
    // don't show the to field
    DFSelectPhotosViewController *selectController = [[DFSelectPhotosViewController alloc]
                                                      initWithTitle:@"Accept Invite"
                                                      showsToField:NO
                                                      suggestedSectionObject:suggestedPhotos
                                                      invitedStrandPosts:invitedStrandPosts
                                                      inviteObject:feedObject];
    selectController.inviteObject = feedObject;
    [self.navigationController pushViewController:selectController animated:YES];
  } else {
    // this is creating a new strand, the object they selected is a suggestion
    // we also want to show a to field to invite others
    selectController = [[DFSelectPhotosViewController alloc]
                        initWithTitle:@"Select Photos"
                        showsToField:YES
                        suggestedSectionObject:feedObject
                        invitedStrandPosts:nil
                        inviteObject:nil
                        ];
    [self.navigationController pushViewController:selectController animated:YES];
  }
}


#pragma mark - Actions

- (void)sync:(id)sender
{
  [[DFCameraRollSyncManager sharedManager] sync];
}


- (void)reloadData
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.allTableView reloadData];
    [self.suggestedTableView reloadData];
  });
}

- (void)refreshFromServer
{
  [self.feedAdapter fetchSuggestedStrandsWithCompletion:^(DFPeanutObjectsResponse *response,
                                                          NSData *responseHash,
                                                          NSError *error) {
    if (error) {
      DDLogError(@"%@ error fetching suggested strands:%@", self.class, error);
    } else {
      dispatch_async(dispatch_get_main_queue(), ^{
        if (![responseHash isEqual:self.lastResponseHash]) {
          DDLogDebug(@"New data for suggestions, updating view...");
          self.allObjectsResponse = response;
          
          self.suggestionObjects = [NSMutableArray new];
          for (DFPeanutFeedObject *object in response.objects) {
            
            if (object.suggestible.boolValue) [self.suggestionObjects addObject:object];
          }
          
          [self reloadTableViews];
          NSUInteger badgeCount = self.inviteObjects.count + self.suggestionObjects.count;
          self.tabBarItem.badgeValue = badgeCount > 0 ? [@(badgeCount) stringValue] : nil;
          
          self.lastResponseHash = responseHash;
        } else {
          DDLogDebug(@"Got back response for strand suggestions but it was the same");
        }
        [self.refreshControl endRefreshing];
      });
    }
  }];
  
}

- (void)reloadTableViews
{
  [self.suggestedTableView reloadData];
  [self.allTableView reloadData];
}

- (void)refreshInvitesFromServer
{
  [self.feedAdapter
   fetchInvitedStrandsWithCompletion:^(DFPeanutObjectsResponse *response,
                                       NSData *responseHash,
                                       NSError *error) {
     dispatch_async(dispatch_get_main_queue(), ^{
       NSArray *oldInvites = self.inviteObjects;
       self.inviteObjects = [response topLevelObjectsOfType:DFFeedObjectInviteStrand];
       if ([DFCreateStrandViewController inviteObjectsChangedForOldInvites:oldInvites
                                                                newInvites:self.inviteObjects])
       {
         [self.suggestedTableView reloadData];
         [self.allTableView reloadData];
       }
     });
   }];
}

+ (BOOL)inviteObjectsChangedForOldInvites:(NSArray *)oldInvites newInvites:(NSArray *)newInvites
{
  if (oldInvites.count != newInvites.count) return YES;
  for (NSUInteger i = 0; i < oldInvites.count; i++) {
    if (![newInvites[i] isEqual:oldInvites[i]]) return YES;
  }
  
  return NO;
}

- (void)setReloadButtonHidden:(BOOL)hidden
{
  if (hidden) {
    if (self.reloadBackground.hidden || self.reloadBackground.alpha == 0.0) return;
    [UIView animateWithDuration:0.7 animations:^{
      self.reloadBackground.alpha = 0.0;
    } completion:^(BOOL finished) {
      self.reloadBackground.hidden = YES;
    }];
  } else {
    self.reloadBackground.hidden = NO;
    self.reloadBackground.alpha = fmax(self.reloadBackground.alpha, 0.0);
    [UIView animateWithDuration:0.7 animations:^{
      self.reloadBackground.alpha = 1.0;
    }];
  }
}

- (void)showReloadButton
{
  [self setReloadButtonHidden:NO];
  self.showReloadButtonTimer = nil;
}

- (NSDictionary *)mapIDsToIPs:(DFPeanutObjectsResponse *)response
{
  NSMutableDictionary *IDsToIPs = [NSMutableDictionary new];
  for (NSUInteger i = 0; i < response.objects.count; i++) {
    DFPeanutFeedObject *object = response.objects[i];
    NSUInteger section = (object.actors.count > 0) ? 1 : 2;
    IDsToIPs[@(object.id)] = [NSIndexPath indexPathForRow:i inSection:section];
  }
  return IDsToIPs;
}

- (NSArray *)idsOfObjectsWithMetadataChanges:(DFPeanutObjectsResponse *)oldResponse
                                 newResponse:(DFPeanutObjectsResponse *)newResponse
{
  NSDictionary *oldIDsToTitles = [self mapIDsToTitles:oldResponse];
  NSDictionary *newIDsToTitles = [self mapIDsToTitles:newResponse];
  
  NSMutableArray *idsOfChangedObjects = [NSMutableArray new];
  for (NSNumber *idNum in oldIDsToTitles.allKeys) {
    if (![oldIDsToTitles[idNum] isEqual:newIDsToTitles[idNum]]) {
      [idsOfChangedObjects addObject:idNum];
    }
  }
  return idsOfChangedObjects;
}

- (NSDictionary *)mapIDsToTitles:(DFPeanutObjectsResponse *)response
{
  NSMutableDictionary *IDsToTitles = [NSMutableDictionary new];
  for (DFPeanutFeedObject *feedObject in response.objects) {
    IDsToTitles[@(feedObject.id)] = feedObject.title;
  }
  return IDsToTitles;
}

- (void)cancelPressed:(id)sender
{
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (DFPeanutStrandFeedAdapter *)feedAdapter
{
  if (!_feedAdapter) {
    _feedAdapter = [[DFPeanutStrandFeedAdapter alloc] init];
  }
  
  return _feedAdapter;
}
- (DFPeanutStrandInviteAdapter *)inviteAdapter
{
  if (!_inviteAdapter) {
    _inviteAdapter = [[DFPeanutStrandInviteAdapter alloc] init];
  }
  
  return _inviteAdapter;
}

- (DFPeanutStrandAdapter *)strandAdapter
{
  if (!_strandAdapter) {
    _strandAdapter = [[DFPeanutStrandAdapter alloc] init];
  }
  
  return _strandAdapter;
}

@end
