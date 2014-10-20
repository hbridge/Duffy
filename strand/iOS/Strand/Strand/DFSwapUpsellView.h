//
//  DFSwapUpsellView.h
//  Strand
//
//  Created by Henry Bridge on 10/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SAMGradientView.h"

@interface DFSwapUpsellView : SAMGradientView

@property (weak, nonatomic) IBOutlet UILabel *sharedPhotosCountLabel;
@property (weak, nonatomic) IBOutlet UIButton *matchMyPhotosButton;
@property (weak, nonatomic) IBOutlet UILabel *upsellTitleLabel;
@property (weak, nonatomic) IBOutlet UIView *activityWrapper;

- (void)configureWithSwappablePhotos:(BOOL)arePhotosSwappable
                        buttonTarget:(id)target
                            selector:(SEL)selector;

- (void)configureForContactsWithError:(BOOL)error
                         buttonTarget:(id)target
                             selector:(SEL)selector;

- (void)configureActivityWithVisibility:(BOOL)visible;
- (BOOL)isMatchingActivityOn;


@end
