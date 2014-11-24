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
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "DFMultiPhotoViewController.h"

@interface DFSwapViewController ()

@property (nonatomic, retain) NSMutableOrderedSet *sectionTitles;
@property (nonatomic, retain) NSMutableDictionary *sectionTitlesToObjects;
@property (nonatomic, retain) DFNoTableItemsView *noItemsView;
@property (nonatomic, retain) UIRefreshControl *refreshControl;
@property (nonatomic, retain) NSArray *allSuggestions;
@property (nonatomic, retain) NSMutableArray *ignoredSuggestions;
@property (nonatomic, retain) NSMutableArray *filteredSuggestions;
@property (nonatomic, retain) DFPeanutFeedObject *currentSuggestion;
@property (nonatomic, retain) NSArray *systemUpsells;
@property (nonatomic, retain) DFPeanutFeedObject *suggestionToUpsellAdd;
@property (nonatomic, retain) MMPopLabel *popLabel;
@property (nonatomic, retain) DFPeanutStrand *lastCreatedStrand;
@property (nonatomic, retain) DFPeanutFeedObject *pickedSuggestion;

@end

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
  [tableView registerNib:[UINib nibForClass:[DFSwapSuggestionTableViewCell class]]
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
  self.sectionTitlesToObjects[SuggestedSectionTitle] = [NSMutableArray new];
  if (self.allSuggestions.count > 0) {
    self.filteredSuggestions = [self.allSuggestions mutableCopy];
    [self.filteredSuggestions removeObjectsInArray:self.ignoredSuggestions];
    
    if (self.currentSuggestion) {
      self.currentSuggestion = self.currentSuggestion;
    } else {
      self.currentSuggestion = self.filteredSuggestions.firstObject;
    }
  }
}

- (void)setCurrentSuggestion:(DFPeanutFeedObject *)currentSuggestion
{
  _currentSuggestion = currentSuggestion;
  if (currentSuggestion)
    self.sectionTitlesToObjects[SuggestedSectionTitle] = @[currentSuggestion];
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
  DFPeanutFeedObject *suggestions = [[inviteObject subobjectsOfType:DFFeedObjectSuggestedPhotos] firstObject];
  DFSwapTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"invite"];
  
  NSString *titleLabelMarkup = [NSString stringWithFormat:@"<name>%@</name> %@ your photos",
                                inviteObject.actorsString,
                                inviteObject.actors.count == 1 ? @"wants" : @"want"];
  if (inviteObject.location) {
    titleLabelMarkup = [titleLabelMarkup stringByAppendingFormat:@" from %@", inviteObject.location];
  }
  cell.profilePhotoStackView.peanutUsers = inviteObject.actors;
  NSError *error;
  cell.topLabel.attributedText = [SLSMarkupParser
                                  attributedStringWithMarkup:titleLabelMarkup
                                  style:[DFStrandConstants defaultTextStyle]
                                  error:&error];
  cell.subTitleLabel.text = [NSDateFormatter relativeTimeStringSinceDate:strandPosts.time_taken abbreviate:NO];


  DFPeanutFeedObject *photoObject;
  if (strandPosts.objects.count > 0) {
    photoObject = [[strandPosts leafNodesFromObjectOfType:DFFeedObjectPhoto] firstObject];
  } else if (suggestions.objects.count > 0) {
    photoObject = [[suggestions leafNodesFromObjectOfType:DFFeedObjectPhoto] firstObject];
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
  
  return cell;
}

- (UITableViewCell *)cellForSuggestionObject:(DFPeanutFeedObject *)suggestionObject indexPath:(NSIndexPath *)indexPath
{
  DFSwapSuggestionTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"suggestion"];
  cell.profilePhotoStackView.peanutUsers = suggestionObject.actors;
    // the suggestion sections don't include this user in the actors list
  
  // If we have no actors for a suggestion, right now that means its time based ("Last Night")
  // For now, simply replace the title and image.
  // Later on, we might want to pull this out to its own type
  NSString *title;
  NSString *subtitle;
  NSString *titleMarkup;
  if (suggestionObject.actorNames.count == 0) {
    title = [NSString stringWithFormat:@"Get photos from %@", suggestionObject.title];
    cell.profileReplacementImageView.image = [UIImage imageNamed:@"Assets/Icons/PhotosSuggestionIcon"];
    cell.explanationLabel.text = @"Get photos from friends";
  } else {
    if (suggestionObject.location) {
      title = [NSString stringWithFormat:@"Get more photos from %@", suggestionObject.location];
      subtitle = [NSDateFormatter
                  relativeTimeStringSinceDate:suggestionObject.time_taken
                  abbreviate:NO];
    } else {
      title = [NSString stringWithFormat:@"Get photos from %@", [NSDateFormatter
                                                                 relativeTimeStringSinceDate:suggestionObject.time_taken
                                                                 abbreviate:NO]];
      subtitle = nil;
    }
    cell.profileReplacementImageView.image = nil;
    cell.explanationLabel.text = [NSString stringWithFormat:@"%@ %@ photos",
                                  suggestionObject.actorsString,
                                  suggestionObject.actors.count == 1 ? @"has" : @"have"];
  }
  
  titleMarkup = [NSString stringWithFormat:@"<suggestiontitle>%@</suggestiontitle>", title];
  NSError *error;
  cell.topLabel.attributedText = [SLSMarkupParser
                                  attributedStringWithMarkup:titleMarkup
                                  style:[DFStrandConstants defaultTextStyle]
                                  error:&error];
  cell.subTitleLabel.text = subtitle;

  // image
  DFPeanutFeedObject *photoObject = [[suggestionObject leafNodesFromObjectOfType:DFFeedObjectPhoto] firstObject];
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
  
  [self configureActionsForSuggestion:suggestionObject
                                 cell:cell
                            indexPath:indexPath];
  
  return cell;
}

- (void)configureActionsForSuggestion:(DFPeanutFeedObject *)sugestion
                                 cell:(DFSwapSuggestionTableViewCell *)cell
                                indexPath:(NSIndexPath *)indexPath
{
  cell.requestButtonHandler = [self requestBlockForSuggestion:sugestion indexPath:indexPath];
  cell.skipButtonHandler = [self skipBlockForSuggestion:sugestion indexPath:indexPath];
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
  cell.topLabel.text = upsell.title;
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
    return 222.0;
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
    DFReviewSwapViewController *reviewSwapController =
    [[DFReviewSwapViewController alloc]
     initWithSuggestions:suggestions
     invite:invite
     swapSuccessful:^{}];
    DFNavigationController *navController = [[DFNavigationController alloc]
                                             initWithRootViewController:reviewSwapController];
    reviewSwapController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
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
  NSArray *photos = [suggestion leafNodesFromObjectOfType:DFFeedObjectPhoto];
  DFMultiPhotoViewController *mpvc = [[DFMultiPhotoViewController alloc] init];
  [mpvc setActivePhoto:photos.firstObject inPhotos:photos];
  mpvc.navigationTitle = @"Your Photos";
  [self presentViewController:mpvc animated:YES completion:nil];
}

- (DFVoidBlock)requestBlockForSuggestion:(DFPeanutFeedObject *)suggestion indexPath:(NSIndexPath *)indexPath
{
  return ^{
    self.pickedSuggestion = suggestion;
    DFPeoplePickerViewController *peoplePicker = [[DFPeoplePickerViewController alloc]
                                                  initWithSuggestedPeanutUsers:suggestion.actors];
    peoplePicker.allowsMultipleSelection = YES;
    peoplePicker.delegate = self;
    peoplePicker.navigationItem.title = @"Who was there?";
    
    [DFNavigationController presentWithRootController:peoplePicker inParent:self];
  };
}

- (void)pickerController:(DFPeoplePickerViewController *)pickerController didFinishWithPickedContacts:(NSArray *)peanutContacts
{
  [[DFPeanutFeedDataManager sharedManager]
   createRequestFromSuggestion:self.pickedSuggestion
   contacts:peanutContacts
   success:^(DFPeanutStrand *resultStrand) {
     DDLogInfo(@"%@ created empty strand", self.class);
     //self.suggestionToUpsellAdd = suggestion;
     self.currentSuggestion = [self nextSuggestion];
     [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:self.sectionTitles.count - 1]]
                           withRowAnimation:UITableViewRowAnimationFade];
     
     self.lastCreatedStrand = resultStrand;
     
     DFPeanutStrandInviteAdapter *adapter = [[DFPeanutStrandInviteAdapter alloc] init];
     [adapter
      sendInvitesForStrand:resultStrand
      toPeanutContacts:peanutContacts
      inviteLocationString:self.pickedSuggestion.location
      invitedPhotosDate:resultStrand.first_photo_time
      success:^(DFSMSInviteStrandComposeViewController *composeView) {
        DDLogInfo(@"%@ created empty strand and invite successful", self.class);
        [SVProgressHUD showSuccessWithStatus:@"Request Sent"];
      } failure:^(NSError *error) {
        DDLogError(@"%@ invite failed: %@", self.class, error);
      }];
     [self dismissViewControllerAnimated:YES completion:nil];
   } failure:^(NSError *error) {
     DDLogError(@"%@ creating empty strand failed: %@", self.class, error);
   }];
}

- (DFPeanutFeedObject *)nextSuggestion
{
  if (!self.currentSuggestion) return self.filteredSuggestions.firstObject;
  NSUInteger indexOfSuggestion = [self.filteredSuggestions indexOfObject:self.currentSuggestion];
  NSUInteger nextIndex = ++indexOfSuggestion;
  if (nextIndex >= self.filteredSuggestions.count) {
    return self.filteredSuggestions.firstObject;
  }
  return self.filteredSuggestions[nextIndex];
}

- (DFVoidBlock)skipBlockForSuggestion:(DFPeanutFeedObject *)suggestion indexPath:(NSIndexPath *)indexPath
{
  return ^{
    self.currentSuggestion = [self nextSuggestion];
    [self reloadSuggestionsSection];
    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationRight];
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
