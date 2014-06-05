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
#import "DFPeanutSearchAdapter.h"
#import "DFPeanutSearchObject.h"

@interface DFSearchViewController ()

@property (nonatomic, retain) DFSearchBar *searchBar;
@property (nonatomic, retain) DFSearchBarController *searchBarController;

@property (nonatomic, retain) NSMutableArray *searchResultPhotoIDs;
@property (nonatomic) NSUInteger lastSeenNumUploaded;

@property (nonatomic, retain) NSURL *lastAttemptedURL;

@property (nonatomic) float webviewLastOffsetY;
@property (nonatomic) BOOL hideStatusBar;
@property (nonatomic) BOOL startedDragging;

@property (nonatomic, retain) DFPeanutSearchAdapter *searchAdapter;

@property (nonatomic, retain) NSArray *tryAgainViews;
@property (nonatomic, retain) NSString *tryAgainSearchQuery;

@end

const unsigned int MaxResultsPerSearchRequest = 5000;

static NSString *GroupsPath = @"/viz/groups/";
static NSString *SearchPath = @"/viz/search/";
static NSString *PhoneIDURLParameter = @"phone_id";
static NSString *UserIDURLParameter = @"user_id";
static NSString *QueryURLParameter = @"q";
static NSString *ReverseResultsURLParameter = @"r";
NSString *const EverythingSearchQuery = @"''";

NSString *const DFObjectsKey = @"DFObjects";
NSString *const UserDefaultsEverythingResultsKey = @"DFSearchViewControllerEverythingResultsJSON";

@implementation DFSearchViewController

- (id)init
{
  self = [super init];
  if (self) {
    self.navigationItem.title = @"Search";
    self.tabBarItem.title = @"Search";
    self.tabBarItem.image = [UIImage imageNamed:@"Icons/Search"];
    self.hideStatusBar = NO;
    self.searchAdapter = [[DFPeanutSearchAdapter alloc] init];
  
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
  
  if (self.isMovingToParentViewController) {
    [self scrollToBottom];
  }
  
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
  [self executeSearchForQuery:EverythingSearchQuery reverseResults:YES];
  [self loadCachedDefaultQuery];
  self.navigationItem.title = self.searchBarController.defaultQuery;
  [self updateUIForSearchBarHasFocus:NO];
  dispatch_async(dispatch_get_main_queue(), ^{
    [self scrollToBottom];
  });
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
  if ([[query lowercaseString] isEqualToString:@"settings"]) {
    [self showSettings];
  } else if ([query isEqualToString:@""] || [[query lowercaseString]
                                               isEqualToString:[self.searchBarController.defaultQuery lowercaseString]]) {
    [self loadDefaultSearch];
  } else {
    [self executeSearchForQuery:self.searchBar.text reverseResults:NO];
    [self updateUIForSearchBarHasFocus:NO];
  }
}

- (void)executeSearchForQuery:(NSString *)query reverseResults:(BOOL)reverseResults
{
  self.currentlyLoadingSearchQuery = query;
  for (UIView *view in self.tryAgainViews) {
    [view removeFromSuperview];
  }
  
  [self.searchAdapter fetchSearchResultsForQuery:query
                                      maxResults:MaxResultsPerSearchRequest
                                   minDateString:nil
                             withCompletionBlock:^(DFPeanutSearchResponse *response) {
    DDLogVerbose(@"SearchViewController got search response with result %d and top level objects count:%d",
                 response.result, (int)response.objects.count);
    if (response.result == TRUE) {
      if (response.objects.count == 0) [self showNoSearchResults:response.retry_suggestions];
      
      // We need to do this work on the main thread because the DFPhoto objects that get created
      // have to be on the main thread so they can be accessed by colleciton view datasource methods
      dispatch_async(dispatch_get_main_queue(), ^{
        NSArray *peanutObjects = response.objects;
        NSArray *sectionNames = [DFSearchViewController topLevelSectionNamesForPeanutObjects:peanutObjects];
        NSDictionary *itemsBySection = [DFSearchViewController itemsBySectionForPeanutObjects:peanutObjects];
        
        [self setSectionNames:sectionNames itemsBySection:itemsBySection];
        [self.collectionView reloadData];
        
        if ([query isEqualToString:EverythingSearchQuery]) {
          [self saveDefaultPeanutObjects:peanutObjects];
          dispatch_async(dispatch_get_main_queue(), ^{
            [self scrollToBottom];
          });
        } else {
          dispatch_async(dispatch_get_main_queue(), ^{
            [self scrollToTop];
          });
        }
      });
    } else {
      DDLogWarn(@"SearchViewController got a non true response.");
    }
    
  }];
  
  //[DFAnalytics logSearchLoadStartedWithQuery:query suggestions:suggestionsStrings];
  self.navigationItem.title = [query capitalizedString];
}

- (void)showNoSearchResults:(NSArray *)retrySuggestions
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [self setSectionNames:nil itemsBySection:nil];
    
//    UIView *view = [[[UINib nibWithNibName:@"DFSearchNoResultsView" bundle:nil]
//                     instantiateWithOwner:self options:nil]
//                    firstObject];
    UILabel *noResultsLabel = [[UILabel alloc] init];
    noResultsLabel.lineBreakMode = NSLineBreakByWordWrapping;
    noResultsLabel.numberOfLines = 0;
    noResultsLabel.textAlignment = NSTextAlignmentCenter;
    noResultsLabel.textColor = [UIColor lightGrayColor];
    noResultsLabel.font = [UIFont fontWithName:@"ProximaNova-Regular" size:20];
    
    noResultsLabel.text = @"Sorry, we couldn't find any photos for that search.";
    
    CGFloat sideMarginPercent = 0.125;
    
    [self.collectionView addSubview:noResultsLabel];
    [noResultsLabel sizeToFit];
    noResultsLabel.frame =
    CGRectMake(self.collectionView.frame.size.width * sideMarginPercent,
               CGRectGetMidY(self.collectionView.frame) - self.collectionView.frame.size.height / 5.0,
               self.collectionView.frame.size.width * (1 - 2*sideMarginPercent),
               self.collectionView.frame.size.height / 5.0
               );
    
    self.tryAgainViews = @[noResultsLabel];
    
    if (retrySuggestions.count > 0) {
      DFPeanutSuggestion *retrySuggestion = [retrySuggestions
                                             objectAtIndex:arc4random_uniform((u_int32_t)retrySuggestions.count)];
      self.tryAgainSearchQuery = retrySuggestion.name;
      
      UIButton *tryAgainButton = [[UIButton alloc] init];
      NSString *tryAgainText = [NSString stringWithFormat:@"Try '%@' instead", retrySuggestion.name];
      [tryAgainButton setTitle:tryAgainText forState:UIControlStateNormal];
      [tryAgainButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
      tryAgainButton.userInteractionEnabled = YES;
      tryAgainButton.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
      tryAgainButton.titleLabel.numberOfLines = 0;
      tryAgainButton.titleLabel.textAlignment = NSTextAlignmentCenter;
      [tryAgainButton addTarget:self
                         action:@selector(tryAgainButtonClicked)
               forControlEvents:UIControlEventTouchUpInside];

      
      [self.collectionView addSubview:tryAgainButton];
      tryAgainButton.frame =
      CGRectMake(self.collectionView.frame.size.width * sideMarginPercent,
                 CGRectGetMaxY(noResultsLabel.frame) + 8.0,
                 self.collectionView.frame.size.width * (1 - 2 *sideMarginPercent),
                 [tryAgainButton sizeThatFits:tryAgainButton.frame.size].height);
      
      self.tryAgainViews = @[noResultsLabel, tryAgainButton];
    }
    
    
  });
}

- (void)tryAgainButtonClicked
{
  self.searchBar.text = self.tryAgainSearchQuery;
  [self executeSearchForQuery:self.tryAgainSearchQuery reverseResults:NO];
}

+ (NSArray *)topLevelSectionNamesForPeanutObjects:(NSArray *)peanutObjects
{
  NSMutableArray *result = [[NSMutableArray alloc] init];
  for (DFPeanutSearchObject *searchObject in peanutObjects) {
     if ([searchObject.type isEqualToString:DFSearchObjectSection]) {
       [result addObject:searchObject.title];
     }
  }
  return result;
}

+ (NSDictionary *)itemsBySectionForPeanutObjects:(NSArray *)peanutObjects
{
  NSMutableDictionary *itemsBySectionResult = [[NSMutableDictionary alloc] init];
  for (DFPeanutSearchObject *sectionObject in peanutObjects) {
    if ([sectionObject.type isEqualToString:DFSearchObjectSection]) {
      NSMutableArray *contiguousPhotoIDsToAdd = [[NSMutableArray alloc] init];
      NSMutableArray *sectionItems = [[NSMutableArray alloc] init];
      
      for (DFPeanutSearchObject *searchObject in sectionObject.objects) {
        if ([searchObject.type isEqualToString:DFSearchObjectPhoto]){
          [contiguousPhotoIDsToAdd addObject:@(searchObject.id)];
        }
        
        if ([searchObject.type isEqualToString:DFSearchObjectCluster]) {
          NSArray *previousContitguousPhotos = [[DFPhotoStore sharedStore]
                                                photosWithPhotoIDs:contiguousPhotoIDsToAdd
                                                retainOrder:YES];
          [sectionItems addObjectsFromArray:previousContitguousPhotos];
          [contiguousPhotoIDsToAdd removeAllObjects];
          
          DFPhotoCollection *clusterCollection = [[DFPhotoCollection alloc]
                                                  initWithPhotos:[self photosForCluster:searchObject]];
          [sectionItems addObject:clusterCollection];
        }
        
      }
      
      NSArray *photos = [[DFPhotoStore sharedStore]
                         photosWithPhotoIDs:contiguousPhotoIDsToAdd retainOrder:YES];
      [sectionItems addObjectsFromArray:photos];
      itemsBySectionResult[sectionObject.title] = sectionItems;
    }
  }
  
  return itemsBySectionResult;
}

+ (NSArray *)photosForCluster:(DFPeanutSearchObject *)cluster
{
  NSMutableArray *clusterPhotoIDs = [[NSMutableArray alloc] init];
  for (DFPeanutSearchObject *subSearchObject in cluster.objects) {
    if ([subSearchObject.type isEqualToString:DFSearchObjectPhoto]) {
      [clusterPhotoIDs addObject:@(subSearchObject.id)];
    }
  }
  
  
  NSArray *photos = [[DFPhotoStore sharedStore] photosWithPhotoIDs:clusterPhotoIDs retainOrder:YES];
  return  photos;
}

- (void)saveDefaultPeanutObjects:(NSArray *)defaultPeanutObjects
{
  if (!defaultPeanutObjects) return;
  NSDictionary *dictToWrite = @{DFObjectsKey : defaultPeanutObjects.copy};
  NSString *jsonString = [[dictToWrite dictionaryWithNonJSONRemoved] JSONString];
  [[NSUserDefaults standardUserDefaults] setObject:jsonString forKey:UserDefaultsEverythingResultsKey];
}

- (void)loadCachedDefaultQuery
{
  NSString *jsonString = [[NSUserDefaults standardUserDefaults]
                          objectForKey:UserDefaultsEverythingResultsKey];
  if (jsonString && ![jsonString isEqualToString:@""]) {
    @try {
      NSArray *peanutObjectJSONDicts = [[NSDictionary dictionaryWithJSONString:jsonString]
                                objectForKey:DFObjectsKey];
      NSMutableArray *peanutObjects = [[NSMutableArray alloc] initWithCapacity:peanutObjectJSONDicts.count];
      for (NSDictionary *jsonDict in peanutObjectJSONDicts) {
        [peanutObjects addObject:[[DFPeanutSearchObject alloc] initWithJSONDict:jsonDict]];
      }
      
      NSArray *sectionNames = [DFSearchViewController topLevelSectionNamesForPeanutObjects:peanutObjects];
      NSDictionary *itemsBySection = [DFSearchViewController itemsBySectionForPeanutObjects:peanutObjects];
      [self setSectionNames:sectionNames itemsBySection:itemsBySection];
    } @catch (NSException *exception) {
      DDLogError(@"Couldn't load default search.  JSONString:%@", jsonString);
      [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:UserDefaultsEverythingResultsKey];
    }
  } else {
    [self setSectionNames:@[@"All"]
           itemsBySection:@{@"All" : [[[DFPhotoStore sharedStore] cameraRoll] photosByDateAscending:YES]}];
  }
}

- (void)updateUIForSearchBarHasFocus:(BOOL)searchBarHasFocus
{
  if (searchBarHasFocus) {
    self.searchResultsTableView.hidden = NO;
  } else {
    self.searchResultsTableView.hidden = YES;
  }
}

- (void)showSettings
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
