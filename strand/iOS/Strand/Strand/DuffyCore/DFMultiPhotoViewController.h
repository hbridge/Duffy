//
//  DFMultiPhotoViewController.h
//  Duffy
//
//  Created by Henry Bridge on 3/26/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutFeedObject.h"
#import "DFNavigationController.h"

@class DFPhotoViewController;


@interface DFMultiPhotoViewController : DFNavigationController <UIPageViewControllerDelegate,
UIPageViewControllerDataSource>

@property (nonatomic, retain) UIPageViewController *pageViewController;
@property (nonatomic, retain) DFPeanutFeedObject *activePhoto;
@property (readonly, nonatomic, retain) DFPhotoViewController *currentPhotoViewController;
@property (nonatomic) BOOL theatreModeEnabled;
@property (nonatomic, retain) NSString *navigationTitle;



- (void)setActivePhoto:(DFPeanutFeedObject *)photo inPhotos:(NSArray *)photos;

- (void)setTheatreModeEnabled:(BOOL)theatreModeEnabled animated:(BOOL)animated;
+ (UIColor *)colorForTheatreModeEnabled:(BOOL)theatreModeEnabled;

@end
