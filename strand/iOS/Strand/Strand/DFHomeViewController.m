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

@interface DFHomeViewController ()

@property (nonatomic, retain) DFSuggestionsPageViewController *suggestionsViewController;

@end

@implementation DFHomeViewController

- (void)viewDidLoad {
  [super viewDidLoad];
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
  }
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (IBAction)reviewButtonPressed:(id)sender {
  self.suggestionsViewController.preferredType = DFIncomingViewType;
  [DFNavigationController presentWithRootController:self.suggestionsViewController
                                           inParent:self
                                withBackButtonTitle:@"Close"];
}

- (IBAction)sendButtonPressed:(id)sender {
  self.suggestionsViewController.preferredType = DFSuggestionViewType;
  [DFNavigationController
   presentWithRootController:self.suggestionsViewController
   inParent:self
   withBackButtonTitle:@"Close"];
}

- (DFSuggestionsPageViewController *)suggestionsViewController
{
  if (!_suggestionsViewController) {
    _suggestionsViewController = [[DFSuggestionsPageViewController alloc] init];
  }
  return _suggestionsViewController;
}

@end
