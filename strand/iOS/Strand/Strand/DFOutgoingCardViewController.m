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
#import "DFHeadPickerViewController.h"
#import "DFDismissableModalViewController.h"

@interface DFOutgoingCardViewController ()

@property (nonatomic ,retain) WYPopoverController *addPersonPopoverController;
@property (nonatomic, retain) DFPeoplePickerViewController *addPersonViewController;
@property (nonatomic, retain) MMPopLabel *sendPopLabel;
@property (nonatomic) BOOL addPersonPressed;

@end



@implementation DFOutgoingCardViewController

@synthesize suggestionFeedObject = _suggestionFeedObject;

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  // call layout if needed first here so the imageview has the right size and we don't wind up
  // having to generate an image again
  [self.suggestionContentView layoutIfNeeded];
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
  self.suggestionContentView.profileStackView.showNames = YES;
  self.suggestionContentView.profileStackView.nameLabelColor = [UIColor whiteColor];
  self.suggestionContentView.profileStackView.nameLabelFont = [UIFont fontWithName:@"HelveticaNeue-Thin" size:11.0];
  self.suggestionContentView.profileStackView.delegate = self;
  self.suggestionContentView.profileStackView.photoMargins = 4.0;
  self.suggestionContentView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.suggestionContentView invalidateIntrinsicContentSize];
  DFOutgoingCardViewController __weak *weakSelf = self;
  self.suggestionContentView.addHandler = ^{
    [weakSelf addPersonButtonPressed:weakSelf.suggestionContentView.addButton];
  };
}

- (id<NSCopying, NSObject>)cardItem
{
  return self.photoFeedObject;
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
    self.suggestionContentView.topLabel.text = @"Send to:";
  } else {
    self.suggestionContentView.topLabel.text = @"Pick Recipients";
  }
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  self.yesButton.enabled = (self.selectedPeanutContacts.count > 0);
  self.yesButton.alpha = (self.selectedPeanutContacts.count > 0) ? 1.0 : 0.5;
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    if (self.selectedPeanutContacts.count == 0) {
      [self.suggestionContentView showAddPeoplePopup];
    } else if (self.suggestionFeedObject.actors.count > 0 && !self.addPersonPressed){
      [self.suggestionContentView showNearbyPeoplePopup];
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.suggestionContentView dismissNearbyPeoplePopup];
      });
    }
  });
}

- (void)buttonPressed:(id)sender
{
  NSString *logResult;
  if (sender == self.yesButton && self.yesButtonHandler) {
    if (self.selectedPeanutContacts.count > 0) {
      [UIView animateWithDuration:0.3 delay:0.2 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.view.center = CGPointMake(self.suggestionContentView.center.x,
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
  self.addPersonViewController = [[DFHeadPickerViewController alloc] init];
  self.addPersonViewController.selectedContacts = [self selectedPeanutContacts];
  self.addPersonViewController.doneButtonActionText = @"Select";
  self.addPersonViewController.allowsMultipleSelection = YES;
  self.addPersonViewController.delegate = self;
  self.addPersonViewController.activityTitle = self.suggestionContentView.topLabel.text;
  
  // try to grab the background blur from our parent to carry over
  UIViewController *parent = self.parentViewController;
  UIImage *backgroundImage = nil;
  while (parent != nil) {
    if ([parent respondsToSelector:@selector(backgroundImage)]) {
      backgroundImage = [(id)parent backgroundImage];
      break;
    }
    parent = parent.parentViewController;
  }
  if (backgroundImage) {
    [DFDismissableModalViewController
     presentWithRootController:self.addPersonViewController
     inParent:self
     withBackgroundImage:backgroundImage
     animated:YES];
  } else {
    [DFDismissableModalViewController
     presentWithRootController:self.addPersonViewController
     inParent:self
     backgroundStyle:DFDismissableModalViewControllerBackgroundStyleTranslucentBlack
     animated:YES];
    
  }
  
  self.addPersonPressed = YES;
}

+ (void)configurePopoverTheme
{
  WYPopoverTheme *theme = [WYPopoverController defaultTheme];
  theme.fillTopColor = [UIColor colorWithRed:201.0/255.0 green:201.0/255.0 blue:206.0/255.0 alpha:1.0];
  theme.overlayColor = [UIColor clearColor];
  [WYPopoverController setDefaultTheme:theme];
}

- (void)pickerController:(DFPeoplePickerViewController *)pickerController
didFinishWithPickedContacts:(NSArray *)peanutContacts
{
  self.selectedPeanutContacts = peanutContacts;
  if (self.presentedViewController) {
    [self dismissViewControllerAnimated:NO completion:nil];
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
    self.suggestionContentView.profileStackView.deleteButtonsVisible = NO;
  } else {
    DFPeanutUserObject *dummyUser = [[DFPeanutUserObject alloc] init];
    dummyUser.display_name = @"?";
    dummyUser.phone_number = @"?";
    self.suggestionContentView.profileStackView.peanutUsers = @[dummyUser];
    self.suggestionContentView.profileStackView.deleteButtonsVisible = NO;
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
    user.id = contact.user.longLongValue;
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

- (void)profileStackView:(DFProfileStackView *)profileStackView peanutUserDeleted:(DFPeanutUserObject *)peanutUser
{
  DFPeanutContact *contact = [[DFPeanutContact alloc] initWithPeanutUser:peanutUser];
  [self setSelectedPeanutContacts:[self.selectedPeanutContacts arrayByRemovingObject:contact]];
}


@end
