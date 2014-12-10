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
#import "DFImageDataSource.h"
#import "DFNoTableItemsView.h"
#import "DFIncomingViewController.h"
#import "DFSettingsViewController.h"
#import "DFInviteFriendViewController.h"
#import "UIColor+DFHelpers.h"

@interface DFHomeViewController ()

@property (nonatomic, retain) DFImageDataSource *datasource;
@property (nonatomic, retain) DFNoTableItemsView *noResultsView;

@end

@implementation DFHomeViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
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
                                               initWithImage:[UIImage imageNamed:@"Assets/Icons/InviteBarButton"]
                                               style:UIBarButtonItemStylePlain
                                               target:self
                                               action:@selector(inviteButtonPressed:)],
                                              ];
  
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                           initWithImage:[UIImage imageNamed:@"Assets/Icons/SettingsBarButton"]
                                           style:UIBarButtonItemStylePlain target:self
                                           action:@selector(settingsPressed:)];
  self.navigationController.navigationBar.barTintColor = [UIColor colorWithRedByte:35 green:35 blue:35 alpha:1.0];
  self.navigationController.navigationBar.translucent = NO;
}

- (void)configureCollectionView
{
  self.datasource = [[DFImageDataSource alloc]
                     initWithCollectionFeedObjects:nil
                     collectionView:self.collectionView];
  self.collectionView.delegate = self;
  self.datasource.showActionsBadge = YES;
  self.collectionView.backgroundColor = [UIColor darkGrayColor];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [[DFPeanutFeedDataManager sharedManager] refreshInboxFromServer:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  if (![DFDefaultsStore isSetupStepPassed:DFSetupStepSuggestionsNux]) {
    [self reviewButtonPressed:self.reviewButton];
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
  self.datasource.collectionFeedObjects = [[DFPeanutFeedDataManager sharedManager]
                                           acceptedStrandsWithPostsCollapsedAndFilteredToUser:0];
  [self.collectionView reloadData];
  [self configureNoResultsView];
  [self configureBadges];
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
  DFPeanutFeedObject *strandObject = self.datasource.collectionFeedObjects[indexPath.section];
  DFPeanutFeedObject *photo = [[[self.datasource feedObjectForIndexPath:indexPath]
                                leafNodesFromObjectOfType:DFFeedObjectPhoto] firstObject];
  
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

- (void)inviteButtonPressed:(id)sender
{
  DFInviteFriendViewController *inviteController = [[DFInviteFriendViewController alloc] init];
  [self presentViewController:inviteController animated:YES completion:nil];
}

@end
