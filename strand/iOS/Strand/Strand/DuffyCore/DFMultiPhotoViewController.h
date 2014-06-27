//
//  DFMultiPhotoViewController.h
//  Duffy
//
//  Created by Henry Bridge on 3/26/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DFPhotoViewController;
@class DFPhoto;

@interface DFMultiPhotoViewController : UIPageViewController <UIPageViewControllerDelegate,
UIPageViewControllerDataSource>

@property (readonly, nonatomic, retain) DFPhotoViewController *currentPhotoViewController;
@property (nonatomic) BOOL theatreModeEnabled;


- (void)setActivePhoto:(DFPhoto *)photo inPhotos:(NSArray *)photos;
- (void)activePhotoDeleted;

- (void)setTheatreModeEnabled:(BOOL)theatreModeEnabled animated:(BOOL)animated;

@end
