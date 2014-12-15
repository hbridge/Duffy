//
//  DFEvaluatedPhotoViewController.h
//  Strand
//
//  Created by Henry Bridge on 12/11/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCommentViewController.h"
#import "DFProfileStackView.h"

@interface DFEvaluatedPhotoViewController : DFCommentViewController

@property (strong, nonatomic) UIImageView *imageView;
@property (weak, nonatomic) IBOutlet DFProfileStackView *recipientsProfileStackView;
@property (weak, nonatomic) IBOutlet DFProfileStackView *senderProfileStackView;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *likeBarButtonItem;
- (IBAction)likeItemPressed:(id)sender;
- (IBAction)addPersonPressed:(id)sender;

@end