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
#import "DFOverlayView.h"
#import <KLCPopup/KLCPopup.h>

@interface DFHomeViewController ()

@property (nonatomic, retain) DFSuggestionsPageViewController *suggestionsPageViewController;

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

- (void)refreshFromServer
{
  [super refreshFromServer];
  [[DFPeanutFeedDataManager sharedManager] refreshSwapsFromServer:nil];
}

- (void)configureBadges
{
  NSUInteger numToReview = [[[DFPeanutFeedDataManager sharedManager] unevaluatedPhotosFromOtherUsers] count];
  NSUInteger numToSend = [[[DFPeanutFeedDataManager sharedManager] suggestedStrands] count];
  for (LKBadgeView *badgeView in @[self.reviewBadgeView, self.sendBadgeView]) {
    badgeView.badgeColor = [DFStrandConstants strandBlue];
    badgeView.textColor = [UIColor whiteColor];
  }
  if (numToReview > 0) {
    self.reviewBadgeView.text = [@(numToReview) stringValue];
    self.reviewBadgeView.hidden = NO;
  } else {
    self.reviewBadgeView.hidden = YES;
  }
  
  if (numToSend > 0) {
    self.sendBadgeView.text = @"★";
    self.sendBadgeView.hidden = NO;
  } else {
    self.sendBadgeView.hidden = YES;
  }
  
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (IBAction)reviewButtonPressed:(id)sender {
  [self showPageViewControllerOverlay:[[DFSuggestionsPageViewController alloc]
                                       initWithPreferredType:DFIncomingViewType]];
}

- (IBAction)sendButtonPressed:(id)sender {
  [self showPageViewControllerOverlay:[[DFSuggestionsPageViewController alloc]
                                       initWithPreferredType:DFSuggestionViewType]];
}

- (void)showPageViewControllerOverlay:(DFSuggestionsPageViewController *)svc
{
  // need to keep the page view controller retained as otherwise it will be GC'ed
  // since we are stripping it's view away from it
  self.suggestionsPageViewController = svc;
  self.suggestionsPageViewController.view.backgroundColor = [UIColor clearColor];
  DFOverlayView *overlayView = [[DFOverlayView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  [overlayView setContentView:self.suggestionsPageViewController.view];
  KLCPopup *popup = [KLCPopup popupWithContentView:overlayView
                                          showType:KLCPopupShowTypeGrowIn
                                       dismissType:KLCPopupDismissTypeShrinkOut
                                          maskType:KLCPopupMaskTypeDimmed
                          dismissOnBackgroundTouch:NO
                             dismissOnContentTouch:NO];
  [popup show];
  overlayView.closeButtonHandler = ^{
    [popup dismiss:YES];
  };

}

@end
