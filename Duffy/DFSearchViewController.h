//
//  DFSearchViewController.h
//  Duffy
//
//  Created by Henry Bridge on 3/14/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFUploadProgressView.h"

@class DFAutocompleteController;

@interface DFSearchViewController : UIViewController <UIWebViewDelegate, UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet UITableView *searchResultsTableView;
@property (weak, nonatomic) IBOutlet DFUploadProgressView *uploadProgressView;
@property (nonatomic, retain) NSMutableDictionary *defaultSearchResults;
@property (nonatomic, retain) DFAutocompleteController *autcompleteController;

- (void)executeSearchForQuery:(NSString *)query;


@end
