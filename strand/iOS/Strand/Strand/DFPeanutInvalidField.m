//
//  DFPeanutErrorResponse.m
//  Strand
//
//  Created by Henry Bridge on 7/11/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutInvalidField.h"
#import "RestKit/RestKit.h"

@implementation DFPeanutInvalidField

+ (RKObjectMapping *)objectMapping {
  RKObjectMapping *mapping = [RKObjectMapping mappingForClass:[self class]];
  mapping.forceCollectionMapping = YES;
  [mapping addAttributeMappingFromKeyOfRepresentationToAttribute:@"field_name"];
  [mapping addAttributeMappingsFromDictionary:@{@"(field_name)": @"field_errors"}];
  return mapping;
}

+ (NSError *)invalidFieldsErrorForError:(NSError *)error
{
  NSArray *invalidFields = error.userInfo[RKObjectMapperErrorObjectsKey];
  if (invalidFields && invalidFields.count > 0) {
    NSMutableString *invalidFieldsString = [[NSMutableString alloc] init];
    for (DFPeanutInvalidField *invalidField in invalidFields) {
      [invalidFieldsString appendString:[NSString stringWithFormat:@"%@: %@. ",
                                         invalidField.field_name,
                                         invalidField.field_errors.firstObject]];
    }
    
    
    NSError *betterError = [NSError errorWithDomain:@"com.duffyapp.duffy"
                                      code:-11 userInfo:@{
                                                          NSLocalizedDescriptionKey: invalidFieldsString
                                                          }];
    return betterError;
  }
  
  return error;
}

@end
