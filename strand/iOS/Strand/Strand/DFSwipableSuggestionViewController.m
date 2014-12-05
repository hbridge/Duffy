//
//  DFSwipableSuggestionViewController.m
//  Strand
//
//  Created by Henry Bridge on 12/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSwipableSuggestionViewController.h"
#import "DFNavigationController.h"

@interface DFSwipableSuggestionViewController ()

@property (nonatomic, retain) NSArray *selectedPeanutContacts;

@end



@implementation DFSwipableSuggestionViewController

- (void)viewDidLoad {
  self.imageView = self.cardinalImageView.imageView;
  
  // Need to set the imageView first since the parent needs it
  [super viewDidLoad];
  
  self.cardinalImageView.delegate = self;

  //self.profileStackView.backgroundColor = [UIColor clearColor];
  self.profileStackView.peanutUsers = self.suggestionFeedObject.actors;
  self.profileStackView.profilePhotoWidth = 50.0;
  self.profileStackView.shouldShowNameLabel = YES;
  self.profileStackView.backgroundColor = [UIColor clearColor];
  self.selectedPeanutContacts = [self suggestedPeanutContacts];
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)viewDidDisappear:(BOOL)animated
{
  [self.cardinalImageView resetView];
}

- (void)cardinalImageView:(DFCardinalImageView *)cardinalImageView
        buttonSelected:(UIButton *)button
{
  if (button == self.cardinalImageView.yesButton && self.yesButtonHandler) self.yesButtonHandler();
  else if (button == self.cardinalImageView.noButton && self.noButtonHandler) self.noButtonHandler();
}

- (IBAction)addPersonButtonPressed:(id)sender {
  DFPeoplePickerViewController *peoplePickerController = [[DFPeoplePickerViewController alloc]
                                                          initWithSelectedPeanutContacts:[self selectedPeanutContacts]];
  
  peoplePickerController.allowsMultipleSelection = YES;
  peoplePickerController.delegate = self;
  [DFNavigationController presentWithRootController:peoplePickerController inParent:self];
}

- (void)pickerController:(DFPeoplePickerViewController *)pickerController
didFinishWithPickedContacts:(NSArray *)peanutContacts
{
  self.selectedPeanutContacts = peanutContacts;
  [self.profileStackView setPeanutUsers:[self selectedPeanutUsers]];
  [self.view setNeedsLayout];
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSArray *)suggestedPeanutContacts
{
  return [self.suggestionFeedObject.actors arrayByMappingObjectsWithBlock:^id(id input) {
    return [[DFPeanutContact alloc] initWithPeanutUser:input];
  }];
}

- (NSArray *)selectedPeanutUsers
{
  NSMutableArray *result = [NSMutableArray new];
  for (DFPeanutContact *contact in self.selectedPeanutContacts) {
    DFPeanutUserObject *user = [[DFPeanutUserObject alloc] init];
    user.phone_number = contact.phone_number;
    user.display_name = contact.name;
    [result addObject:user];
  }
  return result;
}
                                                          

@end
