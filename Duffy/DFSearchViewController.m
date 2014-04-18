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

@interface DFSearchViewController ()

@property (nonatomic, retain) UISearchBar *searchBar;

@property (nonatomic, retain) NSMutableDictionary *searchResultsBySectionName;
@property (nonatomic, retain) NSMutableArray *sectionNames;

@end

static NSInteger NUM_SUGGESTION_RESULTS = 5;

static NSString *FREE_FORM_SECTION_NAME = @"Search";
static NSString *DATE_SECTION_NAME = @"Time";
static NSString *LOCATION_SECTION_NAME = @"Location";
static NSString *CATEGORY_SECTION_NAME = @"Subject";

static NSString *SEARCH_PLACEHOLDER = @"Search for time, location or things";

static NSDictionary *SectionNameToTitles;

static NSString *GroupsPath = @"/viz/groups/";
static NSString *SearchPath = @"/viz/search/";
static NSString *PhoneIDURLParameter = @"phone_id";
static NSString *UserIDURLParameter = @"user_id";
static NSString *QueryURLParameter = @"q";

static CGFloat SearchResultsRowHeight = 38;
static CGFloat SearchResultsCellFontSize = 15;

@implementation DFSearchViewController

@synthesize defaultSearchResults = _defaultSearchResults;

+ (void)initialize
{
    SectionNameToTitles = @{FREE_FORM_SECTION_NAME: @"Search for",
                            DATE_SECTION_NAME: @"Time",
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
        self.tabBarItem.image = [UIImage imageNamed:@"Search"];
        
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
    [self.webView setDelegate:self];
    [self.webView loadHTMLString:@"<br><center style=\"font-family: sans-serif\">Tap above to get started</center>" baseURL:nil];
    
    [self.view insertSubview:self.searchResultsTableView aboveSubview:self.webView];
    self.automaticallyAdjustsScrollViewInsets = YES;
    // TODO hack this should be dynamic
   
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self populateDefaultAutocompleteSearchResults];
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
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = SEARCH_PLACEHOLDER;
    self.navigationItem.titleView = self.searchBar;
}

- (void)setupTableView
{
    self.searchResultsTableView.rowHeight = SearchResultsRowHeight;
    [self.searchResultsTableView registerClass:[UITableViewCell class]
                        forCellReuseIdentifier:@"UITableViewCell"];
    
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
        _defaultSearchResults[DATE_SECTION_NAME] = @[@""];
        _defaultSearchResults[LOCATION_SECTION_NAME] = @[@""];
        _defaultSearchResults[CATEGORY_SECTION_NAME] = @[@""];
    }
    
    
    return _defaultSearchResults;
}

- (NSArray *)sortedTop:(NSInteger)count suggestionsInDict:(NSDictionary *)dict
{
    NSMutableArray *sortedEntries = [dict keysSortedByValueUsingComparator:^NSComparisonResult(NSNumber *count1, NSNumber *count2) {
        return [count2 compare:count1];
    }].mutableCopy;
    
    NSRange range;
    if (dict.count > count) {
        range.location = 0;
        range.length = count;
    } else {
        range.location = 0;
        range.length = dict.count;
    }
    
    return [sortedEntries objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:range]];
}


- (void)populateDefaultAutocompleteSearchResults
{
    [self.autcompleteController fetchSuggestions:^(NSDictionary *categorySuggestionsToCounts,
                                                   NSDictionary *locationSuggestionsToCounts,
                                                   NSDictionary *timeSuggestionsToCounts) {
        if (locationSuggestionsToCounts) {
            self.defaultSearchResults[LOCATION_SECTION_NAME] = [self sortedTop:NUM_SUGGESTION_RESULTS
                                                             suggestionsInDict:locationSuggestionsToCounts];
        } else {
            [self.sectionNames removeObject:LOCATION_SECTION_NAME];
        }
        
        if (categorySuggestionsToCounts) {
            self.defaultSearchResults[CATEGORY_SECTION_NAME] = [self sortedTop:NUM_SUGGESTION_RESULTS
                                                             suggestionsInDict:categorySuggestionsToCounts];
        } else {
            [self.sectionNames removeObject:CATEGORY_SECTION_NAME];
        }
        
        if (timeSuggestionsToCounts) {
            self.defaultSearchResults[DATE_SECTION_NAME] = [self sortedTop:NUM_SUGGESTION_RESULTS
                                                             suggestionsInDict:timeSuggestionsToCounts];
        } else {
            [self.sectionNames removeObject:DATE_SECTION_NAME];
        }
        
        
        [self updateSearchResults:self.searchBar.text];
    }];
}



- (void)loadImageCategoriesForUser:(NSString *)userID
{
    NSURL *url = [[[DFUser currentUser] serverURL] URLByAppendingPathComponent:GroupsPath];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [self.webView loadRequest:request];
}


- (void)executeSearchForQuery:(NSString *)query
{
    self.currentlyLoadingSearchQuery = query;
    NSString *queryURLString = [NSString stringWithFormat:@"%@%@?%@=%@&%@=%@",
                                [[[DFUser currentUser] serverURL] absoluteString],
                                SearchPath,
                                UserIDURLParameter, [[DFUser currentUser] userID],
                                QueryURLParameter, [query stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSURL *queryURL = [NSURL URLWithString:queryURLString];

    
    NSLog(@"Executing search for URL: %@", queryURL.absoluteString);
    [DFAnalytics logSearchLoadStartedWithQuery:query suggestions:self.defaultSearchResults];
    [self.webView loadRequest:[NSURLRequest requestWithURL:queryURL]];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSString *requestURLString = request.URL.absoluteString;
    if ([requestURLString rangeOfString:@"user_data"].location != NSNotFound) {
        [webView stopLoading];
        NSLog(@"Pushing native view of full photo: %@", requestURLString);
        [self pushPhotoWebView:requestURLString];
        return NO;
    }
    
    return YES;
}



- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    if (self.currentlyLoadingSearchQuery) {
        [DFAnalytics logSearchLoadEndedWithQuery:self.currentlyLoadingSearchQuery];
        self.currentlyLoadingSearchQuery = nil;
    }
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

- (void)pushPhotoWebView:(NSString *)photoURLString
{
    NSURL *photoURL = [NSURL URLWithString:photoURLString];
    DFPhotoWebViewController *pvc = [[DFPhotoWebViewController alloc] initWithPhotoURL:photoURL];
    [self.navigationController pushViewController:pvc animated:YES];
}


#pragma mark - Search Bar delegate and helpers

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    [self updateUIForSearchBarHasFocus:YES];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self updateSearchResults:searchText];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [self executeSearchForQuery:self.searchBar.text];
    [self updateUIForSearchBarHasFocus:NO];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [self updateUIForSearchBarHasFocus:NO];
}

- (void)updateUIForSearchBarHasFocus:(BOOL)searchBarHasFocus
{
    if (searchBarHasFocus) {
        self.searchResultsTableView.hidden = NO;
        [self.searchBar setShowsCancelButton:YES animated:YES];
        self.navigationItem.rightBarButtonItem = nil;
    } else {
        [self.searchBar setShowsCancelButton:NO animated:YES];
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
    
    if ([query length] > 0)
    {
        [sections insertObject:FREE_FORM_SECTION_NAME atIndex:0];
        searchResults[FREE_FORM_SECTION_NAME] = [NSArray arrayWithObject:query];
    }
    
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
    for (NSString *dateString in [[self defaultSearchResults] objectForKey:DATE_SECTION_NAME])
    {
        if([query rangeOfString:dateString].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)isLocationInQuery:(NSString *)query
{
    if (query == nil) return NO;
    for (NSString *locationString in [[self defaultSearchResults] objectForKey:LOCATION_SECTION_NAME])
    {
        if([query rangeOfString:locationString].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)isCategoryInQuery:(NSString *)query
{
    if (query == nil) return NO;
    for (NSString *categoryString in [[self defaultSearchResults] objectForKey:CATEGORY_SECTION_NAME])
    {
        if([query rangeOfString:categoryString].location != NSNotFound) {
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
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell"];
    cell.textLabel.text = [[self resultsForSectionWithIndex:indexPath.section] objectAtIndex:indexPath.row];
    cell.textLabel.font = [cell.textLabel.font fontWithSize:SearchResultsCellFontSize];
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == 0) {
        // This is a hack to put this here, but if it's not the header view's frame gets set to something weird
        // and bleeds into other rows when you start typing in the search bar
        UINib *warningViewNib = [UINib nibWithNibName:@"DFSearchResultsTableViewResultsIncompleteWarningHeader" bundle:nil];
        UIView *warningView = [[warningViewNib instantiateWithOwner:self options:nil] objectAtIndex:0];
        self.searchResultsTableView.tableHeaderView.frame = warningView.frame;
    }
    
    DFTableHeaderView *view = [[[UINib nibWithNibName:@"DFTableHeaderView" bundle:nil] instantiateWithOwner:self options:nil] firstObject];
    
    NSString *sectionName = self.sectionNames[section];
    view.textLabel.text = SectionNameToTitles[sectionName];
    
    NSString *imageName = [NSString stringWithFormat:@"%@%@", self.sectionNames[section], @"SectionHeader"];
    view.imageView.image = [UIImage imageNamed:imageName];
    
    return view;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *selectionString = [[self resultsForSectionWithIndex:indexPath.section] objectAtIndex:indexPath.row];
    
    if (![[self sectionNameForIndex:indexPath.section] isEqualToString:FREE_FORM_SECTION_NAME]) {
        if (!self.searchBar.isFirstResponder) [self.searchBar becomeFirstResponder];
            self.searchBar.text = [NSString stringWithFormat:@"%@%@ ", self.searchBar.text, selectionString];
        [self updateSearchResults:self.searchBar.text];
    } else {
        [self executeSearchForQuery:self.searchBar.text];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [self updateUIForSearchBarHasFocus:NO];
    }
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
    DFUploadSessionStats *uploadStats = note.userInfo[DFUploadStatusUpdateSessionUserInfoKey];
    
    if (uploadStats.numRemaining > 0 && self.searchResultsTableView.tableHeaderView == nil) {
        UINib *warningViewNib = [UINib nibWithNibName:@"DFSearchResultsTableViewResultsIncompleteWarningHeader" bundle:nil];
        UIView *warningView = [[warningViewNib instantiateWithOwner:self options:nil] objectAtIndex:0];
        self.searchResultsTableView.tableHeaderView = warningView;
    } else if (uploadStats.numRemaining == 0){
        self.searchResultsTableView.tableHeaderView = nil;
    }
}



@end
