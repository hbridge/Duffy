//
//  DFEvaluatedPhotoViewController.h
//  Strand
//
//  Created by Henry Bridge on 12/11/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCommentViewController.h"
#import "DFProfileStackView.h"
#import "DFCommentToolbar.h"

@interface DFPhotoDetailViewController : DFCommentViewController

@property (strong, nonatomic) UIImageView *imageView;
@property (weak, nonatomic) IBOutlet DFProfileStackView *recipientsProfileStackView;
@property (weak, nonatomic) IBOutlet DFProfileStackView *senderProfileStackView;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet DFCommentToolbar *commentToolbar;
@property (weak, nonatomic) UIButton *likeButtonItem;
@property (weak, nonatomic) IBOutlet UIButton *addPersonButton;
@property (nonatomic) NSUInteger nuxStep;

- (instancetype)initWithNuxStep:(NSUInteger)nuxStep;

- (void)likeItemPressed:(id)sender;
- (IBAction)addPersonPressed:(id)sender;



@end
