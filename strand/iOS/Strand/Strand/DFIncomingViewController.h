//
//  DFIncomingViewController.h
//  Strand
//
//  Created by Henry Bridge on 12/8/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFProfileWithContextView.h"
#import "DFSwipableButtonImageView.h"
#import "DFPeanutUserObject.h"

@interface DFIncomingViewController : UIViewController

@property (weak, nonatomic) IBOutlet DFProfileWithContextView *profileWithContextView;
@property (weak, nonatomic) IBOutlet DFSwipableButtonImageView *swipableButtonImageView;



@property (nonatomic) DFPhotoIDType photoID;
@property (nonatomic) DFStrandIDType strandID;
@property (nonatomic, retain) DFPeanutUserObject *sender;

- (instancetype)initWithPhotoID:(DFPhotoIDType)photoID
                       inStrand:(DFStrandIDType)strandID
                     fromSender:(DFPeanutUserObject *)peanutUser;

@end
