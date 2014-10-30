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

@interface DFSwapViewController ()

@property (nonatomic, retain) NSMutableOrderedSet *sectionTitles;
@property (nonatomic, retain) NSMutableDictionary *sectionTitlesToObjects;
@property (nonatomic, retain) DFNoTableItemsView *noItemsView;
@property (nonatomic, retain) UIRefreshControl *refreshControl;
@property (nonatomic, retain) NSArray *allSuggestions;
@property (nonatomic, retain) NSMutableArray *ignoredSuggestions;
@property (nonatomic, retain) NSMutableArray *filteredSuggestions;

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
  DDLogVerbose(@"%@ viewDidLoad", self.class);
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
  DDLogVerbose(@"view will appear");
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
  DDLogVerbose(@"View did appear");
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
  
  [self reloadSuggestionsSection];
  
  [self.tableView reloadData];
  
  [self configureNoResultsView];
  [self configureTabCount];
  [self.refreshControl endRefreshing];
}

- (void)reloadSuggestionsSection
{
  /* Reloads the suggestions section from the allSuggestions array, broken out
   so it can be called from the swipe handler safely */
  [self.sectionTitles addObject:SuggestedSectionTitle];
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
      DDLogVerbose(@"Killing spinner...");
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
  
  if ([objects[indexPath.row] isKindOfClass:[DFPeanutFeedObject class]])
    return objects[indexPath.row];
  
  return nil;
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
  DFPeanutFeedObject *object = [self feedObjectForIndexPath:indexPath];
  
  UITableViewCell *cell;
  if (!object) {
    cell = [self noResultsCellForIndexPath:indexPath];
  } else if ([object.type isEqual:DFFeedObjectInviteStrand]) {
    cell = [self cellForInviteObject:object indexPath:indexPath];
  } else if ([object.type isEqual:DFFeedObjectSwapSuggestion]) {
    cell = [self cellForSuggestionObject:object indexPath:indexPath];
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
  if ([feedObject.type isEqual:DFFeedObjectStrandPosts]) {
     photoObject = [[[feedObject.objects firstObject]
                                        subobjectsOfType:DFFeedObjectPhoto]
                                       firstObject];
  } else {
    for (DFPeanutFeedObject *descendent in
         feedObject.enumeratorOfDescendents.allObjects.reverseObjectEnumerator.allObjects) {
      if ([descendent.type isEqualToString:DFFeedObjectPhoto]) {
        photoObject = descendent;
        break;
      }
    }
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
  NSString *titleMarkup = [NSString stringWithFormat:@"With <name>%@</name>", [suggestionObject actorsString]];
  
  [self configureCell:suggestionCell
            indexPath:indexPath
            withNames:suggestionObject.actorNames
          titleMarkup:titleMarkup
           feedObject:suggestionObject];
  
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
  if ([self.sectionTitles[section] isEqual:SuggestedSectionTitle]){
    if (self.filteredSuggestions.count > 0)
      return @"Swipe left to hide Suggested Swaps";
    else return @"Invite friends to find more Suggested Swaps";
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
  } else if ([object.type isEqual:DFFeedObjectSwapSuggestion]) {
    DFCreateStrandFlowViewController *createStrandFlow = [[DFCreateStrandFlowViewController alloc]
                                                          initWithHighlightedPhotoCollection:object];
    
    [self presentViewController:createStrandFlow animated:YES completion:nil];
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
      NSUInteger oldSuggestionsCount = self.filteredSuggestions.count;
      DFPeanutFeedObject *feedObject = [self feedObjectForIndexPath:indexPath];
      [self.ignoredSuggestions addObject:feedObject];
      [self reloadSuggestionsSection];
      [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
      if (self.filteredSuggestions.count == oldSuggestionsCount) {
        // we've deleted a row, if we hav the same number of filtered suggestion rows as before,
        // we need to now insert one at the end
        [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:(MaxSuggestionsToShow - 1)
                                                                    inSection:indexPath.section]]
                              withRowAnimation:UITableViewRowAnimationBottom];
      }
      if (self.filteredSuggestions.count == 0) {
        [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:indexPath.section]
                      withRowAnimation:UITableViewRowAnimationAutomatic];
        [self.sectionTitles removeObject:SuggestedSectionTitle];
        [self configureNoResultsView];
      }
      
      [self.tableView endUpdates];
      
      // Mark the strand as no longer suggestible with the server
      [[DFPeanutFeedDataManager sharedManager] markSuggestion:feedObject visible:NO];
    }
  };
}

- (void)createButtonPressed:(id)sender
{
  DFCreateStrandFlowViewController *createController = [[DFCreateStrandFlowViewController alloc] init];
  [self presentViewController:createController animated:YES completion:nil];
}


@end
