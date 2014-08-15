//
//  DFTopBarController.h
//  Strand
//
//  Created by Henry Bridge on 8/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFNavigationBar.h"

@interface DFTopBarController : UIViewController

@property (readonly, nonatomic, retain) DFNavigationBar *navigationBar;
@property (nonatomic, retain) NSArray *viewControllers;

- (instancetype)initWithRootViewController:(UIViewController *)viewController;

- (void)mainScrollViewScrolledToTop:(BOOL)isTop dy:(CGFloat)dy;
- (void)mainScrollViewStoppedScrolling;
- (void)showNavBar;

@end
