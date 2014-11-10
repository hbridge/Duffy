//
//  DFCommentViewController.h
//  Strand
//
//  Created by Henry Bridge on 11/10/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutFeedObject.h"

@interface DFCommentViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (nonatomic, retain) DFPeanutFeedObject *photoObject;


- (instancetype)initWithPhotoObject:(DFPeanutFeedObject *)photoObject;
- (IBAction)sendButtonPressed:(id)sender;
- (IBAction)textDidChange:(UITextField *)sender;




@end
