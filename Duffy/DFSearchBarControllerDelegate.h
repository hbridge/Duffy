//
//  DFSearchBarControllerDelegate.h
//  Duffy
//
//  Created by Henry Bridge on 5/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DFSearchBarController;

@protocol DFSearchBarControllerDelegate <NSObject>


- (void)searchBarController:(DFSearchBarController *)searchBarController
    searchExecutedWithQuery:(NSString *)query;
- (void)searchBarControllerSearchCancelled:(DFSearchBarController *)searchBarController;
- (void)searchBarControllerSearchBegan:(DFSearchBarController *)searchBarController;
- (void)searchBarControllerSearchCleared:(DFSearchBarController *)searchBarController;

@end
