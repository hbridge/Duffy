//
//  DFPhotoViewCell.h
//  Duffy
//
//  Created by Henry Bridge on 1/29/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <LKbadgeView/LKBadgeView.h>
#import "DFBadgeView.h"

@interface DFPhotoViewCell : UICollectionViewCell

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *loadingActivityIndicator;
@property (weak, nonatomic) IBOutlet DFBadgeView *badgeView;
@property (weak, nonatomic) IBOutlet LKBadgeView *countBadgeView;

- (void)setNumLikes:(NSUInteger)numLikes
        numComments:(NSUInteger)numComments
     numUnreadLikes:(NSUInteger)numUnreadLikes
  numUnreadComments:(NSUInteger)numUnreadComments;

@end
