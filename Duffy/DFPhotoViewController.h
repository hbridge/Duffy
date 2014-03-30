//
//  DFPhotoViewController.h
//  Duffy
//
//  Created by Henry Bridge on 3/25/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFImageView.h"

@class DFPhoto;

@interface DFPhotoViewController : UIViewController

@property (strong, nonatomic) DFPhoto *photo;
@property (strong, nonatomic) NSIndexPath *indexPathInParent;

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet DFImageView *imageView;

@end
