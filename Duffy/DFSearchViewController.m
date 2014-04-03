//
//  DFSearchViewController.m
//  Duffy
//
//  Created by Henry Bridge on 3/14/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFSearchViewController.h"
#import "DFUser.h"

@interface DFSearchViewController ()

@property (nonatomic, retain) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, retain) UIBarButtonItem *loadingIndicatorItem;
@property (nonatomic, retain) UIBarButtonItem *refreshBarButtonItem;

@property (nonatomic, retain) UISearchBar *searchBar;

@property (nonatomic, retain) NSMutableDictionary *searchResultsBySectionName;
@property (nonatomic, retain) NSMutableArray *sectionNames;

@end


static NSString *FREE_FORM_SECTION_NAME = @"Search for";
static NSString *DATE_SECTION_NAME = @"Date";
static NSString *LOCATION_SECTION_NAME = @"Location";
static NSString *CATEGORY_SECTION_NAME = @"Category";

static NSString *GroupsBaseURL = @"http://asood123.no-ip.biz:7000/viz/groups/";
static NSString *SearchBaseURL = @"http://asood123.no-ip.biz:7000/viz/search/";
static NSString *PhoneIDURLParameter = @"phone_id";
static NSString *QueryURLParameter = @"q";


@implementation DFSearchViewController

- (id)init
{
    self = [super init];
    if (self) {
        self.navigationItem.title = @"Search";
        
        self.tabBarItem.title = @"Search";
        self.tabBarItem.image = [UIImage imageNamed:@"Search"];
        
        [self setupNavBar];
        [self registerForKeyboardNotifications];
    }
    return self;
}


- (void)setupNavBar
{
    // create loading indicator
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicatorItem = [[UIBarButtonItem alloc]
                                 initWithCustomView:self.loadingIndicator];
    self.navigationItem.rightBarButtonItem = self.loadingIndicatorItem;
    
    // create reload button
    self.refreshBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                              target:self
                                                                              action:@selector(refreshWebView)];
    // create search bar
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Search";
    
    self.navigationItem.titleView = self.searchBar;
}

- (void)setupTableView
{
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
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    dict[DATE_SECTION_NAME] = @[@"last week", @"February 2014", @"last summer"];
    dict[LOCATION_SECTION_NAME] = @[@"New York", @"Hoover Dam", @"Croatia"];
    dict[CATEGORY_SECTION_NAME] = @[@"red_wine", @"valley", @"cheeseburger"];
    return dict;
}


- (void)viewDidLoad
{
    [super viewDidLoad];

    [self setupTableView];
    [self.webView setDelegate:self];
    self.searchResultsTableView.frame = self.webView.frame;
    self.searchResultsTableView.hidden = YES;
    
    [self.view insertSubview:self.searchResultsTableView aboveSubview:self.webView];
    self.automaticallyAdjustsScrollViewInsets = YES;
    // TODO hack this should be dynamic
    self.searchResultsTableView.contentInset = UIEdgeInsetsMake(64, 0, 0, 0);

}

- (void)viewDidAppear:(BOOL)animated
{
    if ([[DFUser currentUser] userID]) {
        [self loadImageCategoriesForUser:[[DFUser currentUser] userID]];
    }
}

- (void)loadImageCategoriesForUser:(NSString *)userID
{
    NSString *urlString = [NSString stringWithFormat:@"%@%@", GroupsBaseURL, userID];
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [self.webView loadRequest:request];
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    self.navigationItem.rightBarButtonItem = self.loadingIndicatorItem;
    [self.loadingIndicator startAnimating];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self.loadingIndicator stopAnimating];
    self.navigationItem.rightBarButtonItem = self.refreshBarButtonItem;
}

- (void)refreshWebView
{
    [self.webView reload];
}


- (void)executeSearchForQuery:(NSString *)query
{
   
    NSString *queryURLString = [NSString stringWithFormat:@"%@?%@=%@&%@=%@",
                                SearchBaseURL,
                                PhoneIDURLParameter, [[DFUser currentUser] deviceID],
                                QueryURLParameter, [query stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSURL *queryURL = [NSURL URLWithString:queryURLString];
    
    NSLog(@"Executing search for URL: %@", queryURL.absoluteString);
    [self.webView loadRequest:[NSURLRequest requestWithURL:queryURL]];
}



#pragma mark - Search Bar delegate and helpers

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    self.searchResultsTableView.hidden = NO;
    self.searchBar.showsCancelButton = YES;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self updateSearchResults:searchText];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [self executeSearchWithSearchbarText];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    self.searchResultsTableView.hidden = YES;
    self.searchBar.showsCancelButton = NO;
    [self.searchBar resignFirstResponder];
}

- (void)updateSearchResults:(NSString *)query
{
	/*
	 Update the filtered array based on the search text and scope.
	 */
    
    NSMutableArray *sections = [self defaultSectionNames];
    NSMutableDictionary *searchResults = [self defaultSearchResults];
    
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
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return self.sectionNames[section];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // TODO configure a view controller and push it
    
    // logging
    //    NSDictionary *openParams = [NSDictionary dictionaryWithObjectsAndKeys:
    //                                cocktail.cocktailName, COCKTAIL_NAME_KEY,
    //                                [[self class] description], PARENT_VIEW_CLASS_KEY,
    //                                eventTrigger, EVENT_TRIGGER_KEY,
    //                                [NSString stringWithFormat:@"%d", indexPath.row], LIST_INDEX_KEY,
    //                                self.navigationItem.title, LIST_NAME_KEY,
    //                                nil];
    //    [Flurry logEvent:COCKTAIL_OPENED_EVENT withParameters:openParams];
    
    NSString *selectionString = [[self resultsForSectionWithIndex:indexPath.section] objectAtIndex:indexPath.row];
    
    if (![[self sectionNameForIndex:indexPath.section] isEqualToString:FREE_FORM_SECTION_NAME]) {
        self.searchBar.text = [NSString stringWithFormat:@"%@%@ ", self.searchBar.text, selectionString];
        [self updateSearchResults:self.searchBar.text];
    } else {
        [self executeSearchWithSearchbarText];
    }
}

- (void)executeSearchWithSearchbarText
{
    [self executeSearchForQuery:self.searchBar.text];
    
    self.searchBar.showsCancelButton = NO;
    self.searchResultsTableView.hidden = YES;
    [self.searchBar resignFirstResponder];
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
    CGRect toRect = [(NSValue *)notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    self.searchResultsTableView.frame = CGRectMake(self.searchResultsTableView.frame.origin.x,
                                                   self.searchResultsTableView.frame.origin.x,
                                                   self.searchResultsTableView.frame.size.width,
                                                   toRect.origin.y);
}

- (void)keyboardDidHide:(NSNotification *)notification {
    CGRect toRect = [(NSValue *)notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    self.searchResultsTableView.frame = CGRectMake(self.searchResultsTableView.frame.origin.x,
                                                   self.searchResultsTableView.frame.origin.x,
                                                   self.searchResultsTableView.frame.size.width,
                                                   toRect.origin.y);
}

@end
