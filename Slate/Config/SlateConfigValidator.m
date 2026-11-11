//
//  SlateConfigValidator.m
//  Slate
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see http://www.gnu.org/licenses

#import "SlateConfigValidator.h"
#import "Binding.h"
#import "SlateConfig.h"
#import "SlateConfigDocument.h"

@implementation SlateConfigIssue

- (instancetype)init {
  self = [super init];
  if (self) _bindingIndex = NSNotFound;
  return self;
}

+ (instancetype)issueWithError:(BOOL)isError message:(NSString *)message line:(NSUInteger)line {
  SlateConfigIssue *issue = [[self alloc] init];
  issue.isError = isError;
  issue.message = message;
  issue.line = line;
  return issue;
}

+ (instancetype)issueFromError:(NSError *)error {
  SlateConfigIssue *issue = [self issueWithError:YES message:[error localizedDescription]
                                            line:[error.userInfo[SlateConfigDocumentErrorLineKey] unsignedIntegerValue]];
  NSNumber *index = error.userInfo[SlateConfigDocumentErrorBindingIndexKey];
  if (index != nil) issue.bindingIndex = [index unsignedIntegerValue];
  issue.entryName = error.userInfo[SlateConfigDocumentErrorEntryNameKey];
  return issue;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"%@ line %lu: %@", self.isError ? @"error" : @"warning", (unsigned long)self.line, self.message];
}

@end

@implementation SlateConfigValidationResult

- (NSUInteger)errorCount {
  return [[self.issues filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isError == YES"]] count];
}

- (NSUInteger)warningCount {
  return [self.issues count] - [self errorCount];
}

@end

@implementation SlateConfigValidator

+ (SlateConfigValidationResult *)validateSource:(NSString *)source {
  NSMutableArray<SlateConfigIssue *> *issues = [NSMutableArray array];
  SlateConfigValidationResult *result = [[SlateConfigValidationResult alloc] init];

  NSError *readError = nil;
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:source lenient:YES error:&readError];
  if (doc == nil) {
    [issues addObject:[SlateConfigIssue issueFromError:readError]];
    result.issues = issues;
    return result;
  }

  NSMutableArray<NSError *> *errors = [NSMutableArray array];
  SlateResolvedConfig *resolved = [doc resolveCollectingErrors:errors];
  for (NSError *error in errors) [issues addObject:[SlateConfigIssue issueFromError:error]];

  SlateConfig *config = [SlateConfig getInstance];
  for (SlateConfigEntry *setting in doc.settings) {
    result.settingCount++;
    if ([config getConfigDefault:setting.name] == nil) {
      SlateConfigIssue *issue = [SlateConfigIssue issueWithError:NO
                                                         message:[NSString stringWithFormat:@"\"%@\" isn't a setting MWM knows about.", setting.name]
                                                            line:setting.line];
      issue.entryName = setting.name;
      [issues addObject:issue];
    }
  }

  NSMutableDictionary<NSString *, NSNumber *> *seenHotkeys = [NSMutableDictionary dictionary];
  for (SlateResolvedBinding *binding in resolved.bindings) {
    result.bindingCount++;
    SlateBindingEntry *entry = doc.bindings[binding.index];
    NSString *label = [NSString stringWithFormat:@"Binding #%lu (%@)", (unsigned long)binding.index + 1, binding.hotkey];
    @try {
      (void)[[Binding alloc] initWithString:[NSString stringWithFormat:@"bind %@ %@", binding.hotkey, binding.action]];
    } @catch (NSException *ex) {
      SlateConfigIssue *issue = [SlateConfigIssue issueWithError:YES
                                                         message:[NSString stringWithFormat:@"%@: %@", label, [ex reason] ?: [ex name]]
                                                            line:entry.line];
      issue.bindingIndex = binding.index;
      [issues addObject:issue];
    }
    NSNumber *first = seenHotkeys[binding.hotkey];
    if (first == nil) {
      seenHotkeys[binding.hotkey] = @(binding.index);
    } else {
      SlateConfigIssue *issue = [SlateConfigIssue issueWithError:NO
                                                         message:[NSString stringWithFormat:@"%@ uses the same keys as binding #%lu.", label, [first unsignedIntegerValue] + 1]
                                                            line:entry.line];
      issue.bindingIndex = binding.index;
      [issues addObject:issue];
    }
  }

  [issues sortUsingComparator:^NSComparisonResult(SlateConfigIssue *a, SlateConfigIssue *b) {
    if (a.isError != b.isError) return a.isError ? NSOrderedAscending : NSOrderedDescending;
    if (a.line == b.line) return NSOrderedSame;
    return a.line < b.line ? NSOrderedAscending : NSOrderedDescending;
  }];
  result.issues = issues;
  return result;
}

@end
