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
#import <JavaScriptCore/JavaScriptCore.h>
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

  if ([notMigrated count] > 0) {
    [warnings addObject:@"Lines that couldn't be converted are still in the backup of ~/.slate."];
  }
  if ([inactive count] > 0) {
    [warnings addObject:[NSString stringWithFormat:@"%lu commented-out line%@ (like \"%@\") weren't carried over; they're still in the backup of ~/.slate.",
                         (unsigned long)[inactive count], [inactive count] == 1 ? @"" : @"s", inactive[0]]];
  }
  return doc;
}

#pragma mark - ~/.slate.js

// A stand-in `slate` that only records applyConfig calls. The file runs in a
// bare JSContext: no Slate API, no files, no shell.
static NSString *const kCapturePrelude =
  @"var window = this;\n"
  @"var __slateCaptured = [];\n"
  @"var slate = { applyConfig: function(c) { __slateCaptured.push(c); } };\n"
  @"var S = slate;\n";

// Turns the captured config into plain data (objects become [{name, value}]).
static NSString *const kExportFunction =
  @"(function(c) {\n"
  @"  function pairs(o) {\n"
  @"    if (o === undefined || o === null || typeof o !== 'object') return [];\n"
  @"    return Object.keys(o).map(function(k) {\n"
  @"      var v = o[k];\n"
  @"      if (Array.isArray(v)) v = v.join(';');\n"
  @"      if (typeof v !== 'boolean' && typeof v !== 'number') v = String(v);\n"
  @"      return { name: k, value: v };\n"
  @"    });\n"
  @"  }\n"
  @"  function opt(v) { return (v === undefined || v === null) ? null : String(v); }\n"
  @"  return {\n"
  @"    settings: pairs(c.settings), modifiers: pairs(c.modifiers), monitors: pairs(c.monitors),\n"
  @"    positions: pairs(c.positions), aliases: pairs(c.aliases),\n"
  @"    bindings: (Array.isArray(c.bindings) ? c.bindings : []).map(function(b) {\n"
  @"      b = b || {};\n"
  @"      return { group: opt(b.group), key: String(b.key), mods: opt(b.mods), action: String(b.action), note: opt(b.note),\n"
  @"               enabled: b.enabled !== false, repeat: typeof b.repeat === 'boolean' ? b.repeat : null };\n"
  @"    })\n"
  @"  };\n"
  @"})";

static NSString *const kCustomCodeMarkerPrefix = @"// ---- Custom code";

static NSError *MigrationError(NSString *message) {
  return [NSError errorWithDomain:SlateConfigDocumentErrorDomain code:SlateConfigDocumentErrorInvalid
                         userInfo:@{NSLocalizedDescriptionKey: message}];
}

static id NilIfNull(id value) {
  return (value == nil || value == [NSNull null]) ? nil : value;
}

+ (SlateConfigDocument *)documentFromJavaScript:(NSString *)javaScript warnings:(NSMutableArray<NSString *> *)warnings error:(NSError **)error {
  NSString *managed = javaScript;
  NSString *custom = @"";
  NSRange marker = [javaScript rangeOfString:[@"\n" stringByAppendingString:kCustomCodeMarkerPrefix]];
  if ([javaScript hasPrefix:kCustomCodeMarkerPrefix]) marker = NSMakeRange(0, 0);
  if (marker.location != NSNotFound) {
    managed = [javaScript substringToIndex:marker.location];
    NSRange lineEnd = [javaScript rangeOfString:@"\n" options:0 range:NSMakeRange(NSMaxRange(marker), [javaScript length] - NSMaxRange(marker))];
    custom = lineEnd.location == NSNotFound ? @"" : [javaScript substringFromIndex:NSMaxRange(lineEnd)];
  }

  JSContext *context = [[JSContext alloc] init];
  [context evaluateScript:kCapturePrelude];
  [context evaluateScript:managed];
  if (context.exception != nil) {
    if (error) *error = MigrationError([NSString stringWithFormat:
      @"~/.slate.js isn't a file written by the configuration window, so it can't be converted (%@).", [context.exception toString]]);
    return nil;
  }
  if ([[context[@"__slateCaptured"][@"length"] toNumber] unsignedIntegerValue] != 1) {
    if (error) *error = MigrationError(@"~/.slate.js isn't a file written by the configuration window (it doesn't call slate.applyConfig once), so it can't be converted.");
    return nil;
  }
  NSDictionary *data = [[[context evaluateScript:kExportFunction] callWithArguments:@[context[@"__slateCaptured"][0]]] toDictionary];
  if (context.exception != nil || data == nil) {
    if (error) *error = MigrationError([NSString stringWithFormat:@"Couldn't read the configuration in ~/.slate.js (%@).", [context.exception toString] ?: @"no data"]);
    return nil;
  }

  SlateConfigDocument *doc = [[SlateConfigDocument alloc] init];
  NSDictionary *sections = @{@"settings": doc.settings, @"modifiers": doc.modifiers, @"monitors": doc.monitors,
                             @"positions": doc.positions, @"aliases": doc.aliases};
  for (NSString *section in sections) {
    for (NSDictionary *pair in data[section]) {
      [sections[section] addObject:[SlateConfigEntry entryWithName:pair[@"name"] value:pair[@"value"]]];
    }
  }
  for (NSDictionary *b in data[@"bindings"]) {
    SlateBindingEntry *binding = [SlateBindingEntry bindingWithKey:b[@"key"] modifiers:NilIfNull(b[@"mods"]) action:b[@"action"]];
    binding.group = NilIfNull(b[@"group"]);
    binding.note = NilIfNull(b[@"note"]);
    binding.enabled = [b[@"enabled"] boolValue];
    binding.repeat = NilIfNull(b[@"repeat"]);
    [doc.bindings addObject:binding];
  }

  NSUInteger codeLines = 0, commentLines = 0;
  for (NSString *line in [custom componentsSeparatedByString:@"\n"]) {
    NSString *trimmed = Trim(line);
    if ([trimmed length] == 0) continue;
    if ([trimmed hasPrefix:@"//"]) commentLines++; else codeLines++;
  }
  if (codeLines > 0) {
    [warnings addObject:@"The custom JavaScript at the end of ~/.slate.js wasn't carried over, because MWM no longer runs JavaScript. It's still in the backup of ~/.slate.js."];
  } else if (commentLines > 0) {
    [warnings addObject:[NSString stringWithFormat:@"%lu comment line%@ at the end of ~/.slate.js weren't carried over; they're still in its backup.",
                         (unsigned long)commentLines, commentLines == 1 ? @"" : @"s"]];
  }
  return doc;
}

#pragma mark - Merging

+ (SlateConfigDocument *)documentByMerging:(SlateConfigDocument *)lower
                                      into:(SlateConfigDocument *)higher
                                 lowerName:(NSString *)lowerName
                                higherName:(NSString *)higherName
                                  warnings:(NSMutableArray<NSString *> *)warnings {
  NSArray *higherSettingNames = [higher.settings valueForKey:@"name"];
  NSMutableArray *settings = [NSMutableArray array];
  for (SlateConfigEntry *entry in lower.settings) {
    if (![higherSettingNames containsObject:entry.name]) [settings addObject:entry];
  }
  [settings addObjectsFromArray:higher.settings];
  higher.settings = settings;

  NSMutableDictionary *higherAliases = [NSMutableDictionary dictionary];
  for (NSArray<SlateConfigEntry *> *section in @[higher.modifiers, higher.monitors, higher.positions, higher.aliases]) {
    for (SlateConfigEntry *entry in section) higherAliases[entry.name] = entry;
  }
  NSArray *lowerSections = @[lower.modifiers, lower.monitors, lower.positions, lower.aliases];
  NSArray *higherSections = @[higher.modifiers, higher.monitors, higher.positions, higher.aliases];
  for (NSUInteger s = 0; s < [lowerSections count]; s++) {
    for (SlateConfigEntry *entry in lowerSections[s]) {
      SlateConfigEntry *existing = higherAliases[entry.name];
      if (existing == nil) {
        [higherSections[s] addObject:entry];
      } else if (![[existing.value description] isEqualToString:[entry.value description]]) {
        [warnings addObject:[NSString stringWithFormat:@"Alias \"%@\" differs between %@ and %@; kept the %@ value.", entry.name, lowerName, higherName, higherName]];
      }
    }
  }

  NSMutableArray *bindings = [NSMutableArray arrayWithArray:lower.bindings];
  [bindings addObjectsFromArray:higher.bindings];
  higher.bindings = bindings;
  return higher;
}

#pragma mark - Files

// <path>.<suffix>-<timestamp>, so repeated runs never collide.
+ (NSString *)backupPathFor:(NSString *)path suffix:(NSString *)suffix {
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
  formatter.dateFormat = @"yyyyMMdd-HHmmss";
  return [NSString stringWithFormat:@"%@.%@-%@", path, suffix, [formatter stringFromDate:[NSDate date]]];
}

+ (nullable NSArray<NSString *> *)migrateLegacyFile:(nullable NSString *)legacyPath
                                     javaScriptFile:(nullable NSString *)jsPath
                                        oldYAMLFile:(nullable NSString *)oldYAMLPath
                                             toFile:(NSString *)ymlPath
                                           warnings:(NSMutableArray<NSString *> *)warnings
                                              error:(NSError **)error {
  NSFileManager *fm = [NSFileManager defaultManager];
  ymlPath = [ymlPath stringByExpandingTildeInPath];
  legacyPath = [legacyPath stringByExpandingTildeInPath];
  jsPath = [jsPath stringByExpandingTildeInPath];
  oldYAMLPath = [oldYAMLPath stringByExpandingTildeInPath];
  if (legacyPath != nil && ![fm fileExistsAtPath:legacyPath]) legacyPath = nil;
  if (jsPath != nil && ![fm fileExistsAtPath:jsPath]) jsPath = nil;
  if (oldYAMLPath != nil && ![fm fileExistsAtPath:oldYAMLPath]) oldYAMLPath = nil;

  // Lowest precedence first, matching the load order of each generation:
  // ~/.slate, then ~/.slate.js, then ~/.slate.yml, then ~/.mwm.yml.
  SlateConfigDocument *doc = nil;
  NSString *docName = nil;
  if (legacyPath != nil) {
    NSString *source = [NSString stringWithContentsOfFile:legacyPath encoding:NSUTF8StringEncoding error:error];
    if (source == nil) return nil;
    doc = [self documentFromLegacySource:source warnings:warnings];
    docName = @"~/.slate";
  }
  if (jsPath != nil) {
    NSString *source = [NSString stringWithContentsOfFile:jsPath encoding:NSUTF8StringEncoding error:error];
    if (source == nil) return nil;
    SlateConfigDocument *js = [self documentFromJavaScript:source warnings:warnings error:error];
    if (js == nil) return nil;
    doc = doc ? [self documentByMerging:doc into:js lowerName:docName higherName:@"~/.slate.js" warnings:warnings] : js;
    docName = @"~/.slate.js";
  }
  if (oldYAMLPath != nil) {
    SlateConfigDocument *old = [SlateConfigDocument documentWithContentsOfFile:oldYAMLPath error:error];
    if (old == nil) return nil;
    doc = doc ? [self documentByMerging:doc into:old lowerName:docName higherName:@"~/.slate.yml" warnings:warnings] : old;
    docName = @"~/.slate.yml";
  }
  if (doc == nil) return @[];

  BOOL ymlExisted = [fm fileExistsAtPath:ymlPath];
  if (ymlExisted) {
    SlateConfigDocument *yml = [SlateConfigDocument documentWithContentsOfFile:ymlPath error:error];
    if (yml == nil) return nil;
    doc = [self documentByMerging:doc into:yml lowerName:docName higherName:@"~/.mwm.yml" warnings:warnings];
  }

  // Refuse to write something that wouldn't load.
  NSError *checkError = nil;
  if ([SlateConfigDocument documentFromString:[doc stringRepresentation] error:&checkError] == nil) {
    if (error) *error = MigrationError([NSString stringWithFormat:@"The converted configuration has a problem: %@", [checkError localizedDescription]]);
    return nil;
  }
  if (![doc writeToFile:ymlPath error:error]) return nil;

  // Rename the old files (a symlink itself, not its target) so they stop loading.
  NSMutableArray *backups = [NSMutableArray array];
  for (NSString *old in @[legacyPath ?: @"", jsPath ?: @"", oldYAMLPath ?: @""]) {
    if ([old length] == 0) continue;
    NSString *backup = [self backupPathFor:old suffix:@"migrated"];
    if (![fm moveItemAtPath:old toPath:backup error:error]) {
      // Put everything back so the next launch tries again from the same state.
      for (NSUInteger i = 0; i < [backups count]; i += 2) [fm moveItemAtPath:backups[i + 1] toPath:backups[i] error:nil];
      NSString *target = [ymlPath stringByResolvingSymlinksInPath];
      [fm removeItemAtPath:target error:nil];
      if (ymlExisted) [fm moveItemAtPath:[target stringByAppendingString:@".bak"] toPath:target error:nil];
      return nil;
    }
    [backups addObject:old];
    [backups addObject:backup];
  }
  NSMutableArray *result = [NSMutableArray array];
  for (NSUInteger i = 1; i < [backups count]; i += 2) [result addObject:backups[i]];
  return result;
}

#pragma mark - Startup

+ (void)showMigrationResult:(NSArray<NSString *> *)backups warnings:(NSArray<NSString *> *)warnings {
  NSAlert *alert = [[NSAlert alloc] init];
  [alert setMessageText:@"MWM now uses ~/.mwm.yml"];
  NSMutableArray *names = [NSMutableArray array];
  for (NSString *backup in backups) [names addObject:[backup stringByAbbreviatingWithTildeInPath]];
  NSMutableString *info = [NSMutableString stringWithFormat:
    @"Your configuration was converted to ~/.mwm.yml, which MWM reads without running any code. "
    @"The old file%@ %@ saved as:\n%@", [backups count] == 1 ? @"" : @"s", [backups count] == 1 ? @"is" : @"are",
    [names componentsJoinedByString:@"\n"]];
  if ([warnings count] > 0) {
    [alert setAlertStyle:NSAlertStyleWarning];
    [info appendString:@"\n\nWorth checking:\n"];
    NSUInteger shown = MIN([warnings count], (NSUInteger)8);
    for (NSUInteger i = 0; i < shown; i++) [info appendFormat:@"\n• %@", warnings[i]];
    if ([warnings count] > shown) [info appendFormat:@"\n• …and %lu more", (unsigned long)([warnings count] - shown)];
  }
  [alert setInformativeText:info];
  [alert addButtonWithTitle:@"OK"];
  [alert runModal];
}

+ (void)showAlert:(NSString *)message detail:(NSString *)detail {
  NSAlert *alert = [[NSAlert alloc] init];
  [alert setAlertStyle:NSAlertStyleWarning];
  [alert setMessageText:message];
  [alert setInformativeText:detail];
  [alert addButtonWithTitle:@"OK"];
  [alert runModal];
}

// ~/.slate.js that can't be converted: stop it from looking like it's in use.
+ (void)retireJavaScriptFile:(NSString *)jsPath reason:(NSError *)reason {
  NSString *backup = [self backupPathFor:jsPath suffix:@"unused"];
  NSError *moveError = nil;
  BOOL moved = [[NSFileManager defaultManager] moveItemAtPath:jsPath toPath:backup error:&moveError];
  SlateLogger(@"~/.slate.js not converted (%@); moved: %d", [reason localizedDescription], moved);
  [self showAlert:@"MWM no longer runs ~/.slate.js"
           detail:[NSString stringWithFormat:@"%@\n\n%@ Recreate what you need in Configure MWM…, which saves to ~/.mwm.yml.",
                   [reason localizedDescription],
                   moved ? [NSString stringWithFormat:@"It was renamed to %@.", [backup stringByAbbreviatingWithTildeInPath]]
                         : @"It's left in place but isn't loaded."]];
}

+ (void)runStartupMigration {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *ymlPath = [SlateConfigDocument defaultPath];
  NSString *legacyPath = [@"~/.slate" stringByExpandingTildeInPath];
  NSString *jsPath = [@"~/.slate.js" stringByExpandingTildeInPath];
  NSString *oldYAMLPath = [@"~/.slate.yml" stringByExpandingTildeInPath];
  BOOL hasLegacy = [fm fileExistsAtPath:legacyPath];
  BOOL hasJS = [fm fileExistsAtPath:jsPath];
  BOOL hasOldYAML = [fm fileExistsAtPath:oldYAMLPath];
  if (!hasLegacy && !hasJS && !hasOldYAML) return;

  // A ~/.slate.js the converter can't read is set aside first, whatever else happens.
  if (hasJS) {
    NSString *source = [NSString stringWithContentsOfFile:jsPath encoding:NSUTF8StringEncoding error:nil];
    NSError *jsError = nil;
    if (source == nil || [self documentFromJavaScript:source warnings:[NSMutableArray array] error:&jsError] == nil) {
      [self retireJavaScriptFile:jsPath reason:jsError ?: MigrationError(@"~/.slate.js couldn't be read.")];
      hasJS = NO;
      if (!hasLegacy && !hasOldYAML) return;
    }
  }

  NSMutableArray *oldNames = [NSMutableArray array];
  if (hasLegacy) [oldNames addObject:@"~/.slate"];
  if (hasJS) [oldNames addObject:@"~/.slate.js"];
  if (hasOldYAML) [oldNames addObject:@"~/.slate.yml"];
  NSString *names = [oldNames componentsJoinedByString:@", "];

  if ([fm fileExistsAtPath:ymlPath]) {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:[NSString stringWithFormat:@"Merge %@ into ~/.mwm.yml?", names]];
    [alert setInformativeText:[NSString stringWithFormat:
      @"MWM keeps its configuration in ~/.mwm.yml. You also have %@, so MWM can merge %@ in; ~/.mwm.yml wins "
      @"where both set the same thing. Either way the old %@ kept as a backup.%@", names,
      [oldNames count] == 1 ? @"file" : @"files", [oldNames count] == 1 ? @"file is" : @"files are",
      hasJS ? @"\n\n~/.slate.js isn't loaded anymore, since MWM no longer runs JavaScript." : @""]];
    [alert addButtonWithTitle:@"Merge"];
    [alert addButtonWithTitle:@"Not now"];
    [alert addButtonWithTitle:@"Stop using them"];
    NSModalResponse response = [alert runModal];
    if (response == NSAlertSecondButtonReturn) {
      SlateLogger(@"Migration postponed.");
      return;
    }
    if (response == NSAlertThirdButtonReturn) {
      for (NSString *old in @[hasLegacy ? legacyPath : @"", hasJS ? jsPath : @"", hasOldYAML ? oldYAMLPath : @""]) {
        if ([old length] == 0) continue;
        NSError *error = nil;
        if (![fm moveItemAtPath:old toPath:[self backupPathFor:old suffix:@"unused"] error:&error]) {
          [self showAlert:@"Couldn't rename the old configuration" detail:[error localizedDescription]];
        }
      }
      return;
    }
  }

  NSMutableArray<NSString *> *warnings = [NSMutableArray array];
  NSError *error = nil;
  NSArray *backups = [self migrateLegacyFile:hasLegacy ? legacyPath : nil
                              javaScriptFile:hasJS ? jsPath : nil
                                 oldYAMLFile:hasOldYAML ? oldYAMLPath : nil
                                      toFile:ymlPath
                                    warnings:warnings
                                       error:&error];
  if (backups == nil) {
    SlateLogger(@"Migration failed: %@", error);
    [self showAlert:@"Couldn't convert the configuration to ~/.mwm.yml"
             detail:[NSString stringWithFormat:@"%@\n\nNothing was changed.%@", [error localizedDescription],
                     hasLegacy ? @" MWM will keep loading ~/.slate." : @""]];
    return;
  }
  SlateLogger(@"Migrated to ~/.mwm.yml (backups: %@, %lu warnings)", backups, (unsigned long)[warnings count]);
  [self showMigrationResult:backups warnings:warnings];
}

@end
