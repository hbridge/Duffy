//
//  DFHomeViewController.m
//  Strand
//
//  Created by Henry Bridge on 12/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFHomeViewController.h"
#import "DFSuggestionsPageViewController.h"
#import "DFNavigationController.h"
#import "DFDefaultsStore.h"
#import "DFPushNotificationsManager.h"
#import "DFPeanutFeedDataManager.h"
#import "DFNoTableItemsView.h"
#import "DFIncomingViewController.h"
#import "DFSettingsViewController.h"
#import "UIColor+DFHelpers.h"
#import "DFSegmentedControlReusableView.h"
#import "DFLabelReusableView.h"
#import "DFPhotoDetailViewController.h"
#import "DFFriendsViewController.h"
#import "DFPeanutNotificationsManager.h"
#import "DFDismissableModalViewController.h"
#import "DFAnalytics.h"
#import "DFMutliPhotoDetailPageController.h"
#import <MMPopLabel/MMPopLabel.h>

const CGFloat headerHeight = 60.0;
const NSUInteger MinPhotosToShowFilter = 20;

@interface DFHomeViewController ()

@property (nonatomic, retain) DFImageDataSource *datasource;
@property (nonatomic, retain) DFNoTableItemsView *noResultsView;
@property (nonatomic) NSUInteger selectedFilterIndex;
@property (nonatomic, retain) MMPopLabel *popLabel;

@end

@implementation DFHomeViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.buttonBar.backgroundColor = [DFStrandConstants defaultBackgroundColor];
  self.numPhotosPerRow = 3;
  [self observeNotifications];
  [self configureNav];
  [self configureCollectionView];
  [self configureNoResultsView];
  [self configurePopLabel];
}

- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNewInboxDataNotificationName
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNewSwapsDataNotificationName
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNotificationsUpdatedNotification
                                             object:nil];
  
}

- (void)configureNav
{
  self.navigationItem.title = @"Swap";
  self.navigationItem.rightBarButtonItems = @[[[UIBarButtonItem alloc]
                                               initWithImage:[UIImage imageNamed:@"Assets/Icons/AddPhotosBarButton"]
                                               style:UIBarButtonItemStylePlain
                                               target:self
                                               action:@selector(createButtonPressed:)],
                                              [[UIBarButtonItem alloc]
                                               initWithImage:[UIImage imageNamed:@"Assets/Icons/PeopleNavBarButton"]
                                               style:UIBarButtonItemStylePlain
                                               target:self
                                               action:@selector(friendsButtonPressed:)],
                                              ];
  
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                           initWithImage:[UIImage imageNamed:@"Assets/Icons/SettingsBarButton"]
                                           style:UIBarButtonItemStylePlain target:self
                                           action:@selector(settingsPressed:)];
}

- (void)configureCollectionView
{
  self.datasource = [[DFImageDataSource alloc]
                     initWithSections:nil
                     collectionView:self.collectionView];
  self.datasource.imageDataSourceDelegate = self;
  self.collectionView.delegate = self;
  
  [self.collectionView registerNib:[UINib nibForClass:[DFSegmentedControlReusableView class]]
        forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
               withReuseIdentifier:@"segmentedHeader"];
  [self.collectionView registerNib:[UINib nibForClass:[DFLabelReusableView class]]
        forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
               withReuseIdentifier:@"labelHeader"];
    self.flowLayout.headerReferenceSize = CGSizeMake(self.collectionView.frame.size.width, headerHeight);
  [self.collectionView registerNib:[UINib nibForClass:[DFLabelReusableView class]]
        forSupplementaryViewOfKind:UICollectionElementKindSectionFooter
               withReuseIdentifier:@"footer"];
  //self.flowLayout.footerReferenceSize = CGSizeMake(self.collectionView.frame.size.width, headerHeight);

  self.datasource.showActionsBadge = YES;
  self.datasource.showUnreadNotifsCount = YES;
  self.collectionView.backgroundColor = [UIColor whiteColor];
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath
{
  if (kind == UICollectionElementKindSectionHeader) {
    return [self headerViewForIndexPath:indexPath];
  } else if (kind == UICollectionElementKindSectionFooter) {
    return [self footerViewForIndexPath:indexPath];
  }
  
  [NSException raise:@"unexpected type" format:@"unexpected supplementary view type type"];
  return nil;
}

static BOOL showFilters = NO;

- (UICollectionReusableView *)headerViewForIndexPath:(NSIndexPath *)indexPath
{
  UICollectionReusableView *reusableView = nil;
  if (showFilters) {
    DFSegmentedControlReusableView *segmentedView =
    [self.collectionView
     dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
     withReuseIdentifier:@"segmentedHeader"
     forIndexPath:indexPath];
    reusableView = segmentedView;
    [segmentedView.segmentedControl setTitle:@"Liked & Commented" forSegmentAtIndex:0];
    [segmentedView.segmentedControl setTitle:@"All Photos" forSegmentAtIndex:1];
    [segmentedView.segmentedControl setWidth:140 forSegmentAtIndex:0];
    [segmentedView.segmentedControl setWidth:140 forSegmentAtIndex:1];
    segmentedView.segmentedControl.tintColor = [UIColor colorWithRedByte:35 green:35 blue:35 alpha:1.0];
    [segmentedView.segmentedControl addTarget:self
                                       action:@selector(filterChanged:)
                             forControlEvents:UIControlEventValueChanged];
  } else {
    DFLabelReusableView *labelHeader = [self.collectionView
     dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
     withReuseIdentifier:@"labelHeader"
     forIndexPath:indexPath];
    reusableView =  labelHeader;
    labelHeader.label.textAlignment = NSTextAlignmentCenter;
    labelHeader.label.textColor = [UIColor lightGrayColor];
    DFSection *section = self.datasource.sections[indexPath.section];
    labelHeader.label.text = section.title;
  }
  
  if (!reusableView) [NSException raise:@"null header" format:@"null header"];
  
  return reusableView;
}

- (UICollectionReusableView *)footerViewForIndexPath:(NSIndexPath *)indexPath
{
  DFLabelReusableView *footerView = [self.collectionView
                                     dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                                     withReuseIdentifier:@"footer"
                                     forIndexPath:indexPath];
  UILabel *footerLabel = footerView.label;

  footerLabel.font = [UIFont fontWithName:@"HelvetiaNeue" size:19.0];
  footerLabel.textColor = [UIColor lightGrayColor];
  footerLabel.textAlignment = NSTextAlignmentCenter;
  
  if ([[self.datasource photosForSection:indexPath.section] count] == 0) {
    footerLabel.text = @"No Photos";
  } else {
    footerLabel.text = @"";
  }
  
  return footerView;
}


- (void)didFinishFirstLoadForDatasource:(DFImageDataSource *)datasource
{
  self.collectionView.contentOffset = CGPointMake(0, headerHeight);
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self configureBadges];
  [[DFPeanutFeedDataManager sharedManager] refreshInboxFromServer:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  if ([DFDefaultsStore isSetupStepPassed:DFSetupStepIncomingNux]) {
    [[DFPushNotificationsManager sharedManager] promptForPushNotifsIfNecessary];
  }
  [self configureBadges];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}



- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  
  CGFloat usableWidth = self.collectionView.frame.size.width -
  ((CGFloat)(self.numPhotosPerRow - 1)  * self.flowLayout.minimumInteritemSpacing);
  CGFloat itemSize = usableWidth / (CGFloat)self.numPhotosPerRow;
  CGSize oldSize = self.flowLayout.itemSize;
  CGSize newSize =  CGSizeMake(itemSize, itemSize);
  if (!CGSizeEqualToSize(oldSize, newSize)) {
    self.flowLayout.itemSize = newSize;
    [self.flowLayout invalidateLayout];
    [self.collectionView reloadData];
  }
  [self.flowLayout invalidateLayout];
}

- (void)reloadData
{
  dispatch_async(dispatch_get_main_queue(), ^{
    if (showFilters) {
      NSArray *feedPhotos;

      if (self.selectedFilterIndex == 0) {
        feedPhotos = [[DFPeanutFeedDataManager sharedManager] photosWithActivity];
      } else {
        feedPhotos = [[DFPeanutFeedDataManager sharedManager]
                      allEvaluatedOrSentPhotos];
      }
      [self.datasource setFeedPhotos:feedPhotos];
    } else {
      NSArray *allPhotos = [[DFPeanutFeedDataManager sharedManager]
                            allEvaluatedOrSentPhotos];
      NSArray *sections = [self.class sectionsFromFeedPhotos:allPhotos];
      [self.datasource setSections:sections];
    }
    
    [self configureNoResultsView];
    [self configureBadges];
  });
}

+ (NSArray *)sectionsFromFeedPhotos:(NSArray *)feedPhotos
{
  // sort by activity date
  NSArray *sorted = [feedPhotos sortedArrayUsingComparator:^NSComparisonResult(DFPeanutFeedObject *photo1, DFPeanutFeedObject *photo2) {
    DFPeanutAction *photo1Latest = [photo1 mostRecentAction];
    DFPeanutAction *photo2Latest = [photo2 mostRecentAction];
    // want reverse sort so reverse comparison
    return [photo2Latest.time_stamp compare:photo1Latest.time_stamp];
  }];
  
  // create arrays for last week and older
  NSMutableArray *lastWeek = [NSMutableArray new];
  NSMutableArray *older = [sorted mutableCopy];
  for (DFPeanutFeedObject *photo in sorted) {
    DFPeanutAction *mostRecentAction = [photo mostRecentAction];
    NSTimeInterval timeAgo = [[mostRecentAction time_stamp] timeIntervalSinceNow];
    if (timeAgo < -60*60*24*7) break;
    [lastWeek addObject:photo];
  }
  
  if (older.count >= lastWeek.count && lastWeek.count > 0) {
    [older removeObjectsInRange:(NSRange){0, lastWeek.count}];
  }
  
  // create section objects for last week and older
  
  NSMutableArray *result = [NSMutableArray new];
  if (lastWeek.count > 0) {
    [result addObject:[DFSection sectionWithTitle:@"Recent Activity" object:nil rows:lastWeek]];
  }
  
  if (older.count > 0) {
    [result addObject:[DFSection sectionWithTitle:@"Older" object:nil rows:older]];
  }

  return result;
}


- (void)configureNoResultsView
{
  dispatch_async(dispatch_get_main_queue(), ^{
    if ([self.datasource numberOfSectionsInCollectionView:self.collectionView] == 0) {
      if (!self.noResultsView) self.noResultsView = [UINib instantiateViewWithClass:[DFNoTableItemsView class]];
      [self.noResultsView setSuperView:self.collectionView];
      if ([[DFPeanutFeedDataManager sharedManager] hasInboxData]) {
        self.noResultsView.titleLabel.text = @"No Photos";
        [self.noResultsView.activityIndicator stopAnimating];
      } else {
        self.noResultsView.titleLabel.text = @"Loading...";
        [self.noResultsView.activityIndicator startAnimating];
      }
    } else {
      if (self.noResultsView) [self.noResultsView removeFromSuperview];
      self.noResultsView = nil;
    }
  });
}

- (void)configurePopLabel
{
  self.popLabel = [MMPopLabel popLabelWithText:@"No photos at this time"];
  [self.view addSubview:self.popLabel];
}

- (void)configureBadges
{
  NSUInteger numToReview = [[[DFPeanutFeedDataManager sharedManager] unevaluatedPhotosFromOtherUsers] count];
  NSUInteger numToSend = [[[DFPeanutFeedDataManager sharedManager] suggestedStrands] count];
  for (LKBadgeView *badgeView in @[self.reviewBadgeView, self.sendBadgeView]) {
    badgeView.badgeColor = [DFStrandConstants strandRed];
    badgeView.textColor = [UIColor whiteColor];
  }
  
  if (![DFDefaultsStore isSetupStepPassed:DFSetupStepIncomingNux]) {
    numToReview++;
  } else if (![DFDefaultsStore isSetupStepPassed:DFSetupStepSuggestionsNux]) {
    numToSend++;
  }
  
  [self configureButtonsWithIncomingCount:numToReview outgoingCount:numToSend];
}

- (void)configureButtonsWithIncomingCount:(NSUInteger)numToReview outgoingCount:(NSUInteger)numToSend
{
  if (numToReview > 0) {
    self.reviewBadgeView.text = [@(MIN(numToReview, 99)) stringValue];
    self.reviewBadgeView.hidden = NO;
    [self.reviewButton setBackgroundImage:[UIImage imageNamed:@"Assets/Icons/HomeInboxHighlighted"] forState:UIControlStateNormal];
  } else {
    self.reviewBadgeView.hidden = YES;
    [self.reviewButton setBackgroundImage:[UIImage imageNamed:@"Assets/Icons/HomeInbox"] forState:UIControlStateNormal];
  }
  
  self.sendBadgeView.hidden = NO;
  if (numToSend > 0) {
    self.sendBadgeView.text = [@(MIN(numToSend, 99)) stringValue];
    [self.sendButton setBackgroundImage:[UIImage imageNamed:@"Assets/Icons/HomeSendHighlighted"]
                               forState:UIControlStateNormal];
  } else {
    [self.sendButton setBackgroundImage:[UIImage imageNamed:@"Assets/Icons/HomeSend"]
                               forState:UIControlStateNormal];
  }
}

#pragma mark - Actions

- (IBAction)reviewButtonPressed:(id)sender {
  NSUInteger numToReview = [[[DFPeanutFeedDataManager sharedManager] unevaluatedPhotosFromOtherUsers] count];
  if (numToReview > 0) {
  [DFDismissableModalViewController
   presentWithRootController:[[DFSuggestionsPageViewController alloc]
                              initWithPreferredType:DFIncomingViewType]
   inParent:self];
  } else {
    [self.popLabel popAtView:sender animatePopLabel:YES animateTargetView:NO];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      [self.popLabel dismiss];
    });
  }
  [self logHomeButtonPressed:sender];
}

- (IBAction)sendButtonPressed:(id)sender {
  NSUInteger numToSend = [[[DFPeanutFeedDataManager sharedManager] suggestedStrands] count];
  if (numToSend > 0) {
  [DFDismissableModalViewController
   presentWithRootController:[[DFSuggestionsPageViewController alloc]
                              initWithPreferredType:DFSuggestionViewType]
   inParent:self];
  } else {
    [self.popLabel popAtView:sender animatePopLabel:YES animateTargetView:NO];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      [self.popLabel dismiss];
    });
  }
  [self logHomeButtonPressed:sender];
}

- (void)logHomeButtonPressed:(id)button
{
  NSString *buttonName = @"";
  if (button == self.reviewButton) buttonName = @"incoming";
  else if (button == self.sendButton) buttonName = @"outgoing";
  NSUInteger numToReview = [[[DFPeanutFeedDataManager sharedManager] unevaluatedPhotosFromOtherUsers] count];
  NSUInteger numToSend = [[[DFPeanutFeedDataManager sharedManager] suggestedStrands] count];
  [DFAnalytics logHomeButtonTapped:buttonName
                incomingBadgeCount:numToReview
                outgoingBadgeCount:numToSend];
}

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *photo = [[[self.datasource feedObjectForIndexPath:indexPath]
                                leafNodesFromObjectOfType:DFFeedObjectPhoto] firstObject];
   
  NSMutableArray *allPhotos = [NSMutableArray new];
  for (NSUInteger section = 0; section < [self.datasource numberOfSectionsInCollectionView:self.collectionView]; section++) {
    [allPhotos addObjectsFromArray:[self.datasource photosForSection:section]];
  }
  DFMutliPhotoDetailPageController *mpvc = [[DFMutliPhotoDetailPageController alloc]
                                            initWithCurrentPhoto:photo inPhotos:allPhotos];
  
  [DFDismissableModalViewController presentWithRootController:mpvc inParent:self];
}

- (void)filterChanged:(UISegmentedControl *)sender
{
  DDLogVerbose(@"new filter %@", [sender titleForSegmentAtIndex:sender.selectedSegmentIndex]);
  self.selectedFilterIndex = sender.selectedSegmentIndex;
}

- (void)setSelectedFilterIndex:(NSUInteger)selectedFilterIndex
{
  _selectedFilterIndex = selectedFilterIndex;
  [self reloadData];
}

- (void)createButtonPressed:(id)sender
{
  DFCreateStrandFlowViewController *createController = [[DFCreateStrandFlowViewController alloc] init];
  [self presentViewController:createController animated:YES completion:nil];
}

- (void)settingsPressed:(id)sender
{
  [DFSettingsViewController presentModallyInViewController:self];
}

- (void)friendsButtonPressed:(id)sender
{
  DFFriendsViewController *friendsViewController = [[DFFriendsViewController alloc] init];
  [DFNavigationController presentWithRootController:friendsViewController
                                           inParent:self
                                withBackButtonTitle:@"Back"];
}

@end
