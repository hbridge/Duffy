//
//  DFSelectableMultiPhotoViewController.h
//  Strand
//
//  Created by Henry Bridge on 11/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFMultiPhotoViewController.h"
#import "DFSelectPhotosController.h"

@interface DFSelectableMultiPhotoViewController : DFMultiPhotoViewController <UIPageViewControllerDelegate>

@property (nonatomic, retain) DFSelectPhotosController *selectPhotosController;

- (instancetype)initWithActivePhoto:(DFPeanutFeedObject *)photo
                  inSection:(NSUInteger)section
   ofSelectPhotosController:(DFSelectPhotosController *)selectPhotosController;

@end
