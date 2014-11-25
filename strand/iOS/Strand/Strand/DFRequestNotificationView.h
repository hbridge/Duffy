//
//  DFRequestNotificationView.h
//  Strand
//
//  Created by Henry Bridge on 11/24/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GBFlatButton/GBFlatButton.h>
#import "DFProfileWithContextView.h"

@interface DFRequestNotificationView : UIView
@property (weak, nonatomic) IBOutlet DFProfileWithContextView *profileWithContextView;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet GBFlatButton *selectPhotosButton;


@end
