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

@interface DFSearchBarController()

@property (nonatomic, retain) NSMutableDictionary *searchResultsBySectionName;
@property (nonatomic, retain) NSMutableArray *sectionNames;
@property (nonatomic, retain) NSDate *lastSuggestionFetch;

@property (readonly, nonatomic, retain) DFAutocompleteAdapter *autocompleteAdapter;
@property (readonly, nonatomic, retain) DFSuggestionAdapter *suggestionAdapter;

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
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(uploadStatusChanged:)
                                                 name:DFUploadStatusNotificationName
                                               object:nil];
    [self refreshSuggestionsIgnoreLastFetchTime:NO];
  }
  return self;
}

- (void)setSearchBar:(DFSearchBar *)searchBar
{
  _searchBar = searchBar;
  searchBar.delegate = self;
  searchBar.placeholder = SEARCH_PLACEHOLDER;
  searchBar.defaultQuery = SEARCH_DEFAULT_QUERY;
}

- (void)setTableView:(UITableView *)tableView
{
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



#pragma mark - Private helpers


- (NSMutableArray *)defaultSectionNames
{
  return [@[DATE_SECTION_NAME, LOCATION_SECTION_NAME, CATEGORY_SECTION_NAME] mutableCopy];
}

- (NSMutableDictionary *)suggestionsBySection
{
  if (!_suggestionsBySection) {
    _suggestionsBySection = [[NSMutableDictionary alloc] init];
    [_suggestionsBySection addEntriesFromDictionary:[self loadDefaultSearchResults]];
  }
  
  
  return _suggestionsBySection;
}

- (void)refreshSuggestionsIgnoreLastFetchTime:(BOOL)ignoreLastFetchTime
{
  if (!ignoreLastFetchTime) {
    if (self.lastSuggestionFetch &&
        [[NSDate date] timeIntervalSinceDate:self.lastSuggestionFetch] < MinTimeBetweenSuggestionFetch) {
      return;
    }
  }
  self.lastSuggestionFetch = [NSDate date];
  
  [self.suggestionAdapter fetchSuggestions:^(NSArray *categoryPeanutSuggestions,
                                                 NSArray *locationPeanutSuggestions,
                                                 NSArray *timePeanutSuggestions) {
    if (categoryPeanutSuggestions) {
      self.suggestionsBySection[CATEGORY_SECTION_NAME] = categoryPeanutSuggestions;
    } else {
      [self.sectionNames removeObject:CATEGORY_SECTION_NAME];
    }
    
    if (locationPeanutSuggestions) {
      self.suggestionsBySection[LOCATION_SECTION_NAME] = locationPeanutSuggestions;
    } else {
      [self.sectionNames removeObject:LOCATION_SECTION_NAME];
    }
    
    if (timePeanutSuggestions) {
      self.suggestionsBySection[DATE_SECTION_NAME] = timePeanutSuggestions;
    } else {
      [self.sectionNames removeObject:DATE_SECTION_NAME];
    }
    
    [self.tableView reloadData];
    [self saveDefaultSearchResults:self.suggestionsBySection];
  }];
}

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

- (void)saveDefaultSearchResults:(NSDictionary *)searchResults
{
  NSString *jsonString = [[searchResults dictionaryWithNonJSONRemoved] JSONString];
  [[NSUserDefaults standardUserDefaults] setObject:jsonString
                                            forKey:@"DFSearchViewControllerDefaultSearchResultsJSON"];
}

- (NSDictionary *)loadDefaultSearchResults
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


#pragma mark - Search Bar delegate and helpers

- (void)searchBarTextDidBeginEditing:(DFSearchBar *)searchBar
{
  [self updateUIForSearchBarHasFocus:YES showingDefaultQuery:NO];
}

- (void)searchBar:(DFSearchBar *)searchBar textDidChange:(NSString *)searchText
{
  if (searchText.length == 0 ||
      [searchText isEqualToString:SEARCH_DEFAULT_QUERY] ||
      [searchText characterAtIndex:searchText.length - 1] == ' ') {
    [self showSuggestions:searchText];
  } else {
    [self showAutocompleteResults:searchText];
  }
}

- (void)searchBarSearchButtonClicked:(DFSearchBar *)searchBar
{
  if ([searchBar.text isEqualToString:@""] || [[searchBar.text lowercaseString]
                                               isEqualToString:[SEARCH_DEFAULT_QUERY lowercaseString]]) {
    [self loadDefaultSearch];
  } else {
    [self executeSearchForQuery:self.searchBar.text reverseResults:NO];
    [self updateUIForSearchBarHasFocus:NO showingDefaultQuery:NO];
  }
}

- (void)searchBarCancelButtonClicked:(DFSearchBar *)searchBar
{
  [self updateUIForSearchBarHasFocus:NO showingDefaultQuery:[self.searchBar.text isEqualToString:SEARCH_DEFAULT_QUERY]];
}

- (void)searchBarClearButtonClicked:(DFSearchBar *)searchBar
{
  searchBar.text = searchBar.defaultQuery;
  [self loadDefaultSearch];
}

- (void)showSuggestions:(NSString *)query
{
	/*
	 Update the filtered array based on the search text and scope.
	 */
  
  NSMutableArray *sections = [self defaultSectionNames];
  NSMutableDictionary *searchResults = [[self defaultSearchResults] mutableCopy];
  
  if ([self isDateInQuery:query]) {
    [searchResults removeObjectForKey:DATE_SECTION_NAME];
    [sections removeObject:DATE_SECTION_NAME];
  }
  if ([self isLocationInQuery:query]){
    [searchResults removeObjectForKey:LOCATION_SECTION_NAME];
    [sections removeObject:LOCATION_SECTION_NAME];
  }
  if ([self isCategoryInQuery:query]) {
    [searchResults removeObjectForKey:CATEGORY_SECTION_NAME];
    [sections removeObject:CATEGORY_SECTION_NAME];
  }
  
  self.sectionNames = sections;
  self.searchResultsBySectionName = searchResults;
  
  [self refreshSuggestionsIgnoreLastFetchTime:NO];
  
  [self.searchResultsTableView reloadData];
}

- (void)showAutocompleteResults:(NSString *)searchText
{
  NSArray *components = [searchText componentsSeparatedByString:@" "];
  NSString *lastComponent = [components lastObject];
  
  [self.autocompleteAdapter fetchSuggestionsForQuery:lastComponent
                                 withCompletionBlock:^(NSArray *peanutSuggestions) {
                                   self.sectionNames = [@[SUGGESTION_SECTION_NAME] mutableCopy];
                                   if (peanutSuggestions) {
                                     self.searchResultsBySectionName[SUGGESTION_SECTION_NAME] = peanutSuggestions;
                                   } else {
                                     self.searchResultsBySectionName[SUGGESTION_SECTION_NAME] = @[];
                                   }
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                     [self.searchResultsTableView reloadData];
                                   });
                                 }];
}


- (BOOL)isDateInQuery:(NSString *)query
{
  if (query == nil) return NO;
  for (DFPeanutSuggestion *dateSuggestion in [[self defaultSearchResults] objectForKey:DATE_SECTION_NAME])
  {
    if([query rangeOfString:dateSuggestion.name].location != NSNotFound) {
      return YES;
    }
  }
  return NO;
}

- (BOOL)isLocationInQuery:(NSString *)query
{
  if (query == nil) return NO;
  for (DFPeanutSuggestion *locationSuggestion in [[self defaultSearchResults] objectForKey:LOCATION_SECTION_NAME])
  {
    if([query rangeOfString:locationSuggestion.name].location != NSNotFound) {
      return YES;
    }
  }
  return NO;
}

- (BOOL)isCategoryInQuery:(NSString *)query
{
  if (query == nil) return NO;
  for (DFPeanutSuggestion *categorySuggestion in [[self defaultSearchResults] objectForKey:CATEGORY_SECTION_NAME])
  {
    if([query rangeOfString:categorySuggestion.name].location != NSNotFound) {
      return YES;
    }
  }
  return NO;
}

#pragma mark - UITableView datasource and delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return self.sectionNames.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section

{
  NSInteger countForSection = [self resultsForSectionWithIndex:section].count;
  return countForSection;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutSuggestion *peanutSuggestion = [[self resultsForSectionWithIndex:indexPath.section]
                                          objectAtIndex:indexPath.row];
  
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DFSearchResultTableViewCell"];
  cell.textLabel.text = peanutSuggestion.name ? peanutSuggestion.name : @"None";
  cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", peanutSuggestion.count];
  cell.textLabel.font = [cell.textLabel.font fontWithSize:SearchResultsCellFontSize];
  return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
  DFTableHeaderView *view = [[[UINib nibWithNibName:@"DFTableHeaderView" bundle:nil] instantiateWithOwner:self options:nil] firstObject];
  
  NSString *sectionName = self.sectionNames[section];
  view.textLabel.text = SectionNameToTitles[sectionName];
  
  NSString *imageName = [NSString stringWithFormat:@"Icons/%@%@", self.sectionNames[section], @"SectionHeader"];
  view.imageView.image = [UIImage imageNamed:imageName];
  
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
    DDLogWarn(@"DFSearchViewController user selected blank indexPath: %@ searchResultsBySecitonName:%@",
              indexPath.description, self.searchResultsBySectionName.description);
  }
  
  //if (!self.searchBar.isFirstResponder) [self.searchBar becomeFirstResponder];
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


#pragma mark - Data Accessors


- (NSArray *)resultsForSectionWithIndex:(NSInteger)sectionIndex
{
  return self.searchResultsBySectionName[[self sectionNameForIndex:sectionIndex]];
}

- (NSArray *)resultsForSectionWithName:(NSString *)sectionName
{
  return self.searchResultsBySectionName[sectionName];
}

- (NSString *)sectionNameForIndex:(NSInteger)index
{
  if (index > self.sectionNames.count) {
    DDLogWarn(@"sectionNameForIndex exceeds sectionName.count.  index:%d, sectionNames:%@, searchResultsBySectionName:%@",
              (int)index, self.sectionNames.description, self.searchResultsBySectionName.description);
    return nil;
  }
  return self.sectionNames[index];
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



@end
