//
//  DFNoIncomingViewController.h
//  Strand
//
//  Created by Derek Parham on 12/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFSwipableButtonView.h"
#import "DFUpsellContentView.h"


@interface DFUpsellCardViewController : UIViewController <DFSwipableButtonViewDelegate>

typedef NS_ENUM(NSInteger, DFUpsellCardViewType) {
  DFUpsellCardViewGotoSuggestions,
  DFUpsellCardViewBackgroundLocation,
};

@property (nonatomic) DFUpsellCardViewType upsellType;
@property (nonatomic, retain) DFUpsellContentView *upsellContentView;
@property (nonatomic, copy) DFVoidBlock yesButtonHandler;
@property (nonatomic, copy) DFVoidBlock noButtonHandler;

@property (weak, nonatomic) IBOutlet DFSwipableButtonView *swipableButtonView;

- (instancetype)initWithType:(DFUpsellCardViewType)upsellType;

@end
