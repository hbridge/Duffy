//
//  DFSearchViewController.h
//  Duffy
//
//  Created by Henry Bridge on 3/14/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFUploadProgressView.h"
#import "DFSearchBar.h"

@class DFAutocompleteController;

@interface DFSearchViewController : UIViewController <UIWebViewDelegate, DFSearchBarDelegate, UITableViewDataSource, UITableViewDelegate, UIPageViewControllerDataSource>

@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet UITableView *searchResultsTableView;
@property (nonatomic, retain) NSMutableDictionary *defaultSearchResults;
@property (nonatomic, retain) DFAutocompleteController *autcompleteController;

@property (atomic, retain) NSString *currentlyLoadingSearchQuery;

- (void)executeSearchForQuery:(NSString *)query;


@end
