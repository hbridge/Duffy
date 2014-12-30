//
//  DFNoIncomingViewController.h
//  Strand
//
//  Created by Derek Parham on 12/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFSwipableButtonView.h"

@interface DFUpsellCardViewController : UIViewController <DFSwipableButtonViewDelegate>

typedef void(^DFNoIncomingYesHandler)(void);
typedef void(^DFNoIncomingNoHandler)(void);

@property (nonatomic, copy) DFNoIncomingYesHandler yesButtonHandler;
@property (nonatomic, copy) DFNoIncomingNoHandler noButtonHandler;

@property (weak, nonatomic) IBOutlet DFSwipableButtonView *swipableButtonView;

@end
