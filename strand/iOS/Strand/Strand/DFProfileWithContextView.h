//
//  DFProfileWithContextView.h
//  Strand
//
//  Created by Henry Bridge on 11/24/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFProfileStackView.h"

IB_DESIGNABLE
@interface DFProfileWithContextView : UIView
@property (weak, nonatomic) IBOutlet DFProfileStackView *profileStackView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *subtitleLabel;

@property (nonatomic, retain) IBInspectable NSString *title;
@property (nonatomic, retain) IBInspectable NSString *subTitle;

@end
