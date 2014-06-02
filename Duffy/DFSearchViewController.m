//
//  DFSearchViewController.m
//  Duffy
//
//  Created by Henry Bridge on 3/14/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFSearchViewController.h"
#import "DFUser.h"
#import "DFPhotoWebViewController.h"
#import "DFTableHeaderView.h"
#import "DFSuggestionAdapter.h"
#import "DFAnalytics.h"
#import "DFUploadController.h"
#import "DFNotificationSharedConstants.h"
#import "DFPhoto.h"
#import "DFPhotoStore.h"
#import "DFPhotoViewController.h"
#import "DFMultiPhotoViewController.h"
#import "DFPeanutSuggestion.h"
#import "DFSearchResultTableViewCell.h"
#import "NSDictionary+DFJSON.h"
#import "DFSettingsViewController.h"
#import "DFURLProtocol.h"
#import "DFAutocompleteAdapter.h"
#import "DFPeanutSuggestion.h"
#import "DFSearchBarController.h"

@interface DFSearchViewController ()

@property (nonatomic, retain) DFSearchBar *searchBar;
@property (nonatomic, retain) DFSearchBarController *searchBarController;

@property (nonatomic, retain) NSMutableArray *searchResultPhotoIDs;
@property (nonatomic) NSUInteger lastSeenNumUploaded;

@property (nonatomic, retain) NSURL *lastAttemptedURL;

@property (nonatomic) float webviewLastOffsetY;
@property (nonatomic) BOOL hideStatusBar;
@property (nonatomic) BOOL startedDragging;

@end



static NSString *GroupsPath = @"/viz/groups/";
static NSString *SearchPath = @"/viz/search/";
static NSString *PhoneIDURLParameter = @"phone_id";
static NSString *UserIDURLParameter = @"user_id";
static NSString *QueryURLParameter = @"q";
static NSString *ReverseResultsURLParameter = @"r";

@implementation DFSearchViewController

- (id)init
{
  self = [super init];
  if (self) {
    self.navigationItem.title = @"Search";
    self.tabBarItem.title = @"Search";
    self.tabBarItem.image = [UIImage imageNamed:@"Icons/Search"];
    self.hideStatusBar = NO;
    
    self.photos = [[[DFPhotoStore sharedStore] cameraRoll] photosByDateAscending:YES];
    
    [self registerForKeyboardNotifications];
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self configureSearchBarController];
  self.automaticallyAdjustsScrollViewInsets = YES;
  
  [self loadDefaultSearch];
}

- (void)configureSearchBarController
{

  self.searchResultsTableView = [[UITableView alloc] init];
  [self.view insertSubview:self.searchResultsTableView aboveSubview:self.collectionView];
  self.searchResultsTableView.frame = self.collectionView.frame;
  
  self.searchBarController = [[DFSearchBarController alloc] init];
  self.searchBarController.delegate = self;
  self.searchBar = [[[UINib nibWithNibName:@"DFSearchBar" bundle:nil]
                     instantiateWithOwner:self options:nil]
                    firstObject];
  
  
  self.searchBarController.searchBar = self.searchBar;
  self.navigationItem.titleView = self.searchBar;
  self.navigationController.toolbar.tintColor = [UIColor colorWithRed:241 green:155 blue:43
                                                                alpha:1.0];
  
  self.searchBarController.tableView = self.searchResultsTableView;
  
  [self.searchBarController setActive:YES animated:NO];
  self.searchResultsTableView.hidden = NO;
}

- (void)registerForKeyboardNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(keyboardDidShow:)
                                               name:UIKeyboardDidShowNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(keyboardDidHide:)
                                               name:UIKeyboardDidHideNotification
                                             object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
  self.hideStatusBar = NO;
  [self.navigationController setNavigationBarHidden:NO animated:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [self setTableViewInsets];
  
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [DFAnalytics logViewController:self disappearedWithParameters:nil];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
  [self setTableViewInsets];
}

- (void)setTableViewInsets
{
  self.searchResultsTableView.contentInset = UIEdgeInsetsMake(self.topLayoutGuide.length, 0, 0, 0);
}

- (void)loadDefaultSearch
{
  [self executeSearchForQuery:@"''" reverseResults:YES];
  [self updateUIForSearchBarHasFocus:NO];
}

- (void)searchBarControllerSearchBegan:(DFSearchBarController *)searchBarController
{
  [self updateUIForSearchBarHasFocus:YES];
}

- (void)searchBarControllerSearchCancelled:(DFSearchBarController *)searchBarController
{
  [self updateUIForSearchBarHasFocus:NO];
}

- (void)searchBarControllerSearchCleared:(DFSearchBarController *)searchBarController
{
  [self loadDefaultSearch];
  [self updateUIForSearchBarHasFocus:NO];
}

- (void)searchBarController:(DFSearchBarController *)searchBarController searchExecutedWithQuery:(NSString *)query
{
  if ([query isEqualToString:@""] || [[query lowercaseString]
                                               isEqualToString:[self.searchBarController.defaultQuery lowercaseString]]) {
    [self loadDefaultSearch];
  } else {
    [self executeSearchForQuery:self.searchBar.text reverseResults:NO];
    [self updateUIForSearchBarHasFocus:NO];
  }
}

- (void)executeSearchForQuery:(NSString *)query reverseResults:(BOOL)reverseResults
{
  // TODO stop loading other query first
  
  self.currentlyLoadingSearchQuery = query;
  
  //[DFAnalytics logSearchLoadStartedWithQuery:query suggestions:suggestionsStrings];
  self.navigationItem.title = [query capitalizedString];
  
}

- (void)updateUIForSearchBarHasFocus:(BOOL)searchBarHasFocus
{
  if (searchBarHasFocus) {
    self.searchResultsTableView.hidden = NO;
  } else {
    self.searchResultsTableView.hidden = YES;
  }
}


- (void)pushPhotoView:(NSString *)photoURLString
{
  NSURL *photoURL = [NSURL URLWithString:photoURLString];
  NSString *photoIDString = [[photoURL lastPathComponent] stringByDeletingPathExtension];
  DDLogVerbose(@"photoURL:%@, photo id string: %@", photoURL, photoIDString);
  
  
  NSRange photoIDArrayRange = [photoURLString rangeOfString:@"?photoIdArray="];
  if (photoIDArrayRange.location != NSNotFound) {
    NSString *searchResultIDs = [photoURLString
                                 substringFromIndex:photoIDArrayRange.location+photoIDArrayRange.length];
    DDLogVerbose(@"searchResultIDs:%@", searchResultIDs);
    self.searchResultPhotoIDs = [[NSMutableArray alloc] init];
    for (NSString *idString in [searchResultIDs componentsSeparatedByString:@","]) {
      [self.searchResultPhotoIDs addObject:@([idString longLongValue])];
    }
  }
  DFPhoto *photo = [[DFPhotoStore sharedStore] photoWithPhotoID:[photoIDString longLongValue]];
  
  if (photo) {
    DFPhotoViewController *pvc = [[DFPhotoViewController alloc] init];
    pvc.photo = photo;
    DFMultiPhotoViewController *mvc = [[DFMultiPhotoViewController alloc] init];
    [mvc setViewControllers:[NSArray arrayWithObject:pvc]
                  direction:UIPageViewControllerNavigationDirectionForward
                   animated:NO
                 completion:^(BOOL finished) {
                 }];
    mvc.dataSource = self;
    [self.navigationController pushViewController:mvc animated:YES];
  } else {
    DDLogError(@"Error: no local photo found for photoID:%llu, showing web view", [photoIDString longLongValue]);
    DFPhotoWebViewController *pvc = [[DFPhotoWebViewController alloc] initWithPhotoURL:photoURL];
    [self.navigationController pushViewController:pvc animated:YES];
  }
}



- (void)showSettings:(id)sender
{
  DFSettingsViewController *svc = [[DFSettingsViewController alloc] init];
  [self.navigationController pushViewController:svc animated:YES];
}




#pragma mark - Keyboard handlers

- (void)keyboardDidShow:(NSNotification *)notification {
  // cache the header view frame so we can reset it.
  CGRect headerViewFrame = self.searchResultsTableView.tableHeaderView.frame;
  
  CGRect toRect = [(NSValue *)notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
  toRect = [self.view convertRect:toRect fromView:nil ];
  self.searchResultsTableView.frame = CGRectMake(self.searchResultsTableView.frame.origin.x,
                                                 self.searchResultsTableView.frame.origin.y,
                                                 self.searchResultsTableView.frame.size.width,
                                                 toRect.origin.y);
  
  // reset the header view frame
  self.searchResultsTableView.tableHeaderView.frame = headerViewFrame;
}

- (void)keyboardDidHide:(NSNotification *)notification {
  // cache the header view frame so we can reset it.
  CGRect headerViewFrame = self.searchResultsTableView.tableHeaderView.frame;
  
  CGRect toRect = [(NSValue *)notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
  toRect = [self.view convertRect:toRect fromView:nil ];
  self.searchResultsTableView.frame = CGRectMake(self.searchResultsTableView.frame.origin.x,
                                                 self.searchResultsTableView.frame.origin.y,
                                                 self.searchResultsTableView.frame.size.width,
                                                 toRect.origin.y);
  
  // reset the header view frame
  self.searchResultsTableView.tableHeaderView.frame = headerViewFrame;
}


//
//- (UIViewController*)pageViewController:(UIPageViewController *)pageViewController
//     viewControllerBeforeViewController:(UIViewController *)viewController
//{
//  NSUInteger currentPhotoIDIndex = [self
//                                    indexOfPhotoController:(DFPhotoViewController*)viewController];
//  NSUInteger newPhotoIDIndex;
//  if (currentPhotoIDIndex > 0) {
//    newPhotoIDIndex = currentPhotoIDIndex - 1;
//  } else {
//    newPhotoIDIndex = self.searchResultPhotoIDs.count - 1;
//  }
//  
//  NSNumber *newPhotoID = [self.searchResultPhotoIDs objectAtIndex:newPhotoIDIndex];
//  DDLogVerbose(@"oldPhotoIDIndex = %d, newPhotoIDIndex = %d, newPhotoID=%d", (int)currentPhotoIDIndex, (int)newPhotoIDIndex, [newPhotoID intValue]);
//  DFPhoto *photo = [[DFPhotoStore sharedStore] photoWithPhotoID:
//                    [newPhotoID longLongValue]];
//  DFPhotoViewController *pvc = [[DFPhotoViewController alloc] init];
//  pvc.photo = photo;
//  return pvc;
//}
//
//- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
//       viewControllerAfterViewController:(UIViewController *)viewController
//{
//  NSUInteger currentPhotoIDIndex =
//  [self indexOfPhotoController:(DFPhotoViewController *)viewController];
//  
//  NSUInteger newPhotoIDIndex;
//  if (currentPhotoIDIndex < self.searchResultPhotoIDs.count - 1) {
//    newPhotoIDIndex = currentPhotoIDIndex + 1;
//  } else {
//    newPhotoIDIndex = 0;
//  }
//  
//  NSNumber *newPhotoID = [self.searchResultPhotoIDs objectAtIndex:newPhotoIDIndex];
//  DDLogVerbose(@"oldPhotoIDIndex = %d, newPhotoIDIndex = %d, newPhotoID=%d", (int)currentPhotoIDIndex, (int)newPhotoIDIndex, [newPhotoID intValue]);
//  DFPhoto *photo = [[DFPhotoStore sharedStore] photoWithPhotoID:
//                    [newPhotoID longLongValue]];
//  DFPhotoViewController *pvc = [[DFPhotoViewController alloc] init];
//  pvc.photo = photo;
//  return pvc;
//}
//
//- (NSUInteger)indexOfPhotoController:(DFPhotoViewController *)pvc
//{
//  DFPhotoIDType currentPhotoID = pvc.photo.photoID;
//  NSNumber *photoIDNumber = [NSNumber numberWithUnsignedLongLong:currentPhotoID];
//  return [self.searchResultPhotoIDs indexOfObject:photoIDNumber];
//}

#pragma mark - UIScrollViewDelegate
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
  if (scrollView == self.collectionView) {
    self.webviewLastOffsetY = scrollView.contentOffset.y;
    self.startedDragging = YES;
  }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  if (scrollView == self.collectionView && self.startedDragging) {
    bool hide = (scrollView.contentOffset.y > self.webviewLastOffsetY);
    [[self navigationController] setNavigationBarHidden:hide animated:YES];
    self.hideStatusBar = hide;
    self.startedDragging = NO;
  }
}


#pragma mark - Hide and show status bar

- (void)setHideStatusBar:(BOOL)hideStatusBar
{
  if (_hideStatusBar != hideStatusBar) {
    _hideStatusBar = hideStatusBar;
    [self setNeedsStatusBarAppearanceUpdate];
  }
}

- (BOOL)prefersStatusBarHidden
{
  return self.hideStatusBar;
}


@end
