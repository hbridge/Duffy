//
//  DFSwipableSuggestionViewController.m
//  Strand
//
//  Created by Henry Bridge on 12/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSwipableSuggestionViewController.h"
#import "DFNavigationController.h"
#import <MMPopLabel/MMPopLabel.h>

@interface DFSwipableSuggestionViewController ()

@property (nonatomic, retain) MMPopLabel *selectPeoplePopLabel;

@end



@implementation DFSwipableSuggestionViewController

- (instancetype)initWithNuxStep:(NSUInteger)step
{
  self = [super init];
  if (self) {
    self.nuxStep = step;
  }
  return self;
}

- (void)viewDidLoad {
  self.imageView = self.cardinalImageView.imageView;

  // Need to set the imageView first since the parent needs it
  [super viewDidLoad];
  
  [self configurePopLabel];
  
  self.cardinalImageView.delegate = self;
  
  if (self.nuxStep == 0) {
    if (self.suggestionFeedObject.actors.count > 0) {
      self.profileStackView.peanutUsers = self.suggestionFeedObject.actors;
    } else {
      DFPeanutUserObject *dummyUser = [[DFPeanutUserObject alloc] init];
      dummyUser.display_name = @"?";
      dummyUser.phone_number = @"?";
      self.profileStackView.peanutUsers = @[dummyUser];
    }
    self.selectedPeanutContacts = [self suggestedPeanutContacts];
  } else {
    self.addRecipientButton.hidden = YES;
    
    self.profileStackView.maxAbbreviationLength = 2;
    DFPeanutUserObject *teamSwapUser = [[DFPeanutUserObject alloc] init];
    teamSwapUser.display_name = @"TS";
    teamSwapUser.phone_number = @"TS";
    [self.profileStackView setPeanutUser:teamSwapUser];
    [self.profileStackView setColor:[DFStrandConstants defaultBackgroundColor]
                            forUser:teamSwapUser];
    UIImage *nuxImage;
    if (self.nuxStep == 1) {
      nuxImage = [UIImage imageNamed:@"Assets/Nux/NuxSendImage"];
      self.cardinalImageView.noEnabled = NO;
    } else {
      nuxImage = [UIImage imageNamed:@"Assets/Nux/NuxSkipImage"];
      self.cardinalImageView.yesEnabled = NO;
    }
    self.imageView.image = nuxImage;
    
  }
  
  [self configurePeopleLabel];
  self.profileStackView.profilePhotoWidth = 50.0;
  self.profileStackView.shouldShowNameLabel = YES;
  self.profileStackView.backgroundColor = [UIColor clearColor];
}

- (void)configurePopLabel
{
  self.selectPeoplePopLabel = [MMPopLabel popLabelWithText:@"Select people first"];
  [self.view addSubview:self.selectPeoplePopLabel];
}

- (void)configurePeopleLabel
{
  if (self.nuxStep == 0) {
    if (self.selectedPeanutContacts.count > 0) {
      NSArray *contactNames = [self.selectedPeanutContacts arrayByMappingObjectsWithBlock:^id(DFPeanutContact *contact) {
        return [contact firstName];
      }];
      NSString *commaList = [contactNames componentsJoinedByString:@", "];
      self.peopleLabel.text = [NSString stringWithFormat:@"Send to %@",commaList];
    } else {
      self.peopleLabel.text = @"Pick Recipients";
    }
  } else {
    self.peopleLabel.text = @"Send to Team Swap";
  }
  [self.peopleLabel invalidateIntrinsicContentSize];
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
  if (button == self.cardinalImageView.yesButton && self.yesButtonHandler) {
    if (self.selectedPeanutContacts.count > 0 || self.nuxStep > 0) {
      self.yesButtonHandler(self.suggestionFeedObject, self.selectedPeanutContacts);
    } else {
      [self.selectPeoplePopLabel popAtView:self.addRecipientButton animatePopLabel:YES animateTargetView:YES];
      [self.cardinalImageView resetView];
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.selectPeoplePopLabel dismiss];
      });
    }
  }
  else if (button == self.cardinalImageView.noButton && self.noButtonHandler)
    self.noButtonHandler(self.suggestionFeedObject);
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
  [self configurePeopleLabel];
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
