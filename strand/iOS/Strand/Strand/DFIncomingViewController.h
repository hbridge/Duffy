//
//  DFIncomingViewController.h
//  Strand
//
//  Created by Henry Bridge on 12/8/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFProfileWithContextView.h"
#import "DFSwipableButtonView.h"
#import "DFPeanutUserObject.h"
#import "DFHomeSubViewController.h"
#import "DFPhotoDetailViewController.h"

@interface DFIncomingViewController : DFHomeSubViewController <DFSwipableButtonViewDelegate>

@property (weak, nonatomic) IBOutlet DFProfileWithContextView *profileWithContextView;
@property (weak, nonatomic) IBOutlet DFSwipableButtonView *swipableButtonView;

typedef void (^DFIncomingPhotoActionHandler)(DFPhotoIDType photoID, DFShareInstanceIDType shareInstanceID);

@property (nonatomic) DFPhotoIDType photoID;
@property (nonatomic) DFShareInstanceIDType shareInstance;
@property (nonatomic, retain) DFPeanutUserObject *sender;
@property (nonatomic, copy) DFIncomingPhotoActionHandler nextHandler;
@property (nonatomic, copy) DFIncomingPhotoActionHandler commentHandler;
@property (nonatomic, copy) DFIncomingPhotoActionHandler likeHandler;
@property (nonatomic, retain) DFPhotoDetailViewController *photoDetailViewController;

@property (nonatomic, retain) UIImageView *imageView;

- (instancetype)initWithPhotoID:(DFPhotoIDType)photoID
                  shareInstance:(DFShareInstanceIDType)shareInstance
                     fromSender:(DFPeanutUserObject *)peanutUser;

- (instancetype)initWithNuxStep:(NSUInteger)nuxStep;

@end
