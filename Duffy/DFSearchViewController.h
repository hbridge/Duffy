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

@class DFSuggestionAdapter;

@interface DFSearchViewController : UIViewController <UIWebViewDelegate, DFSearchBarDelegate, UITableViewDataSource, UITableViewDelegate, UIPageViewControllerDataSource, UIScrollViewDelegate>

@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet UITableView *searchResultsTableView;

@property (atomic, retain) NSString *currentlyLoadingSearchQuery;

- (void)executeSearchForQuery:(NSString *)query reverseResults:(BOOL)reverseResults;


@end
