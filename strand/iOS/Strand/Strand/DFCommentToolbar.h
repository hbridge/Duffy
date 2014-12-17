//
//  DFCommentToolbar.h
//  Strand
//
//  Created by Henry Bridge on 12/15/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFProfileStackView.h"

@interface DFCommentToolbar : UIView
@property (weak, nonatomic) IBOutlet DFProfileStackView *profileStackView;
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UIButton *likeButton;
@property (nonatomic, retain) UIButton *sendButton;
@property (nonatomic, retain) UIButton *retainedLikeButton;
@property (nonatomic) BOOL likeButtonDisabled;


- (void)textChanged:(UITextField *)sender;
@end
