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

@interface DFSwapViewController ()

@property (nonatomic, retain) NSMutableOrderedSet *sectionTitles;
@property (nonatomic, retain) NSMutableDictionary *sectionTitlesToObjects;
@property (nonatomic, retain) DFNoTableItemsView *noItemsView;
@property (nonatomic, retain) UIRefreshControl *refreshControl;
@property (nonatomic, retain) NSArray *allSuggestions;
@property (nonatomic, retain) NSMutableArray *ignoredSuggestions;
@property (nonatomic, retain) NSMutableArray *filteredSuggestions;
@property (nonatomic, retain) NSArray *systemUpsells;

@end

const NSUInteger MaxSuggestionsToShow = 3;
NSString *const InvitesSectionTitle = @"Requested Swaps";
NSString *const SuggestedSectionTitle = @"Suggested Swaps";

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
  [DFAnalytics logViewController:self appearedWithParameters:nil];
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
  [tableView registerNib:[UINib nibForClass:[DFSwapTableViewCell class]]
  forCellReuseIdentifier:@"upsell"];
  
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
  [self.sectionTitles addObject:InvitesSectionTitle];
  if (invites.count > 0) {
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
  NSMutableArray *upsells = [NSMutableArray new];
  if (self.allSuggestions.count == 0
      && [[DFBackgroundLocationManager sharedManager] canPromptForAuthorization]) {
    DFSwapUpsell *locationUpsell = [[DFSwapUpsell alloc] init];
    locationUpsell.type = DFSwapUpsellLocation;
    [upsells addObject:locationUpsell];
  }
  DFSwapUpsell *inviteUpsell = [[DFSwapUpsell alloc] init];
  inviteUpsell.type = DFSwapUpsellInviteFriends;
  [upsells addObject:inviteUpsell];
  self.systemUpsells = upsells;
}

- (void)reloadSuggestionsSection
{
  /* Reloads the suggestions section from the allSuggestions array, broken out
   so it can be called from the swipe handler safely */
  [self.sectionTitles addObject:SuggestedSectionTitle];
  self.sectionTitlesToObjects[SuggestedSectionTitle] = [NSMutableArray new];
  if (self.allSuggestions.count > 0) {
    self.filteredSuggestions = [self.allSuggestions mutableCopy];
    [self.filteredSuggestions removeObjectsInArray:self.ignoredSuggestions];
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
  NSUInteger minCount = 1;
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
      cell = [self cellForSuggestionObject:object indexPath:indexPath];
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
  
  NSString *titleLabelMarkup = [NSString stringWithFormat:@"From <name>%@</name>",
                                inviteObject.actorsString];
  [self configureCell:inviteCell
            indexPath:indexPath
            withNames:inviteObject.actorNames
          titleMarkup:titleLabelMarkup
           feedObject:strandPosts];
  
  
  return inviteCell;
}

- (void)configureCell:(DFSwapTableViewCell *)cell
            indexPath:(NSIndexPath *)indexPath
            withNames:(NSArray *)names
          titleMarkup:(NSString *)titleMarkup
           feedObject:(DFPeanutFeedObject *)feedObject
{
  
  cell.profilePhotoStackView.names = names;
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
  DFSwapTableViewCell *suggestionCell = [self.tableView dequeueReusableCellWithIdentifier:@"suggestion"];
  suggestionCell.profilePhotoStackView.names = suggestionObject.actorNames;
    // the suggestion sections don't include this user in the actors list
  
  NSString *titleMarkup;
  
  // If we have no actors for a suggestion, right now that means its time based ("Last Night")
  // For now, simply replace the title and image.
  // Later on, we might want to pull this out to its own type
  if (suggestionObject.actorNames.count == 0) {
    titleMarkup = suggestionObject.title;
    suggestionCell.profileReplacementImageView.image = [UIImage imageNamed:@"Assets/Icons/PhotosSuggestionIcon"];
  } else {
    titleMarkup = [NSString stringWithFormat:@"with <name>%@</name>", [suggestionObject actorsString]];
    suggestionCell.profileReplacementImageView.image = nil;
  }
  
  [self configureCell:suggestionCell
            indexPath:indexPath
            withNames:suggestionObject.actorNames
          titleMarkup:titleMarkup
           feedObject:suggestionObject];
  
  return suggestionCell;
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

#pragma mark - Actions

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  id object = [self feedObjectForIndexPath:indexPath];
  if ([[object class] isSubclassOfClass:[DFPeanutFeedObject class]]) {
    DFPeanutFeedObject *feedObject = (DFPeanutFeedObject *)object;
    if ([feedObject.type isEqual:DFFeedObjectInviteStrand]) {
      DFFeedViewController *feedViewController = [[DFFeedViewController alloc] initWithFeedObject:object];
      [self.navigationController pushViewController:feedViewController animated:YES];
    } else if ([feedObject.type isEqual:DFFeedObjectSwapSuggestion]) {
      DFCreateStrandFlowViewController *createStrandFlow = [[DFCreateStrandFlowViewController alloc]
                                                            initWithHighlightedPhotoCollection:object];
      [self presentViewController:createStrandFlow animated:YES completion:nil];
      createStrandFlow.extraAnalyticsInfo =
       @{
         @"suggestionType" : feedObject.suggestion_type,
         @"suggestionRank" : feedObject.suggestion_rank,
         @"suggestionActorsCount" : [DFAnalytics bucketStringForObjectCount:feedObject.actors.count]
        };
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


- (void)createButtonPressed:(id)sender
{
  DFCreateStrandFlowViewController *createController = [[DFCreateStrandFlowViewController alloc] init];
  [self presentViewController:createController animated:YES completion:nil];
}


@end
