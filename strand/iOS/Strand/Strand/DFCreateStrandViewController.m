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
#import "DFActivityFeedTableViewCell.h"
#import "UIDevice+DFHelpers.h"
#import "NSArray+DFHelpers.h"

const CGFloat CreateCellWithTitleHeight = 192;
const CGFloat CreateCellTitleHeight = 20;
const CGFloat CreateCellTitleSpacing = 8;


@interface DFCreateStrandViewController ()

@property (readonly, nonatomic, retain) DFPeanutStrandFeedAdapter *feedAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandInviteAdapter *inviteAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandAdapter *strandAdapter;

@property (nonatomic, retain) DFPeanutObjectsResponse *suggestedResponse;
@property (nonatomic, retain) NSArray *inviteObjects;
@property (nonatomic, retain) NSMutableArray *friendSuggestions;
@property (nonatomic, retain) NSMutableArray *noFriendSuggestions;

@property (nonatomic, retain) NSData *lastResponseHash;
@property (nonatomic, retain) NSMutableDictionary *cellTemplatesByIdentifier;
@property (nonatomic, retain) NSTimer *refreshTimer;

@end

@implementation DFCreateStrandViewController
@synthesize feedAdapter = _feedAdapter;
@synthesize inviteAdapter = _inviteAdapter;
@synthesize strandAdapter = _strandAdapter;
@synthesize showAsFirstTimeSetup = _showAsFirstTimeSetup;

static DFCreateStrandViewController *instance;
- (IBAction)reloadButtonPressed:(id)sender {
  [self.tableView reloadData];
  self.tableView.contentOffset = CGPointMake(0, 0);
  [self setReloadButtonHidden:YES];
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
  self.cellTemplatesByIdentifier = [NSMutableDictionary new];
  [self.tableView registerNib:[UINib nibWithNibName:@"DFCreateStrandTableViewCell" bundle:nil]
       forCellReuseIdentifier:InviteId];
  [self.tableView registerNib:[UINib nibWithNibName:@"DFCreateStrandTableViewCell" bundle:nil]
       forCellReuseIdentifier:SuggestionWithPeopleId];
  [self.tableView registerNib:[UINib nibWithNibName:@"DFCreateStrandTableViewCell" bundle:nil]
       forCellReuseIdentifier:SuggestionNoPeopleId];
  self.refreshControl = [[UIRefreshControl alloc] init];
  [self.refreshControl addTarget:self
                          action:@selector(refreshFromServer)
                forControlEvents:UIControlEventValueChanged];
  [self.refreshControl beginRefreshing];
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
}

- (void)configureReloadButton
{
  self.reloadBackground.layer.cornerRadius = 5.0;
  self.reloadBackground.layer.masksToBounds = YES;
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  
  [self.tableView reloadData];
  if (self.navigationController.isBeingPresented) {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                             initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                             target:self
                                             action:@selector(cancelPressed:)];
  }
}

- (void)viewDidAppear:(BOOL)animated
{
  if (self.showAsFirstTimeSetup && !self.refreshTimer) {
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                         target:self
                                                       selector:@selector(refreshFromServer)
                                                       userInfo:nil
                                                        repeats:YES];
  }
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [self.refreshTimer invalidate];
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
  return ([self shouldShowInvites])
  + (self.friendSuggestions.count > 0)
  + (self.noFriendSuggestions.count > 0);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  NSArray *sectionObjects = [self sectionObjectsForSection:section];
  if (sectionObjects == self.inviteObjects) {
    return [NSString stringWithFormat:@"Invitations (%d)", (int)sectionObjects.count];
  } else if (sectionObjects == self.friendSuggestions) {
    return [NSString stringWithFormat:@"With Friends (%d)", (int)sectionObjects.count];
  } else if (sectionObjects == self.noFriendSuggestions) {
    return [NSString stringWithFormat:@"Other Events (%d)", (int)sectionObjects.count];
  }
  
  return @"Other";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [[self sectionObjectsForSection:section] count];
}

- (NSArray *)sectionObjectsForSection:(NSUInteger)section
{
  NSMutableArray *sections = [NSMutableArray new];
  if ([self shouldShowInvites]) {
    [sections addObject:self.inviteObjects];
  } if (self.friendSuggestions.count > 0) {
    [sections addObject:self.friendSuggestions];
  } if (self.noFriendSuggestions.count >0) {
    [sections addObject:self.noFriendSuggestions];
  }
  
  return sections[section];
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
  DFPeanutFeedObject *feedObject = [self sectionObjectsForSection:indexPath.section][indexPath.row];
  if ([feedObject.type isEqual:DFFeedObjectInviteStrand]) {
    cell = [self cellWithInviteObject:feedObject];
  } else {
    cell = [self cellWithSuggestedStrandObject:feedObject];
  }
  
  return cell;
}

- (UITableViewCell *)cellWithInviteObject:(DFPeanutFeedObject *)inviteObject
{
  DFCreateStrandTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:InviteId];
  [cell configureWithStyle:DFCreateStrandCellStyleInvite];
  cell.inviterLabel.text = [inviteObject.actors.firstObject display_name];
  
  DFPeanutFeedObject *strandObject = inviteObject.objects.firstObject;
  [self configureTextForCreateStrandCell:cell withStrand:strandObject];
  [self setRemotePhotosForCell:cell withSection:strandObject];
  
  return cell;
}

- (UITableViewCell *)cellWithSuggestedStrandObject:(DFPeanutFeedObject *)strandObject
{
  DFCreateStrandTableViewCell *cell;
  if (strandObject.actors.count > 0) {
    cell = [self.tableView dequeueReusableCellWithIdentifier:SuggestionWithPeopleId];
    [cell configureWithStyle:DFCreateStrandCellStyleSuggestionWithPeople];
  } else {
    cell = [self.tableView dequeueReusableCellWithIdentifier:SuggestionNoPeopleId];
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
    [photoIDs addObject:@(photoObject.id)];
    [photos addObject:photoObject];
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


- (void)setLocalPhotosForCell:(DFCreateStrandTableViewCell *)cell
                      section:(DFPeanutFeedObject *)section
{
  // Get the IDs of all the photos we want to show
  NSMutableArray *idsToShow = [NSMutableArray new];
  for (DFPeanutFeedObject *object in section.objects) {
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
        thumbnailSize = cell.flowLayout.itemSize.height * [[UIScreen mainScreen] scale];
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
  DFPeanutFeedObject *feedObject = [self sectionObjectsForSection:indexPath.section][indexPath.row];
  
  if ([feedObject.type isEqual:DFFeedObjectInviteStrand]) {
    DFCreateStrandTableViewCell *templateCell = self.cellTemplatesByIdentifier[InviteId];
    if (!templateCell) templateCell = [DFCreateStrandTableViewCell cellWithStyle:DFCreateStrandCellStyleInvite];
    self.cellTemplatesByIdentifier[InviteId] = templateCell;
    CGFloat height = [templateCell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
    return height;
  } else if ([feedObject.type isEqual:DFFeedObjectSection]) {
    if (feedObject.actors.count > 0) {
      DFCreateStrandTableViewCell *templateCell = self.cellTemplatesByIdentifier[SuggestionWithPeopleId];
      if (!templateCell) templateCell = [DFCreateStrandTableViewCell cellWithStyle:DFCreateStrandCellStyleSuggestionWithPeople];
      self.cellTemplatesByIdentifier[SuggestionWithPeopleId] = templateCell;
      CGFloat height = [templateCell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
      return height;
    } else {
      DFCreateStrandTableViewCell *templateCell = self.cellTemplatesByIdentifier[SuggestionNoPeopleId];
      if (!templateCell) templateCell = [DFCreateStrandTableViewCell cellWithStyle:DFCreateStrandCellStyleSuggestionNoPeople];
      self.cellTemplatesByIdentifier[SuggestionNoPeopleId] = templateCell;
      CGFloat height = [templateCell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
      return height;
    }
  }

  return 230.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSArray *feedObjectsForSection = [self sectionObjectsForSection:indexPath.section];
  DFPeanutFeedObject *feedObject = feedObjectsForSection[indexPath.row];
  DFSelectPhotosViewController *selectController;
  if ([feedObject.type isEqualToString:DFFeedObjectInviteStrand]) {
    DFPeanutFeedObject *invitedStrand = [[feedObject subobjectsOfType:DFFeedObjectSection]
                                         firstObject];
    DFPeanutFeedObject *suggestedPhotos = [[feedObject subobjectsOfType:DFFeedObjectSuggestedPhotos]
                                           firstObject];
    // this is an invite, the object that user selected represenets the shared photos
    // don't show the to field
    DFSelectPhotosViewController *selectController = [[DFSelectPhotosViewController alloc]
                                                      initWithTitle:@"Accept Invite"
                                                      showsToField:NO
                                                      suggestedSectionObject:suggestedPhotos
                                                      sharedSectionObject:invitedStrand
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
                        sharedSectionObject:nil
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
    [self.tableView reloadData];
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
        DFPeanutObjectsResponse *lastResponse = self.suggestedResponse;
        self.suggestedResponse = response;
        
        self.friendSuggestions = [NSMutableArray new];
        self.noFriendSuggestions = [NSMutableArray new];
        for (DFPeanutFeedObject *object in response.objects) {
          if (object.actors.count > 0) [self.friendSuggestions addObject:object];
          else [self.noFriendSuggestions addObject:object];
        }
        
        [self updateTableViewForOldResponse:lastResponse newResponse:response];
        self.lastResponseHash = responseHash;
      } else {
        DDLogDebug(@"Got back response for strand suggestions but it was the same");
      }
        [self.refreshControl endRefreshing];
      });
    }
  }];
  
  if (self.showAsFirstTimeSetup) {
    [self refreshInvitesFromServer];
  }
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
         if (oldInvites.count > 0 && self.inviteObjects.count > 0) {
           [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0]
                         withRowAnimation:UITableViewRowAnimationNone];
         } else if (oldInvites.count == 0 && self.inviteObjects.count > 0) {
           [self.tableView insertSections:[NSIndexSet indexSetWithIndex:0]
                         withRowAnimation:UITableViewRowAnimationFade];
         } else if (oldInvites.count > 0 && self.inviteObjects.count == 0){
           [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:0]
                         withRowAnimation:UITableViewRowAnimationLeft];
         } else {
           DDLogError(@"%@ unexpected condition: oldInvites:%d newInvites:%d",
                      self.class, (int)oldInvites.count, (int)self.inviteObjects.count);
         }
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

- (void)updateTableViewForOldResponse:(DFPeanutObjectsResponse *)oldResponse
                           newResponse:(DFPeanutObjectsResponse *)newResponse
{
  if (!oldResponse || oldResponse.objects.count < 10) {
    [self.tableView reloadData];
    self.reloadBackground.hidden = YES; // immediately hide, don't animate
    return;
  }
  
  [self setReloadButtonHidden:NO];
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
