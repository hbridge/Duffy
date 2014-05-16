//
//  DFIntroPageViewController.m
//  Duffy
//
//  Created by Henry Bridge on 5/15/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFIntroContentViewController.h"
#import "DFPeanutSuggestion.h"
#import "DFAutocompleteController.h"

@interface DFIntroContentViewController ()

@property (nonatomic, retain) DFAutocompleteController *autoCompleteController;

@end

@implementation DFIntroContentViewController

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
  
  
  if (self.pageIndex == 0) {
    [self configureWelcomeScreen];
  } else if (self.pageIndex == 1) {
    [self configureUploadScreen];
  } else if (self.pageIndex == 2) {
    [self configureDoneScreen];
  }
}

- (void)configureWelcomeScreen
{
  self.titleLabel.text = @"Welcome";
  self.contentLabel.attributedText = [self attributedStringForPage:0];
  
  self.activityIndicator.hidden = YES;
  [self.actionButton setTitle:@"Grant Permission" forState:UIControlStateNormal];
  [self.actionButton addTarget:self
                        action:@selector(askForPermissions:)
              forControlEvents:UIControlEventTouchUpInside];
}

- (void)configureUploadScreen
{
  self.titleLabel.text = @"Uploading";
  self.contentLabel.attributedText = [self attributedStringForPage:1];
  [self.activityIndicator startAnimating];
  self.actionButton.hidden = YES;
}

- (void)configureDoneScreen
{
  self.titleLabel.text = @"Ready to Get Started";
  
  DFIntroContentViewController __weak *weakSelf = self;
  self.autoCompleteController = [[DFAutocompleteController alloc] init];
  [self.autoCompleteController fetchSuggestions:^(NSArray *categoryPeanutSuggestions,
                                             NSArray *locationPeanutSuggestions,
                                             NSArray *timePeanutSuggestions) {
//    [weakSelf showDoneTextWithTimeSuggestions:timePeanutSuggestions
//                      locationSuggestions:locationPeanutSuggestions
//                         thingSuggestions:categoryPeanutSuggestions];
    
    DFPeanutSuggestion *timePeanutSuggestion = [[DFPeanutSuggestion alloc] init];
    timePeanutSuggestion.name = @"last week";
    timePeanutSuggestion.count = 5;
    
    DFPeanutSuggestion *locationPeanutSuggestion = [[DFPeanutSuggestion alloc] init];
    locationPeanutSuggestion.name = @"New York";
    locationPeanutSuggestion.count = 100;
    
    DFPeanutSuggestion *thingPeanutSuggestion = [[DFPeanutSuggestion alloc] init];
    thingPeanutSuggestion.name = @"Nutriment";
    thingPeanutSuggestion.count = 15;
    
    [weakSelf showDoneTextWithTimeSuggestions:@[timePeanutSuggestion]
                          locationSuggestions:@[locationPeanutSuggestion]
                             thingSuggestions:@[thingPeanutSuggestion]];
    
  }];
  
  
  [self.actionButton setTitle:@"Get Started" forState:UIControlStateNormal];
  self.activityIndicator.hidden = YES;
  [self.actionButton addTarget:self
                        action:@selector(dimsissIntro:)
              forControlEvents:UIControlEventTouchUpInside];
}

- (void)showDoneTextWithTimeSuggestions:(NSArray *)timeSuggestions
                    locationSuggestions:(NSArray *)locationSuggestions
                       thingSuggestions:(NSArray *)thingSuggestions
{
  NSMutableAttributedString *attributedFormatString = [[self attributedStringForPage:2] mutableCopy];
  NSMutableString *formatString = [attributedFormatString mutableString];
  
  DFPeanutSuggestion *timeSuggestion = [timeSuggestions firstObject];
  if (timeSuggestion) {
    [formatString replaceOccurrencesOfString:@"%TimeNumber"
                                            withString:[NSString stringWithFormat:@"%d", timeSuggestion.count]
                                               options:0
                                                 range:NSMakeRange(0, attributedFormatString.length)];
    [formatString replaceOccurrencesOfString:@"%TimeString"
                                            withString:[timeSuggestion.name capitalizedString]
                                               options:0
                                                 range:NSMakeRange(0, attributedFormatString.length)];
  }
  
  DFPeanutSuggestion *locationSuggestion = [locationSuggestions firstObject];
  if (locationSuggestion) {
    [formatString replaceOccurrencesOfString:@"%LocationNumber"
                                            withString:[NSString stringWithFormat:@"%d", locationSuggestion.count]
                                               options:0
                                                 range:NSMakeRange(0, attributedFormatString.length)];
    [formatString replaceOccurrencesOfString:@"%LocationString"
                                            withString:[locationSuggestion.name capitalizedString]
                                               options:0
                                                 range:NSMakeRange(0, attributedFormatString.length)];
  }
  
  DFPeanutSuggestion *thingSuggestion = [thingSuggestions firstObject];
  if (locationSuggestion) {
    [formatString replaceOccurrencesOfString:@"%ThingNumber"
                                            withString:[NSString stringWithFormat:@"%d", thingSuggestion.count]
                                               options:0
                                                 range:NSMakeRange(0, attributedFormatString.length)];
    [formatString replaceOccurrencesOfString:@"%ThingString"
                                            withString:[thingSuggestion.name capitalizedString]
                                               options:0
                                                 range:NSMakeRange(0, attributedFormatString.length)];
  }
  
  self.contentLabel.attributedText = attributedFormatString;
}

- (NSAttributedString *)attributedStringForPage:(unsigned int)pageNum
{
  NSError *error;
  NSString *fileName = [NSString stringWithFormat:@"%@%d", @"IntroPage", pageNum+1];
  NSURL *fileURL = [[NSBundle mainBundle] URLForResource:fileName withExtension:@"rtf"];
  NSAttributedString *result = [[NSAttributedString alloc] initWithFileURL:fileURL
                                                                         options:nil
                                                              documentAttributes:nil
                                                                           error:&error];
  
  
  
  return result;
}



- (void)askForPermissions:(id)sender
{
  DDLogInfo(@"Asking for user permissinos.");
}

- (void)dimsissIntro:(id)sender
{
  DDLogInfo(@"User dismissed intro");
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}




/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
