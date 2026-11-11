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
#import <JavaScriptCore/JavaScriptCore.h>
#import "Binding.h"
#import "Operation.h"
#import "SlateConfig.h"
#import "JSInfoWrapper.h"

static NSString *const kSourceName = @"/slate-config.js";

// A stand-in for JSController: records what the config asks for, never binds
// keys or runs operations/shell commands. __line() finds the calling line in
// the config file from the JS stack.
static NSString *const kStubController =
  @"var window = this;\n"
  @"var __calls = [];\n"
  @"function __line() {\n"
  @"  var m = String((new Error()).stack || '').match(/slate-config\\.js:(\\d+)/);\n"
  @"  return m ? parseInt(m[1], 10) : 0;\n"
  @"}\n"
  @"function __op() { return { __validatorOperation: true }; }\n"
  @"var _controller = {\n"
  @"  log: function() {},\n"
  @"  configNative: function(k) { __calls.push({ kind: 'config', key: k, line: __line() }); },\n"
  @"  configFunction: function(k) { __calls.push({ kind: 'config', key: k, line: __line() }); },\n"
  @"  bindString: function(h, a) { __calls.push({ kind: 'bindString', hotkey: h, action: a, line: __line() }); },\n"
  @"  bindNative: function(h) { __calls.push({ kind: 'bindKey', hotkey: h, line: __line() }); },\n"
  @"  bindFunction: function(h) { __calls.push({ kind: 'bindKey', hotkey: h, line: __line() }); },\n"
  @"  operationFromString: function(s) { __calls.push({ kind: 'operation', action: s, line: __line() }); return __op(); },\n"
  @"  operation: function() { return __op(); },\n"
  @"  doOperation: function() { return true; },\n"
  @"  layout: function(name) { return name; },\n"
  @"  'default': function() {},\n"
  @"  shell: function() { return ''; },\n"
  @"  on: function() {},\n"
  @"  source: function() { return true; }\n"
  @"};\n";

// Records managed bindings with their index so errors can point at their line.
static NSString *const kApplyConfigOverride =
  @"slate.applyConfig = function(config) {\n"
  @"  var line = __line();\n"
  @"  var resolved;\n"
  @"  try { resolved = _slateManagedConfig.resolve(config); }\n"
  @"  catch (e) { __calls.push({ kind: 'error', message: String(e), line: line }); return; }\n"
  @"  resolved.settings.forEach(function(s) { __calls.push({ kind: 'config', key: s.name, line: line }); });\n"
  @"  resolved.bindings.forEach(function(b) {\n"
  @"    __calls.push({ kind: 'bindString', hotkey: b.hotkey, action: b.action, index: b.index, line: line });\n"
  @"  });\n"
  @"};\n";

@implementation SlateConfigIssue

+ (instancetype)issueWithError:(BOOL)isError message:(NSString *)message line:(NSUInteger)line {
  SlateConfigIssue *issue = [[self alloc] init];
  issue.isError = isError;
  issue.message = message;
  issue.line = line;
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

// Line numbers of each `{ ... }` entry in a managed `bindings: [` array.
+ (NSArray<NSNumber *> *)managedBindingLines:(NSString *)source {
  NSMutableArray *lines = [NSMutableArray array];
  BOOL inBindings = NO;
  NSArray *all = [source componentsSeparatedByString:@"\n"];
  for (NSUInteger i = 0; i < [all count]; i++) {
    NSString *line = [all[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (!inBindings) {
      if ([line hasPrefix:@"bindings:"]) inBindings = YES;
      continue;
    }
    if ([line hasPrefix:@"]"]) break;
    if ([line hasPrefix:@"{"]) [lines addObject:@(i + 1)];
  }
  return lines;
}

+ (void)loadRuntimeInto:(JSContext *)context {
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  for (NSString *script in @[@"underscore", @"utils", @"managed-config", @"initialize"]) {
    NSString *path = [bundle pathForResource:script ofType:@"js"];
    [context evaluateScript:[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil]];
  }
}

+ (SlateConfigValidationResult *)validateSource:(NSString *)source {
  NSMutableArray<SlateConfigIssue *> *issues = [NSMutableArray array];
  SlateConfigValidationResult *result = [[SlateConfigValidationResult alloc] init];

  JSContext *context = [[JSContext alloc] init];
  [context evaluateScript:kStubController];
  JSValue *info = [JSValue valueWithNewObjectInContext:context];
  for (NSString *method in [[JSInfoWrapper getInstance] jsMethods]) {
    BOOL isCount = [method isEqualToString:@"screenCount"] || [method isEqualToString:@"screenc"];
    info[method] = [context evaluateScript:isCount ? @"(function() { return 1; })" : @"(function() { return null; })"];
  }
  info[@"jsMethods"] = ^NSArray *{ return [[JSInfoWrapper getInstance] jsMethods]; };
  context[@"_info"] = info;
  [self loadRuntimeInto:context];
  if (context.exception != nil) {
    [issues addObject:[SlateConfigIssue issueWithError:YES message:[@"Slate's scripting runtime failed to load: " stringByAppendingString:[context.exception toString]] line:0]];
    result.issues = issues;
    return result;
  }
  [context evaluateScript:kApplyConfigOverride];

  [context evaluateScript:source withSourceURL:[NSURL fileURLWithPath:kSourceName]];
  if (context.exception != nil) {
    JSValue *line = context.exception[@"line"];
    [issues addObject:[SlateConfigIssue issueWithError:YES
                                               message:[context.exception toString]
                                                  line:[line isNumber] ? [[line toNumber] unsignedIntegerValue] : 0]];
  }

  NSArray<NSNumber *> *bindingLines = [self managedBindingLines:source];
  NSMutableDictionary<NSString *, NSNumber *> *seenHotkeys = [NSMutableDictionary dictionary];
  SlateConfig *config = [SlateConfig getInstance];

  for (NSDictionary *call in [context[@"__calls"] toArray]) {
    NSString *kind = call[@"kind"];
    NSUInteger line = [call[@"line"] unsignedIntegerValue];
    NSNumber *index = call[@"index"];
    if (index != nil && [index unsignedIntegerValue] < [bindingLines count]) {
      line = [bindingLines[[index unsignedIntegerValue]] unsignedIntegerValue];
    }

    if ([kind isEqualToString:@"error"]) {
      [issues addObject:[SlateConfigIssue issueWithError:YES message:call[@"message"] line:line]];
    } else if ([kind isEqualToString:@"config"]) {
      result.settingCount++;
      if ([config getConfigDefault:call[@"key"]] == nil) {
        [issues addObject:[SlateConfigIssue issueWithError:NO message:[NSString stringWithFormat:@"\"%@\" isn't a setting Slate knows about.", call[@"key"]] line:line]];
      }
    } else if ([kind isEqualToString:@"bindString"] || [kind isEqualToString:@"bindKey"]) {
      result.bindingCount++;
      NSString *hotkey = call[@"hotkey"];
      @try {
        if ([kind isEqualToString:@"bindString"]) {
          (void)[[Binding alloc] initWithString:[NSString stringWithFormat:@"bind %@ %@", hotkey, call[@"action"]]];
        } else {
          (void)[Binding getKeystrokeFromString:hotkey];
        }
      } @catch (NSException *ex) {
        [issues addObject:[SlateConfigIssue issueWithError:YES message:[NSString stringWithFormat:@"%@: %@", hotkey, [ex reason] ?: [ex name]] line:line]];
      }
      NSNumber *firstLine = seenHotkeys[hotkey];
      if (firstLine == nil) {
        seenHotkeys[hotkey] = @(line);
      } else {
        [issues addObject:[SlateConfigIssue issueWithError:NO
                                                   message:[NSString stringWithFormat:@"%@ is also bound on line %@.", hotkey, firstLine]
                                                      line:line]];
      }
    } else if ([kind isEqualToString:@"operation"]) {
      @try {
        if ([Operation operationFromString:call[@"action"]] == nil) {
          [issues addObject:[SlateConfigIssue issueWithError:YES message:[NSString stringWithFormat:@"Unknown operation \"%@\".", call[@"action"]] line:line]];
        }
      } @catch (NSException *ex) {
        [issues addObject:[SlateConfigIssue issueWithError:YES message:[NSString stringWithFormat:@"\"%@\": %@", call[@"action"], [ex reason] ?: [ex name]] line:line]];
      }
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
