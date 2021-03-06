//
//  DFProfileStackView.h
//  Strand
//
//  Created by Henry Bridge on 11/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MMPopLabel/MMPopLabel.h>
#import "DFUserListViewController.h"

@class DFPeanutUserObject;
@class DFProfileStackView;

@protocol DFProfileStackViewDelegate <NSObject>

- (void)profileStackView:(DFProfileStackView *)profileStackView
        peanutUserTapped:(DFPeanutUserObject *)peanutUser;
@optional
- (void)profileStackView:(DFProfileStackView *)profileStackView
       peanutUserDeleted:(DFPeanutUserObject *)peanutUser;

@end

@interface DFProfileStackView : UIView <MMPopLabelDelegate, DFPeoplePickerDelegate>

@property (nonatomic) NSUInteger maxProfilePhotos;
@property (nonatomic, retain) NSArray *peanutUsers;
@property (nonatomic) BOOL showNames;
@property (nonatomic) NSUInteger maxAbbreviationLength;
@property (nonatomic, retain) UIFont *nameLabelFont;
@property (nonatomic, retain) UIColor *nameLabelColor;
@property (nonatomic) CGFloat photoMargins;
@property (nonatomic) CGFloat nameLabelVerticalMargin;
@property (nonatomic, weak) id<DFProfileStackViewDelegate> delegate;
@property (nonatomic) BOOL deleteButtonsVisible;

- (void)setPeanutUser:(DFPeanutUserObject *)user;
- (void)setColor:(UIColor *)color forUser:(DFPeanutUserObject *)user;
- (void)setBadgeImage:(UIImage *)badgeImage forUser:(DFPeanutUserObject *)user;

@end
