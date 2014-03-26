//
//  DFMultiPhotoViewController.h
//  Duffy
//
//  Created by Henry Bridge on 3/26/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DFPhotoViewController;

@interface DFMultiPhotoViewController : UIPageViewController <UIPageViewControllerDelegate>

@property (readonly, nonatomic, retain) DFPhotoViewController *currentPhotoViewController;

@end
