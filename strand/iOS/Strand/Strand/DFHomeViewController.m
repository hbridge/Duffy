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

@interface DFHomeViewController ()

@end

@implementation DFHomeViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNewSwapsDataNotificationName
                                             object:nil];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNewInboxDataNotificationName
                                             object:nil];
  
  [self configureNav];
  [self configureTableView];
}

- (void)configureNav
{
  self.navigationItem.title = @"Swap";
}

- (void)configureTableView
{
  self.tableView.rowHeight = 65;
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

- (void)reloadData
{
  [super reloadData];
  [self configureBadges];
}

- (void)configureBadges
{
  NSUInteger numToReview = [[[DFPeanutFeedDataManager sharedManager] unevaluatedPhotosFromOtherUsers] count];
  NSUInteger numToSend = [[[DFPeanutFeedDataManager sharedManager] suggestedStrands] count];
  for (LKBadgeView *badgeView in @[self.reviewBadgeView, self.sendBadgeView]) {
    badgeView.badgeColor = [DFStrandConstants strandBlue];
    badgeView.textColor = [UIColor whiteColor];
  }
  self.reviewBadgeView.text = [@(numToReview) stringValue];
  self.sendBadgeView.text = [@(numToSend) stringValue];
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

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

@end
