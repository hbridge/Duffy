//
//  DFSearchDisplayController.h
//  Duffy
//
//  Created by Henry Bridge on 4/2/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DFSearchViewController;

@interface DFSearchDisplayController : UISearchDisplayController <UISearchBarDelegate,
    UISearchDisplayDelegate, UITableViewDataSource, UITableViewDelegate>


@property (readonly, nonatomic, weak) DFSearchViewController *searchViewController;

@end
