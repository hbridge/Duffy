//
//  DFSwapViewController.m
//  Strand
//
//  Created by Henry Bridge on 10/22/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSwapViewController.h"
#import <Slash/Slash.h>
#import "DFSwapTableViewCell.h"
#import "DFPeanutFeedDataManager.h"
#import "DFNoTableItemsView.h"
#import "DFFeedViewController.h"
#import "DFCreateStrandViewController.h"
#import "NSAttributedString+DFHelpers.h"
#import "DFAnalytics.h"
#import "DFCreateStrandFlowViewController.h"
#import "DFNavigationController.h"
#import "DFCreateStrandFlowViewController.h"
#import "DFNoResultsTableViewCell.h"
#import "DFImageManager.h"
#import "UIView+DFExtensions.h"
#import "DFPushNotificationsManager.h"
#import "DFSwapUpsell.h"
#import "DFInviteFriendViewController.h"
#import "DFBackgroundLocationManager.h"
#import "DFPeanutStrandInviteAdapter.h"
#import "DFReviewSwapViewController.h"
#import "DFSwapAddPhotosCell.h"
#import <MMPopLabel/MMPopLabel.h>
#import <SVProgressHUD/SVProgressHUD.h>
#import "DFSwapSuggestionTableViewCell.h"

@interface DFSwapViewController ()

@property (nonatomic, retain) NSMutableOrderedSet *sectionTitles;
@property (nonatomic, retain) NSMutableDictionary *sectionTitlesToObjects;
@property (nonatomic, retain) DFNoTableItemsView *noItemsView;
@property (nonatomic, retain) UIRefreshControl *refreshControl;
@property (nonatomic, retain) NSArray *allSuggestions;
@property (nonatomic, retain) NSMutableArray *ignoredSuggestions;
@property (nonatomic, retain) NSMutableArray *filteredSuggestions;
@property (nonatomic, retain) NSMutableArray *notNowedSuggestions;
@property (nonatomic, retain) NSArray *systemUpsells;
@property (nonatomic, retain) DFPeanutFeedObject *suggestionToUpsellAdd;
@property (nonatomic, retain) MMPopLabel *popLabel;
@property (nonatomic, retain) DFPeanutStrand *lastCreatedStrand;

@end

const NSUInteger MaxSuggestionsToShow = 1;
NSString *const InvitesSectionTitle = @"Send Back Photos";
NSString *const SuggestedSectionTitle = @"Get Photos";

@implementation DFSwapViewController

- (instancetype)initWithUserToFilter:(DFPeanutUserObject *)user
{
  self = [self init];
  if (self) {
    _userToFilter = user;
  }
  return self;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    [self observeNotifications];
    [self configureNavAndTab];
    self.ignoredSuggestions = [NSMutableArray new];
    self.notNowedSuggestions = [NSMutableArray new];
  }
  return self;
}

- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNewSwapsDataNotificationName
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFPermissionStateChangedNotificationName
                                             object:nil];
}

- (void)configureNavAndTab
{
  self.navigationItem.title = @"Swaps";
  self.tabBarItem.title = @"Swaps";
  self.tabBarItem.image = [UIImage imageNamed:@"Assets/Icons/SwapBarButton"];
  self.tabBarItem.selectedImage = [UIImage imageNamed:@"Assets/Icons/SwapBarButtonSelected"];
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                            initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                            target:self
                                            action:@selector(createButtonPressed:)];
  self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]
                                           initWithTitle:@""
                                           style:UIBarButtonItemStylePlain
                                            target:self
                                            action:nil];
}

- (void)viewDidLoad {
  [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
  [self configureTableView:self.tableView];
  [self configureRefreshControl];
  self.popLabel = [MMPopLabel popLabelWithText:@"Swipe right to request, left to hide"];
  [self.view addSubview:self.popLabel];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self reloadData];
  [self.refreshControl endRefreshing];
  [self refreshFromServer];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  NSDictionary *parameters;
  if ([[DFPeanutFeedDataManager sharedManager] hasSwapsData]) {
    NSInteger numInvites = [[[DFPeanutFeedDataManager sharedManager] inviteStrands] count];
    NSInteger numSuggestions = [[[DFPeanutFeedDataManager sharedManager] suggestedStrands] count];
    parameters = @{
                   @"numInvites" : [DFAnalytics bucketStringForObjectCount:numInvites],
                   @"numSuggestions" : [DFAnalytics bucketStringForObjectCount:numSuggestions],
                   @"context" : (self.userToFilter != nil) ? @"userFilter" : @"allSwaps",
                   };
  }
  
  [DFAnalytics logViewController:self appearedWithParameters:parameters];
  if ([[[DFPeanutFeedDataManager sharedManager] acceptedStrands] count] > 0) {
    // if user has any accepted strands and we haven't prompted for push notifs, do so now
    [[DFPushNotificationsManager sharedManager] promptForPushNotifsIfNecessary];
  }
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [DFAnalytics logViewController:self disappearedWithParameters:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)configureTableView:(UITableView *)tableView
{
  self.tableView.rowHeight = [DFSwapTableViewCell height];
  [tableView registerNib:[UINib nibForClass:[DFNoResultsTableViewCell class]]
  forCellReuseIdentifier:@"noResults"];
  [tableView registerNib:[UINib nibForClass:[DFSwapTableViewCell class]]
  forCellReuseIdentifier:@"invite"];
  [tableView registerNib:[UINib nibForClass:[DFSwapTableViewCell class]]
  forCellReuseIdentifier:@"suggestion"];
  [tableView registerNib:[UINib nibForClass:[DFSwapSuggestionTableViewCell class]]
  forCellReuseIdentifier:@"upsell"];
  [tableView registerNib:[UINib nibForClass:[DFSwapAddPhotosCell class]]
  forCellReuseIdentifier:@"addPhotosUpsell"];
  
  
  self.tableView.separatorInset = [DFSwapTableViewCell edgeInsets];
}

- (void)configureRefreshControl
{
  self.refreshControl = [[UIRefreshControl alloc] init];
  
  UITableViewController *mockTVC = [[UITableViewController alloc] init];
  mockTVC.tableView = self.tableView;
  mockTVC.refreshControl = self.refreshControl;
  
  [self.refreshControl addTarget:self
                          action:@selector(refreshFromServer)
                forControlEvents:UIControlEventValueChanged];
}

#pragma Data loading

- (void)reloadData
{
  self.sectionTitles = [NSMutableOrderedSet new];
  self.sectionTitlesToObjects = [NSMutableDictionary new];
  
  if (![[DFPeanutFeedDataManager sharedManager] hasSwapsData]) {
    [self configureNoResultsView];
    return;
  }
  
  [self reloadInvites];
  [self reloadSuggestions];
  [self reloadUpsells];
  
  [self reloadSuggestionsSection];
  
  [self.tableView reloadData];
  
  [self configureNoResultsView];
  [self configureTabCount];
  [self.refreshControl endRefreshing];
}

- (void)reloadInvites
{
  NSArray *invites = [[DFPeanutFeedDataManager sharedManager] inviteStrands];
  if (self.userToFilter) {
    NSMutableArray *filteredInvites = [NSMutableArray new];
    for (DFPeanutFeedObject *invite in invites) {
      if ([invite.actors containsObject:self.userToFilter]) {
        [filteredInvites addObject:invite];
      }
    }
    invites = filteredInvites;
  }
  
  if (invites.count > 0) {
    [self.sectionTitles addObject:InvitesSectionTitle];
    self.sectionTitlesToObjects[InvitesSectionTitle] = invites;
  }
}

- (void)reloadSuggestions
{
  self.allSuggestions = [[DFPeanutFeedDataManager sharedManager] suggestedStrands];
  if (self.userToFilter) {
    NSMutableArray *filteredSuggestions = [NSMutableArray new];
    for (DFPeanutFeedObject *suggestion in self.allSuggestions) {
      if ([suggestion.actors containsObject:self.userToFilter]) {
        [filteredSuggestions addObject:suggestion];
      }
    }
    self.allSuggestions = filteredSuggestions;
  }
}

- (void)reloadUpsells
{
//  NSMutableArray *upsells = [NSMutableArray new];
//  if (self.allSuggestions.count == 0
//      && [[DFBackgroundLocationManager sharedManager] canPromptForAuthorization]) {
//    DFSwapUpsell *locationUpsell = [[DFSwapUpsell alloc] init];
//    locationUpsell.type = DFSwapUpsellLocation;
//    [upsells addObject:locationUpsell];
//  }
//  DFSwapUpsell *inviteUpsell = [[DFSwapUpsell alloc] init];
//  inviteUpsell.type = DFSwapUpsellInviteFriends;
//  [upsells addObject:inviteUpsell];
  self.systemUpsells = @[];
}

- (void)reloadSuggestionsSection
{
  /* Reloads the suggestions section from the allSuggestions array, broken out
   so it can be called from the swipe handler safely */
  [self.sectionTitles addObject:SuggestedSectionTitle];
  if (self.suggestionToUpsellAdd) {
    self.sectionTitlesToObjects[SuggestedSectionTitle] = @[self.suggestionToUpsellAdd];
    return;
  }

  self.sectionTitlesToObjects[SuggestedSectionTitle] = [NSMutableArray new];
  if (self.allSuggestions.count > 0) {
    self.filteredSuggestions = [self.allSuggestions mutableCopy];
    [self.filteredSuggestions removeObjectsInArray:self.ignoredSuggestions];
    [self.filteredSuggestions removeObjectsInArray:self.notNowedSuggestions];
    DDLogVerbose(@"allCount:%@ ignoredCount:%@ filteredCount:%@",
                 @(self.allSuggestions.count), @(self.ignoredSuggestions.count), @(self.filteredSuggestions.count));
    if (self.filteredSuggestions.count > MaxSuggestionsToShow) {
      [self.filteredSuggestions
       removeObjectsInRange:(NSRange){MaxSuggestionsToShow, self.filteredSuggestions.count - MaxSuggestionsToShow}];
    }
    self.sectionTitlesToObjects[SuggestedSectionTitle] = self.filteredSuggestions;
  }
  if (!self.userToFilter) {
    if (!self.sectionTitlesToObjects[SuggestedSectionTitle]) {
      self.sectionTitlesToObjects[SuggestedSectionTitle] = [NSMutableArray new];
    }
    [self.sectionTitlesToObjects[SuggestedSectionTitle] addObjectsFromArray:self.systemUpsells];
  }
}

- (void)configureTabCount
{
  NSArray *invites = self.sectionTitlesToObjects[InvitesSectionTitle];
  if (invites.count > 0) {
    self.tabBarItem.badgeValue = [@(invites.count) stringValue];
  } else {
    self.tabBarItem.badgeValue = nil;
  }
}

- (void)refreshFromServer
{
  [[DFPeanutFeedDataManager sharedManager] refreshSwapsFromServer:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      DDLogVerbose(@"Killing spinner in swap view...");
      [self.refreshControl endRefreshing];
      [self reloadData];
    });
  }];

}

- (void)configureNoResultsView
{
  if (self.sectionTitles.count == 0) {
    if (!self.noItemsView) {
      self.noItemsView = [UINib instantiateViewWithClass:[DFNoTableItemsView class]];
      [self.noItemsView setSuperView:self.tableView];
    }
    
    self.noItemsView.hidden = NO;
    if ([[DFPeanutFeedDataManager sharedManager] hasSwapsData]) {
      self.noItemsView.titleLabel.text = @"Nothing To Swap";
      [self.noItemsView.activityIndicator stopAnimating];
    } else {
      self.noItemsView.titleLabel.text = @"Loading...";
      [self.noItemsView.activityIndicator startAnimating];
      self.noItemsView.subtitleLabel.text = @"";
    }
  } else {
    self.noItemsView.hidden = YES;
    self.tableView.hidden = NO;
  }
}


- (NSArray *)sectionObjectsForSection:(NSInteger)section
{
  return self.sectionTitlesToObjects[self.sectionTitles[section]];
}

- (DFPeanutFeedObject *)feedObjectForIndexPath:(NSIndexPath *)indexPath
{
  NSArray *objects = [self sectionObjectsForSection:indexPath.section];
  if (objects.count == 0) return nil;
  
  return objects[indexPath.row];
}

- (void)removeObjectAtIndexPath:(NSIndexPath *)indexPath
{
  NSString *sectionTitle = self.sectionTitles[indexPath.section];
  NSMutableArray *objectsForSection = [self.sectionTitlesToObjects[sectionTitle] mutableCopy];
  [objectsForSection removeObjectAtIndex:indexPath.row];
  self.sectionTitlesToObjects[sectionTitle] = objectsForSection;
}


#pragma mark - UITableView Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return self.sectionTitles.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  NSUInteger minCount = 0;
  if ([self.sectionTitles[section] isEqualToString:InvitesSectionTitle]) minCount = 0;
  if ([self.sectionTitles[section] isEqualToString:SuggestedSectionTitle]) minCount = 1;
  return MAX([[self sectionObjectsForSection:section] count], minCount);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  id object = [self feedObjectForIndexPath:indexPath];
  
  UITableViewCell *cell;
  if ([[object class] isSubclassOfClass:[DFPeanutFeedObject class]]) {
    DFPeanutFeedObject *feedObject = (DFPeanutFeedObject *)object;
    if ([feedObject.type isEqual:DFFeedObjectInviteStrand]) {
      cell = [self cellForInviteObject:object indexPath:indexPath];
    } else if ([feedObject.type isEqual:DFFeedObjectSwapSuggestion]) {
      if ([object isEqual:self.suggestionToUpsellAdd]) {
        cell = [self addPhotosUpsellCellForSuggestion:object indexPath:indexPath];
      } else {
        cell = [self cellForSuggestionObject:object indexPath:indexPath];
      }
    }
  } else if ([[object class] isSubclassOfClass:[DFSwapUpsell class]]) {
    cell = [self cellForUpsell:object indexPath:indexPath];
  } else {
    cell = [self noResultsCellForIndexPath:indexPath];
  }

  if (!cell) [NSException raise:@"unexpected object" format:@""];
  
  return cell;
}

- (UITableViewCell *)noResultsCellForIndexPath:(NSIndexPath *)indexPath
{
    DFNoResultsTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"noResults"];
  if ([self.sectionTitles[indexPath.section] isEqualToString:InvitesSectionTitle]) {
    cell.noResultsLabel.text = @"No Requests";
  } else {
    cell.noResultsLabel.text = @"No Suggestions";
  }
  return cell;
}

- (UITableViewCell *)cellForInviteObject:(DFPeanutFeedObject *)inviteObject indexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *strandPosts = [[inviteObject subobjectsOfType:DFFeedObjectStrandPosts] firstObject];
  DFSwapTableViewCell *inviteCell = [self.tableView dequeueReusableCellWithIdentifier:@"invite"];
  
  NSString *titleLabelMarkup = [NSString stringWithFormat:@"<name>%@</name> wants your photos",
                                inviteObject.actorsString];
  [self configureCell:inviteCell
            indexPath:indexPath
      withPeanutUsers:inviteObject.actors
          titleMarkup:titleLabelMarkup
           feedObject:strandPosts];
  
  
  return inviteCell;
}

- (void)configureCell:(DFSwapTableViewCell *)cell
            indexPath:(NSIndexPath *)indexPath
      withPeanutUsers:(NSArray *)peanutUsers
          titleMarkup:(NSString *)titleMarkup
           feedObject:(DFPeanutFeedObject *)feedObject
{
  
  cell.profilePhotoStackView.peanutUsers = peanutUsers;
  NSError *error;
  cell.peopleLabel.attributedText = [SLSMarkupParser
                                     attributedStringWithMarkup:titleMarkup
                                     style:[DFStrandConstants defaultTextStyle]
                                     error:&error];
  cell.subTitleLabel.text = [feedObject placeAndRelativeTimeString];
  
  DFPeanutFeedObject *photoObject;
  DFPeanutFeedObject *strandPosts = [feedObject strandPostsObject];
  if (strandPosts) {
    // if this is a strandpost, get the first photo in the first post
    photoObject = [[[strandPosts.objects firstObject]
                    descendentdsOfType:DFFeedObjectPhoto]
                   firstObject];
  } else {
    // otherwise, it's a suggestion. get the first photo (by timestamp) of the photos
    NSArray *photos = [feedObject descendentdsOfType:DFFeedObjectPhoto];
    NSSortDescriptor *timeSort = [NSSortDescriptor sortDescriptorWithKey:@"time_taken" ascending:YES];
    photoObject = [[photos sortedArrayUsingDescriptors:@[timeSort]] firstObject];
  }

  if (!photoObject) {
    DDLogInfo(@"%@ couldn't get photoObject for %@", self.class, feedObject);
  }
  
  [[DFImageManager sharedManager]
   imageForID:photoObject.id
   size:cell.previewImageView.pixelSize
   contentMode:DFImageRequestContentModeAspectFill
   deliveryMode:DFImageRequestOptionsDeliveryModeFastFormat
   completion:^(UIImage *image) {
     dispatch_async(dispatch_get_main_queue(), ^{
       if ([[self.tableView indexPathForCell:cell] isEqual:indexPath]) {
         cell.previewImageView.image = image;
       }
     });
   }];
}

- (UITableViewCell *)cellForSuggestionObject:(DFPeanutFeedObject *)suggestionObject indexPath:(NSIndexPath *)indexPath
{
  DFSwapSuggestionTableViewCell *suggestionCell = [self.tableView dequeueReusableCellWithIdentifier:@"suggestion"];
  suggestionCell.profilePhotoStackView.peanutUsers = suggestionObject.actors;
    // the suggestion sections don't include this user in the actors list
  
  NSString *titleMarkup;
  
  // If we have no actors for a suggestion, right now that means its time based ("Last Night")
  // For now, simply replace the title and image.
  // Later on, we might want to pull this out to its own type
  if (suggestionObject.actorNames.count == 0) {
    titleMarkup = suggestionObject.title;
    suggestionCell.profileReplacementImageView.image = [UIImage imageNamed:@"Assets/Icons/PhotosSuggestionIcon"];
  } else {
    titleMarkup = [NSString stringWithFormat:@"<name>%@</name> have photos from when you took this photo", [suggestionObject actorsString]];
    suggestionCell.profileReplacementImageView.image = nil;
  }
  
  [self configureCell:suggestionCell
            indexPath:indexPath
      withPeanutUsers:suggestionObject.actors
          titleMarkup:titleMarkup
           feedObject:suggestionObject];
  [self configureActionsForSuggestion:suggestionObject
                                 cell:suggestionCell
                            indexPath:indexPath];
  
  return suggestionCell;
}

- (void)configureActionsForSuggestion:(DFPeanutFeedObject *)sugestion
                                 cell:(DFSwapTableViewCell *)cell
                                indexPath:(NSIndexPath *)indexPath
{
  UILabel *hideLabel = [[UILabel alloc] init];
  hideLabel.text = @"Not Now";
  hideLabel.textColor = [UIColor whiteColor];
  [hideLabel sizeToFit];
  [cell
   setSwipeGestureWithView:hideLabel
   color:[DFStrandConstants strandYellow]
   mode:MCSwipeTableViewCellModeExit
   state:MCSwipeTableViewCellState3
   completionBlock:[self notNowSwipeBlockForSuggestion:sugestion indexPath:indexPath]];
  
  
  UILabel *requestLabel = [[UILabel alloc] init];
  requestLabel.text = @"Request";
  requestLabel.textColor = [UIColor whiteColor];
  [requestLabel sizeToFit];
  [cell
   setSwipeGestureWithView:requestLabel
   color:[DFStrandConstants strandGreen]
   mode:MCSwipeTableViewCellModeExit
   state:MCSwipeTableViewCellState1
   completionBlock:[self requestSwipeBlockForSuggestion:sugestion indexPath:indexPath]];
  
  // the default color is the color that appears before you swipe far enough for the action
  // we set to the group tableview background color to blend in
  cell.defaultColor = [UIColor lightGrayColor];

}

- (UITableViewCell *)addPhotosUpsellCellForSuggestion:(DFPeanutFeedObject *)suggestion indexPath:(NSIndexPath *)indexPath
{
  DFSwapAddPhotosCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"addPhotosUpsell"];
  
  cell.cancelBlock = [self cancelBlockForAddPhotosForSuggestion:suggestion indexPath:indexPath];
  
  cell.okBlock = [self okBlockForAddPhotosForSuggestion:suggestion indexPath:indexPath];
  
  return cell;
}

- (UITableViewCell *)cellForUpsell:(DFSwapUpsell *)upsell indexPath:(NSIndexPath *)indexPath
{
  DFSwapTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"upsell"];
  [cell.previewImageView removeFromSuperview];
  cell.profileReplacementImageView.image = upsell.image;
  cell.peopleLabel.text = upsell.title;
  cell.subTitleLabel.text = upsell.subtitle;
  
  return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  return self.sectionTitles[section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  if ([self.sectionTitles[indexPath.section] isEqualToString:InvitesSectionTitle]) {
    return 69.0;
  } else if ([self.sectionTitles[indexPath.section] isEqualToString:SuggestedSectionTitle]){
    return 102.0;
  }
  
  return 69.0;
}

#pragma mark - Actions

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  id object = [self feedObjectForIndexPath:indexPath];
  if ([[object class] isSubclassOfClass:[DFPeanutFeedObject class]]) {
    DFPeanutFeedObject *feedObject = (DFPeanutFeedObject *)object;
    if ([feedObject.type isEqual:DFFeedObjectInviteStrand]) {
      [self inviteTapped:feedObject];
    } else if ([feedObject.type isEqual:DFFeedObjectSwapSuggestion]) {
      [self suggestionTapped:feedObject indexPath:indexPath];
    }
  } else if ([[object class] isSubclassOfClass:[DFSwapUpsell class]]) {
    DFSwapUpsell *upsell = (DFSwapUpsell *)object;
    if ([upsell.type isEqual:DFSwapUpsellInviteFriends]) {
      DFInviteFriendViewController *inviteFriendViewController = [[DFInviteFriendViewController alloc] init];
      [self presentViewController:inviteFriendViewController animated:YES completion:nil];
    } else if ([upsell.type isEqualToString:DFSwapUpsellLocation]) {
      [[DFBackgroundLocationManager sharedManager] promptForAuthorization];
    }
  }
  [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

- (void)inviteTapped:(DFPeanutFeedObject *)invite
{
  if (invite.strandPostsObject.objects.count > 0) {
    DFFeedViewController *feedViewController = [[DFFeedViewController alloc] initWithFeedObject:invite];
    [self.navigationController pushViewController:feedViewController animated:YES];
  } else {
    // this is a request for photos
    DFPeanutFeedObject *suggestionsObject = [[invite subobjectsOfType:DFFeedObjectSuggestedPhotos] firstObject];
    NSArray *suggestions = suggestionsObject.objects;
    DFReviewSwapViewController *addPhotosController =
    [[DFReviewSwapViewController alloc]
     initWithSuggestions:suggestions
     invite:invite
     swapSuccessful:^{
       
     }];
    DFNavigationController *navController = [[DFNavigationController alloc]
                                             initWithRootViewController:addPhotosController];
    addPhotosController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                                            initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                            target:self
                                                            action:@selector(dismissReviewSwap:)];
    [self presentViewController:navController animated:YES completion:nil];

  }
}

- (void)dismissReviewSwap:(id)sender
{
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)suggestionTapped:(DFPeanutFeedObject *)suggestion indexPath:(NSIndexPath *)indexPath
{
  DFSwapTableViewCell *cell = (DFSwapTableViewCell *)[self.tableView cellForRowAtIndexPath:indexPath];
  [self.popLabel popAtView:cell animatePopLabel:YES animateTargetView:NO];
  [UIView animateWithDuration:0.2 delay:0 usingSpringWithDamping:cell.damping initialSpringVelocity:cell.velocity options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAutoreverse animations:^{
    CGRect frame = cell.frame;
    frame.origin.x = 20;
    cell.frame = frame;
  } completion:^(BOOL finished) {
    CGRect frame = cell.frame;
    frame.origin.x = 0;
    cell.frame = frame;
  }];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [self.popLabel dismiss];
  });
  
}

- (MCSwipeCompletionBlock)requestSwipeBlockForSuggestion:(DFPeanutFeedObject *)suggestion indexPath:(NSIndexPath *)indexPath
{
  return ^(MCSwipeTableViewCell *cell, MCSwipeTableViewCellState state, MCSwipeTableViewCellMode mode) {
    [self requestPhotosForSuggestion:suggestion];
    
  };
}

- (void)requestPhotosForSuggestion:(DFPeanutFeedObject *)suggestion
{
  [[DFPeanutFeedDataManager sharedManager]
   createRequestFromSuggestion:suggestion
   contacts:suggestion.actors
   success:^(DFPeanutStrand *resultStrand) {
     DDLogInfo(@"%@ created empty strand", self.class);
     self.suggestionToUpsellAdd = suggestion;
     [self.notNowedSuggestions addObject:suggestion];
     [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:self.sectionTitles.count - 1]]
                           withRowAnimation:UITableViewRowAnimationFade];
     
     self.lastCreatedStrand = resultStrand;
     
     DFPeanutStrandInviteAdapter *adapter = [[DFPeanutStrandInviteAdapter alloc] init];
     [adapter
      sendInvitesForStrand:resultStrand
      toPeanutContacts:suggestion.actors
      inviteLocationString:suggestion.location
      invitedPhotosDate:resultStrand.first_photo_time
      success:^(DFSMSInviteStrandComposeViewController *composeView) {
        DDLogInfo(@"%@ created empty strand and invite successful", self.class);
        
      } failure:^(NSError *error) {
        DDLogError(@"%@ invite failed: %@", self.class, error);
      }];
   } failure:^(NSError *error) {
     DDLogError(@"%@ creating empty strand failed: %@", self.class, error);
   }];
}

- (MCSwipeCompletionBlock)notNowSwipeBlockForSuggestion:(DFPeanutFeedObject *)suggestion indexPath:(NSIndexPath *)indexPath
{
  return ^(MCSwipeTableViewCell *cell, MCSwipeTableViewCellState state, MCSwipeTableViewCellMode mode) {
    [self.ignoredSuggestions addObject:suggestion];
    [self reloadSuggestionsSection];
    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
  };
}

- (DFVoidBlock)cancelBlockForAddPhotosForSuggestion:(DFPeanutFeedObject *)suggestion indexPath:(NSIndexPath *)indexPath
{
  return ^{
    self.suggestionToUpsellAdd = nil;
    [self reloadSuggestionsSection];
    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
  };
}

- (DFVoidBlock)okBlockForAddPhotosForSuggestion:(DFPeanutFeedObject *)suggestion indexPath:(NSIndexPath *)indexPath
{
  return ^{
    NSArray *privateStrands = [[DFPeanutFeedDataManager sharedManager] privateStrandsByDateAscending:YES];
    DFSelectPhotosViewController *selectPhotosViewController = [[DFSelectPhotosViewController alloc]
                                                                initWithCollectionFeedObjects:privateStrands
                                                                highlightedFeedObject:suggestion];
    
    selectPhotosViewController.highlightedFeedObject = suggestion;
    selectPhotosViewController.navigationItem.title = @"Add Photos";
    selectPhotosViewController.actionButtonVerb = @"Add";
    selectPhotosViewController.delegate = self;
    DFNavigationController *navController = [[DFNavigationController alloc]
                                             initWithRootViewController:selectPhotosViewController];
    
    [self presentViewController:navController animated:YES completion:nil];
  };
}

- (void)selectPhotosViewController:(DFSelectPhotosViewController *)controller
     didFinishSelectingFeedObjects:(NSArray *)selectedFeedObjects
{
  [self dismissViewControllerAnimated:YES completion:nil];
  [[DFPeanutFeedDataManager sharedManager]
   addFeedObjects:selectedFeedObjects
   toStrandWithID:self.lastCreatedStrand.id.longLongValue
   success:^{
     DDLogInfo(@"%@ added photos to %@ after sending request", self.class, self.lastCreatedStrand.id);
     dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
       [SVProgressHUD showSuccessWithStatus:@"Sent!"];
     });
     self.suggestionToUpsellAdd = nil;
     [self reloadSuggestionsSection];
     [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:1]]
                           withRowAnimation:UITableViewRowAnimationFade];
   } failure:^(NSError *error) {
     DDLogError(@"%@ failed to addPhotos after sending request: %@", self.class, error);
     [SVProgressHUD showErrorWithStatus:@"Failed."];
   }];
}


- (void)createButtonPressed:(id)sender
{
  DFCreateStrandFlowViewController *createController = [[DFCreateStrandFlowViewController alloc] init];
  [self presentViewController:createController animated:YES completion:nil];
}


@end
