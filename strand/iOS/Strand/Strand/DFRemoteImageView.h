//
//  DFRemoteImageView.h
//  Strand
//
//  Created by Henry Bridge on 1/12/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFImageManager.h"

@interface DFRemoteImageView : UIImageView

@property (nonatomic, retain) UIActivityIndicatorView *activityView;
@property (nonatomic) DFPhotoIDType photoID;
@property (nonatomic) DFImageRequestDeliveryMode deliveryMode;
@property (nonatomic, retain) UILabel *errorLabel;
@property (nonatomic, retain) UIButton *reloadButton;

- (void)loadImageWithID:(DFPhotoIDType)photoID deliveryMode:(DFImageRequestDeliveryMode)deliveryMode;

@end
