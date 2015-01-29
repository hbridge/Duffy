//
//  DFMutliPhotoDetailPageController.h
//  Strand
//
//  Created by Henry Bridge on 12/19/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutFeedObject.h"

@interface DFMultiPhotoDetailPageController : UIPageViewController <UIPageViewControllerDataSource>

@property (nonatomic, retain) NSArray *photos;

- (instancetype)initWithCurrentPhoto:(DFPeanutFeedObject *)photo inPhotos:(NSArray *)photos;

@end
