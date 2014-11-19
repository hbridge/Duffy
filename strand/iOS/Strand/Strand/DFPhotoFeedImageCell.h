//
//  DFPhotoFeedImageCellTableViewCell.h
//  Strand
//
//  Created by Henry Bridge on 11/18/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFPhotoFeedImageCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *photoImageView;
@property (nonatomic, copy) void (^doubleTapBlock)(void);
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomPaddingConstraint;

typedef NS_ENUM(NSInteger, DFPhotoFeedImageCellAspect) {
  DFPhotoFeedImageCellAspectSquare,
  DFPhotoFeedImageCellAspectPortrait,
  DFPhotoFeedImageCellAspectLandscape,
};

+ (CGFloat)imageViewHeightForReferenceWidth:(CGFloat)referenceWidth
                                     aspect:(DFPhotoFeedImageCellAspect)aspect;

@end
