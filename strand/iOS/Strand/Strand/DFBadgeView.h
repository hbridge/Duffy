//
//  DFBadgeView.h
//  Strand
//
//  Created by Henry Bridge on 12/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFBadgeView : UIView

@property (nonatomic, retain) NSArray *badgeImages;
@property (nonatomic, retain) NSArray *badgeColors;
@property (nonatomic, retain) NSArray *badgeSizes;
@property (nonatomic) CGFloat horizontalSpacing;

@end
