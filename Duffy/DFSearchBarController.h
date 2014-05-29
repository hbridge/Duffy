//
//  DFSearchBarController.h
//  Duffy
//
//  Created by Henry Bridge on 5/29/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFSearchBar.h"

@class DFSearchBar;


@interface DFSearchBarController : NSObject <DFSearchBarDelegate, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, retain) DFSearchBar *searchBar;
@property (nonatomic, retain) UITableView *tableView;
@property (nonatomic, weak) UIViewController *parentViewController;
@property (readonly, nonatomic, retain) NSMutableDictionary *suggestionsBySection;

- (void)clearSearchBar;
- (NSDictionary *)suggestionsStrings;

@end
