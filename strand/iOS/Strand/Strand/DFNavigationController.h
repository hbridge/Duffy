//
//  DFNavigationController.h
//  Strand
//
//  Created by Henry Bridge on 7/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFNavigationController : UINavigationController

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController
                        animateInStatusBar:(BOOL)animateInStatusBar;
- (void)animateInStatusBar;
@end
