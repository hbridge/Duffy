//
//  DFSearchViewController2.m
//  Duffy
//
//  Created by Henry Bridge on 4/3/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFSearchViewController2.h"
#import "DFUser.h"

@interface DFSearchViewController2 ()

@property (nonatomic, retain) UIWebView *webView;

@property (nonatomic, retain) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, retain) UIBarButtonItem *loadingIndicatorItem;
@property (nonatomic, retain) UIBarButtonItem *refreshBarButtonItem;

@property (nonatomic, retain) UISearchBar *searchBar;

@property (nonatomic, retain) NSMutableDictionary *searchResultsBySectionName;
@property (nonatomic, retain) NSMutableArray *sectionNames;


@end

@implementation DFSearchViewController2

static NSString *FREE_FORM_SECTION_NAME = @"Search for";
static NSString *DATE_SECTION_NAME = @"Date";
static NSString *LOCATION_SECTION_NAME = @"Location";
static NSString *CATEGORY_SECTION_NAME = @"Category";

static NSString *SearchBaseURL = @"http://asood123.no-ip.biz:7000/viz/search/";
static NSString *PhoneIDURLParameter = @"phone_id";
static NSString *QueryURLParameter = @"q";

- (id)init
{
    self = [super init];
    if (self) {
        self.navigationItem.title = @"Search";
        self.tabBarItem.title = @"Search";
        self.tabBarItem.image = [UIImage imageNamed:@"Search"];
        
        [self setupNavBar];
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
    self.navigationItem.titleView = self.searchBar;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"UITableViewCell"];

    [self updateSearchResults:nil];
    
    [self setupWebView];
}

- (void)setupWebView
{
    self.webView = [[UIWebView alloc] initWithFrame:self.tableView.frame];
    self.webView.delegate = self;
    [self.tableView addSubview:self.webView];
    self.webView.hidden = YES;
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
    NSString *selectionString = [[self resultsForSectionWithIndex:indexPath.section] objectAtIndex:indexPath.row];
    
    if (![[self sectionNameForIndex:indexPath.section] isEqualToString:FREE_FORM_SECTION_NAME]) {
        self.searchBar.text = [NSString stringWithFormat:@"%@%@ ", self.searchBar.text, selectionString];
        [self updateSearchResults:self.searchBar.text];
    } else {
        [self executeSearchWithSearchbarText];
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)updateSearchResults:(NSString *)query
{
    NSMutableArray *sections = [self defaultSectionNames];
    NSMutableDictionary *searchResults = [self defaultSearchResults];
    
    if ((query != nil) && [query length] > 0)
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
    
    [self.tableView reloadData];
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


#pragma mark - Search Bar delegate and helpers

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    self.webView.hidden = YES;
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
    self.webView.hidden = NO;
    self.searchBar.showsCancelButton = NO;
    [self.searchBar resignFirstResponder];
}

- (void)executeSearchWithSearchbarText
{
    [self executeSearchForQuery:self.searchBar.text];
    
    self.searchBar.showsCancelButton = NO;
    self.webView.hidden = NO;
    [self.searchBar resignFirstResponder];
}

#pragma mark - Web View Delegate and Actions

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


@end
