//
//  DFHeadPickerViewController.m
//  Strand
//
//  Created by Henry Bridge on 2/6/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFHeadPickerViewController.h"
#import "DFPeanutUserObject.h"
#import "UICollectionView+DFExtras.h"

@interface DFHeadPickerViewController ()

@end

@implementation DFHeadPickerViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.titleLabel.text = self.activityTitle;
  self.view.backgroundColor = [UIColor clearColor];
  self.hideSelectedSection = YES;
  [self configureHeadScrollView];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [self scrollHeadsToLast];
}

- (void)configureHeadScrollView
{
  self.profileStackView = [[DFProfileStackView alloc] initWithFrame:self.headScrollView.bounds];
  self.profileStackView.deleteButtonsVisible = YES;
  self.profileStackView.backgroundColor = [UIColor clearColor];
  self.profileStackView.photoMargins = 4.0;
  self.profileStackView.showNames = YES;
  self.profileStackView.nameLabelColor = [UIColor whiteColor];
  self.profileStackView.nameLabelFont = [UIFont fontWithName:@"HelveticaNeue-Thin" size:11.0];
  self.profileStackView.delegate = self;
  [self.headScrollView addSubview:self.profileStackView];

  [self updateHeads];
  [self scrollHeadsToLast];
}

- (void)setActivityTitle:(NSString *)activityTitle
{
  [super setActivityTitle:activityTitle];
  self.titleLabel.text = activityTitle;
}

- (NSArray *)selectedUsers
{
  return [self.selectedContacts arrayByMappingObjectsWithBlock:^id(DFPeanutContact *contact) {
    return [[DFPeanutUserObject alloc] initWithPeanutContact:contact];
  }];
}

- (void)scrollHeadsToLast
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.headScrollView
     scrollRectToVisible:CGRectMake(CGRectGetMaxX(self.profileStackView.frame) + HeadsHorizontalMargin - 1.0,
                                    CGRectGetMidY(self.profileStackView.frame),
                                    1,
                                    1)
     animated:YES];
  });
}

static CGFloat HeadsHorizontalMargin = 10.0;
- (void)updateHeads
{
  NSArray *users = [self selectedUsers];
  DDLogVerbose(@"new selected users: %@", users);
  [self.profileStackView setPeanutUsers:users];
  // we have to reset the frame each time becasuse the stackview calcs its width based on height
  CGRect profileStackFrame = self.headScrollView.bounds;
  profileStackFrame.origin.x = HeadsHorizontalMargin;
  self.profileStackView.frame = profileStackFrame;
  [self.profileStackView sizeToFit];
  
  CGSize contentSize = CGSizeMake(CGRectGetMaxX(self.profileStackView.frame) + HeadsHorizontalMargin,
                                  self.profileStackView.frame.size.height);
  self.headScrollView.contentSize = contentSize;
}

#pragma mark - Collection View Datasource/Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  [super tableView:tableView didSelectRowAtIndexPath:indexPath];
  [self updateHeads];
  [self scrollHeadsToLast];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
  [super tableView:tableView didDeselectRowAtIndexPath:indexPath];
  [self updateHeads];
}


- (void)profileStackView:(DFProfileStackView *)profileStackView
        peanutUserTapped:(DFPeanutUserObject *)peanutUser
{
  DDLogVerbose(@"user tapped: %@", peanutUser);
}

- (void)profileStackView:(DFProfileStackView *)profileStackView
       peanutUserDeleted:(DFPeanutUserObject *)peanutUser
{
  DFPeanutContact *contact = [[DFPeanutContact alloc] initWithPeanutUser:peanutUser];
  self.selectedContacts = [self.selectedContacts arrayByRemovingObject:contact];
  [self updateHeads];
}


@end
