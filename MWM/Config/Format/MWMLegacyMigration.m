//
//  MWMLegacyMigration.m
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

#import "MWMLegacyMigration.h"
#import "MWMAlert.h"
#import <Cocoa/Cocoa.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "MWMConfigDocument.h"
#import "MWMConfigFormat.h"
#import "MWMProfiles.h"
#import "StringTokenizer.h"
#import "MWMLogger.h"

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

@implementation MWMLegacyMigration

#pragma mark - Converting

+ (NSMutableArray<MWMConfigEntry *> *)aliasSectionIn:(MWMConfigDocument *)doc name:(NSString *)name value:(NSString *)value {
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
+ (MWMBindingEntry *)bindingFromLine:(NSString *)line {
  NSMutableArray *tokens = [NSMutableArray array];
  [StringTokenizer tokenize:line into:tokens maxTokens:3];
  if ([tokens count] < 3 || ![tokens[0] isEqualToString:@"bind"]) return nil;
  NSString *keystroke = tokens[1];
  NSString *action = Trim(tokens[2]);
  if ([action length] == 0) return nil;
  NSRange colon = [keystroke rangeOfString:@":"];
  if (colon.location == NSNotFound) return [MWMBindingEntry bindingWithKey:keystroke modifiers:nil action:action];
  return [MWMBindingEntry bindingWithKey:[keystroke substringToIndex:colon.location]
                                 modifiers:[keystroke substringFromIndex:NSMaxRange(colon)]
                                    action:action];
}

+ (MWMConfigDocument *)documentFromLegacySource:(NSString *)source warnings:(NSMutableArray<NSString *> *)warnings {
  MWMConfigDocument *doc = [[MWMConfigDocument alloc] init];
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
        MWMBindingEntry *binding = [self bindingFromLine:StripComment(body)];
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
          [doc.settings addObject:[MWMConfigEntry entryWithName:name value:value]];
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
          [[self aliasSectionIn:doc name:name value:value] addObject:[MWMConfigEntry entryWithName:name value:value]];
          continue;
        }
        if ([aliasValues[name] isEqualToString:value]) continue;
        [warnings addObject:[NSString stringWithFormat:@"Line %lu: alias \"%@\" is defined twice with different values; kept the first one.", (unsigned long)lineNumber, name]];
        [notMigrated addObject:content];
        continue;
      }
    }

    if ([directive isEqualToString:@"bind"]) {
      MWMBindingEntry *binding = [self bindingFromLine:content];
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
  return [NSError errorWithDomain:MWMConfigDocumentErrorDomain code:MWMConfigDocumentErrorInvalid
                         userInfo:@{NSLocalizedDescriptionKey: message}];
}

static id NilIfNull(id value) {
  return (value == nil || value == [NSNull null]) ? nil : value;
}

+ (MWMConfigDocument *)documentFromJavaScript:(NSString *)javaScript warnings:(NSMutableArray<NSString *> *)warnings error:(NSError **)error {
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

  MWMConfigDocument *doc = [[MWMConfigDocument alloc] init];
  NSDictionary *sections = @{@"settings": doc.settings, @"modifiers": doc.modifiers, @"monitors": doc.monitors,
                             @"positions": doc.positions, @"aliases": doc.aliases};
  for (NSString *section in sections) {
    for (NSDictionary *pair in data[section]) {
      [sections[section] addObject:[MWMConfigEntry entryWithName:pair[@"name"] value:pair[@"value"]]];
    }
  }
  for (NSDictionary *b in data[@"bindings"]) {
    MWMBindingEntry *binding = [MWMBindingEntry bindingWithKey:b[@"key"] modifiers:NilIfNull(b[@"mods"]) action:b[@"action"]];
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
    [warnings addObject:@"The custom JavaScript at the end of ~/.slate.js wasn't carried over, because MWM no longer runs JavaScript. It's still in ~/.slate.js."];
  } else if (commentLines > 0) {
    [warnings addObject:[NSString stringWithFormat:@"%lu comment line%@ at the end of ~/.slate.js weren't carried over; they're still in ~/.slate.js.",
                         (unsigned long)commentLines, commentLines == 1 ? @"" : @"s"]];
  }
  return doc;
}

#pragma mark - Merging

+ (MWMConfigDocument *)documentByMerging:(MWMConfigDocument *)lower
                                      into:(MWMConfigDocument *)higher
                                 lowerName:(NSString *)lowerName
                                higherName:(NSString *)higherName
                                  warnings:(NSMutableArray<NSString *> *)warnings {
  NSArray *higherSettingNames = [higher.settings valueForKey:@"name"];
  NSMutableArray *settings = [NSMutableArray array];
  for (MWMConfigEntry *entry in lower.settings) {
    if (![higherSettingNames containsObject:entry.name]) [settings addObject:entry];
  }
  [settings addObjectsFromArray:higher.settings];
  higher.settings = settings;

  NSMutableDictionary *higherAliases = [NSMutableDictionary dictionary];
  for (NSArray<MWMConfigEntry *> *section in @[higher.modifiers, higher.monitors, higher.positions, higher.aliases]) {
    for (MWMConfigEntry *entry in section) higherAliases[entry.name] = entry;
  }
  NSArray *lowerSections = @[lower.modifiers, lower.monitors, lower.positions, lower.aliases];
  NSArray *higherSections = @[higher.modifiers, higher.monitors, higher.positions, higher.aliases];
  for (NSUInteger s = 0; s < [lowerSections count]; s++) {
    for (MWMConfigEntry *entry in lowerSections[s]) {
      MWMConfigEntry *existing = higherAliases[entry.name];
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

#pragma mark - Converting

+ (nullable MWMConfigDocument *)documentByConvertingLegacyFile:(nullable NSString *)legacyPath
                                                 javaScriptFile:(nullable NSString *)jsPath
                                                    oldYAMLFile:(nullable NSString *)oldYAMLPath
                                                       warnings:(NSMutableArray<NSString *> *)warnings
                                                          error:(NSError **)error {
  NSFileManager *fm = [NSFileManager defaultManager];
  if (legacyPath != nil && ![fm fileExistsAtPath:legacyPath]) legacyPath = nil;
  if (jsPath != nil && ![fm fileExistsAtPath:jsPath]) jsPath = nil;
  if (oldYAMLPath != nil && ![fm fileExistsAtPath:oldYAMLPath]) oldYAMLPath = nil;

  // Lowest precedence first, matching the load order of each generation: ~/.slate, then ~/.slate.js,
  // then ~/.slate.yml. A ~/.slate.js that can't be converted is left out and reported.
  MWMConfigDocument *doc = nil;
  NSString *docName = nil;
  if (legacyPath != nil) {
    NSString *source = [NSString stringWithContentsOfFile:legacyPath encoding:NSUTF8StringEncoding error:error];
    if (source == nil) return nil;
    doc = [self documentFromLegacySource:source warnings:warnings];
    docName = @"~/.slate";
  }
  if (jsPath != nil) {
    NSString *source = [NSString stringWithContentsOfFile:jsPath encoding:NSUTF8StringEncoding error:nil];
    NSError *jsError = nil;
    MWMConfigDocument *js = source ? [self documentFromJavaScript:source warnings:warnings error:&jsError] : nil;
    if (js == nil) {
      [warnings addObject:[NSString stringWithFormat:@"~/.slate.js wasn't imported: %@", [jsError localizedDescription] ?: @"it couldn't be read."]];
    } else {
      doc = doc ? [self documentByMerging:doc into:js lowerName:docName higherName:@"~/.slate.js" warnings:warnings] : js;
      docName = @"~/.slate.js";
    }
  }
  if (oldYAMLPath != nil) {
    MWMConfigDocument *old = [MWMConfigDocument documentWithContentsOfFile:oldYAMLPath error:error];
    if (old == nil) return nil;
    doc = doc ? [self documentByMerging:doc into:old lowerName:docName higherName:@"~/.slate.yml" warnings:warnings] : old;
  }
  if (doc == nil) return nil;

  // Refuse to hand back something that wouldn't load.
  NSError *checkError = nil;
  if ([MWMConfigDocument documentFromString:[doc stringRepresentation] error:&checkError] == nil) {
    if (error) *error = MigrationError([NSString stringWithFormat:@"The converted configuration has a problem: %@", [checkError localizedDescription]]);
    return nil;
  }
  return doc;
}

#pragma mark - First launch

+ (nullable NSDictionary *)importFirstRunProfiles {
  if ([MWMProfiles folderExists]) return nil;
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *home = [MWMProfiles homeDirectory];
  NSString *mwmYML = [home stringByAppendingPathComponent:@".mwm.yml"];
  NSMutableArray<NSString *> *slateFiles = [NSMutableArray array];
  NSString *legacyPath = [home stringByAppendingPathComponent:@".slate"];
  NSString *jsPath = [home stringByAppendingPathComponent:@".slate.js"];
  NSString *oldYAMLPath = [home stringByAppendingPathComponent:@".slate.yml"];
  BOOL hasLegacy = [fm fileExistsAtPath:legacyPath], hasJS = [fm fileExistsAtPath:jsPath], hasOldYAML = [fm fileExistsAtPath:oldYAMLPath];
  if (hasLegacy) [slateFiles addObject:@"~/.slate"];
  if (hasJS) [slateFiles addObject:@"~/.slate.js"];
  if (hasOldYAML) [slateFiles addObject:@"~/.slate.yml"];
  BOOL hasMWMYML = [fm fileExistsAtPath:mwmYML];
  if (!hasMWMYML && [slateFiles count] == 0) return nil;

  NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:@{@"moved": @NO, @"warnings": [NSMutableArray array]}];
  NSMutableArray *warnings = result[@"warnings"];
  NSError *error = nil;
  if (![MWMProfiles createFolder:&error]) {
    result[@"error"] = [error localizedDescription];
    return result;
  }

  // The configuration people already use moves into the folder (a symlink moves as a symlink).
  if (hasMWMYML) {
    NSString *target = [MWMProfiles pathForName:@"default"];
    if ([fm moveItemAtPath:mwmYML toPath:target error:&error]) {
      result[@"moved"] = @YES;
    } else {
      [fm removeItemAtPath:[MWMProfiles folder] error:nil];   // empty, so the next launch tries again
      result[@"error"] = [NSString stringWithFormat:@"~/.mwm.yml couldn't be moved: %@", [error localizedDescription]];
      return result;
    }
  }

  // Slate files are only read. A converted one is "default", or "slate-import" next to a moved ~/.mwm.yml.
  if ([slateFiles count] > 0) {
    result[@"slateFiles"] = slateFiles;
    MWMConfigDocument *doc = [self documentByConvertingLegacyFile:hasLegacy ? legacyPath : nil
                                                    javaScriptFile:hasJS ? jsPath : nil
                                                       oldYAMLFile:hasOldYAML ? oldYAMLPath : nil
                                                          warnings:warnings error:&error];
    if (doc == nil) {
      result[@"slateProblem"] = error ? [error localizedDescription] : @"Nothing in them could be converted.";
    } else {
      NSString *name = hasMWMYML ? [MWMProfiles freeNameFrom:@"slate-import"] : @"default";
      if ([MWMProfiles createNamed:name text:[doc stringRepresentation] error:&error]) {
        result[@"importedName"] = name;
      } else {
        result[@"slateProblem"] = [error localizedDescription];
      }
    }
  }
  [MWMProfiles setActiveName:@"default"];
  return result;
}

+ (void)showFirstRunResult:(NSDictionary *)result {
  NSMutableString *info = [NSMutableString string];
  NSArray *warnings = result[@"warnings"];
  NSString *slate = [result[@"slateFiles"] componentsJoinedByString:@", "];
  BOOL moved = [result[@"moved"] boolValue];
  NSString *imported = result[@"importedName"];
  MWMAlertKind kind = MWMAlertKindSuccess;
  NSString *title = @"MWM keeps your profiles in ~/.mwm";
  if (result[@"error"] != nil) {
    kind = MWMAlertKindWarning;
    title = @"Couldn't set up ~/.mwm";
    [info appendFormat:@"%@\n\nNothing was changed. MWM will try again next time it opens.", result[@"error"]];
  } else {
    if (moved) [info appendString:@"Your settings moved from ~/.mwm.yml to the profile ~/.mwm/default.mwm.yaml."];
    if (imported != nil) {
      title = moved ? @"Your Slate setup was imported too" : @"Your Slate setup was imported";
      [info appendFormat:@"%@%@ %@ imported as “%@”. Your Slate files weren't changed.", [info length] ? @"\n\n" : @"", slate, [result[@"slateFiles"] count] == 1 ? @"was" : @"were", imported];
    } else if (result[@"slateProblem"] != nil) {
      kind = MWMAlertKindWarning;
      [info appendFormat:@"%@%@ couldn't be imported: %@\n\nYour Slate files weren't changed.", [info length] ? @"\n\n" : @"", slate, result[@"slateProblem"]];
    }
    if ([warnings count] > 0) {
      kind = MWMAlertKindWarning;
      [info appendString:@"\n\nWorth checking:\n"];
      NSUInteger shown = MIN([warnings count], (NSUInteger)8);
      for (NSUInteger i = 0; i < shown; i++) [info appendFormat:@"\n• %@", warnings[i]];
      if ([warnings count] > shown) [info appendFormat:@"\n• …and %lu more", (unsigned long)([warnings count] - shown)];
    }
    if ([[MWMProfiles names] count] > 1) [info appendString:@"\n\nYou can switch between profiles in the menu bar or in Settings."];
  }
  MWMAlert *alert = [MWMAlert alert];
  [alert setShowsAppIcon:YES];
  [alert setKind:kind];
  [alert setMessageText:title];
  [alert setInformativeText:info];
  [alert addButtonWithTitle:@"OK"];
  [alert runModal];
}

+ (void)showAlert:(NSString *)message detail:(NSString *)detail {
  MWMAlert *alert = [MWMAlert alert];
  [alert setShowsAppIcon:YES];
  [alert setKind:MWMAlertKindWarning];
  [alert setMessageText:message];
  [alert setInformativeText:detail];
  [alert addButtonWithTitle:@"OK"];
  [alert runModal];
}

+ (void)runStartupMigration {
  NSDictionary *result = [self importFirstRunProfiles];
  if (result == nil) return;
  MWMLogger(@"First launch with ~/.mwm: %@", result);
  [self showFirstRunResult:result];
}

+ (void)runFormatMigration {
  NSString *path = [MWMConfigDocument defaultPath];
  NSString *backup = nil;
  NSError *error = nil;
  if ([MWMConfigFormat migrateFileAtPath:path backupPath:&backup error:&error]) {
    NSString *shown = [backup stringByReplacingOccurrencesOfString:NSHomeDirectory() withString:@"~"];
    MWMLogger(@"Updated %@ to the current format; the old file is %@", path, shown);
    MWMAlert *alert = [MWMAlert alert];
    [alert setShowsAppIcon:YES];
    [alert setKind:MWMAlertKindSuccess];
    [alert setMessageText:@"Your profile was updated"];
    [alert setInformativeText:[NSString stringWithFormat:
      @"%@ now uses the new format: one entry per monitor and slot, and actions written out as fields. "
      @"Nothing changes in how your shortcuts work. The old file is kept as %@.", [path stringByAbbreviatingWithTildeInPath], shown]];
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
  } else if (error != nil) {
    MWMLogger(@"Couldn't update %@ to the current format (it still loads as it is): %@", path, [error localizedDescription]);
  }
}

@end
