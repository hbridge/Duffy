//
//  DFSearchController.m
//  Duffy
//
//  Created by Henry Bridge on 3/10/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFSearchController.h"

@interface DFSearchController()

@end

@implementation DFSearchController

-(id)initWithSearchBar:(UISearchBar *)searchBar contentsController:(UIViewController *)viewController
{
    self = [super initWithSearchBar:searchBar contentsController:viewController];
    if (self) {
        self.delegate = self;
        self.searchResultsDataSource = self;
        self.searchResultsDelegate = self;
        self.displaysSearchBarInNavigationBar = YES;
    }
    return self;
}


#pragma mark - UITableViewDatasource methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section

{
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
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
    if ((search == nil) || [search length] == 0)
    {
        // show suggestions here
        return;
    }
    
    //self.searchResults = [searcher universalSearchWithQueryString:search];
    
    
}




- (void)logSearchEvent:(NSTimer *)t
{
    //    NSDictionary *searchEventParams = (NSDictionary *)t.userInfo;
    //    [Flurry logEvent:SEARCH_TEXT_ENTERED_EVENT withParameters:searchEventParams];
}


- (void)searchDisplayControllerDidBeginSearch:(UISearchDisplayController *)controller
{
    NSLog(@"search began");
    //[Flurry logEvent:SEARCH_VIEWED_EVENT withParameters:nil timed:YES];
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
}


@end