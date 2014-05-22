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
#import "DFAutocompleteController.h"
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

@interface DFSearchViewController ()

@property (nonatomic, retain) DFSearchBar *searchBar;

@property (nonatomic, retain) NSMutableDictionary *searchResultsBySectionName;
@property (nonatomic, retain) NSMutableArray *sectionNames;
@property (nonatomic, retain) NSMutableArray *searchResultPhotoIDs;
@property (nonatomic) NSUInteger currentPhotoIDIndex;
@property (nonatomic) NSUInteger lastSeenNumUploaded;

@property (nonatomic, retain) NSURL *lastAttemptedURL;

@property (nonatomic) float lastOffsetY;
@property (nonatomic) BOOL hideStatusBar;

@end

static NSString *DATE_SECTION_NAME = @"Time";
static NSString *LOCATION_SECTION_NAME = @"Location";
static NSString *CATEGORY_SECTION_NAME = @"Subject";

static NSString *SEARCH_PLACEHOLDER = @"Search Photos";
static NSString *SEARCH_DEFAULT_QUERY = @"Everything";


static NSDictionary *SectionNameToTitles;

static NSString *GroupsPath = @"/viz/groups/";
static NSString *SearchPath = @"/viz/search/";
static NSString *PhoneIDURLParameter = @"phone_id";
static NSString *UserIDURLParameter = @"user_id";
static NSString *QueryURLParameter = @"q";
static NSString *ReverseResultsURLParameter = @"r";

static CGFloat SearchResultsRowHeight = 38;
static CGFloat SearchResultsCellFontSize = 15;
static NSUInteger RefreshSuggestionsThreshold = 50;


@implementation DFSearchViewController

@synthesize defaultSearchResults = _defaultSearchResults;

+ (void)initialize
{
  SectionNameToTitles = @{DATE_SECTION_NAME: @"Time",
                          LOCATION_SECTION_NAME: @"Location",
                          CATEGORY_SECTION_NAME: @"Things"
                          };
}

- (id)init
{
  self = [super init];
  if (self) {
    self.navigationItem.title = @"Search";
    
    self.tabBarItem.title = @"Search";
    self.tabBarItem.image = [UIImage imageNamed:@"Icons/Search"];
    
    self.hideStatusBar = NO;
    
    self.autcompleteController = [[DFAutocompleteController alloc] init];
    [self setupNavBar];
    [self registerForKeyboardNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(uploadStatusChanged:)
                                                 name:DFUploadStatusNotificationName
                                               object:nil];
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self setupTableView];
  [self populateDefaultAutocompleteSearchResults];
  self.webView.delegate = self;
  self.webView.scrollView.delegate = self;
  
  [self.view insertSubview:self.searchResultsTableView aboveSubview:self.webView];
  self.automaticallyAdjustsScrollViewInsets = YES;
  
  
  [self loadDefaultSearch];
}

- (void)viewWillAppear:(BOOL)animated
{
  self.hideStatusBar = NO;
  [self.navigationController setNavigationBarHidden:NO animated:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [self setViewInsets];
  
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [DFAnalytics logViewController:self disappearedWithParameters:nil];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
  [self setViewInsets];
}

- (void)setViewInsets
{
  self.searchResultsTableView.contentInset = UIEdgeInsetsMake(self.topLayoutGuide.length, 0, 0, 0);
}

- (void)setupNavBar
{
  // create search bar
  self.searchBar = [[[UINib nibWithNibName:@"DFSearchBar" bundle:nil]
                     instantiateWithOwner:self options:nil]
                    firstObject];
  self.searchBar.delegate = self;
  self.searchBar.placeholder = SEARCH_PLACEHOLDER;
  self.searchBar.defaultQuery = SEARCH_DEFAULT_QUERY;
  
  
  self.navigationItem.titleView = self.searchBar;
  self.navigationController.toolbar.tintColor = [UIColor colorWithRed:241 green:155 blue:43
                                                                      alpha:1.0];
}

- (void)setupTableView
{
  self.searchResultsTableView.rowHeight = SearchResultsRowHeight;
  [self.searchResultsTableView registerClass:[DFSearchResultTableViewCell class]
                      forCellReuseIdentifier:@"DFSearchResultTableViewCell"];
  
  [self updateSearchResults:nil];
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

- (NSMutableArray *)defaultSectionNames
{
  return [@[DATE_SECTION_NAME, LOCATION_SECTION_NAME, CATEGORY_SECTION_NAME] mutableCopy];
}

- (NSMutableDictionary *)defaultSearchResults
{
  if (!_defaultSearchResults) {
    _defaultSearchResults = [[NSMutableDictionary alloc] init];
    [_defaultSearchResults addEntriesFromDictionary:[self loadDefaultSearchResults]];
  }
  
  
  return _defaultSearchResults;
}

- (void)populateDefaultAutocompleteSearchResults
{
  [self.autcompleteController fetchSuggestions:^(NSArray *categoryPeanutSuggestions,
                                                 NSArray *locationPeanutSuggestions,
                                                 NSArray *timePeanutSuggestions) {
    if (categoryPeanutSuggestions) {
      self.defaultSearchResults[CATEGORY_SECTION_NAME] = categoryPeanutSuggestions;
    } else {
      [self.sectionNames removeObject:CATEGORY_SECTION_NAME];
    }
    
    if (locationPeanutSuggestions) {
      self.defaultSearchResults[LOCATION_SECTION_NAME] = locationPeanutSuggestions;
    } else {
      [self.sectionNames removeObject:LOCATION_SECTION_NAME];
    }
    
    if (timePeanutSuggestions) {
      self.defaultSearchResults[DATE_SECTION_NAME] = timePeanutSuggestions;
    } else {
      [self.sectionNames removeObject:DATE_SECTION_NAME];
    }
    
    [self updateSearchResults:self.searchBar.text];
    
    [self saveDefaultSearchResults:self.defaultSearchResults];
  }];
}

- (void)saveDefaultSearchResults:(NSDictionary *)searchResults
{
  NSString *jsonString = [[searchResults dictionaryWithNonJSONRemoved] JSONString];
  [[NSUserDefaults standardUserDefaults] setObject:jsonString
                                            forKey:@"DFSearchViewControllerDefaultSearchResultsJSON"];
}

- (NSDictionary *)loadDefaultSearchResults
{
  NSString *loadedDictString = [[NSUserDefaults standardUserDefaults]
                              objectForKey:@"DFSearchViewControllerDefaultSearchResultsJSON"];
  NSMutableDictionary *resultsDict = [[NSDictionary dictionaryWithJSONString:loadedDictString] mutableCopy];
  [resultsDict enumerateKeysAndObjectsUsingBlock:^(NSString *sectionName, NSArray *suggestions, BOOL *stop) {
    if (suggestions) {
      NSMutableArray *mutableSuggestions = suggestions.mutableCopy;
      for (unsigned long i = 0; i < mutableSuggestions.count; i++) {
        NSDictionary *suggestionDict = mutableSuggestions[i];
        mutableSuggestions[i] = [[DFPeanutSuggestion alloc] initWithJSONDict:suggestionDict];
      }
      
      resultsDict[sectionName] = mutableSuggestions;
    }
  }];
  
  
  return resultsDict;
}



- (void)loadImageCategoriesForUser:(NSString *)userID
{
  NSURL *url = [[[DFUser currentUser] serverURL] URLByAppendingPathComponent:GroupsPath];
  NSURLRequest *request = [NSURLRequest requestWithURL:url];
  [self.webView loadRequest:request];
}

- (void)loadDefaultSearch
{
  [self executeSearchForQuery:@"''" reverseResults:YES];
  self.searchBar.text = @"Everything";
  self.navigationItem.title = @"Everything";
  [self updateUIForSearchBarHasFocus:NO showingDefaultQuery:YES];
}

- (void)executeSearchForQuery:(NSString *)query reverseResults:(BOOL)reverseResults
{
  if (self.webView.isLoading) {
    [self.webView stopLoading];
  }
  
  self.currentlyLoadingSearchQuery = query;
  
  NSString *queryURLString = [NSString stringWithFormat:@"%@%@?%@=%@&%@=%@&%@=%d",
                              [[[DFUser currentUser] serverURL] absoluteString],
                              SearchPath,
                              UserIDURLParameter, [NSNumber numberWithUnsignedLongLong:[[DFUser currentUser] userID]],
                              QueryURLParameter, [query stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                              ReverseResultsURLParameter, reverseResults ? 1 : 0];
  NSURL *queryURL = [NSURL URLWithString:queryURLString];
  self.lastAttemptedURL = queryURL;
  
  
  DDLogVerbose(@"Executing search for URL: %@", queryURL.absoluteString);
  NSDictionary *suggestionsStrings = [self suggestionsStrings];
  [DFAnalytics logSearchLoadStartedWithQuery:query suggestions:suggestionsStrings];
  self.navigationItem.title = [query capitalizedString];
  [self.webView loadRequest:[NSURLRequest requestWithURL:queryURL]];
}

- (NSDictionary *)suggestionsStrings
{
  NSMutableDictionary *result = self.defaultSearchResults.mutableCopy;
  for (NSString *key in result.allKeys) {
    NSMutableArray *suggestions = [(NSArray *)result[key] mutableCopy];
    for (int i = 0; i < suggestions.count; i++) {
      DFPeanutSuggestion *suggestion = suggestions[i];
      suggestions[i] = suggestion.name;
    }
    result[key] = suggestions;
  }
  return result;
}

#pragma mark - Webview Delegate Methods


- (BOOL)webView:(UIWebView *)webView
shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)navigationType
{
  NSString *requestURLString = request.URL.absoluteString;
  if ([requestURLString rangeOfString:@"user_data"].location != NSNotFound) {
    [webView stopLoading];
    DDLogVerbose(@"Search result clicked for photo with URL: %@", requestURLString);
    
    [self pushPhotoView:requestURLString];
    return NO;
  } else if ([requestURLString rangeOfString:@"settings"].location != NSNotFound) {
    [webView stopLoading];
    DDLogInfo(@"Settings request detect in search string with URL: %@", requestURLString);
    
    DFSettingsViewController *svc = [[DFSettingsViewController alloc] init];
    self.navigationItem.title = @"Search";
    [self.navigationController pushViewController:svc animated:YES];
    
    return NO;
  }
  
  return YES;
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
  if (![self isLoadErrorAnotherRequest:error]) {
    NSURL *file = [[NSBundle mainBundle] URLForResource:@"LoadSearchError" withExtension:@"html"];
    NSStringEncoding *encoding = nil;
    NSError *loadTextError;
    NSString *htmlStringFormat = [NSString stringWithContentsOfFile:file.path
                                                       usedEncoding:encoding
                                                              error:&loadTextError];
    NSString *htmlString = [NSString stringWithFormat:htmlStringFormat,
                            error.localizedDescription, self.lastAttemptedURL.absoluteString];
    DDLogVerbose(@"%@", htmlString);
    [self.webView loadHTMLString:htmlString baseURL:nil];
    
    if (self.currentlyLoadingSearchQuery) {
      [DFAnalytics logSearchLoadEndedWithQuery:self.currentlyLoadingSearchQuery];
      self.currentlyLoadingSearchQuery = nil;
    }
  }
  
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

- (BOOL)isLoadErrorAnotherRequest:(NSError *)error
{
  return (error.domain == NSURLErrorDomain && error.code == -999);
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
  
  if (self.currentlyLoadingSearchQuery) {
    [DFAnalytics logSearchLoadEndedWithQuery:self.currentlyLoadingSearchQuery];
    self.currentlyLoadingSearchQuery = nil;
  }
  
  NSString *requestURLString = self.webView.request.URL.absoluteString;
  
  NSError *error;
  NSRegularExpression *pageNumRegex = [NSRegularExpression regularExpressionWithPattern:@"page\\=(\\d+)" options:0 error:&error];
  NSArray *matches = [pageNumRegex matchesInString:requestURLString options:0 range:[requestURLString rangeOfString:requestURLString]];
  if (matches && matches.count > 0) {
    NSRange pageCountRange = [[matches firstObject] rangeAtIndex:1];
    NSString *pageCountString = [requestURLString substringWithRange:pageCountRange];
    NSInteger pageCount = [pageCountString integerValue];
    [DFAnalytics logSearchResultPageLoaded:pageCount];
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
  self.currentPhotoIDIndex = [self.searchResultPhotoIDs
                              indexOfObject:@([photoIDString longLongValue])];
  
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


#pragma mark - Search Bar delegate and helpers

- (void)searchBarTextDidBeginEditing:(DFSearchBar *)searchBar
{
  [self updateUIForSearchBarHasFocus:YES showingDefaultQuery:NO];
}

- (void)searchBar:(DFSearchBar *)searchBar textDidChange:(NSString *)searchText
{
  [self updateSearchResults:searchText];
}

- (void)searchBarSearchButtonClicked:(DFSearchBar *)searchBar
{
  if ([searchBar.text isEqualToString:@""] || [[searchBar.text lowercaseString] isEqualToString:@"everything"]) {
    [self loadDefaultSearch];
  } else {
    [self executeSearchForQuery:self.searchBar.text reverseResults:NO];
    [self updateUIForSearchBarHasFocus:NO showingDefaultQuery:NO];
  }
}

- (void)searchBarCancelButtonClicked:(DFSearchBar *)searchBar
{
  [self updateUIForSearchBarHasFocus:NO showingDefaultQuery:[self.searchBar.text isEqualToString:SEARCH_DEFAULT_QUERY]];
}

- (void)searchBarClearButtonClicked:(DFSearchBar *)searchBar
{
  searchBar.text = searchBar.defaultQuery;
  [self loadDefaultSearch];
}

- (void)updateUIForSearchBarHasFocus:(BOOL)searchBarHasFocus
              showingDefaultQuery:(BOOL)showingDefault
{
  if (searchBarHasFocus) {
    self.searchResultsTableView.hidden = NO;
    [self.searchBar setShowsCancelButton:YES animated:YES];
    [self.searchBar setShowsClearButton:NO animated:YES];
  } else {
    [self.searchBar setShowsCancelButton:NO animated:YES];
    if (showingDefault) {
      [self.searchBar setShowsClearButton:NO animated:YES];
    } else {
      [self.searchBar setShowsClearButton:YES animated:YES];
    }
    self.searchResultsTableView.hidden = YES;
    [self.searchBar resignFirstResponder];
  }
}

- (void)updateSearchResults:(NSString *)query
{
	/*
	 Update the filtered array based on the search text and scope.
	 */
  
  NSMutableArray *sections = [self defaultSectionNames];
  NSMutableDictionary *searchResults = [[self defaultSearchResults] mutableCopy];
  
  if ([self isDateInQuery:query]) {
    [searchResults removeObjectForKey:DATE_SECTION_NAME];
    [sections removeObject:DATE_SECTION_NAME];
  }
  if ([self isLocationInQuery:query]){
    [searchResults removeObjectForKey:LOCATION_SECTION_NAME];
    [sections removeObject:LOCATION_SECTION_NAME];
  }
  if ([self isCategoryInQuery:query]) {
    [searchResults removeObjectForKey:CATEGORY_SECTION_NAME];
    [sections removeObject:CATEGORY_SECTION_NAME];
  }
  
  self.sectionNames = sections;
  self.searchResultsBySectionName = searchResults;
  
  [self.searchResultsTableView reloadData];
  
}


- (BOOL)isDateInQuery:(NSString *)query
{
  if (query == nil) return NO;
  for (DFPeanutSuggestion *dateSuggestion in [[self defaultSearchResults] objectForKey:DATE_SECTION_NAME])
  {
    if([query rangeOfString:dateSuggestion.name].location != NSNotFound) {
      return YES;
    }
  }
  return NO;
}

- (BOOL)isLocationInQuery:(NSString *)query
{
  if (query == nil) return NO;
  for (DFPeanutSuggestion *locationSuggestion in [[self defaultSearchResults] objectForKey:LOCATION_SECTION_NAME])
  {
    if([query rangeOfString:locationSuggestion.name].location != NSNotFound) {
      return YES;
    }
  }
  return NO;
}

- (BOOL)isCategoryInQuery:(NSString *)query
{
  if (query == nil) return NO;
  for (DFPeanutSuggestion *categorySuggestion in [[self defaultSearchResults] objectForKey:CATEGORY_SECTION_NAME])
  {
    if([query rangeOfString:categorySuggestion.name].location != NSNotFound) {
      return YES;
    }
  }
  return NO;
}

#pragma mark - UITableView datasource and delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return self.sectionNames.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section

{
  NSInteger countForSection = [self resultsForSectionWithIndex:section].count;
  return countForSection;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutSuggestion *peanutSuggestion = [[self resultsForSectionWithIndex:indexPath.section]
                                          objectAtIndex:indexPath.row];
  
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DFSearchResultTableViewCell"];
  cell.textLabel.text = peanutSuggestion.name ? peanutSuggestion.name : @"None";
  cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", peanutSuggestion.count];
  cell.textLabel.font = [cell.textLabel.font fontWithSize:SearchResultsCellFontSize];
  return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
  DFTableHeaderView *view = [[[UINib nibWithNibName:@"DFTableHeaderView" bundle:nil] instantiateWithOwner:self options:nil] firstObject];
  
  NSString *sectionName = self.sectionNames[section];
  view.textLabel.text = SectionNameToTitles[sectionName];
  
  NSString *imageName = [NSString stringWithFormat:@"Icons/%@%@", self.sectionNames[section], @"SectionHeader"];
  view.imageView.image = [UIImage imageNamed:imageName];
  
  return view;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSString *selectionString;
  NSArray *resultsForSectionWithIndex = [self resultsForSectionWithIndex:indexPath.section];
  if (resultsForSectionWithIndex && resultsForSectionWithIndex.count > 0) {
    DFPeanutSuggestion *suggestion = [[self resultsForSectionWithIndex:indexPath.section]
                                      objectAtIndex:indexPath.row];
    selectionString = suggestion.name;
  } else {
    selectionString = @"";
    DDLogWarn(@"DFSearchViewController user selected blank indexPath: %@ searchResultsBySecitonName:%@",
              indexPath.description, self.searchResultsBySectionName.description);
  }
  
  if (!self.searchBar.isFirstResponder) [self.searchBar becomeFirstResponder];
  self.searchBar.text = [NSString stringWithFormat:@"%@%@ ", self.searchBar.text, selectionString];
  [self updateSearchResults:self.searchBar.text];
}


- (void)showSettings:(id)sender
{
  DFSettingsViewController *svc = [[DFSettingsViewController alloc] init];
  [self.navigationController pushViewController:svc animated:YES];
}

#pragma mark - Data Accessors


- (NSArray *)resultsForSectionWithIndex:(NSInteger)sectionIndex
{
  return self.searchResultsBySectionName[[self sectionNameForIndex:sectionIndex]];
}

- (NSArray *)resultsForSectionWithName:(NSString *)sectionName
{
  return self.searchResultsBySectionName[sectionName];
}

- (NSString *)sectionNameForIndex:(NSInteger)index
{
  return self.sectionNames[index];
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

#pragma mark - Upload notificatoin handler

- (void)uploadStatusChanged:(NSNotification *)note
{
  DFUploadSessionStats *sessionStats = note.userInfo[DFUploadStatusUpdateSessionUserInfoKey];
  if (sessionStats.numThumbnailsUploaded - self.lastSeenNumUploaded > RefreshSuggestionsThreshold) {
    [self populateDefaultAutocompleteSearchResults];
  }
  
  self.lastSeenNumUploaded = sessionStats.numThumbnailsUploaded;
}



- (UIViewController*)pageViewController:(UIPageViewController *)pageViewController
     viewControllerBeforeViewController:(UIViewController *)viewController
{
  
  if (self.currentPhotoIDIndex > 0) {
    self.currentPhotoIDIndex -= 1;
  } else {
    self.currentPhotoIDIndex = self.searchResultPhotoIDs.count - 1;
  }
  
  NSNumber *newPhotoID = [self.searchResultPhotoIDs objectAtIndex:self.currentPhotoIDIndex];
  DFPhoto *photo = [[DFPhotoStore sharedStore] photoWithPhotoID:
                    [newPhotoID longLongValue]];
  DFPhotoViewController *pvc = [[DFPhotoViewController alloc] init];
  pvc.photo = photo;
  return pvc;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
       viewControllerAfterViewController:(UIViewController *)viewController
{
  if (self.currentPhotoIDIndex < self.searchResultPhotoIDs.count - 1) {
    self.currentPhotoIDIndex += 1;
  } else {
    self.currentPhotoIDIndex = 0;
  }
  
  NSNumber *newPhotoID = [self.searchResultPhotoIDs objectAtIndex:self.currentPhotoIDIndex];
  DFPhoto *photo = [[DFPhotoStore sharedStore] photoWithPhotoID:
                    [newPhotoID longLongValue]];
  DFPhotoViewController *pvc = [[DFPhotoViewController alloc] init];
  pvc.photo = photo;
  return pvc;
}

#pragma mark - UIScrollViewDelegate
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
  self.lastOffsetY = scrollView.contentOffset.y;
}

- (void) scrollViewWillBeginDecelerating:(UIScrollView *)scrollView
{
  bool hide = (scrollView.contentOffset.y > self.lastOffsetY);
  [[self navigationController] setNavigationBarHidden:hide animated:YES];
  self.hideStatusBar = hide;
}

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
