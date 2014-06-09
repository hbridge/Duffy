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
#import "DFSearchBarControllerDelegate.h"
#import "DFPhotosGridViewController.h"
#import <MessageUI/MFMailComposeViewController.h>


@class DFSuggestionAdapter;

@interface DFSearchViewController : DFPhotosGridViewController <DFSearchBarControllerDelegate, MFMailComposeViewControllerDelegate>

@property (nonatomic, retain) UITableView *searchResultsTableView;
@property (atomic, retain) NSString *currentlyLoadingSearchQuery;
@property (nonatomic, retain) NSArray *searchObjects;

@end
