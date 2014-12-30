//
//  DFSwipableSuggestionViewController.m
//  Strand
//
//  Created by Henry Bridge on 12/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFOutgoingCardViewController.h"
#import "DFNavigationController.h"
#import "DFImageManager.h"
#import "DFAnalytics.h"

@interface DFOutgoingCardViewController ()


@end



@implementation DFOutgoingCardViewController

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
                                     pointSize:self.suggestionContentView.imageView.frame.size
                                   contentMode:DFImageRequestContentModeAspectFill
                                  deliveryMode:DFImageRequestOptionsDeliveryModeOpportunistic completion:^(UIImage *image) {
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                      self.suggestionContentView.imageView.image = image;
                                    });
                                  }];
  }
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  [self configureSuggestionContentView];
  if (self.suggestionFeedObject)
    [self configureWithSuggestion:self.suggestionFeedObject withPhoto:self.photoFeedObject];
  
  [self configureSwipableButtonView];
  
  [self.swipableButtonView configureToUseImage];

  if (self.nuxStep > 0) {
    [self configureNuxStep:self.nuxStep];
  }
  self.view.backgroundColor = [UIColor clearColor];
  
  [self configurePeopleLabel];
  
  self.suggestionContentView.profileStackView.nameMode = DFProfileStackViewNameShowOnTap;
  self.suggestionContentView.profileStackView.backgroundColor = [UIColor clearColor];
}

- (void)configureSuggestionContentView
{
  if (!self.suggestionContentView) self.suggestionContentView =
    [UINib instantiateViewWithClass:[DFOutgoingCardContentView class]];
  self.suggestionContentView.translatesAutoresizingMaskIntoConstraints = NO;
  DFOutgoingCardViewController __weak *weakSelf = self;
  self.suggestionContentView.addHandler = ^{
    [weakSelf addPersonButtonPressed:weakSelf.suggestionContentView.addButton];
  };
}

- (void)configureNuxStep:(NSUInteger)nuxStep
{
  self.suggestionContentView.addButton.hidden = YES;
  self.suggestionContentView.profileStackView.maxAbbreviationLength = 2;
  [self.suggestionContentView.profileStackView setPeanutUser:[DFPeanutUserObject TeamSwapUser]];
  
  UIImage *nuxImage;
  if (self.nuxStep == 1) {
    nuxImage = [UIImage imageNamed:@"Assets/Nux/NuxMatchImage"];
    [self.suggestionContentView.topLabel removeFromSuperview];
    [self.suggestionContentView.profileStackView removeFromSuperview];
    [self.swipableButtonView.yesButton setImage:[UIImage imageNamed:@"Assets/Icons/SwipeRightButton"]
                                       forState:UIControlStateNormal];
    self.swipableButtonView.noButton.hidden = YES;
    self.swipableButtonView.noEnabled = NO;
  } else if (self.nuxStep == 2) {
    nuxImage = [UIImage imageNamed:@"Assets/Nux/NuxSendImage"];
    self.swipableButtonView.noEnabled = NO;
  } else {
    nuxImage = [UIImage imageNamed:@"Assets/Nux/NuxSkipImage"];
    self.swipableButtonView.yesEnabled = NO;
  }
  self.suggestionContentView.imageView.image = nuxImage;
}

- (void)setSuggestionFeedObject:(DFPeanutFeedObject *)suggestionFeedObject
{
  _suggestionFeedObject = suggestionFeedObject;
  if (self.nuxStep == 0) {
    self.suggestionContentView.profileStackView.peanutUsers = self.suggestionFeedObject.actors;
    self.selectedPeanutContacts = self.suggestionFeedObject.actorPeanutContacts;
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
  [self.swipableButtonView configureToUseView:self.suggestionContentView];
}

- (void)configurePeopleLabel
{
  if (self.nuxStep == 0) {
    if (self.selectedPeanutContacts.count > 0) {
      NSArray *contactNames = [self.selectedPeanutContacts arrayByMappingObjectsWithBlock:^id(DFPeanutContact *contact) {
        return [contact firstName];
      }];
      NSString *commaList = [contactNames componentsJoinedByString:@", "];
      self.suggestionContentView.topLabel.text = [NSString stringWithFormat:@"Send to %@",commaList];
    } else {
      self.suggestionContentView.topLabel.text = @"Pick Recipients";
    }
  } else {
    self.suggestionContentView.topLabel.text = @"Send to Team Swap";
  }
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
                   isSwipe:(BOOL)isSwipe
{
  NSString *logResult;
  if (button == self.swipableButtonView.yesButton && self.yesButtonHandler) {
    if (self.selectedPeanutContacts.count > 0 || self.nuxStep > 0) {
      self.yesButtonHandler(self.suggestionFeedObject, self.selectedPeanutContacts);
    } else {
      [self.suggestionContentView showAddPeoplePopup];
      [self.swipableButtonView resetView];
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.suggestionContentView dismissAddPeoplePopup];
      });
    }
    logResult = @"send";
  }
  else if (button == self.swipableButtonView.noButton && self.noButtonHandler) {
    self.noButtonHandler(self.suggestionFeedObject);
    logResult = @"skip";
  }
  
  if (self.nuxStep > 0) {
    [DFAnalytics logNux:[NSString stringWithFormat:@"MatchStep%d", (int)self.nuxStep]
    completedWithResult:logResult];
  } else {
    [DFAnalytics logOutgoingCardProcessedWithSuggestion:self.suggestionFeedObject
                                                 result:logResult
                                             actionType:isSwipe ? DFAnalyticsActionTypeSwipe : DFAnalyticsActionTypeTap];
  }
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
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)setSelectedPeanutContacts:(NSArray *)selectedPeanutContacts
{
  _selectedPeanutContacts = selectedPeanutContacts;
  [self configurePeopleLabel];
  if (selectedPeanutContacts.count > 0) {
    [self.suggestionContentView.profileStackView setPeanutUsers:[self selectedPeanutUsers]];
  } else {
    DFPeanutUserObject *dummyUser = [[DFPeanutUserObject alloc] init];
    dummyUser.display_name = @"?";
    dummyUser.phone_number = @"?";
    self.suggestionContentView.profileStackView.peanutUsers = @[dummyUser];
  }
  [self.view setNeedsLayout];
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

  [self configurePeopleLabel];
  
  [self.view setNeedsLayout];
}



@end
