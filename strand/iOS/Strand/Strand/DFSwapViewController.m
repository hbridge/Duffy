//
//  DFSwapViewController.m
//  Strand
//
//  Created by Henry Bridge on 10/22/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSwapViewController.h"
#import "DFPersonSelectionTableViewCell.h"
#import "DFPeanutFeedDataManager.h"
#import "DFNoTableItemsView.h"
#import "DFFeedViewController.h"
#import "DFCreateStrandViewController.h"
#import "NSAttributedString+DFHelpers.h"
#import "DFAnalytics.h"
#import "DFStrandSuggestionsViewController.h"
#import "DFNavigationController.h"

@interface DFSwapViewController ()

@property (nonatomic, retain) NSMutableOrderedSet *sectionTitles;
@property (nonatomic, retain) NSMutableDictionary *sectionTitlesToObjects;
@property (nonatomic, retain) DFNoTableItemsView *noItemsView;
@property (nonatomic, retain) UIRefreshControl *refreshControl;
@property (nonatomic, retain) NSArray *allSuggestions;
@property (nonatomic, retain) NSMutableArray *ignoredSuggestions;

@end

const NSUInteger MaxSuggestionsToShow = 3;
const NSString *InvitesSectionTitle = @"Requested Swaps";
const NSString *SuggestedSectionTitle = @"Suggested Swaps";

@implementation DFSwapViewController

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
                                               name:DFStrandNewInboxDataNotificationName
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNewPrivatePhotosDataNotificationName
                                             object:nil];
}

- (void)configureNavAndTab
{
  self.navigationItem.title = @"Swap";
  self.tabBarItem.image = [UIImage imageNamed:@"Assets/Icons/SwapBarButton"];
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                            initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                            target:self
                                            action:@selector(createButtonPressed:)];
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
  self.tableView.rowHeight = DFPersonSelectionTableViewCellHeight;
  [tableView registerNib:[UINib nibForClass:[DFPersonSelectionTableViewCell class]] forCellReuseIdentifier:@"invite"];
  [tableView registerNib:[UINib nibForClass:[DFPersonSelectionTableViewCell class]] forCellReuseIdentifier:@"suggestion"];
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
  
  NSArray *invites = [[DFPeanutFeedDataManager sharedManager] inviteStrands];
  if (invites.count > 0) {
    [self.sectionTitles addObject:InvitesSectionTitle];
    self.sectionTitlesToObjects[InvitesSectionTitle] = invites;
  }
  
  self.allSuggestions = [[DFPeanutFeedDataManager sharedManager] suggestedStrands];
  [self reloadSuggestionsSection];
  
  [self.tableView reloadData];
  
  [self configureNoResultsView];
  [self configureTabCount];
}

- (void)reloadSuggestionsSection
{
  /* Reloads the suggestions section from the allSuggestions array, broken out
   so it can be called from the swipe handler safely */
  if (self.allSuggestions.count > 0) {
    [self.sectionTitles addObject:SuggestedSectionTitle];
    NSMutableArray *filteredSuggestions = [self.allSuggestions mutableCopy];
    [filteredSuggestions removeObjectsInArray:self.ignoredSuggestions];
    DDLogVerbose(@"allCount:%@ ignoredCount:%@ filteredCount:%@",
                 @(self.allSuggestions.count), @(self.ignoredSuggestions.count), @(filteredSuggestions.count));
    self.sectionTitlesToObjects[SuggestedSectionTitle] =
    [filteredSuggestions subarrayWithRange:(NSRange){0, MIN(filteredSuggestions.count, MaxSuggestionsToShow)}];
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
  // we're getting our data from both feeds, so wait till both are done to call endRefreshing
  BOOL __block inboxDone = NO;
  BOOL __block privatePhotosDone = NO;
  [[DFPeanutFeedDataManager sharedManager] refreshInboxFromServer:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      inboxDone = YES;
      if (inboxDone && privatePhotosDone) {
        [self.refreshControl endRefreshing];
        [self reloadData];
      }
    });
  }];
  [[DFPeanutFeedDataManager sharedManager] refreshPrivatePhotosFromServer:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      privatePhotosDone = YES;
      if (inboxDone && privatePhotosDone) {
        [self.refreshControl endRefreshing];
        [self reloadData];
      }
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
    if ([[DFPeanutFeedDataManager sharedManager] hasData]) {
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
  return [[self sectionObjectsForSection:section] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *object = [self feedObjectForIndexPath:indexPath];
  
  UITableViewCell *cell;
  if ([object.type isEqual:DFFeedObjectInviteStrand]) {
    cell = [self cellForInviteObject:object];
  } else if ([object.type isEqual:DFFeedObjectSection]) {
    cell = [self cellForSuggestionObject:object];
  }
  
  if (!cell) [NSException raise:@"unexpected object" format:@""];
  
  return cell;
}

- (UITableViewCell *)cellForInviteObject:(DFPeanutFeedObject *)inviteObject
{
  DFPeanutFeedObject *strandPosts = [[inviteObject subobjectsOfType:DFFeedObjectStrandPosts] firstObject];
  DFPersonSelectionTableViewCell *inviteCell = [self.tableView dequeueReusableCellWithIdentifier:@"invite"];

  [inviteCell configureWithCellStyle:(DFPersonSelectionTableViewCellStyleStrandUser
                                      | DFPersonSelectionTableViewCellStyleSubtitle)];
  inviteCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  
  inviteCell.profilePhotoStackView.names = inviteObject.actorNames;
  UIFont *grayFont = [UIFont fontWithName:@"HelveticaNeue-Light" size:inviteCell.nameLabel.font.pointSize];
  inviteCell.nameLabel.attributedText = [NSAttributedString
                                          attributedStringWithBlackText:inviteObject.actorsString
                                          grayText:@" wants to swap photos"
                                         grayFont:grayFont];
  inviteCell.subtitleLabel.text = strandPosts.title;
  
  return inviteCell;
}

- (UITableViewCell *)cellForSuggestionObject:(DFPeanutFeedObject *)suggestionObject
{
  DFPersonSelectionTableViewCell *suggestionCell = [self.tableView dequeueReusableCellWithIdentifier:@"suggestion"];
  // Setup cell attrbutes
  [suggestionCell configureWithCellStyle:(DFPersonSelectionTableViewCellStyleStrandUser
                                          | DFPersonSelectionTableViewCellStyleSubtitle)];
  suggestionCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  suggestionCell.profilePhotoStackView.names = suggestionObject.actorNames;
  
  // the suggestion sections don't include this user in the actors list
  suggestionCell.nameLabel.font = [UIFont fontWithName:@"HelveticaNeue-Mediume" size:suggestionCell.nameLabel.font.pointSize];
  NSString *nameString = [NSString stringWithFormat:@"%@ and You", [suggestionObject actorsString]];
  UIFont *grayFont = [UIFont fontWithName:@"HelveticaNeue-Light" size:suggestionCell.nameLabel.font.pointSize];
  suggestionCell.nameLabel.attributedText = [NSAttributedString
                                             attributedStringWithBlackText:nameString
                                             grayText:@" have photos"
                                             grayFont:grayFont];
  suggestionCell.subtitleLabel.text = [suggestionObject placeAndRelativeTimeString];
  
  // Setup the swipe action
  UILabel *hideLabel = [[UILabel alloc] init];
  hideLabel.text = @"Hide";
  hideLabel.textColor = [UIColor whiteColor];
  [hideLabel sizeToFit];
  [suggestionCell setSwipeGestureWithView:hideLabel
                          color:[UIColor lightGrayColor]
                           mode:MCSwipeTableViewCellModeExit
                          state:MCSwipeTableViewCellState3
                completionBlock:[self hideCompletionBlock]];
  // the default color is the color that appears before you swipe far enough for the action
  // we set to the group tableview background color to blend in
  suggestionCell.defaultColor = [UIColor groupTableViewBackgroundColor];

  
  return suggestionCell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  return self.sectionTitles[section];
}


- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
  if ([self.sectionTitles[section] isEqual:SuggestedSectionTitle]) {
    return @"Swipe left to hide Suggested Swaps";
  }
  
  return nil;
}

#pragma mark - Actions

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *object = [self feedObjectForIndexPath:indexPath];
  if ([object.type isEqual:DFFeedObjectInviteStrand]) {
    DFFeedViewController *feedViewController = [[DFFeedViewController alloc] initWithFeedObject:object];
    [self.navigationController pushViewController:feedViewController animated:YES];
  } else if ([object.type isEqual:DFFeedObjectSection]) {
    DFCreateStrandViewController *createViewController = [[DFCreateStrandViewController alloc]
                                                          initWithSuggestions:@[object]];
    [self.navigationController pushViewController:createViewController animated:YES];
  }
  [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

- (MCSwipeCompletionBlock)hideCompletionBlock
{
  return ^(MCSwipeTableViewCell *cell, MCSwipeTableViewCellState state, MCSwipeTableViewCellMode mode) {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (indexPath) {
      //Update the view locally
      [self.tableView beginUpdates];
      DFPeanutFeedObject *feedObject = [self feedObjectForIndexPath:indexPath];
      [self.ignoredSuggestions addObject:feedObject];
      [self reloadSuggestionsSection];
      [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
      if (self.allSuggestions.count >= MaxSuggestionsToShow) {
        [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:(MaxSuggestionsToShow - 1)
                                                                    inSection:indexPath.section]]
                              withRowAnimation:UITableViewRowAnimationBottom];
      }
      [self.tableView endUpdates];
      
      // Mark the strand as no longer suggestible with the server
      [[DFPeanutFeedDataManager sharedManager] markSuggestion:feedObject visible:NO];
    }
  };
}

- (void)createButtonPressed:(id)sender
{
  DFStrandSuggestionsViewController *createController = [DFStrandSuggestionsViewController sharedViewController];
  DFNavigationController *navController = [[DFNavigationController
                                            alloc] initWithRootViewController:createController];
  
  [self presentViewController:navController animated:YES completion:nil];
}


@end
