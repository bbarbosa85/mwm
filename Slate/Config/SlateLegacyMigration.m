//
//  SlateLegacyMigration.m
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

#import "SlateLegacyMigration.h"
#import <Cocoa/Cocoa.h>
#import "SlateConfigDocument.h"
#import "StringTokenizer.h"
#import "SlateLogger.h"

static NSString *Trim(NSString *s) {
  return [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

// Text after the leading #'s of a comment line.
static NSString *CommentBody(NSString *trimmedLine) {
  NSUInteger i = 0;
  while (i < [trimmedLine length] && [trimmedLine characterAtIndex:i] == '#') i++;
  return Trim([trimmedLine substringFromIndex:i]);
}

// Same as the legacy parser: everything from the first # is a comment.
static NSString *StripComment(NSString *line) {
  NSRange hash = [line rangeOfString:@"#"];
  return Trim(hash.location == NSNotFound ? line : [line substringToIndex:hash.location]);
}

static BOOL IsUnderline(NSString *line) {
  NSString *trimmed = Trim(line);
  if (![trimmed hasPrefix:@"#"]) return NO;
  NSString *body = CommentBody(trimmed);
  return [body hasPrefix:@"---"] || [body hasPrefix:@"==="];
}

static NSString *FirstWord(NSString *s) {
  NSMutableString *word = [NSMutableString string];
  [StringTokenizer firstToken:s into:word];
  return word;
}

// "GLOBAL CONFIGURATIONS" -> "Global configurations"
static NSString *SentenceCase(NSString *s) {
  NSString *lower = [s lowercaseString];
  if ([lower length] == 0) return lower;
  return [[[lower substringToIndex:1] uppercaseString] stringByAppendingString:[lower substringFromIndex:1]];
}

static BOOL Matches(NSString *pattern, NSString *s) {
  NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
  return [re numberOfMatchesInString:s options:0 range:NSMakeRange(0, [s length])] == 1;
}

// Legacy config values are strings; type the obvious ones for the GUI.
static id TypedValue(NSString *raw) {
  NSUInteger len = [raw length];
  if (len >= 2) {
    unichar first = [raw characterAtIndex:0];
    if ((first == '"' || first == '\'') && [raw characterAtIndex:len - 1] == first) {
      return [raw substringWithRange:NSMakeRange(1, len - 2)];
    }
  }
  if ([raw isEqualToString:@"true"]) return @YES;
  if ([raw isEqualToString:@"false"]) return @NO;
  if (Matches(@"^-?[0-9]+(\\.[0-9]+)?$", raw)) return @([raw doubleValue]);
  return raw;
}

@implementation SlateLegacyMigration

#pragma mark - Converting

+ (NSMutableArray<SlateConfigEntry *> *)aliasSectionIn:(SlateConfigDocument *)doc name:(NSString *)name value:(NSString *)value {
  NSSet *modifierNames = [NSSet setWithObjects:@"ctrl", @"alt", @"cmd", @"shift", @"fn", nil];
  NSArray *parts = [[value lowercaseString] componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@";,"]];
  BOOL allModifiers = [parts count] > 0;
  for (NSString *part in parts) {
    if (![modifierNames containsObject:part]) allModifiers = NO;
  }
  if (allModifiers) return doc.modifiers;
  if ([name hasPrefix:@"monitor"] || Matches(@"^([0-9]+|[0-9]+x[0-9]+|ordered:[0-9]+)$", value)) return doc.monitors;
  NSString *op = FirstWord(value);
  if ([op isEqualToString:@"move"] || [op isEqualToString:@"corner"]) return doc.positions;
  return doc.aliases;
}

// Parses "bind <key[:mods]> <action>", or returns nil.
+ (SlateBindingEntry *)bindingFromLine:(NSString *)line {
  NSMutableArray *tokens = [NSMutableArray array];
  [StringTokenizer tokenize:line into:tokens maxTokens:3];
  if ([tokens count] < 3 || ![tokens[0] isEqualToString:@"bind"]) return nil;
  NSString *keystroke = tokens[1];
  NSString *action = Trim(tokens[2]);
  if ([action length] == 0) return nil;
  NSRange colon = [keystroke rangeOfString:@":"];
  if (colon.location == NSNotFound) return [SlateBindingEntry bindingWithKey:keystroke modifiers:nil action:action];
  return [SlateBindingEntry bindingWithKey:[keystroke substringToIndex:colon.location]
                                 modifiers:[keystroke substringFromIndex:NSMaxRange(colon)]
                                    action:action];
}

+ (SlateConfigDocument *)documentFromLegacySource:(NSString *)source warnings:(NSMutableArray<NSString *> *)warnings {
  SlateConfigDocument *doc = [[SlateConfigDocument alloc] init];
  NSMutableDictionary<NSString *, NSString *> *aliasValues = [NSMutableDictionary dictionary];
  NSMutableArray<NSString *> *notMigrated = [NSMutableArray array];
  NSMutableArray<NSString *> *inactive = [NSMutableArray array];
  NSMutableArray<NSString *> *noteLines = [NSMutableArray array];
  NSString *group = nil;

  NSArray<NSString *> *lines = [source componentsSeparatedByString:@"\n"];
  for (NSUInteger i = 0; i < [lines count]; i++) {
    NSString *line = Trim(lines[i]);
    NSUInteger lineNumber = i + 1;

    if ([line length] == 0) {
      [noteLines removeAllObjects];
      continue;
    }

    if ([line hasPrefix:@"#"]) {
      if (IsUnderline(line)) continue;
      NSString *body = CommentBody(line);
      if ([body length] == 0) continue;
      if (i + 1 < [lines count] && IsUnderline(lines[i + 1])) {
        group = SentenceCase(body);
        [noteLines removeAllObjects];
        continue;
      }
      // Prose that happens to start with "alias" or "bind" is a note, not a directive.
      BOOL prose = [body rangeOfString:@". "].location != NSNotFound;
      NSString *directive = prose ? @"" : FirstWord(body);
      if ([directive isEqualToString:@"bind"]) {
        SlateBindingEntry *binding = [self bindingFromLine:StripComment(body)];
        if (binding != nil) {
          binding.enabled = NO;
          binding.group = group;
          if ([noteLines count] > 0) binding.note = [noteLines componentsJoinedByString:@" "];
          [doc.bindings addObject:binding];
          continue;
        }
      }
      if ([@[@"bind", @"config", @"alias", @"layout", @"default", @"source"] containsObject:directive]) {
        [inactive addObject:body];
      } else {
        [noteLines addObject:body];
      }
      continue;
    }

    NSString *content = StripComment(line);
    if ([content length] == 0) continue;
    NSString *directive = FirstWord(content);

    if ([directive isEqualToString:@"config"]) {
      NSMutableArray *tokens = [NSMutableArray array];
      [StringTokenizer tokenize:content into:tokens];
      if ([tokens count] >= 3 && [tokens[1] rangeOfString:@":"].location == NSNotFound) {
        NSString *name = tokens[1];
        id value = TypedValue(tokens[2]);
        NSUInteger existing = [[doc.settings valueForKey:@"name"] indexOfObject:name];
        if (existing == NSNotFound) {
          [doc.settings addObject:[SlateConfigEntry entryWithName:name value:value]];
        } else {
          doc.settings[existing].value = value;  // later lines win, as before
        }
        continue;
      }
      [warnings addObject:[NSString stringWithFormat:@"Line %lu: per-app configs aren't supported yet: %@", (unsigned long)lineNumber, content]];
      [notMigrated addObject:content];
      continue;
    }

    if ([directive isEqualToString:@"alias"]) {
      NSMutableArray *tokens = [NSMutableArray array];
      [StringTokenizer tokenize:content into:tokens maxTokens:3];
      if ([tokens count] >= 3) {
        NSString *name = tokens[1];
        NSString *value = Trim(tokens[2]);
        if (aliasValues[name] == nil) {
          aliasValues[name] = value;
          [[self aliasSectionIn:doc name:name value:value] addObject:[SlateConfigEntry entryWithName:name value:value]];
          continue;
        }
        if ([aliasValues[name] isEqualToString:value]) continue;
        [warnings addObject:[NSString stringWithFormat:@"Line %lu: alias \"%@\" is defined twice with different values; kept the first one.", (unsigned long)lineNumber, name]];
        [notMigrated addObject:content];
        continue;
      }
    }

    if ([directive isEqualToString:@"bind"]) {
      SlateBindingEntry *binding = [self bindingFromLine:content];
      if (binding != nil) {
        binding.group = group;
        if ([noteLines count] > 0) binding.note = [noteLines componentsJoinedByString:@" "];
        [doc.bindings addObject:binding];
        continue;
      }
    }

    NSString *reason = [@[@"layout", @"default", @"source"] containsObject:directive]
      ? [NSString stringWithFormat:@"\"%@\" lines aren't supported by the configuration window yet", directive]
      : @"couldn't be read";
    [warnings addObject:[NSString stringWithFormat:@"Line %lu %@: %@", (unsigned long)lineNumber, reason, content]];
    [notMigrated addObject:content];
  }

  NSMutableString *custom = [NSMutableString string];
  if ([notMigrated count] > 0) {
    [custom appendString:@"// From ~/.slate: these lines were active but couldn't be migrated.\n"
                         @"// Rewrite them as JavaScript to keep using them.\n"];
    for (NSString *line in notMigrated) [custom appendFormat:@"// %@\n", line];
  }
  if ([inactive count] > 0) {
    if ([custom length] > 0) [custom appendString:@"\n"];
    [custom appendString:@"// From ~/.slate: these lines were commented out there.\n"];
    for (NSString *line in inactive) [custom appendFormat:@"// %@\n", line];
  }
  doc.customCode = custom;
  return doc;
}

#pragma mark - Merging

+ (NSString *)sectionName:(NSArray *)section in:(SlateConfigDocument *)doc {
  if (section == doc.modifiers) return @"modifiers";
  if (section == doc.monitors) return @"monitors";
  if (section == doc.positions) return @"positions";
  return @"aliases";
}

+ (SlateConfigDocument *)documentByMergingLegacy:(SlateConfigDocument *)legacy
                                   intoJavaScript:(NSString *)javaScript
                                         warnings:(NSMutableArray<NSString *> *)warnings {
  NSError *readError = nil;
  SlateConfigDocument *js = [SlateConfigDocument documentFromString:javaScript error:&readError];
  if (js == nil) {
    // Hand-written JS: it ran after ~/.slate before, and still does as custom code.
    SlateConfigDocument *merged = legacy;
    NSString *separator = [legacy.customCode length] > 0 ? @"\n" : @"";
    merged.customCode = [NSString stringWithFormat:@"%@%@// From ~/.slate.js:\n%@", legacy.customCode, separator, javaScript];
    return merged;
  }

  // ~/.slate loaded first, so ~/.slate.js wins wherever both set something.
  NSArray *jsSettingNames = [js.settings valueForKey:@"name"];
  NSMutableArray *settings = [NSMutableArray array];
  for (SlateConfigEntry *entry in legacy.settings) {
    if (![jsSettingNames containsObject:entry.name]) [settings addObject:entry];
  }
  [settings addObjectsFromArray:js.settings];
  js.settings = settings;

  NSMutableDictionary *jsAliases = [NSMutableDictionary dictionary];
  for (NSArray<SlateConfigEntry *> *section in @[js.modifiers, js.monitors, js.positions, js.aliases]) {
    for (SlateConfigEntry *entry in section) jsAliases[entry.name] = entry;
  }
  NSArray *legacySections = @[legacy.modifiers, legacy.monitors, legacy.positions, legacy.aliases];
  NSArray *jsSections = @[js.modifiers, js.monitors, js.positions, js.aliases];
  for (NSUInteger s = 0; s < [legacySections count]; s++) {
    for (SlateConfigEntry *entry in legacySections[s]) {
      SlateConfigEntry *existing = jsAliases[entry.name];
      if (existing == nil) {
        [jsSections[s] addObject:entry];
      } else if (![[existing.value description] isEqualToString:[entry.value description]]) {
        [warnings addObject:[NSString stringWithFormat:@"Alias \"%@\" differs between ~/.slate and ~/.slate.js; kept the ~/.slate.js value.", entry.name]];
      }
    }
  }

  NSMutableArray *bindings = [NSMutableArray arrayWithArray:legacy.bindings];
  [bindings addObjectsFromArray:js.bindings];
  js.bindings = bindings;

  if ([legacy.customCode length] > 0) {
    js.customCode = [NSString stringWithFormat:@"%@\n%@", js.customCode, legacy.customCode];
  }
  return js;
}

#pragma mark - Files

// <path>.<suffix>-<timestamp>, so repeated runs never collide.
+ (NSString *)backupPathFor:(NSString *)path suffix:(NSString *)suffix {
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
  formatter.dateFormat = @"yyyyMMdd-HHmmss";
  return [NSString stringWithFormat:@"%@.%@-%@", path, suffix, [formatter stringFromDate:[NSDate date]]];
}

+ (nullable NSString *)migrateLegacyFile:(NSString *)legacyPath
                                  toFile:(NSString *)jsPath
                                warnings:(NSMutableArray<NSString *> *)warnings
                                   error:(NSError **)error {
  legacyPath = [legacyPath stringByExpandingTildeInPath];
  jsPath = [jsPath stringByExpandingTildeInPath];
  NSFileManager *fm = [NSFileManager defaultManager];

  NSString *legacySource = [NSString stringWithContentsOfFile:legacyPath encoding:NSUTF8StringEncoding error:error];
  if (legacySource == nil) return nil;
  SlateConfigDocument *doc = [self documentFromLegacySource:legacySource warnings:warnings];

  BOOL jsExisted = [fm fileExistsAtPath:jsPath];
  if (jsExisted) {
    NSString *javaScript = [NSString stringWithContentsOfFile:jsPath encoding:NSUTF8StringEncoding error:error];
    if (javaScript == nil) return nil;
    doc = [self documentByMergingLegacy:doc intoJavaScript:javaScript warnings:warnings];
  }

  // Refuse to write something the configuration window couldn't read back.
  if ([SlateConfigDocument documentFromString:[doc stringRepresentation] error:error] == nil) return nil;
  if (![doc writeToFile:jsPath error:error]) return nil;

  NSString *backup = [self backupPathFor:legacyPath suffix:@"migrated"];
  // Renames a symlinked ~/.slate itself, leaving its target untouched.
  if (![fm moveItemAtPath:legacyPath toPath:backup error:error]) {
    // Undo the write so the next launch isn't left with both files merged once already.
    NSString *target = [jsPath stringByResolvingSymlinksInPath];
    if (jsExisted) {
      NSString *jsBackup = [target stringByAppendingString:@".bak"];
      [fm removeItemAtPath:target error:nil];
      [fm moveItemAtPath:jsBackup toPath:target error:nil];
    } else {
      [fm removeItemAtPath:target error:nil];
    }
    return nil;
  }
  return backup;
}

#pragma mark - Startup

+ (void)showMigrationResult:(NSString *)backup warnings:(NSArray<NSString *> *)warnings {
  NSAlert *alert = [[NSAlert alloc] init];
  [alert setMessageText:@"Slate now uses ~/.slate.js"];
  NSMutableString *info = [NSMutableString stringWithFormat:
    @"Your ~/.slate configuration was moved to ~/.slate.js. The original file is saved as %@.",
    [backup stringByAbbreviatingWithTildeInPath]];
  if ([warnings count] > 0) {
    [alert setAlertStyle:NSAlertStyleWarning];
    [info appendString:@"\n\nSome lines need your attention. They're kept as comments at the end of ~/.slate.js:\n"];
    NSUInteger shown = MIN([warnings count], (NSUInteger)8);
    for (NSUInteger i = 0; i < shown; i++) [info appendFormat:@"\n• %@", warnings[i]];
    if ([warnings count] > shown) [info appendFormat:@"\n• …and %lu more", (unsigned long)([warnings count] - shown)];
  }
  [alert setInformativeText:info];
  [alert addButtonWithTitle:@"OK"];
  [alert runModal];
}

+ (void)showMigrationFailure:(NSError *)error {
  NSAlert *alert = [[NSAlert alloc] init];
  [alert setAlertStyle:NSAlertStyleWarning];
  [alert setMessageText:@"Couldn't move ~/.slate to ~/.slate.js"];
  [alert setInformativeText:[NSString stringWithFormat:
    @"%@\n\nNothing was changed, and Slate will keep loading ~/.slate.", [error localizedDescription]]];
  [alert addButtonWithTitle:@"OK"];
  [alert runModal];
}

+ (void)runStartupMigration {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *legacyPath = [@"~/.slate" stringByExpandingTildeInPath];
  NSString *jsPath = [SlateConfigDocument defaultPath];
  if (![fm fileExistsAtPath:legacyPath]) return;

  if ([fm fileExistsAtPath:jsPath]) {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Merge ~/.slate into ~/.slate.js?"];
    [alert setInformativeText:
      @"Slate now keeps its configuration in ~/.slate.js. You have both files, so Slate can merge "
      @"~/.slate into ~/.slate.js, where ~/.slate.js wins if both set the same thing. "
      @"Either way, ~/.slate is kept as a backup."];
    [alert addButtonWithTitle:@"Merge"];
    [alert addButtonWithTitle:@"Not now"];
    [alert addButtonWithTitle:@"Stop using ~/.slate"];
    NSModalResponse response = [alert runModal];
    if (response == NSAlertSecondButtonReturn) {
      SlateLogger(@"Legacy migration postponed; loading both files.");
      return;
    }
    if (response == NSAlertThirdButtonReturn) {
      NSError *error = nil;
      NSString *backup = [self backupPathFor:legacyPath suffix:@"unused"];
      if (![fm moveItemAtPath:legacyPath toPath:backup error:&error]) [self showMigrationFailure:error];
      return;
    }
  }

  NSMutableArray<NSString *> *warnings = [NSMutableArray array];
  NSError *error = nil;
  NSString *backup = [self migrateLegacyFile:legacyPath toFile:jsPath warnings:warnings error:&error];
  if (backup == nil) {
    SlateLogger(@"Legacy migration failed: %@", error);
    [self showMigrationFailure:error];
    return;
  }
  SlateLogger(@"Migrated ~/.slate to ~/.slate.js (backup: %@, %lu warnings)", backup, (unsigned long)[warnings count]);
  [self showMigrationResult:backup warnings:warnings];
}

@end
