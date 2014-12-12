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
#import "DFEvaluatedPhotoViewController.h"
#import "DFFriendsViewController.h"
#import "DFBadgeReusableView.h"
#import "DFPeanutNotificationsManager.h"

const CGFloat headerHeight = 60.0;

@interface DFHomeViewController ()

@property (nonatomic, retain) DFImageDataSource *datasource;
@property (nonatomic, retain) DFNoTableItemsView *noResultsView;
@property (nonatomic) NSUInteger selectedFilterIndex;
@property (nonatomic, retain) UILabel *footerLabel;

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
    self.navigationController.navigationBar.barTintColor = [UIColor colorWithRedByte:233 green:233 blue:233 alpha:0.6];
  self.navigationController.navigationBar.translucent = NO;
}

- (void)configureCollectionView
{
  self.datasource = [[DFImageDataSource alloc]
                     initWithCollectionFeedObjects:nil
                     collectionView:self.collectionView];
  self.datasource.imageDataSourceDelegate = self;
  self.collectionView.delegate = self;
  
  [self.collectionView registerNib:[UINib nibForClass:[DFSegmentedControlReusableView class]]
        forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
               withReuseIdentifier:@"header"];
  self.flowLayout.headerReferenceSize = CGSizeMake(self.collectionView.frame.size.width, headerHeight);
  [self.collectionView registerNib:[UINib nibForClass:[DFLabelReusableView class]]
        forSupplementaryViewOfKind:UICollectionElementKindSectionFooter
               withReuseIdentifier:@"footer"];
  self.flowLayout.footerReferenceSize = CGSizeMake(self.collectionView.frame.size.width, headerHeight);
  [self.collectionView registerClass:[DFBadgeReusableView class]
          forSupplementaryViewOfKind:DFBadgingCollectionViewFlowLayoutBadgeView
                 withReuseIdentifier:@"badge"];

  self.datasource.showActionsBadge = NO;
  self.collectionView.backgroundColor = [UIColor whiteColor];
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath
{
  if (kind == UICollectionElementKindSectionHeader &&
      indexPath.section == 0 &&
      indexPath.row == 0) {
    
    return [self headerViewForIndexPath:indexPath];
  } else if (kind == UICollectionElementKindSectionFooter &&
             indexPath.section == 0 &&
             indexPath.row == 0)
  {
    return [self footerViewForIndexPath:indexPath];
  } else if (kind == DFBadgingCollectionViewFlowLayoutBadgeView) {
    return [self unreadBadgeForIndexPath:indexPath];
  }
  return nil;
}

- (UICollectionReusableView *)headerViewForIndexPath:(NSIndexPath *)indexPath
{
  DFSegmentedControlReusableView *segmentedView =
  [self.collectionView
   dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
   withReuseIdentifier:@"header"
   forIndexPath:indexPath];
  [segmentedView.segmentedControl setTitle:@"Activity" forSegmentAtIndex:0];
  [segmentedView.segmentedControl setTitle:@"All Photos" forSegmentAtIndex:1];
  [segmentedView.segmentedControl setWidth:120 forSegmentAtIndex:0];
  [segmentedView.segmentedControl setWidth:120 forSegmentAtIndex:1];
  segmentedView.segmentedControl.tintColor = [UIColor colorWithRedByte:35 green:35 blue:35 alpha:1.0];
  [segmentedView.segmentedControl addTarget:self
                                     action:@selector(filterChanged:)
                           forControlEvents:UIControlEventValueChanged];
  
  
  return segmentedView;
}

- (UICollectionReusableView *)footerViewForIndexPath:(NSIndexPath *)indexPath
{
  DFLabelReusableView *footerView = [self.collectionView
                                     dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                                     withReuseIdentifier:@"footer"
                                     forIndexPath:indexPath];
  self.footerLabel = footerView.label;

  self.footerLabel.font = [UIFont fontWithName:@"HelvetiaNeue" size:19.0];
  self.footerLabel.textColor = [UIColor lightGrayColor];
  self.footerLabel.textAlignment = NSTextAlignmentCenter;
  
  
  [self configureFooterLabelText];
  return footerView;
}

- (UICollectionReusableView *)unreadBadgeForIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *photoObject = [self.datasource feedObjectForIndexPath:indexPath];
  NSArray *unreadNotifs = [[DFPeanutNotificationsManager sharedManager] unreadNotifications];
  NSUInteger unreadCount = 0;
  for (DFPeanutAction *action in photoObject.actions) {
    if ([unreadNotifs containsObject:action]) unreadCount++;
  }
  
  DFBadgeReusableView *badgeReusableView = [self.collectionView
                                            dequeueReusableSupplementaryViewOfKind:DFBadgingCollectionViewFlowLayoutBadgeView
                                            withReuseIdentifier:@"badge"
                                            forIndexPath:indexPath];
  badgeReusableView.badgeView.text = [@(unreadCount) stringValue];
  if (unreadCount > 0) {
    badgeReusableView.hidden = NO;
  } else {
    badgeReusableView.hidden = YES;
  }
  
  return badgeReusableView;
}

- (void)configureFooterLabelText
{
  NSString *filterString;
  if (self.selectedFilterIndex == 0){
    filterString = @"with Activity";
  } else {
    filterString = @"Photos";
  }
  
  if ([self.datasource numberOfSectionsInCollectionView:self.collectionView] > 0) {
    NSString *text = [NSString stringWithFormat:@"%@ %@",
                    @([[self.datasource photosForSection:0] count]),
                    filterString];
    self.footerLabel.text = text;
  } else {
    self.footerLabel.text = @"No Photos Yet";
  }
}

- (void)didFinishFirstLoadForDatasource:(DFImageDataSource *)datasource
{
  self.collectionView.contentOffset = CGPointMake(0, headerHeight);
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self reloadData];
  [[DFPeanutFeedDataManager sharedManager] refreshInboxFromServer:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  if (![DFDefaultsStore isSetupStepPassed:DFSetupStepSuggestionsNux]) {
    if ([[[DFPeanutFeedDataManager sharedManager] unevaluatedPhotosFromOtherUsers] count] > 0) {
      [self reviewButtonPressed:self.reviewButton];
    } else {
      [self sendButtonPressed:self.sendButton];
    }
  } else {
    [[DFPushNotificationsManager sharedManager] promptForPushNotifsIfNecessary];
  }
  [self configureBadges];
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
  NSArray *feedPhotos;
  if (self.selectedFilterIndex == 0) {
    feedPhotos = [[DFPeanutFeedDataManager sharedManager] favoritedPhotos];
  } else {
    feedPhotos = [[DFPeanutFeedDataManager sharedManager]
                  allEvaluatedOrSentPhotos];
  }
  [self.datasource setFeedPhotos:feedPhotos];
  [self.collectionView reloadData];
  [self configureNoResultsView];
  [self configureBadges];
  [self configureFooterLabelText];
}


- (void)configureNoResultsView
{
  dispatch_async(dispatch_get_main_queue(), ^{
    if (self.datasource.collectionFeedObjects.count == 0) {
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

- (void)configureBadges
{
  NSUInteger numToReview = [[[DFPeanutFeedDataManager sharedManager] unevaluatedPhotosFromOtherUsers] count];
  NSUInteger numToSend = [[[DFPeanutFeedDataManager sharedManager] suggestedStrands] count];
  for (LKBadgeView *badgeView in @[self.reviewBadgeView, self.sendBadgeView]) {
    badgeView.badgeColor = [DFStrandConstants strandRed];
    badgeView.textColor = [UIColor whiteColor];
  }
  if (numToReview > 0) {
    self.reviewBadgeView.text = [@(numToReview) stringValue];
    self.reviewBadgeView.hidden = NO;
    [self.reviewButton setBackgroundImage:[UIImage imageNamed:@"Assets/Icons/HomeInboxHighlighted"] forState:UIControlStateNormal];
  } else {
    self.reviewBadgeView.hidden = YES;
    [self.reviewButton setBackgroundImage:[UIImage imageNamed:@"Assets/Icons/HomeInbox"] forState:UIControlStateNormal];
  }
  
  if (numToSend > 0) {
    self.sendBadgeView.text = @"★";
    self.sendBadgeView.hidden = NO;
    [self.sendButton setBackgroundImage:[UIImage imageNamed:@"Assets/Icons/HomeSendHighlighted"] forState:UIControlStateNormal];
  } else {
    self.sendBadgeView.hidden = YES;
    [self.sendButton setBackgroundImage:[UIImage imageNamed:@"Assets/Icons/HomeSend"] forState:UIControlStateNormal];
    
  }
}

#pragma mark - Actions

- (IBAction)reviewButtonPressed:(id)sender {
  [DFNavigationController presentWithRootController:[[DFSuggestionsPageViewController alloc]
                                                     initWithPreferredType:DFIncomingViewType]
                                           inParent:self
                                withBackButtonTitle:@"Close"];
}

- (IBAction)sendButtonPressed:(id)sender {
  [DFNavigationController presentWithRootController:[[DFSuggestionsPageViewController alloc]
                                                     initWithPreferredType:DFSuggestionViewType]
                                           inParent:self
                                withBackButtonTitle:@"Close"];
}

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *photo = [[[self.datasource feedObjectForIndexPath:indexPath]
                                leafNodesFromObjectOfType:DFFeedObjectPhoto] firstObject];
  DFPeanutFeedObject *strandPosts = [[DFPeanutFeedDataManager sharedManager]
                                     strandPostsObjectWithId:photo.strand_id.longLongValue];
  
  DFEvaluatedPhotoViewController *epvc = [[DFEvaluatedPhotoViewController alloc]
                                          initWithPhotoObject:photo
                                          inPostsObject:strandPosts];
  
  [DFNavigationController presentWithRootController:epvc inParent:self withBackButtonTitle:@"Close"];
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
