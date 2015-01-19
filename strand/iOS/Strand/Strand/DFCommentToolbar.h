//
//  DFCommentToolbar.h
//  Strand
//
//  Created by Henry Bridge on 12/15/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFProfileStackView.h"

@interface DFCommentToolbar : UIView <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UIButton *likeButton;
@property (weak, nonatomic) IBOutlet UIButton *commentButton;
@property (weak, nonatomic) IBOutlet UIButton *moreButton;
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UIButton *sendButton;

- (void)textChanged:(UITextField *)sender;

- (void)setLikeBarButtonItemOn:(BOOL)on;
- (void)setCommentFieldHidden:(BOOL)commentFieldHidden;

- (IBAction)likeButtonPressed:(id)sender;
- (IBAction)commentButtonPressed:(id)sender;
- (IBAction)sendButtonPressed:(id)sender;
- (IBAction)moreButtonPressed:(id)sender;

typedef void (^DFCommentToolbarSendBlock)(NSString *text);
@property (nonatomic, copy) DFCommentToolbarSendBlock sendBlock;
@property (nonatomic, copy) DFVoidBlock likeHandler;
@property (nonatomic, copy) DFVoidBlock moreHandler;


@end
