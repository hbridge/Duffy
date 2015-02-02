//
//  DFNoIncomingViewController.h
//  Strand
//
//  Created by Derek Parham on 12/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCardViewController.h"
#import "DFUpsellContentView.h"
#import "DFPeanutFeedObject.h"


@interface DFUpsellCardViewController : DFCardViewController

typedef NS_ENUM(NSInteger, DFUpsellCardViewType) {
  DFUpsellCardViewGotoSuggestions,
  DFUpsellCardViewBackgroundLocation,
};

@property (nonatomic) DFUpsellCardViewType upsellType;
@property (nonatomic, weak) IBOutlet DFUpsellContentView *upsellContentView;
@property (nonatomic, copy) DFVoidBlock yesButtonHandler;
@property (nonatomic, copy) DFVoidBlock noButtonHandler;

@property (weak, nonatomic) IBOutlet UIButton *noButton;
@property (weak, nonatomic) IBOutlet UIButton *yesButton;

- (instancetype)initWithType:(DFUpsellCardViewType)upsellType;

@end
