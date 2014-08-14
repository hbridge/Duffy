//
//  DFBadgeButton.h
//  Strand
//
//  Created by Henry Bridge on 7/24/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFBadgeButton : UIButton

@property (nonatomic, retain) UIColor *badgeColor;
@property (nonatomic, retain) UIColor *badgeTextColor;
@property (nonatomic) int badgeCount;
@property (nonatomic) UIEdgeInsets badgeEdgeInsets;

@end
