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

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (IBAction)reviewButtonPressed:(id)sender {
  [DFNavigationController presentWithRootController:self.suggestionsViewController inParent:self];
}

- (IBAction)sendButtonPressed:(id)sender {
  [DFNavigationController presentWithRootController:self.suggestionsViewController inParent:self];
}

- (DFSuggestionsPageViewController *)suggestionsViewController
{
  if (!_suggestionsViewController) {
    _suggestionsViewController = [[DFSuggestionsPageViewController alloc] init];
  }
  return _suggestionsViewController;
}

@end
