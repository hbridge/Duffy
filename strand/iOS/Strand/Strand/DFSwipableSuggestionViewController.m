//
//  DFSwipableSuggestionViewController.m
//  Strand
//
//  Created by Henry Bridge on 12/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSwipableSuggestionViewController.h"
#import "DFNavigationController.h"
#import "DFImageManager.h"
#import <MMPopLabel/MMPopLabel.h>

@interface DFSwipableSuggestionViewController ()

@property (nonatomic, retain) MMPopLabel *selectPeoplePopLabel;

@end



@implementation DFSwipableSuggestionViewController

@synthesize suggestionFeedObject = _suggestionFeedObject;

- (instancetype)initWithNuxStep:(NSUInteger)step
{
  self = [super init];
  if (self) {
    self.nuxStep = step;
  }
  return self;
}

- (void)viewDidLayoutSubviews
{
  if (self.nuxStep == 0) {
    [[DFImageManager sharedManager] imageForID:self.photoFeedObject.id
                                     pointSize:self.swipableButtonView.centerView.frame.size
                                   contentMode:DFImageRequestContentModeAspectFill
                                  deliveryMode:DFImageRequestOptionsDeliveryModeOpportunistic completion:^(UIImage *image) {
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                      self.swipableButtonView.imageView.image = image;
                                    });
                                  }];
  }
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  if (self.suggestionFeedObject)
    [self configureWithSuggestion:self.suggestionFeedObject withPhoto:self.photoFeedObject];
  
  [self configurePopLabel];
  [self configureSwipableButtonView];
  
  [self.swipableButtonView configureToUseImage];

  if (self.nuxStep > 0) {
    [self configureNuxStep:self.nuxStep];
  }
  
  [self configurePeopleLabel];
  
  self.profileStackView.nameMode = DFProfileStackViewNameShowOnTap;
  self.profileStackView.backgroundColor = [UIColor clearColor];
}

- (void)configureNuxStep:(NSUInteger)nuxStep
{
  self.addRecipientButton.hidden = YES;
  self.profileStackView.maxAbbreviationLength = 2;
  [self.profileStackView setPeanutUser:[DFPeanutUserObject TeamSwapUser]];
  
  UIImage *nuxImage;
  if (self.nuxStep == 1) {
    nuxImage = [UIImage imageNamed:@"Assets/Nux/NuxSendImage"];
    self.swipableButtonView.noEnabled = NO;
  } else {
    nuxImage = [UIImage imageNamed:@"Assets/Nux/NuxSkipImage"];
    self.swipableButtonView.yesEnabled = NO;
  }
  self.swipableButtonView.imageView.image = nuxImage;
}

- (void)setSuggestionFeedObject:(DFPeanutFeedObject *)suggestionFeedObject
{
  _suggestionFeedObject = suggestionFeedObject;
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
  }
}

- (void)configureSwipableButtonView
{
  [self.swipableButtonView configureWithShowsOther:NO];
  self.swipableButtonView.delegate = self;
  [self.swipableButtonView.yesButton
   setImage:[UIImage imageNamed:@"Assets/Icons/SendButtonIcon"]
   forState:UIControlStateNormal];
  [self.swipableButtonView.noButton
   setImage:[UIImage imageNamed:@"Assets/Icons/IncomingSkipButtonIcon"]
   forState:UIControlStateNormal];
  for (UIButton *button in @[self.swipableButtonView.yesButton, self.swipableButtonView.noButton]) {
    [button setTitle:nil forState:UIControlStateNormal];
    button.backgroundColor = [UIColor clearColor];
  }
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
  [self.swipableButtonView resetView];
}

- (void)swipableButtonView:(DFSwipableButtonView *)swipableButtonView
        buttonSelected:(UIButton *)button
{
  if (button == self.swipableButtonView.yesButton && self.yesButtonHandler) {
    if (self.selectedPeanutContacts.count > 0 || self.nuxStep > 0) {
      self.yesButtonHandler(self.suggestionFeedObject, self.selectedPeanutContacts);
    } else {
      [self.selectPeoplePopLabel popAtView:self.addRecipientButton animatePopLabel:YES animateTargetView:YES];
      [self.swipableButtonView resetView];
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.selectPeoplePopLabel dismiss];
      });
    }
  }
  else if (button == self.swipableButtonView.noButton && self.noButtonHandler)
    self.noButtonHandler(self.suggestionFeedObject);
}

- (IBAction)addPersonButtonPressed:(id)sender {
  DFPeoplePickerViewController *peoplePickerController = [[DFPeoplePickerViewController alloc]
                                                          initWithSelectedPeanutContacts:[self selectedPeanutContacts]];
  peoplePickerController.doneButtonActionText = @"Select";
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

- (void)configureWithSuggestion:(DFPeanutFeedObject *)suggestion withPhoto:(DFPeanutFeedObject *)photo
{
  self.suggestionFeedObject = suggestion;
  self.photoFeedObject = photo;
  
  if (suggestion.actors.count == 0) self.bottomLabel.hidden = YES;
  self.bottomLabel.text = [NSString stringWithFormat:@"Send to %@",
                           suggestion.actorsString];
  self.topLabel.text = suggestion.placeAndRelativeTimeString;
  
  [self.view setNeedsLayout];
}



@end
