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

@property (nonatomic) NSUInteger maxProfilePhotos;
@property (nonatomic) CGFloat profilePhotoWidth;
@property (nonatomic, retain) NSArray *peanutUsers;
@property (nonatomic) BOOL shouldShowNameLabel;

- (void)setPeanutUser:(DFPeanutUserObject *)user;

@end
