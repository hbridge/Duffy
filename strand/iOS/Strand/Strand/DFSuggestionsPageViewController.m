//
//  DFSuggestionsPageViewController.m
//  Strand
//
//  Created by Henry Bridge on 11/25/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSuggestionsPageViewController.h"
#import "DFSuggestionViewController.h"
#import "DFPeanutFeedDataManager.h"
#import "DFNavigationController.h"
#import "DFPeanutStrandInviteAdapter.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "DFNoTableItemsView.h"
#import "DFUploadController.h"

@interface DFSuggestionsPageViewController ()

@property (nonatomic, retain) NSArray *allSuggestions;
@property (nonatomic, retain) NSMutableArray *filteredSuggestions;
@property (nonatomic, retain) DFPeanutFeedObject *pickedSuggestion;
@property (nonatomic, retain) DFPeanutStrand *lastCreatedStrand;
@property (nonatomic, retain) NSMutableArray *suggestionsToRemove;
@property (nonatomic, retain) DFNoTableItemsView *noResultsView;

@end

@implementation DFSuggestionsPageViewController


- (instancetype)init
{
  self = [super initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                  navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                options:nil];
  if (self) {
    self.delegate = self;
    [self observeNotifications];
    [self configureNavAndTab];
    self.suggestionsToRemove = [NSMutableArray new];
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
  self.navigationItem.title = @"Suggestions";
  self.tabBarItem.title = @"Suggestions";
  self.tabBarItem.image = [UIImage imageNamed:@"Assets/Icons/SwapBarButton"];
  self.tabBarItem.selectedImage = [UIImage imageNamed:@"Assets/Icons/SwapBarButtonSelected"];
//  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
//                                            initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
//                                            target:self
//                                            action:@selector(createButtonPressed:)];
  self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]
                                           initWithTitle:@""
                                           style:UIBarButtonItemStylePlain
                                           target:self
                                           action:nil];
}


- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view.
  self.view.backgroundColor = [UIColor whiteColor];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [[DFPeanutFeedDataManager sharedManager] refreshSwapsFromServer:nil];
  [self configureLoadingView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)reloadData
{
  self.allSuggestions = [[DFPeanutFeedDataManager sharedManager] suggestedStrands];
  self.filteredSuggestions = [self.allSuggestions mutableCopy];
  if (self.userToFilter) {
    NSMutableArray *filteredSuggestions = [NSMutableArray new];
    for (DFPeanutFeedObject *suggestion in self.allSuggestions) {
      if ([suggestion.actors containsObject:self.userToFilter]) {
        [filteredSuggestions addObject:suggestion];
      }
    }
  }
  
  [self.filteredSuggestions removeObjectsInArray:self.suggestionsToRemove];
  
  if ((self.viewControllers.count == 0
      || ![[self.viewControllers.firstObject class] // if the VC isn't a suggestion, reload in case there is one now
           isSubclassOfClass:[DFSuggestionViewController class]])
      && [[DFPeanutFeedDataManager sharedManager] areSuggestionsReady])
    [self gotoNextController];
  [self configureLoadingView];
}

- (void)configureLoadingView
{
  if (self.filteredSuggestions.count == 0) {
    if (!self.noResultsView) self.noResultsView = [UINib instantiateViewWithClass:[DFNoTableItemsView class]];
    [self.noResultsView setSuperView:self.view];
    if ([[DFPeanutFeedDataManager sharedManager] areSuggestionsReady]) {
      self.noResultsView.titleLabel.text = @"";
      [self.noResultsView.activityIndicator stopAnimating];
    } else {
      self.noResultsView.titleLabel.text = @"Loading...";
      [self.noResultsView.activityIndicator startAnimating];
    }
  } else {
    if (self.noResultsView) [self.noResultsView removeFromSuperview];
    self.noResultsView = nil;
  }
}

- (NSUInteger)indexOfViewController:(UIViewController *)viewController
{
  if (![[viewController class] isSubclassOfClass:[DFSuggestionViewController class]]) return -1;
  DFSuggestionViewController *suggestionVC = (DFSuggestionViewController *)viewController;
  NSUInteger currentIndex = [self.filteredSuggestions indexOfObject:suggestionVC.suggestionFeedObject];
  return currentIndex != NSNotFound ? currentIndex : -1;
}


- (NSUInteger)currentViewControllerIndex
{
  UIViewController *currentController = self.viewControllers.firstObject;
  return  [self indexOfViewController:currentController];
}

- (DFSuggestionViewController *)viewControllerForIndex:(NSInteger)index
{
  if (index < 0 || index >= self.filteredSuggestions.count) {
    if (self.filteredSuggestions.count > 0) {
      DDLogWarn(@"%@ viewControllerForIndex: %@ filteredSuggestions.count: %@",
                self.class,
                @(index),
                @(self.filteredSuggestions.count));
      return nil;
    }
  }
  DFPeanutFeedObject *suggestion = self.filteredSuggestions[index];
  DFSuggestionViewController *svc = [[DFSuggestionViewController alloc] init];
  svc.suggestionFeedObject = suggestion;
  svc.frame = self.view.bounds;
  DFSuggestionsPageViewController __weak *weakSelf = self;
  svc.requestButtonHandler = ^{
    [weakSelf suggestionSelected:suggestion];
  };
  svc.noButtonHandler = ^{
    [weakSelf suggestionHidden:suggestion];
  };
  
  
  return svc;
}

- (UIViewController *)noSuggestionsViewController
{
  UIViewController *noSuggestionVC = [[UIViewController alloc] init];
  DFNoTableItemsView *noSuggestionsView = [UINib instantiateViewWithClass:[DFNoTableItemsView class]];
  noSuggestionsView.titleLabel.text = @"No More Suggestions";
  noSuggestionsView.subtitleLabel.text = @"Take more photos or invite more friends.";
  noSuggestionsView.superView = noSuggestionVC.view;
  return noSuggestionVC;
}


#pragma mark - UIPageViewController Delegate/Datasource

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
      viewControllerBeforeViewController:(UIViewController *)viewController
{
  if (self.filteredSuggestions.count < 2) return nil;
  
  NSUInteger currentIndex = [self indexOfViewController:viewController];
  NSInteger beforeIndex = currentIndex - 1;
  if (beforeIndex < 0) return nil;
  return [self viewControllerForIndex:beforeIndex];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
       viewControllerAfterViewController:(UIViewController *)viewController
{
  if (self.filteredSuggestions.count < 2) return nil;
  NSInteger currentIndex = [self indexOfViewController:viewController];
  NSInteger afterIndex = currentIndex + 1;
  if (afterIndex >= self.filteredSuggestions.count) return nil;
  return [self viewControllerForIndex:afterIndex];
}

- (void)suggestionSelected:(DFPeanutFeedObject *)suggestion
{
  DFCreateStrandFlowViewController *createStrandFlow = [[DFCreateStrandFlowViewController alloc]
                                                        initWithHighlightedPhotoCollection:suggestion];
  createStrandFlow.delegate = self;
  [self presentViewController:createStrandFlow animated:YES completion:nil];
  createStrandFlow.extraAnalyticsInfo = suggestion.suggestionAnalyticsSummary;
}

- (void)suggestionHidden:(DFPeanutFeedObject *)suggestion
{
  [[DFPeanutFeedDataManager sharedManager] markSuggestion:suggestion visible:NO];
  [self gotoNextController];
}

- (void)gotoNextController
{
  UIViewController *nextController;
  if (self.filteredSuggestions.count > 0) {
    if (self.viewControllers.count == 0) {
      nextController = [self viewControllerForIndex:0];
    } else {
      UIViewController *currentController = self.viewControllers.firstObject;
      nextController = [self pageViewController:self
              viewControllerAfterViewController:currentController];
    }
  }
  
  if (!nextController)
    nextController = [self noSuggestionsViewController];

  [self setViewControllers:@[nextController]
                 direction:UIPageViewControllerNavigationDirectionForward
                  animated:YES
                completion:nil];

}

#pragma mark - DFCreateStrandFlowController delegate

- (void)createStrandFlowController:(DFCreateStrandFlowViewController *)controller
               completedWithResult:(DFCreateStrandResult)result
                            photos:(NSArray *)photos
                          contacts:(NSArray *)contacts
{
  if (result == DFCreateStrandResultSuccess) {
    [self gotoNextController];
  }
}


@end
