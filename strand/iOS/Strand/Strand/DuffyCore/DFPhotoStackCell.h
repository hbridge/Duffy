//
//  DFPhotoStackCell.h
//  Duffy
//
//  Created by Henry Bridge on 6/3/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFCircleBadge.h"

@interface DFPhotoStackCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet DFCircleBadge *badgeView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *loadingActivityIndicator;
@property (nonatomic) NSUInteger count;


@end
