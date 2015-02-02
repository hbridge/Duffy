//
//  DFSwipableSuggestionViewController.m
//  Strand
//
//  Created by Henry Bridge on 12/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFOutgoingCardViewController.h"
#import <WYPopoverController/WYPopoverController.h>
#import "DFNavigationController.h"
#import "DFImageManager.h"
#import "DFAnalytics.h"
#import "DFFriendProfileViewController.h"
#import "DFPeanutFeedDataManager.h"
#import "DFDefaultsStore.h"

@interface DFOutgoingCardViewController ()

@property (nonatomic ,retain) WYPopoverController *addPersonPopoverController;
@property (nonatomic, retain) DFPeoplePickerViewController *addPersonViewController;
@property (nonatomic, retain) MMPopLabel *sendPopLabel;

@end



@implementation DFOutgoingCardViewController

@synthesize suggestionFeedObject = _suggestionFeedObject;

- (void)viewDidLayoutSubviews
{
  [[DFImageManager sharedManager] imageForID:self.photoFeedObject.id
                                   pointSize:self.suggestionContentView.imageView.frame.size
                                 contentMode:DFImageRequestContentModeAspectFill
                                deliveryMode:DFImageRequestOptionsDeliveryModeOpportunistic completion:^(UIImage *image) {
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                    self.suggestionContentView.imageView.image = image;
                                  });
                                }];
  
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.view.backgroundColor = [UIColor clearColor];
  [self configureSuggestionContentView];
  if (self.suggestionFeedObject)
    [self configureWithSuggestion:self.suggestionFeedObject withPhoto:self.photoFeedObject];
  
  [self configureButtons];

  [self configurePeopleLabel];
  [self observeNotifications];
}

- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)configureSuggestionContentView
{
  if (!self.suggestionContentView) {
    self.suggestionContentView =
    [UINib instantiateViewWithClass:[DFOutgoingCardContentView class]];
    self.suggestionContentView.profileStackView.showNames = NO;
    self.suggestionContentView.profileStackView.delegate = self;
    self.suggestionContentView.profileStackView.backgroundColor = [UIColor clearColor];
  }
  self.suggestionContentView.translatesAutoresizingMaskIntoConstraints = NO;
  DFOutgoingCardViewController __weak *weakSelf = self;
  self.suggestionContentView.addHandler = ^{
    [weakSelf addPersonButtonPressed:weakSelf.suggestionContentView.addButton];
  };
}


- (void)setSuggestionFeedObject:(DFPeanutFeedObject *)suggestionFeedObject
{
  _suggestionFeedObject = suggestionFeedObject;
  self.suggestionContentView.profileStackView.peanutUsers = self.suggestionFeedObject.actors;
  self.selectedPeanutContacts = self.suggestionFeedObject.actorPeanutContacts;
}

- (void)configureButtons
{
  [self.yesButton
   setImage:[UIImage imageNamed:@"Assets/Icons/SendButtonIcon"]
   forState:UIControlStateNormal];
  [self.yesButton setTitle:@"Send" forState:UIControlStateNormal];
  [self.yesButton addTarget:self
                    action:@selector(buttonPressed:)
          forControlEvents:UIControlEventTouchUpInside];
  [self.noButton
   setImage:[UIImage imageNamed:@"Assets/Icons/SwipeXButton"]
   forState:UIControlStateNormal];
  [self.noButton setTitle:@"Skip" forState:UIControlStateNormal];
  [self.noButton addTarget:self
                    action:@selector(buttonPressed:)
          forControlEvents:UIControlEventTouchUpInside];
  
  self.sendPopLabel = [MMPopLabel popLabelWithText:@"Tap to Send"];
  self.sendPopLabel.forceArrowDown = YES;
  [self.view addSubview:self.sendPopLabel];
  
}

- (void)configurePeopleLabel
{
  if (self.selectedPeanutContacts.count > 0) {
    NSArray *contactNames = [self.selectedPeanutContacts arrayByMappingObjectsWithBlock:^id(DFPeanutContact *contact) {
      return [contact firstName];
    }];
    NSString *commaList = [contactNames componentsJoinedByString:@", "];
    self.suggestionContentView.topLabel.text = [NSString stringWithFormat:@"Send to %@",commaList];
  } else {
    self.suggestionContentView.topLabel.text = @"Pick Recipients";
  }
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    if (self.selectedPeanutContacts.count == 0) {
      [self.suggestionContentView showAddPeoplePopup];
    }
  });
}

- (void)buttonPressed:(id)sender
{
  NSString *logResult;
  if (sender == self.yesButton && self.yesButtonHandler) {
    if (self.selectedPeanutContacts.count > 0) {
      [UIView animateWithDuration:0.3 delay:0.2 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.view.center = CGPointMake(self.cardView.center.x,
                                       0 - self.view.frame.size.height / 2.0);
      } completion:^(BOOL finished) {
        self.view.hidden = YES;
        self.yesButtonHandler(self.suggestionFeedObject,
                              self.selectedPeanutContacts,
                              self.suggestionContentView.commentTextField.text);
        [DFDefaultsStore incrementCountForAction:DFUserActionSendSuggestion];
      }];
    } else {
      [self.suggestionContentView showAddPeoplePopup];
    }
    
    logResult = @"send";
  }
  else if (sender == self.noButton && self.noButtonHandler) {
    [UIView animateWithDuration:0.3 delay:0.2 options:UIViewAnimationOptionCurveEaseInOut animations:^{
      self.view.alpha = 0.0;
    } completion:^(BOOL finished) {
      self.view.hidden = YES;
      self.noButtonHandler(self.suggestionFeedObject);
    }];
    
    logResult = @"skip";
  }
  
  [DFAnalytics logOutgoingCardProcessedWithSuggestion:self.suggestionFeedObject
                                               result:logResult
                                           actionType:DFAnalyticsActionTypeTap];
}

- (IBAction)addPersonButtonPressed:(UIButton *)sender {
  [self.suggestionContentView dismissAddPeoplePopup];
  self.addPersonViewController = [[DFRecipientPickerViewController alloc]
                                  initWithSelectedPeanutContacts:[self selectedPeanutContacts]];
  self.addPersonViewController.doneButtonActionText = @"Select";
  self.addPersonViewController.allowsMultipleSelection = YES;
  self.addPersonViewController.delegate = self;
  
  WYPopoverBackgroundView *appearance = [WYPopoverBackgroundView appearance];
  appearance.fillTopColor = [UIColor colorWithRed:201.0/255.0 green:201.0/255.0 blue:206.0/255.0 alpha:1.0];
  self.addPersonPopoverController = [[WYPopoverController alloc]
                                     initWithContentViewController:self.addPersonViewController];
  
  CGRect rect = [self.view convertRect:sender.frame fromView:sender.superview];
  [self.addPersonPopoverController presentPopoverFromRect:rect
                                                   inView:self.view
                                 permittedArrowDirections:WYPopoverArrowDirectionUp
                                                 animated:YES
                                                  options:WYPopoverAnimationOptionFadeWithScale
                                               completion:nil];
}

- (void)pickerController:(DFPeoplePickerViewController *)pickerController
didFinishWithPickedContacts:(NSArray *)peanutContacts
{
  self.selectedPeanutContacts = peanutContacts;
  if (self.presentedViewController) {
    [self dismissViewControllerAnimated:YES completion:nil];
  } else {
    [self.addPersonPopoverController dismissPopoverAnimated:YES];
  }
  if ([DFDefaultsStore actionCountForAction:DFUserActionSendSuggestion] == 0) {
    [self.sendPopLabel popAtView:self.yesButton
                 animatePopLabel:YES
               animateTargetView:NO];
  }
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

- (void)keyboardWillShow:(NSNotification *)notification {
  self.yesButton.hidden = YES;
  self.noButton.hidden = YES;
  self.cardBottomConstraint.priority = 999;
  [self updateFrameFromKeyboardNotif:notification otherAnimationsBlock:^{
    [self.suggestionContentView setNeedsLayout];
  }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
  self.yesButton.hidden = NO;
  self.noButton.hidden = NO;
  self.cardBottomConstraint.priority = 997;
  [self updateFrameFromKeyboardNotif:notification otherAnimationsBlock:^{
    [self.suggestionContentView setNeedsLayout];
  }];
}


- (void)profileStackView:(DFProfileStackView *)profileStackView peanutUserTapped:(DFPeanutUserObject *)peanutUser
{
  // info can be incomplete, look up to see if we have a legit user
  DFPeanutUserObject *user = [[DFPeanutFeedDataManager sharedManager] userWithPhoneNumber:peanutUser.phone_number];
  if (user) {
    DFFriendProfileViewController *friendViewController = [[DFFriendProfileViewController alloc] initWithPeanutUser:user];
    [DFNavigationController presentWithRootController:friendViewController inParent:self];
  }
}


@end
