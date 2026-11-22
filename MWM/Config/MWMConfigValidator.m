//
//  MWMConfigValidator.m
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

#import "MWMConfigValidator.h"
#import "Binding.h"
#import "MWMConfig.h"
#import "MWMConfigDocument.h"
#import "MWMShortcut.h"

@implementation MWMConfigIssue

- (instancetype)init {
  self = [super init];
  if (self) _bindingIndex = NSNotFound;
  return self;
}

+ (instancetype)issueWithError:(BOOL)isError message:(NSString *)message line:(NSUInteger)line {
  MWMConfigIssue *issue = [[self alloc] init];
  issue.isError = isError;
  issue.message = message;
  issue.line = line;
  return issue;
}

+ (instancetype)issueFromError:(NSError *)error {
  MWMConfigIssue *issue = [self issueWithError:YES message:[error localizedDescription]
                                            line:[error.userInfo[MWMConfigDocumentErrorLineKey] unsignedIntegerValue]];
  NSNumber *index = error.userInfo[MWMConfigDocumentErrorBindingIndexKey];
  if (index != nil) issue.bindingIndex = [index unsignedIntegerValue];
  issue.entryName = error.userInfo[MWMConfigDocumentErrorEntryNameKey];
  return issue;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"%@ line %lu: %@", self.isError ? @"error" : @"warning", (unsigned long)self.line, self.message];
}

@end

@implementation MWMConfigValidationResult

- (NSUInteger)errorCount {
  return [[self.issues filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isError == YES"]] count];
}

- (NSUInteger)warningCount {
  return [self.issues count] - [self errorCount];
}

@end

@implementation MWMConfigValidator

+ (MWMConfigValidationResult *)validateSource:(NSString *)source {
  NSMutableArray<MWMConfigIssue *> *issues = [NSMutableArray array];
  MWMConfigValidationResult *result = [[MWMConfigValidationResult alloc] init];

  NSError *readError = nil;
  MWMConfigDocument *doc = [MWMConfigDocument documentFromString:source lenient:YES error:&readError];
  if (doc == nil) {
    [issues addObject:[MWMConfigIssue issueFromError:readError]];
    result.issues = issues;
    return result;
  }

  NSMutableArray<NSError *> *errors = [NSMutableArray array];
  MWMResolvedConfig *resolved = [doc resolveCollectingErrors:errors];
  for (NSError *error in errors) [issues addObject:[MWMConfigIssue issueFromError:error]];

  MWMConfig *config = [MWMConfig getInstance];
  for (MWMConfigEntry *setting in doc.settings) {
    result.settingCount++;
    if ([config getConfigDefault:setting.name] == nil) {
      MWMConfigIssue *issue = [MWMConfigIssue issueWithError:NO
                                                         message:[NSString stringWithFormat:@"\"%@\" isn't a setting MWM knows about.", setting.name]
                                                            line:setting.line];
      issue.entryName = setting.name;
      [issues addObject:issue];
    }
  }

  NSMutableDictionary<NSString *, NSNumber *> *seenHotkeys = [NSMutableDictionary dictionary];
  for (MWMResolvedBinding *binding in resolved.bindings) {
    result.bindingCount++;
    MWMBindingEntry *entry = doc.bindings[binding.index];
    NSString *label = [NSString stringWithFormat:@"Binding #%lu (%@)", (unsigned long)binding.index + 1, binding.hotkey];
    @try {
      (void)[[Binding alloc] initWithString:[NSString stringWithFormat:@"bind %@ %@", binding.hotkey, binding.action]];
    } @catch (NSException *ex) {
      MWMConfigIssue *issue = [MWMConfigIssue issueWithError:YES
                                                         message:[NSString stringWithFormat:@"%@: %@", label, [ex reason] ?: [ex name]]
                                                            line:entry.line];
      issue.bindingIndex = binding.index;
      [issues addObject:issue];
    }
    // Same keys whatever order the modifiers are written in.
    NSRange colon = [binding.hotkey rangeOfString:@":"];
    NSString *identity = [MWMShortcut identityForKey:colon.location == NSNotFound ? binding.hotkey : [binding.hotkey substringToIndex:colon.location]
                                            modifiers:colon.location == NSNotFound ? nil : [binding.hotkey substringFromIndex:NSMaxRange(colon)]]
                         ?: binding.hotkey;
    NSNumber *first = seenHotkeys[identity];
    if (first == nil) {
      seenHotkeys[identity] = @(binding.index);
    } else {
      MWMConfigIssue *issue = [MWMConfigIssue issueWithError:NO
                                                         message:[NSString stringWithFormat:@"%@ uses the same keys as binding #%lu.", label, [first unsignedIntegerValue] + 1]
                                                            line:entry.line];
      issue.bindingIndex = binding.index;
      [issues addObject:issue];
    }
  }

  [issues sortUsingComparator:^NSComparisonResult(MWMConfigIssue *a, MWMConfigIssue *b) {
    if (a.isError != b.isError) return a.isError ? NSOrderedAscending : NSOrderedDescending;
    if (a.line == b.line) return NSOrderedSame;
    return a.line < b.line ? NSOrderedAscending : NSOrderedDescending;
  }];
  result.issues = issues;
  return result;
}

@end
