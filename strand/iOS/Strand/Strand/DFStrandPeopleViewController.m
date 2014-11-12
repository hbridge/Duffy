//
//  DFStrandPeopleViewController.m
//  Strand
//
//  Created by Henry Bridge on 11/4/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFStrandPeopleViewController.h"
#import "DFPersonSelectionTableViewCell.h"
#import "DFPeanutUserObject.h"
#import "DFActionButton.h"
#import "DFActionButtonTableViewCell.h"
#import "DFInviteStrandViewController.h"
#import "DFNavigationController.h"

@interface DFStrandPeopleViewController ()

@property (nonatomic, retain) DFInviteStrandViewController *inviteViewController;

@end

@implementation DFStrandPeopleViewController

- (instancetype)initWithStrandPostsObject:(DFPeanutFeedObject *)strandPostsObject
{
  self = [self init];
  if (self) {
    _strandPostsObject = strandPostsObject;
  }
  
  return self;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    [self configureNav];
  }
  return self;
}

- (void)configureNav
{
  self.navigationItem.title = @"Members";
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                            initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                            target:self
                                            action:@selector(addMembersPressed:)];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  [self configureTableView];
}

- (void)viewWillAppear:(BOOL)animated
{
  if (self.inviteViewController) {
    [self addSelectedContactsFromInviteController];
  }
}

- (void)addSelectedContactsFromInviteController
{
  NSMutableArray *newUsers = [NSMutableArray new];
  for (DFPeanutContact *contact in self.inviteViewController.selectedPeanutContacts) {
    DFPeanutUserObject *user = [[DFPeanutUserObject alloc] init];
    user.display_name = contact.name;
    user.phone_number = contact.phone_number;
    [newUsers addObject:user];
  }
  self.strandPostsObject.actors = [self.strandPostsObject.actors arrayByAddingObjectsFromArray:newUsers];
  [self.tableView reloadData];

}

- (void)configureTableView
{
  self.tableView.delegate = self;
  self.tableView.dataSource = self;
  [self.tableView registerNib:[UINib nibForClass:[DFPersonSelectionTableViewCell class]]
       forCellReuseIdentifier:@"user"];
  [self.tableView registerNib:[UINib nibForClass:[DFPersonSelectionTableViewCell class]]
       forCellReuseIdentifier:@"nonuser"];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return self.strandPostsObject.actors.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutUserObject *user = self.strandPostsObject.actors[indexPath.row];
  UITableViewCell *cell;
  if (user.id) {
    cell = [self cellForUser:user];
  } else {
    cell = [self cellForNonUser:user];
  }
  
  cell.selectionStyle = UITableViewCellSelectionStyleNone;
  
  return cell;
}

- (DFPersonSelectionTableViewCell *)cellForUser:(DFPeanutUserObject *)user
{
  DFPersonSelectionTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"user"];
  [cell configureWithCellStyle:DFPersonSelectionTableViewCellStyleStrandUser
   | DFPersonSelectionTableViewCellStyleRightLabel];
  
  cell.nameLabel.text = [user fullName];
  cell.profilePhotoStackView.names = @[[user fullName]];
  cell.rightLabel.text = user.invited.boolValue ? @"Swap Requested" : @"Joined";
  
  return cell;
}

- (DFPersonSelectionTableViewCell *)cellForNonUser:(DFPeanutUserObject *)user
{
  DFPersonSelectionTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"user"];
  [cell configureWithCellStyle: DFPersonSelectionTableViewCellStyleRightLabel | DFPersonSelectionTableViewCellStyleSubtitle];
  
  cell.nameLabel.text = [user fullName];
  cell.subtitleLabel.text = user.phone_number;
  cell.rightLabel.text = @"Swap Requested";
  
  return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  return @"Joined and Requested";
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
  DFActionButtonTableViewCell *cell = [UINib instantiateViewWithClass:[DFActionButtonTableViewCell class]];
  cell.contentView.backgroundColor = [UIColor whiteColor];
  [cell.actionButton setTitle:@"Add Members" forState:UIControlStateNormal];
  cell.actionButton.userInteractionEnabled = YES;
  
  [cell.actionButton addTarget:self action:@selector(addMembersPressed:)
              forControlEvents:UIControlEventTouchUpInside];

  return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
  return 64;
}


- (void)addMembersPressed:(id)sender
{
  NSArray *contactsArray = [self.strandPostsObject.actors arrayByMappingObjectsWithBlock:^id(DFPeanutUserObject *user) {
    return [[DFPeanutContact alloc] initWithPeanutUser:user];
  }];
  self.inviteViewController = [[DFInviteStrandViewController alloc]
                                      initWithSuggestedPeanutContacts:nil
                                      notSelectablePeanutContacts:contactsArray
                                      notSelectableReason:@"Already Member"];
  self.inviteViewController.sectionObject = self.strandPostsObject;
  self.inviteViewController.navigationItem.title = @"Add Members";
  [self presentViewController:[[DFNavigationController alloc]
                               initWithRootViewController:self.inviteViewController]
                     animated:YES
                   completion:nil];
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  // prevent selecting anything in the table view
  return nil;
}


@end
