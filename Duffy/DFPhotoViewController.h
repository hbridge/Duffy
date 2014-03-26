//
//  DFPhotoViewController.h
//  Duffy
//
//  Created by Henry Bridge on 3/25/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFPhotoViewController : UIViewController

@property (strong, nonatomic) UIImage *image;
@property (strong, nonatomic) NSIndexPath *indexPathInParent;

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@end
