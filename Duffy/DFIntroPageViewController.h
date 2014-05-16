//
//  DFIntroPageViewController.h
//  Duffy
//
//  Created by Henry Bridge on 5/15/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFIntroPageViewController : UIViewController <UIPageViewControllerDataSource>


- (void)showNextStep:(UIViewController *)currentViewController;

@end
