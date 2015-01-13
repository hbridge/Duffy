//
//  DFEvaluatedPhotoViewController.h
//  Strand
//
//  Created by Henry Bridge on 12/11/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFProfileStackView.h"
#import "DFCommentToolbar.h"
#import "DFPeanutFeedObject.h"
#import "DFRemoteImageView.h"

@interface DFPhotoDetailViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (strong, nonatomic) DFRemoteImageView *imageView;
@property (weak, nonatomic) IBOutlet DFProfileStackView *recipientsProfileStackView;
@property (weak, nonatomic) IBOutlet DFProfileStackView *senderProfileStackView;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet DFCommentToolbar *commentToolbar;
@property (weak, nonatomic) UIButton *likeButtonItem;
@property (weak, nonatomic) IBOutlet UIButton *addPersonButton;
@property (nonatomic) NSUInteger nuxStep;
@property (nonatomic) BOOL compressedModeEnabled;
@property (nonatomic) BOOL commentsExpanded;
@property (nonatomic) BOOL openKeyboardOnAppear;
@property (nonatomic) BOOL closeOnSend;
@property (nonatomic) BOOL disableKeyboardHandler;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *contentBottomConstraint;
@property (nonatomic, retain) DFPeanutFeedObject *photoObject;

- (instancetype)initWithNuxStep:(NSUInteger)nuxStep;

- (void)likeItemPressed:(id)sender;
- (IBAction)addPersonPressed:(id)sender;

- (instancetype)initWithPhotoObject:(DFPeanutFeedObject *)photoObject;

@end
