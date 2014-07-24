//
//  RootViewController.h
//  Strand
//
//  Created by Henry Bridge on 6/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RootViewController : UIViewController <UIPageViewControllerDelegate, UIPageViewControllerDataSource>

@property (strong, nonatomic) UIPageViewController *pageViewController;
@property (nonatomic) BOOL hideStatusBar;

- (void)showGallery;
- (void)showCamera;
- (void)showPhotoWithID:(DFPhotoIDType)photoID;

- (void)setSwipingEnabled:(BOOL)isSwipingEnabled;

@end

