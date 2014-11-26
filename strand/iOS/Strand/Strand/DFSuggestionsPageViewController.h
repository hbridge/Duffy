//
//  DFSuggestionsPageViewController.h
//  Strand
//
//  Created by Henry Bridge on 11/25/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutUserObject.h"
#import "DFPeoplePickerViewController.h"
#import <MessageUI/MessageUI.h>


@interface DFSuggestionsPageViewController : UIPageViewController
<UIPageViewControllerDataSource, UIPageViewControllerDelegate>

@property (nonatomic, retain) DFPeanutUserObject *userToFilter;


@end
