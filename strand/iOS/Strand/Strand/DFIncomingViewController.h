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

typedef void (^DFIncomingPhotoNextBlock)(DFPhotoIDType photoID, DFStrandIDType strandID);
typedef void (^DFIncomingPhotoCommentBlock)(DFPhotoIDType photoID, DFStrandIDType strandID);
typedef void (^DFIncomingPhotoLikeBlock)(DFPhotoIDType photoID, DFStrandIDType strandID);

@property (nonatomic) DFPhotoIDType photoID;
@property (nonatomic) DFStrandIDType strandID;
@property (nonatomic, retain) DFPeanutUserObject *sender;
@property (nonatomic, copy) DFIncomingPhotoNextBlock nextHandler;
@property (nonatomic, copy) DFIncomingPhotoCommentBlock commentHandler;
@property (nonatomic, copy) DFIncomingPhotoLikeBlock likeHandler;
@property (nonatomic, retain) DFPhotoDetailViewController *photoDetailViewController;

@property (nonatomic, retain) UIImageView *imageView;

- (instancetype)initWithPhotoID:(DFPhotoIDType)photoID
                       inStrand:(DFStrandIDType)strandID
                     fromSender:(DFPeanutUserObject *)peanutUser;

- (instancetype)initWithNuxStep:(NSUInteger)nuxStep;

@end
