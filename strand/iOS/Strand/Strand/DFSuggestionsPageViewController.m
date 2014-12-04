//
//  DFSuggestionsPageViewController.m
//  Strand
//
//  Created by Henry Bridge on 11/25/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSuggestionsPageViewController.h"
#import "DFSwipableSuggestionViewController.h"
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

@property (nonatomic) NSInteger photoIndex;
@property (retain, nonatomic) NSMutableArray *indexPaths;

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
  
  NSInteger sectionCount = 0;
  self.indexPaths = [NSMutableArray new];
  
  NSMutableArray *filteredSuggestions = [NSMutableArray new];
  for (DFPeanutFeedObject *suggestion in self.allSuggestions) {
    if (!self.userToFilter || (self.userToFilter && [suggestion.actors containsObject:self.userToFilter])) {
      NSInteger itemCount = 0;
      [filteredSuggestions addObject:suggestion];
      NSArray *photos = [suggestion leafNodesFromObjectOfType:DFFeedObjectPhoto];
      for (int x=0; x < photos.count; x++) {
        [self.indexPaths addObject:[NSIndexPath indexPathForItem:itemCount inSection:sectionCount]];
        itemCount++;
      }
      sectionCount++;
    }
  }
  
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

/*
 * We need to return the IndexPath which corrisponds to the given view controller
 */
- (NSUInteger)indexOfViewController:(UIViewController *)viewController
{
  if (![[viewController class] isSubclassOfClass:[DFSuggestionViewController class]]) return -1;
  DFSuggestionViewController *suggestionVC = (DFSuggestionViewController *)viewController;
  NSUInteger sectionIndex = [self.filteredSuggestions indexOfObject:suggestionVC.suggestionFeedObject];
  
  if (sectionIndex == NSNotFound) return -1;
  NSArray *photos = [self.filteredSuggestions[sectionIndex] leafNodesFromObjectOfType:DFFeedObjectPhoto];
  NSUInteger itemIndex = [photos indexOfObject:suggestionVC.photoFeedObject];
  if (itemIndex == NSNotFound) return -1;
  
  for (int x=0; x < self.indexPaths.count; x++) {
    NSIndexPath *indexPath = self.indexPaths[x];
    if (indexPath.section == sectionIndex && indexPath.item == itemIndex) {
      return x;
    }
  }
  return -1;
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
  NSIndexPath *indexPath = self.indexPaths[index];
  DFPeanutFeedObject *suggestion = self.filteredSuggestions[indexPath.section];
  NSArray *photos = [suggestion leafNodesFromObjectOfType:DFFeedObjectPhoto];
  DFPeanutFeedObject *photo = photos[indexPath.item];
  
  
  DFSwipableSuggestionViewController *svc = [[DFSwipableSuggestionViewController alloc] init];
  svc.suggestionFeedObject = suggestion;
  svc.photoFeedObject = photo;

  svc.frame = self.view.bounds;
  DFSuggestionsPageViewController __weak *weakSelf = self;
  
  svc.yesButtonHandler = ^{
    [weakSelf suggestionSelected:suggestion photo:photo];
  };
  svc.noButtonHandler = ^{
    [weakSelf suggestionHidden:suggestion photo:photo];
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

- (void)suggestionSelected:(DFPeanutFeedObject *)suggestion photo:(DFPeanutFeedObject *)photo
{
  [[DFPeanutFeedDataManager sharedManager] sharePhotoWithFriends:photo users:suggestion.actors];
  [self gotoNextController];
}

- (void)suggestionHidden:(DFPeanutFeedObject *)suggestion  photo:(DFPeanutFeedObject *)photo
{
  [[DFPeanutFeedDataManager sharedManager] hasEvaluatedPhoto:photo.id strandID:suggestion.id];
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
