//
//  DFKeyboardResizingViewController.m
//  Duffy
//
//  Created by Henry Bridge on 4/5/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFKeyboardResizingViewController.h"

@interface DFKeyboardResizingViewController ()

@end

@implementation DFKeyboardResizingViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(DFKeyoardResizingKeyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(DFKeyoardResizingKeyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardDidShowNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardDidHideNotification
                                                  object:nil];
}


- (void)DFKeyoardResizingKeyboardDidShow:(NSNotification *)notification {
    CGRect toRect = [(NSValue *)notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    self.view.frame = CGRectMake(self.view.frame.origin.x,
                                 self.view.frame.origin.x,
                                 self.view.frame.size.width,
                                 toRect.origin.y);
}

- (void)DFKeyoardResizingKeyboardWillHide:(NSNotification *)notification {
    CGRect toRect = [(NSValue *)notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    self.view.frame = CGRectMake(self.view.frame.origin.x,
                                 self.view.frame.origin.x,
                                 self.view.frame.size.width,
                                 toRect.origin.y);
}




@end
