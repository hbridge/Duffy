//
//  DFPhotoNavigationControllerViewController.h
//  Duffy
//
//  Created by Henry Bridge on 3/26/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DFPhotoViewController, DFMultiPhotoViewController, DFPhotosGridViewController;

@interface DFPhotoNavigationControllerViewController : UINavigationController

- (void)pushMultiPhotoViewController:(DFMultiPhotoViewController *)multiPhotoViewController
        withFrontPhotoViewController:(DFPhotoViewController *)photoViewController
            fromPhotosGridController:(DFPhotosGridViewController *)photosGridController
                     itemAtIndexPath:(NSIndexPath *)indexPath;

@end
