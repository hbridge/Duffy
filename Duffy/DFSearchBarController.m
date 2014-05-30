//
//  DFSearchBarController.m
//  Duffy
//
//  Created by Henry Bridge on 5/29/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFSearchBarController.h"
#import "DFAutocompleteAdapter.h"
#import "DFSuggestionAdapter.h"
#import "DFNotificationSharedConstants.h"
#import "DFSearchResultTableViewCell.h"
#import "NSDictionary+DFJSON.h"
#import "DFTableHeaderView.h"
#import "DFUploadSessionStats.h"


static NSDictionary *SectionNameToTitles;
static NSString *DATE_SECTION_NAME = @"Time";
static NSString *LOCATION_SECTION_NAME = @"Location";
static NSString *CATEGORY_SECTION_NAME = @"Subject";
static NSString *SUGGESTION_SECTION_NAME = @"Suggestions";
static NSString *SEARCH_PLACEHOLDER = @"Search Photos";
static NSString *SEARCH_DEFAULT_QUERY = @"Everything";

static CGFloat SearchResultsRowHeight = 38;
static CGFloat SearchResultsCellFontSize = 15;
static NSUInteger RefreshSuggestionsThreshold = 50;
static float MinTimeBetweenSuggestionFetch = 60.0;
static float MinTimeBetweenAutocompleteFetch = 60.0;


typedef enum {
  DFSearchResultTypeAutocomplete,
  DFSearchResultTypeSuggestions,
} DFSearchResultType;

@interface DFSearchBarController()

@property (nonatomic, retain) NSDate *lastSuggestionFetchDate;

@property (nonatomic, retain) NSMutableDictionary *autocompleteResultsByQuery;
@property (nonatomic, retain) NSMutableDictionary *autocompleteFetchDateByQuery;

@property (readonly, nonatomic, retain) DFAutocompleteAdapter *autocompleteAdapter;
@property (readonly, nonatomic, retain) DFSuggestionAdapter *suggestionAdapter;

@property (nonatomic) NSUInteger lastSeenNumUploaded;
@end


@implementation DFSearchBarController

@synthesize autocompleteAdapter = _autocompleteAdapter;
@synthesize suggestionAdapter = _suggestionAdapter;
@synthesize suggestionsBySection = _suggestionsBySection;

+ (void)initialize
{
  SectionNameToTitles = @{DATE_SECTION_NAME: @"Time",
                          LOCATION_SECTION_NAME: @"Location",
                          CATEGORY_SECTION_NAME: @"Things",
                          SUGGESTION_SECTION_NAME : @"Suggestions from your photos",
                          };
}


- (id)init
{
  self = [super init];
  if (self) {
    _suggestionAdapter = [[DFSuggestionAdapter alloc] init];
    _autocompleteAdapter = [[DFAutocompleteAdapter alloc] init];
    self.autocompleteResultsByQuery = [[NSMutableDictionary alloc] init];
    self.autocompleteFetchDateByQuery = [[NSMutableDictionary alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(uploadStatusChanged:)
                                                 name:DFUploadStatusNotificationName
                                               object:nil];
    [self refreshSuggestionsIgnoreLastFetchTime:NO];
  }
  return self;
}

#pragma mark - Public methods

- (void)setSearchBar:(DFSearchBar *)searchBar
{
  _searchBar = searchBar;
  searchBar.delegate = self;
  searchBar.placeholder = SEARCH_PLACEHOLDER;
  searchBar.defaultQuery = SEARCH_DEFAULT_QUERY;
}

- (void)setTableView:(UITableView *)tableView
{
  _tableView = tableView;
  tableView.delegate = self;
  tableView.dataSource = self;
  tableView.rowHeight = SearchResultsRowHeight;
  [tableView registerClass:[DFSearchResultTableViewCell class]
                      forCellReuseIdentifier:@"DFSearchResultTableViewCell"];
}

- (void)clearSearchBar
{
  self.searchBar.text = SEARCH_DEFAULT_QUERY;
}


- (void)setActive:(BOOL)visible animated:(BOOL)animated
{
  

}

#pragma mark - Search Bar delegate and helpers

- (void)searchBarTextDidBeginEditing:(DFSearchBar *)searchBar
{
  [self.delegate searchBarControllerSearchBegan:self];
  [self updateUIForSearchBarHasFocus:YES showingDefaultQuery:NO];
}

- (void)searchBar:(DFSearchBar *)searchBar textDidChange:(NSString *)searchText
{
  [self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(DFSearchBar *)searchBar
{
  [self updateUIForSearchBarHasFocus:NO showingDefaultQuery:NO];
  [self.delegate searchBarController:self searchExecutedWithQuery:searchBar.text];
}

- (void)searchBarCancelButtonClicked:(DFSearchBar *)searchBar
{
  [self updateUIForSearchBarHasFocus:NO showingDefaultQuery:[self.searchBar.text isEqualToString:SEARCH_DEFAULT_QUERY]];
  [self.delegate searchBarControllerSearchCancelled:self];
}

- (void)updateUIForSearchBarHasFocus:(BOOL)searchBarHasFocus
                 showingDefaultQuery:(BOOL)showingDefault
{
  if (searchBarHasFocus) {
    [self.searchBar setShowsCancelButton:YES animated:YES];
    [self.searchBar setShowsClearButton:NO animated:YES];
  } else {
    [self.searchBar setShowsCancelButton:NO animated:YES];
    if (showingDefault) {
      [self.searchBar setShowsClearButton:NO animated:YES];
    } else {
      [self.searchBar setShowsClearButton:YES animated:YES];
    }
    [self.searchBar resignFirstResponder];
  }
}

- (void)searchBarClearButtonClicked:(DFSearchBar *)searchBar
{
  searchBar.text = searchBar.defaultQuery;
  [self.delegate searchBarControllerSearchCleared:self];
}
  
#pragma mark - Search results filtering
  

- (DFSearchResultType) searchResultTypeToShow
{
  NSString *searchText = self.searchBar.text;
  if (searchText.length == 0 ||
      [searchText isEqualToString:SEARCH_DEFAULT_QUERY] ||
      [searchText characterAtIndex:searchText.length - 1] == ' ')
    return DFSearchResultTypeSuggestions;
  
  return DFSearchResultTypeAutocomplete;
}

- (NSArray *)sectionsToDisplay
{
  if ([self searchResultTypeToShow] == DFSearchResultTypeAutocomplete) {
    return @[SUGGESTION_SECTION_NAME];
  } else if ([self searchResultTypeToShow] == DFSearchResultTypeSuggestions) {
    NSMutableArray *suggestionSections = [@[DATE_SECTION_NAME, LOCATION_SECTION_NAME, CATEGORY_SECTION_NAME] mutableCopy];
    [suggestionSections removeObjectsInArray:
     [[self categorySuggestionsInQuery:self.searchBar.text] allObjects]];
    return suggestionSections;
  }
  
  return nil;
}

- (NSMutableSet *)categorySuggestionsInQuery:(NSString *)query
{
  NSMutableSet *categories = [[NSMutableSet alloc] init];
  for (NSString *sectionName in self.suggestionsBySection.allKeys) {
    for (DFPeanutSuggestion *suggestion in (NSArray *)self.suggestionsBySection[sectionName]) {
      if ([query rangeOfString:suggestion.name].location != NSNotFound) {
        [categories addObject:sectionName];
      }
    }
  }
  
  return categories;
}

#pragma mark - Suggestions Dictionary management

- (NSMutableDictionary *)suggestionsBySection
{
  if (!_suggestionsBySection) {
    _suggestionsBySection = [[NSMutableDictionary alloc] init];
    [_suggestionsBySection addEntriesFromDictionary:[self loadSuggestions]];
  }
  
  return _suggestionsBySection;
}

- (void)refreshSuggestionsIgnoreLastFetchTime:(BOOL)ignoreLastFetchTime
{
  if (!ignoreLastFetchTime) {
    if (self.lastSuggestionFetchDate &&
        [[NSDate date] timeIntervalSinceDate:self.lastSuggestionFetchDate] < MinTimeBetweenSuggestionFetch) {
      return;
    }
  }
  self.lastSuggestionFetchDate = [NSDate date];
  
  [self.suggestionAdapter fetchSuggestions:^(NSArray *categoryPeanutSuggestions,
                                             NSArray *locationPeanutSuggestions,
                                             NSArray *timePeanutSuggestions) {
    if (categoryPeanutSuggestions) {
      self.suggestionsBySection[CATEGORY_SECTION_NAME] = categoryPeanutSuggestions;
    }
    
    if (locationPeanutSuggestions) {
      self.suggestionsBySection[LOCATION_SECTION_NAME] = locationPeanutSuggestions;
    }
    
    if (timePeanutSuggestions) {
      self.suggestionsBySection[DATE_SECTION_NAME] = timePeanutSuggestions;
    }
    
    [self.tableView reloadData];
    [self saveSuggestions:self.suggestionsBySection];
  }];
}

- (void)saveSuggestions:(NSDictionary *)searchResults
{
  NSString *jsonString = [[searchResults dictionaryWithNonJSONRemoved] JSONString];
  [[NSUserDefaults standardUserDefaults] setObject:jsonString
                                            forKey:@"DFSearchViewControllerDefaultSearchResultsJSON"];
}

- (NSDictionary *)loadSuggestions
{
  NSString *loadedDictString = [[NSUserDefaults standardUserDefaults]
                                objectForKey:@"DFSearchViewControllerDefaultSearchResultsJSON"];
  NSMutableDictionary *resultsDict = [[NSDictionary dictionaryWithJSONString:loadedDictString] mutableCopy];
  [resultsDict enumerateKeysAndObjectsUsingBlock:^(NSString *sectionName, NSArray *suggestions, BOOL *stop) {
    if (suggestions) {
      NSMutableArray *mutableSuggestions = suggestions.mutableCopy;
      for (unsigned long i = 0; i < mutableSuggestions.count; i++) {
        NSDictionary *suggestionDict = mutableSuggestions[i];
        mutableSuggestions[i] = [[DFPeanutSuggestion alloc] initWithJSONDict:suggestionDict];
      }
      
      resultsDict[sectionName] = mutableSuggestions;
    }
  }];
  
  
  return resultsDict;
}

#pragma mark - Autocomplete Results

- (NSString *)autocompleteTextInSearchBar
{
  NSArray *components = [self.searchBar.text componentsSeparatedByString:@" "];
  NSString *lastComponent = [components lastObject];
  return lastComponent;
}

- (void)refreshAutocompleteResultsForQuery:(NSString *)query
                       ignoreLastFetchDate:(BOOL)ignoreLastDate
{
  if (!ignoreLastDate) {
    NSDate *lastDate = self.autocompleteFetchDateByQuery[query];
    if (lastDate && [[NSDate date] timeIntervalSinceDate:lastDate] < MinTimeBetweenAutocompleteFetch)
      return;
  }
  
  self.autocompleteFetchDateByQuery[query] = [NSDate date];
  [self fetchAutocompeteResultsForQuery:query];
}


- (void)fetchAutocompeteResultsForQuery:(NSString *)query
{
  [self.autocompleteAdapter fetchSuggestionsForQuery:query
                                 withCompletionBlock:^(NSArray *peanutSuggestions) {
                                   if (peanutSuggestions) {
                                     self.autocompleteResultsByQuery[query] = peanutSuggestions;
                                   }
                                   
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                     [self.tableView reloadData];
                                   });
                                 }];
}

#pragma mark - UITableView datasource and delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return [[self sectionsToDisplay] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section

{
  NSArray *results = [self resultsForSectionWithIndex:section];

  return results.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSArray *results = [self resultsForSectionWithIndex:indexPath.section];
  DFPeanutSuggestion *peanutSuggestion = results[indexPath.row];
  
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DFSearchResultTableViewCell"];
  cell.textLabel.text = peanutSuggestion.name ? peanutSuggestion.name : @"None";
  cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", peanutSuggestion.count];
  cell.textLabel.font = [cell.textLabel.font fontWithSize:SearchResultsCellFontSize];
  return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
  DFTableHeaderView *view = [[[UINib nibWithNibName:@"DFTableHeaderView" bundle:nil] instantiateWithOwner:self options:nil] firstObject];
  
  NSArray *sectionsToDisplay = [self sectionsToDisplay];
  if (section < sectionsToDisplay.count) {
    NSString *sectionID = [sectionsToDisplay objectAtIndex:section];
    view.textLabel.text = SectionNameToTitles[sectionID];
    NSString *imageName = [NSString stringWithFormat:@"Icons/%@%@", sectionID, @"SectionHeader"];
    view.imageView.image = [UIImage imageNamed:imageName];
  } else {
    DDLogWarn(@"Race: view for header in section called with higher number than number of sections");
    
  }
  
  return view;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSString *selectionString;
  NSArray *resultsForSectionWithIndex = [self resultsForSectionWithIndex:indexPath.section];
  if (resultsForSectionWithIndex && resultsForSectionWithIndex.count > 0) {
    DFPeanutSuggestion *suggestion = [[self resultsForSectionWithIndex:indexPath.section]
                                      objectAtIndex:indexPath.row];
    selectionString = suggestion.name;
  } else {
    selectionString = @"";
    DDLogWarn(@"DFSearchViewController user selected blank indexPath: %@",
              indexPath.description);
  }
  
  if (self.searchBar.text.length > 0
      && [self.searchBar.text characterAtIndex:self.searchBar.text.length - 1] != ' '){
    NSString *partialTerm = [[self.searchBar.text componentsSeparatedByString:@" "] lastObject];
    self.searchBar.text = [self.searchBar.text
                           stringByReplacingOccurrencesOfString:partialTerm
                           withString:[selectionString stringByAppendingString:@" "]
                           options:0
                           range:(NSRange){self.searchBar.text.length-partialTerm.length, partialTerm.length}];
    
  } else {
    self.searchBar.text = [NSString stringWithFormat:@"%@%@ ", self.searchBar.text, selectionString];
  }
}

- (NSArray *)resultsForSectionWithIndex:(NSUInteger)sectionIndex
{
  NSArray *results;
  if ([self searchResultTypeToShow] == DFSearchResultTypeAutocomplete) {
    NSString *query = [self autocompleteTextInSearchBar];
    results = self.autocompleteResultsByQuery[query];
    [self refreshAutocompleteResultsForQuery:query ignoreLastFetchDate:NO];
  } else {
    NSString *sectionID = [[self sectionsToDisplay] objectAtIndex:sectionIndex];
    results = self.suggestionsBySection[sectionID];
  }
  return results;
}


#pragma mark - Upload notificatoin handler

- (void)uploadStatusChanged:(NSNotification *)note
{
  DFUploadSessionStats *sessionStats = note.userInfo[DFUploadStatusUpdateSessionUserInfoKey];
  if (sessionStats.numThumbnailsUploaded - self.lastSeenNumUploaded > RefreshSuggestionsThreshold) {
    [self refreshSuggestionsIgnoreLastFetchTime:YES];
  }
  
  self.lastSeenNumUploaded = sessionStats.numThumbnailsUploaded;
}


#pragma mark - Silly helpers that should die

- (NSDictionary *)suggestionsStrings
{
  NSMutableDictionary *result = self.suggestionsBySection.mutableCopy;
  for (NSString *key in result.allKeys) {
    NSMutableArray *suggestions = [(NSArray *)result[key] mutableCopy];
    for (int i = 0; i < suggestions.count; i++) {
      DFPeanutSuggestion *suggestion = suggestions[i];
      suggestions[i] = suggestion.name;
    }
    result[key] = suggestions;
  }
  return result;
}


@end
