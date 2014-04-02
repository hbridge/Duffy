//
//  DFSearchDisplayController.m
//  Duffy
//
//  Created by Henry Bridge on 4/2/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFSearchDisplayController.h"
#import "DFSearchViewController.h"

@interface DFSearchDisplayController ()

@property (nonatomic, retain) NSMutableDictionary *searchResultsBySection;
@property (nonatomic, retain) NSDictionary *sectionNamesToIndex;
@property (nonatomic, retain) UIView *searchResultsSuperview;

@end

@implementation DFSearchDisplayController

-(id)initWithSearchBar:(UISearchBar *)searchBar contentsController:(UIViewController *)viewController
{
    self = [super initWithSearchBar:searchBar contentsController:viewController];
    if (self) {
        self.delegate = self;
        self.searchResultsDataSource = self;
        self.searchResultsDelegate = self;
        self.displaysSearchBarInNavigationBar = YES;
        
        [self.searchResultsTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"UITableViewCell"];
        //self.searchResultsTableView.style = UITableViewStyleGrouped;
        [self setDefaultSectionNames];
        [self setDefaultSearchResults];
    }
    return self;
}

- (DFSearchViewController *)searchViewController
{
    return (DFSearchViewController *)self.searchContentsController;
}

- (void)setDefaultSectionNames
{
    self.sectionNamesToIndex = @{@"Date": [NSNumber numberWithInteger:0],
                                   @"Location": [NSNumber numberWithInteger:1],
                                   @"Category": [NSNumber numberWithInteger:2]
                                   };
    
}

- (void)setDefaultSearchResults
{
    self.searchResultsBySection = [[NSMutableDictionary alloc] init];
    self.searchResultsBySection[[self sectionIndexForName:@"Date"]] = @[@"last week", @"last month", @"last summer"];
    self.searchResultsBySection[[self sectionIndexForName:@"Location"]] = @[@"New York", @"Hoover Dam", @"Croatia"];
    self.searchResultsBySection[[self sectionIndexForName:@"Category"]] = @[@"red_wine", @"valley", @"cheeseburger"];
}


#pragma mark - UITableViewDatasource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.sectionNamesToIndex.count;
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
    return [[self.sectionNamesToIndex allKeysForObject:[NSNumber numberWithInteger:section]]
            firstObject];
}

- (NSArray *)resultsForSectionWithIndex:(NSInteger)section
{
    return self.searchResultsBySection[[NSNumber numberWithInteger:section]];
}

- (NSArray *)resultsForSectionWithName:(NSString *)sectionName
{
    return [self resultsForSectionWithIndex:[[self sectionIndexForName:sectionName] integerValue]];
}

- (NSNumber *)sectionIndexForName:(NSString *)name
{
    return (NSNumber*)self.sectionNamesToIndex[name];
}


#pragma mark - UISearchDisplayController Delegate Methods

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [self updateFilteredContentForSearch:searchString];
    
    //schedule the logging of this search term if it isn't replaced by another too quickly
    //    NSDictionary *searchEventParams = [NSDictionary dictionaryWithObjectsAndKeys:
    //                                       [NSString stringWithFormat:@"%d", self.searchResults.count], SEARCH_NUM_RESULTS_KEY,
    //                                       self.searchController.searchBar.text, SEARCH_QUERY_KEY,
    //                                       nil];
    //    if (self.searchDelayTimer) {
    //        [self.searchDelayTimer invalidate];
    //    }
    //    self.searchDelayTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
    //                                                             target:self
    //                                                           selector:@selector(logSearchEvent:)
    //                                                           userInfo:searchEventParams
    //                                                            repeats:NO];
    
    
    // Return YES to cause the search result table view to be reloaded.
    return YES;
}

- (void)updateFilteredContentForSearch:(NSString *)search
{
	/*
	 Update the filtered array based on the search text and scope.
	 */
    
    // Show default suggestions
    if ((search == nil) || [search length] == 0)
    {
        [self setDefaultSectionNames];
        [self setDefaultSearchResults];
        
        return;
    }
    
    
    self.sectionNamesToIndex = @{@"Freeform": [NSNumber numberWithInteger:0]};
    self.searchResultsBySection = [@{[NSNumber numberWithInteger:0]: @[search]} mutableCopy];
    

}

- (void)searchDisplayControllerDidBeginSearch:(UISearchDisplayController *)controller
{
    NSLog(@"search began");
    //[Flurry logEvent:SEARCH_VIEWED_EVENT withParameters:nil timed:YES];
}

- (void)searchDisplayControllerWillBeginSearch:(UISearchDisplayController *)controller
{

}

- (void)searchDisplayController:(UISearchDisplayController *)controller didHideSearchResultsTableView:(UITableView *)tableView
{
    // force the table view to appear
    tableView.hidden = NO;
    UIView *sdcContainerView = tableView.superview.superview;
    if (sdcContainerView.subviews.count == 3) {
        UIView *overlay = [[sdcContainerView subviews] lastObject];
        tableView.contentInset = UIEdgeInsetsMake(overlay.frame.origin.y, overlay.frame.origin.x, 0, 0);
        [overlay setHidden:YES];
    }
}




- (void)logSearchEvent:(NSTimer *)t
{
    //    NSDictionary *searchEventParams = (NSDictionary *)t.userInfo;
    //    [Flurry logEvent:SEARCH_TEXT_ENTERED_EVENT withParameters:searchEventParams];
}


- (void)searchDisplayControllerWillEndSearch:(UISearchDisplayController *)controller
{
    //    NSDictionary *endSearchParams = [NSDictionary dictionaryWithObjectsAndKeys:
    //                                     [NSString stringWithFormat:@"%d", self.searchResults.count], SEARCH_NUM_RESULTS_KEY,
    //                                     self.searchController.searchBar.text, SEARCH_QUERY_KEY,
    //                                     nil];
    //    [Flurry endTimedEvent:SEARCH_VIEWED_EVENT withParameters:endSearchParams];
}

#pragma mark - Table view delegate

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

    if ([self.searchBar.text isEqualToString:@""] || !self.searchBar.text) {
        self.searchBar.text =  selectionString;
    }
    
    [self executeSearchWithSearchbarText];

}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [self executeSearchWithSearchbarText];
    [self setActive:NO animated:YES];
}


- (void)executeSearchWithSearchbarText
{
    [self.searchViewController executeSearchForQuery:self.searchBar.text];
    [self setActive:NO animated:YES];
}

@end
