//
//  DFProfileStackView.h
//  Strand
//
//  Created by Henry Bridge on 11/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MMPopLabel/MMPopLabel.h>

@class DFPeanutUserObject;

@interface DFProfileStackView : UIView <MMPopLabelDelegate>

typedef NS_ENUM(NSInteger, DFProfileStackViewNameMode) {
  DFProfileStackViewNameModeNone = 0,
  DFProfileStackViewNameShowOnTap,
  DFProfileStackViewNameShowAlways,
};

@property (nonatomic) NSUInteger maxProfilePhotos;
@property (nonatomic) CGFloat profilePhotoWidth;
@property (nonatomic, retain) NSArray *peanutUsers;
@property (nonatomic) DFProfileStackViewNameMode nameMode;
@property (nonatomic) NSUInteger maxAbbreviationLength;
@property (nonatomic, retain) UIFont *nameLabelFont;

- (void)setPeanutUser:(DFPeanutUserObject *)user;
- (void)setColor:(UIColor *)color forUser:(DFPeanutUserObject *)user;

@end
