//
//  DFSuggestionsPageViewController.h
//  Strand
//
//  Created by Henry Bridge on 11/25/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutUserObject.h"
#import "DFCreateStrandFlowViewController.h"
#import "DFCardViewController.h"



@interface DFCardsPageViewController : UIPageViewController <UIPageViewControllerDataSource, UIPageViewControllerDelegate>

@property (nonatomic, retain) DFPeanutUserObject *userToFilter;
@property (nonatomic) DFHomeSubViewType preferredType;
@property (nonatomic) DFPeanutFeedObject *startingPhoto;

- (instancetype)initWithPreferredType:(DFHomeSubViewType)preferredType;
- (instancetype)initWithPreferredType:(DFHomeSubViewType)preferredType
                        startingPhoto:(DFPeanutFeedObject *)startingPhoto;

@end
