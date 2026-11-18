//
//  SlateConfigFormat.m
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

#import "SlateConfigFormat.h"
#import "SlateAction.h"
#import "SlateConfigDocument.h"
#import "SlateSlots.h"
#import "SlateYAML.h"

const NSInteger SlateConfigFormatCurrentVersion = 2;

static NSError *FormatError(NSString *message, NSUInteger line, NSNumber *bindingIndex, NSString *entryName) {
  NSString *text = line > 0 ? [NSString stringWithFormat:@"Line %lu: %@", (unsigned long)line, message] : message;
  NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject:text forKey:NSLocalizedDescriptionKey];
  if (line > 0) info[SlateConfigDocumentErrorLineKey] = @(line);
  if (bindingIndex != nil) info[SlateConfigDocumentErrorBindingIndexKey] = bindingIndex;
  if (entryName != nil) info[SlateConfigDocumentErrorEntryNameKey] = entryName;
  return [NSError errorWithDomain:SlateConfigDocumentErrorDomain code:SlateConfigDocumentErrorInvalid userInfo:info];
}

static BOOL IsBool(id value) {
  return [value isKindOfClass:[NSNumber class]] && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
}

static BOOL IsText(id value) {
  return [value isKindOfClass:[NSString class]] || ([value isKindOfClass:[NSNumber class]] && !IsBool(value));
}

static NSString *TextOf(id value) {
  return [value isKindOfClass:[NSString class]] ? value : [value stringValue];
}

static NSString *Trim(NSString *s) {
  return [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static BOOL Matches(NSString *pattern, NSString *s) {
  return [s rangeOfString:pattern options:NSRegularExpressionSearch].location != NSNotFound;
}

// "5120x1440"
static BOOL LooksLikeSize(NSString *value) { return Matches(@"^[0-9]+x[0-9]+$", value); }

#pragma mark - Percent text

static NSString *PercentText(CGFloat fraction) {
  NSString *text = [NSString stringWithFormat:@"%.6f", fraction * 100];
  if ([text containsString:@"."]) {
    while ([text hasSuffix:@"0"]) text = [text substringToIndex:[text length] - 1];
    if ([text hasSuffix:@"."]) text = [text substringToIndex:[text length] - 1];
  }
  return [text stringByAppendingString:@"%"];
}

static BOOL ParsePercent(id value, CGFloat *fraction) {
  if (![value isKindOfClass:[NSString class]] || !Matches(@"^[0-9]+(\\.[0-9]+)?%$", value)) return NO;
  *fraction = [[value substringToIndex:[value length] - 1] doubleValue] / 100;
  return YES;
}

@implementation SlateConfigFormat

#pragma mark - Reading (version 2 → the tree version 1 reads)

+ (SlateYAMLMapping *)versionOneTreeFromVersionTwo:(SlateYAMLMapping *)config error:(NSError **)error {
  NSArray *known = @[@"version", @"settings", @"modifiers", @"monitors", @"slots", @"aliases", @"bindings"];
  for (NSString *section in config.keys) {
    if (![known containsObject:section]) {
      if (error) *error = FormatError([NSString stringWithFormat:@"Unknown section \"%@\". Sections are %@.", section, [[known subarrayWithRange:NSMakeRange(1, [known count] - 1)] componentsJoinedByString:@", "]], [config lineForKey:section], nil, nil);
      return nil;
    }
  }
  SlateYAMLMapping *tree = [[SlateYAMLMapping alloc] init];
  tree.line = config.line;

  // settings and aliases are the same in both formats.
  for (NSString *section in @[@"settings", @"aliases"]) {
    id value = [config objectForKey:section];
    if (value != nil) [tree setObject:value forKey:section line:[config lineForKey:section]];
  }

  // modifiers: a list or text -> text joined with ";".
  NSMutableSet *modifierNames = [NSMutableSet set];
  id modifiers = [config objectForKey:@"modifiers"];
  if (modifiers != nil && modifiers != [NSNull null]) {
    if (![modifiers isKindOfClass:[SlateYAMLMapping class]]) {
      if (error) *error = FormatError(@"modifiers should be a list of \"name: [ctrl, alt]\" lines.", [config lineForKey:@"modifiers"], nil, nil);
      return nil;
    }
    SlateYAMLMapping *out = [[SlateYAMLMapping alloc] init];
    for (NSString *name in [(SlateYAMLMapping *)modifiers keys]) {
      id item = [(SlateYAMLMapping *)modifiers objectForKey:name];
      NSUInteger line = [(SlateYAMLMapping *)modifiers lineForKey:name];
      [modifierNames addObject:name];
      if ([item isKindOfClass:[NSArray class]]) {
        NSMutableArray *parts = [NSMutableArray array];
        for (id part in item) {
          if (!IsText(part)) {
            if (error) *error = FormatError([NSString stringWithFormat:@"Modifier group \"%@\": the list should have modifier names like ctrl and alt.", name], line, nil, name);
            return nil;
          }
          [parts addObject:TextOf(part)];
        }
        item = [parts componentsJoinedByString:@";"];
      } else if (!IsText(item)) {
        if (error) *error = FormatError([NSString stringWithFormat:@"Modifier group \"%@\" should be a list like [ctrl, alt, cmd].", name], line, nil, name);
        return nil;
      }
      [out setObject:item forKey:name line:line];
    }
    [tree setObject:out forKey:@"modifiers" line:[config lineForKey:@"modifiers"]];
  }

  // monitors: {display, size} -> name: display, and name-size: size.
  NSMutableSet *monitorNames = [NSMutableSet set];
  id monitors = [config objectForKey:@"monitors"];
  if (monitors != nil && monitors != [NSNull null]) {
    if (![monitors isKindOfClass:[SlateYAMLMapping class]]) {
      if (error) *error = FormatError(@"monitors should be a list of \"name: {display: ..., size: ...}\" lines.", [config lineForKey:@"monitors"], nil, nil);
      return nil;
    }
    SlateYAMLMapping *out = [[SlateYAMLMapping alloc] init];
    SlateYAMLMapping *source = monitors;
    for (NSString *name in source.keys) {
      id item = [source objectForKey:name];
      NSUInteger line = [source lineForKey:name];
      [monitorNames addObject:name];
      if (IsText(item)) { [out setObject:item forKey:name line:line]; continue; }   // just which screen
      if (![item isKindOfClass:[SlateYAMLMapping class]]) {
        if (error) *error = FormatError([NSString stringWithFormat:@"Monitor \"%@\" should be {display: ..., size: ...}.", name], line, nil, name);
        return nil;
      }
      SlateYAMLMapping *fields = item;
      for (NSString *field in fields.keys) {
        if (![@[@"display", @"screen", @"size"] containsObject:field]) {
          if (error) *error = FormatError([NSString stringWithFormat:@"Monitor \"%@\" has an unknown field \"%@\". Fields are display, screen, size.", name, field], [fields lineForKey:field], nil, name);
          return nil;
        }
        if (!IsText([fields objectForKey:field])) {
          if (error) *error = FormatError([NSString stringWithFormat:@"Monitor \"%@\": %@ should be text.", name, field], [fields lineForKey:field], nil, name);
          return nil;
        }
      }
      id display = [fields objectForKey:@"display"], screen = [fields objectForKey:@"screen"], size = [fields objectForKey:@"size"];
      if (display != nil && screen != nil) {
        if (error) *error = FormatError([NSString stringWithFormat:@"Monitor \"%@\": use display (by name) or screen (by number), not both.", name], line, nil, name);
        return nil;
      }
      // display names a screen by its model ("built-in", "Samsung Odyssey 5120x1440"); screen is an older
      // reference ("0", "ordered:1", "next").
      NSString *which = display != nil ? [@"display: " stringByAppendingString:Trim(TextOf(display))] : (screen != nil ? Trim(TextOf(screen)) : nil);
      if (which != nil) {
        [out setObject:which forKey:name line:line];
        if (size != nil) [out setObject:TextOf(size) forKey:[name stringByAppendingString:@"-size"] line:line];
      } else if (size != nil) {
        [out setObject:TextOf(size) forKey:name line:line];   // a size on its own is the entry's value
      }
    }
    [tree setObject:out forKey:@"monitors" line:[config lineForKey:@"monitors"]];
  }

  // slots: {x, y, width, height} in percent, or {formula} -> the "move" formula.
  id slots = [config objectForKey:@"slots"];
  if (slots != nil && slots != [NSNull null]) {
    if (![slots isKindOfClass:[SlateYAMLMapping class]]) {
      if (error) *error = FormatError(@"slots should be a list of \"name: {x: 0%, y: 0%, width: 50%, height: 100%}\" lines.", [config lineForKey:@"slots"], nil, nil);
      return nil;
    }
    SlateYAMLMapping *out = [[SlateYAMLMapping alloc] init];
    SlateYAMLMapping *source = slots;
    for (NSString *name in source.keys) {
      id item = [source objectForKey:name];
      NSUInteger line = [source lineForKey:name];
      if (IsText(item)) { [out setObject:item forKey:name line:line]; continue; }
      if (![item isKindOfClass:[SlateYAMLMapping class]]) {
        if (error) *error = FormatError([NSString stringWithFormat:@"Slot \"%@\" should be {x: 0%%, y: 0%%, width: 50%%, height: 100%%}.", name], line, nil, name);
        return nil;
      }
      SlateYAMLMapping *fields = item;
      NSString *formula = [self formulaForSlot:name fields:fields line:line error:error];
      if (formula == nil) return nil;
      [out setObject:formula forKey:name line:line];
    }
    [tree setObject:out forKey:@"positions" line:[config lineForKey:@"slots"]];
  }

  // bindings: mods names and action objects -> text.
  id bindings = [config objectForKey:@"bindings"];
  if (bindings != nil && bindings != [NSNull null]) {
    if (![bindings isKindOfClass:[NSArray class]]) {
      if (error) *error = FormatError(@"bindings should be a list, with each binding starting with \"- \".", [config lineForKey:@"bindings"], nil, nil);
      return nil;
    }
    NSMutableArray *out = [NSMutableArray array];
    NSUInteger index = 0;
    for (id item in bindings) {
      if (![item isKindOfClass:[SlateYAMLMapping class]]) { [out addObject:item]; index++; continue; }   // version 1's reader reports it
      SlateYAMLMapping *binding = item;
      SlateYAMLMapping *converted = [[SlateYAMLMapping alloc] init];
      converted.line = binding.line;
      for (NSString *field in binding.keys) {
        id value = [binding objectForKey:field];
        NSUInteger line = [binding lineForKey:field];
        if ([field isEqualToString:@"mods"]) {
          if ([value isKindOfClass:[NSArray class]]) {
            NSMutableArray *parts = [NSMutableArray array];
            for (id part in value) {
              if (!IsText(part)) {
                if (error) *error = FormatError([NSString stringWithFormat:@"Binding #%lu: mods should be a group name or a list like [ctrl, alt].", (unsigned long)index + 1], line, @(index), nil);
                return nil;
              }
              [parts addObject:TextOf(part)];
            }
            value = [parts componentsJoinedByString:@";"];
          } else if (IsText(value) && [modifierNames containsObject:TextOf(value)]) {
            value = [NSString stringWithFormat:@"${%@}", TextOf(value)];
          }
        } else if ([field isEqualToString:@"action"] && [value isKindOfClass:[SlateYAMLMapping class]]) {
          value = [self actionTextFor:value monitors:monitorNames bindingIndex:index error:error];
          if (value == nil) return nil;
        }
        [converted setObject:value forKey:field line:line];
      }
      [out addObject:converted];
      index++;
    }
    [tree setObject:out forKey:@"bindings" line:[config lineForKey:@"bindings"]];
  }
  return tree;
}

+ (NSString *)formulaForSlot:(NSString *)name fields:(SlateYAMLMapping *)fields line:(NSUInteger)line error:(NSError **)error {
  for (NSString *field in fields.keys) {
    if (![@[@"x", @"y", @"width", @"height", @"formula"] containsObject:field]) {
      if (error) *error = FormatError([NSString stringWithFormat:@"Slot \"%@\" has an unknown field \"%@\". Fields are x, y, width, height, or formula.", name, field], [fields lineForKey:field], nil, name);
      return nil;
    }
  }
  id formula = [fields objectForKey:@"formula"];
  if (formula != nil) {
    if (!IsText(formula) || [fields.keys count] != 1) {
      if (error) *error = FormatError([NSString stringWithFormat:@"Slot \"%@\": use either formula: or x, y, width and height.", name], line, nil, name);
      return nil;
    }
    return TextOf(formula);
  }
  CGFloat values[4];
  NSArray *names = @[@"x", @"y", @"width", @"height"];
  for (NSUInteger i = 0; i < 4; i++) {
    id value = [fields objectForKey:names[i]];
    if (value == nil) {
      if (error) *error = FormatError([NSString stringWithFormat:@"Slot \"%@\" needs %@ (a percent like 50%%).", name, names[i]], line, nil, name);
      return nil;
    }
    if (!ParsePercent(value, &values[i])) {
      if (error) *error = FormatError([NSString stringWithFormat:@"Slot \"%@\": %@ should be a percent like 50%%.", name, names[i]], [fields lineForKey:names[i]], nil, name);
      return nil;
    }
  }
  return [SlateSlots formulaForRect:CGRectMake(values[0], values[1], values[2], values[3])];
}

+ (NSString *)actionTextFor:(SlateYAMLMapping *)fields monitors:(NSSet<NSString *> *)monitors bindingIndex:(NSUInteger)index error:(NSError **)error {
  NSString *where = [NSString stringWithFormat:@"Binding #%lu", (unsigned long)index + 1];
  id typeValue = [fields objectForKey:@"type"];
  if (!IsText(typeValue)) {
    if (error) *error = FormatError([where stringByAppendingString:@": the action needs a type (move, focus-app, focus, throw, nudge, resize, push, hint, grid, switch, relaunch or custom)."], fields.line, @(index), nil);
    return nil;
  }
  NSString *type = TextOf(typeValue);
  NSDictionary *allowed = @{
    @"move": @[@"slot", @"screen"], @"focus-app": @[@"app"], @"focus": @[@"direction"], @"throw": @[@"screen", @"style"],
    @"nudge": @[@"x", @"y"], @"resize": @[@"x", @"y"], @"push": @[@"direction", @"options"], @"hint": @[@"letters"],
    @"grid": @[@"arguments"], @"switch": @[], @"relaunch": @[], @"custom": @[@"text"],
  };
  NSArray *fieldNames = allowed[type];
  if (fieldNames == nil) {
    if (error) *error = FormatError([NSString stringWithFormat:@"%@: unknown action type \"%@\".", where, type], [fields lineForKey:@"type"], @(index), nil);
    return nil;
  }
  for (NSString *field in fields.keys) {
    if ([field isEqualToString:@"type"]) continue;
    if (![fieldNames containsObject:field]) {
      if (error) *error = FormatError([NSString stringWithFormat:@"%@: a %@ action has no \"%@\". It has %@.", where, type, field, [fieldNames count] > 0 ? [fieldNames componentsJoinedByString:@", "] : @"no fields"], [fields lineForKey:field], @(index), nil);
      return nil;
    }
    if (!IsText([fields objectForKey:field])) {
      if (error) *error = FormatError([NSString stringWithFormat:@"%@: %@ should be text.", where, field], [fields lineForKey:field], @(index), nil);
      return nil;
    }
  }
  NSString *(^field)(NSString *) = ^NSString *(NSString *name) { id v = [fields objectForKey:name]; return v != nil ? Trim(TextOf(v)) : @""; };
  void (^missing)(NSString *, NSString *) = ^(NSString *name, NSString *what) {
    if (error) *error = FormatError([NSString stringWithFormat:@"%@: a %@ action needs %@.", where, type, what], fields.line, @(index), nil);
  };

  SlateAction *action;
  if ([type isEqualToString:@"move"]) {
    if ([field(@"slot") length] == 0) { missing(@"slot", @"a slot"); return nil; }
    action = [SlateAction actionOfKind:SlateActionKindMove];
    action.a = field(@"slot"); action.b = field(@"screen");
  } else if ([type isEqualToString:@"focus-app"]) {
    if ([field(@"app") length] == 0) { missing(@"app", @"an app"); return nil; }
    action = [SlateAction actionOfKind:SlateActionKindFocusApp]; action.a = field(@"app");
  } else if ([type isEqualToString:@"focus"]) {
    if (![[SlateAction directions] containsObject:field(@"direction")]) { missing(@"direction", @"a direction (left, right, up, down or behind)"); return nil; }
    action = [SlateAction actionOfKind:SlateActionKindFocusDirection]; action.a = field(@"direction");
  } else if ([type isEqualToString:@"throw"]) {
    if ([field(@"screen") length] == 0) { missing(@"screen", @"a screen (a monitor name, next, previous or a number)"); return nil; }
    action = [SlateAction actionOfKind:SlateActionKindThrow];
    action.a = [monitors containsObject:field(@"screen")] ? [NSString stringWithFormat:@"${%@}", field(@"screen")] : field(@"screen");
    action.b = field(@"style");
  } else if ([type isEqualToString:@"nudge"] || [type isEqualToString:@"resize"]) {
    if ([field(@"x") length] == 0 || [field(@"y") length] == 0) { missing(@"x", @"x and y (like +10% and +0)"); return nil; }
    action = [SlateAction actionOfKind:[type isEqualToString:@"nudge"] ? SlateActionKindNudge : SlateActionKindResize];
    action.a = field(@"x"); action.b = field(@"y");
  } else if ([type isEqualToString:@"push"]) {
    if (![[SlateAction pushDirections] containsObject:field(@"direction")]) { missing(@"direction", @"a direction (up, down, left or right)"); return nil; }
    action = [SlateAction actionOfKind:SlateActionKindPush]; action.a = field(@"direction"); action.b = field(@"options");
  } else if ([type isEqualToString:@"hint"]) {
    action = [SlateAction actionOfKind:SlateActionKindHint]; action.a = field(@"letters");
  } else if ([type isEqualToString:@"grid"]) {
    action = [SlateAction actionOfKind:SlateActionKindGrid]; action.a = field(@"arguments");
  } else if ([type isEqualToString:@"switch"]) {
    action = [SlateAction actionOfKind:SlateActionKindSwitch];
  } else if ([type isEqualToString:@"relaunch"]) {
    action = [SlateAction actionOfKind:SlateActionKindRelaunch];
  } else {
    if ([field(@"text") length] == 0) { missing(@"text", @"the text of the action"); return nil; }
    action = [SlateAction actionOfKind:SlateActionKindCustom]; action.a = field(@"text");
  }
  return [action string];
}

#pragma mark - Writing

+ (NSString *)yamlText:(NSString *)text { return [SlateYAML text:text]; }

+ (NSString *)settingScalar:(id)value {
  return [value isKindOfClass:[NSString class]] ? [SlateYAML text:value] : [SlateYAML scalar:value];
}

+ (void)appendMapSection:(NSString *)name lines:(NSArray<NSString *> *)lines to:(NSMutableString *)out {
  if ([lines count] == 0) { [out appendFormat:@"\n%@: {}\n", name]; return; }
  [out appendFormat:@"\n%@:\n", name];
  for (NSString *line in lines) [out appendFormat:@"  %@\n", line];
}

+ (NSString *)modifiersText:(NSString *)value {
  NSMutableArray *parts = [NSMutableArray array];
  for (NSString *part in [value componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@";,"]]) {
    NSString *name = Trim(part);
    if ([name length] > 0) [parts addObject:name];
  }
  BOOL list = [parts count] > 0;
  for (NSString *part in parts) if (!Matches(@"^[A-Za-z]+$", part)) list = NO;
  if (!list) return [self yamlText:value];
  return [NSString stringWithFormat:@"[%@]", [parts componentsJoinedByString:@", "]];
}

+ (NSArray<NSString *> *)monitorLines:(NSArray<SlateConfigEntry *> *)monitors {
  NSMutableDictionary *byName = [NSMutableDictionary dictionary];
  for (SlateConfigEntry *entry in monitors) byName[entry.name] = entry;
  NSMutableArray *lines = [NSMutableArray array];
  for (SlateConfigEntry *entry in monitors) {
    NSString *value = [entry.value description];
    // "<name>-size" belongs to the monitor called <name>, when there is one.
    if ([entry.name hasSuffix:@"-size"] && [entry.name length] > 5 && byName[[entry.name substringToIndex:[entry.name length] - 5]] != nil) continue;
    NSMutableArray *fields = [NSMutableArray array];
    if (LooksLikeSize(value)) {
      [fields addObject:[@"size: " stringByAppendingString:value]];
    } else {
      if ([value hasPrefix:@"display: "]) [fields addObject:[@"display: " stringByAppendingString:[self yamlText:[value substringFromIndex:9]]]];
      else [fields addObject:[@"screen: " stringByAppendingString:[self yamlText:value]]];
      SlateConfigEntry *size = byName[[entry.name stringByAppendingString:@"-size"]];
      if (size != nil) [fields addObject:[@"size: " stringByAppendingString:[self yamlText:[size.value description]]]];
    }
    [lines addObject:[NSString stringWithFormat:@"%@: {%@}", [SlateYAML key:entry.name], [fields componentsJoinedByString:@", "]]];
  }
  return lines;
}

+ (NSString *)normalized:(NSString *)text {
  return [[Trim(text) componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsJoinedByString:@" "];
}

+ (NSArray<NSString *> *)slotLines:(NSArray<SlateConfigEntry *> *)positions {
  NSMutableArray *lines = [NSMutableArray array];
  for (SlateConfigEntry *entry in positions) {
    NSString *formula = [entry.value description];
    NSString *text = nil;
    CGRect rect;
    if ([SlateSlots getRect:&rect fromFormula:formula]) {
      NSString *x = PercentText(rect.origin.x), *y = PercentText(rect.origin.y), *w = PercentText(rect.size.width), *h = PercentText(rect.size.height);
      CGFloat fx, fy, fw, fh;
      // Only when reading it back gives the very same formula; anything else keeps its own text.
      if (ParsePercent(x, &fx) && ParsePercent(y, &fy) && ParsePercent(w, &fw) && ParsePercent(h, &fh) &&
          [[SlateSlots formulaForRect:CGRectMake(fx, fy, fw, fh)] isEqualToString:[self normalized:formula]]) {
        text = [NSString stringWithFormat:@"{x: %@, y: %@, width: %@, height: %@}", x, y, w, h];
      }
    }
    if (text == nil) text = [NSString stringWithFormat:@"{formula: %@}", [SlateYAML quotedString:formula]];
    [lines addObject:[NSString stringWithFormat:@"%@: %@", [SlateYAML key:entry.name], text]];
  }
  return lines;
}

// "${name}" -> name, when the whole text is one reference.
+ (NSString *)bareName:(NSString *)text {
  return Matches(@"^\\$\\{[^}]+\\}$", text) ? [text substringWithRange:NSMakeRange(2, [text length] - 3)] : text;
}

+ (NSString *)actionObject:(NSString *)source {
  SlateAction *action = [SlateAction parse:source];
  // Written as fields only when that reads back as the very same text (spacing and quotes included);
  // anything else keeps its own text, so nothing is changed by saving.
  if (![[action string] isEqualToString:Trim(source)]) {
    action = [SlateAction actionOfKind:SlateActionKindCustom];
    action.a = source;
  }
  NSMutableArray *fields = [NSMutableArray array];
  void (^add)(NSString *, NSString *) = ^(NSString *name, NSString *value) {
    if ([value length] > 0) [fields addObject:[NSString stringWithFormat:@"%@: %@", name, [self yamlText:value]]];
  };
  switch (action.kind) {
    case SlateActionKindMove: [fields addObject:@"type: move"]; add(@"slot", action.a); add(@"screen", action.b); break;
    case SlateActionKindFocusApp: [fields addObject:@"type: focus-app"]; add(@"app", action.a); break;
    case SlateActionKindFocusDirection: [fields addObject:@"type: focus"]; add(@"direction", action.a); break;
    case SlateActionKindThrow: [fields addObject:@"type: throw"]; add(@"screen", [self bareName:action.a]); add(@"style", action.b); break;
    case SlateActionKindNudge: [fields addObject:@"type: nudge"]; add(@"x", action.a); add(@"y", action.b); break;
    case SlateActionKindResize: [fields addObject:@"type: resize"]; add(@"x", action.a); add(@"y", action.b); break;
    case SlateActionKindPush: [fields addObject:@"type: push"]; add(@"direction", action.a); add(@"options", action.b); break;
    case SlateActionKindHint: [fields addObject:@"type: hint"]; add(@"letters", action.a); break;
    case SlateActionKindGrid: [fields addObject:@"type: grid"]; add(@"arguments", action.a); break;
    case SlateActionKindSwitch: [fields addObject:@"type: switch"]; break;
    case SlateActionKindRelaunch: [fields addObject:@"type: relaunch"]; break;
    case SlateActionKindCustom: [fields addObject:@"type: custom"]; [fields addObject:[@"text: " stringByAppendingString:[SlateYAML quotedString:action.a ?: @""]]]; break;
  }
  return [NSString stringWithFormat:@"{%@}", [fields componentsJoinedByString:@", "]];
}

+ (NSString *)textForDocument:(SlateConfigDocument *)document header:(NSString *)header {
  NSMutableString *out = [NSMutableString stringWithString:header];
  [out appendFormat:@"\nversion: %ld\n", (long)SlateConfigFormatCurrentVersion];

  NSMutableArray *lines = [NSMutableArray array];
  for (SlateConfigEntry *entry in document.settings) [lines addObject:[NSString stringWithFormat:@"%@: %@", [SlateYAML key:entry.name], [self settingScalar:entry.value]]];
  [self appendMapSection:@"settings" lines:lines to:out];

  lines = [NSMutableArray array];
  NSMutableSet *modifierNames = [NSMutableSet set];
  for (SlateConfigEntry *entry in document.modifiers) {
    [modifierNames addObject:entry.name];
    [lines addObject:[NSString stringWithFormat:@"%@: %@", [SlateYAML key:entry.name], [self modifiersText:[entry.value description]]]];
  }
  [self appendMapSection:@"modifiers" lines:lines to:out];
  [self appendMapSection:@"monitors" lines:[self monitorLines:document.monitors] to:out];
  [self appendMapSection:@"slots" lines:[self slotLines:document.positions] to:out];

  lines = [NSMutableArray array];
  for (SlateConfigEntry *entry in document.aliases) [lines addObject:[NSString stringWithFormat:@"%@: %@", [SlateYAML key:entry.name], [self settingScalar:entry.value]]];
  [self appendMapSection:@"aliases" lines:lines to:out];

  if ([document.bindings count] == 0) {
    [out appendString:@"\nbindings: []\n"];
    return out;
  }
  [out appendString:@"\nbindings:\n"];
  for (SlateBindingEntry *binding in document.bindings) {
    NSMutableArray *fields = [NSMutableArray array];
    if ([binding.group length] > 0) [fields addObject:[@"group: " stringByAppendingString:[self yamlText:binding.group]]];
    [fields addObject:[@"key: " stringByAppendingString:[self yamlText:binding.key]]];
    if ([binding.modifiers length] > 0) {
      NSString *bare = [self bareName:binding.modifiers];
      BOOL group = ![bare isEqualToString:binding.modifiers] && [modifierNames containsObject:bare];
      [fields addObject:[@"mods: " stringByAppendingString:group ? [self yamlText:bare] : [self modifiersText:binding.modifiers]]];
    }
    [fields addObject:[@"action: " stringByAppendingString:[self actionObject:binding.action]]];
    if (binding.repeat != nil) [fields addObject:[binding.repeat boolValue] ? @"repeat: true" : @"repeat: false"];
    if (!binding.enabled) [fields addObject:@"enabled: false"];
    if ([binding.note length] > 0) [fields addObject:[@"note: " stringByAppendingString:[self yamlText:binding.note]]];
    [out appendFormat:@"  - %@\n", fields[0]];
    for (NSUInteger i = 1; i < [fields count]; i++) [out appendFormat:@"    %@\n", fields[i]];
  }
  return out;
}

#pragma mark - Migrating a file

+ (BOOL)sameContent:(SlateConfigDocument *)a as:(SlateConfigDocument *)b {
  return [a.settings isEqualToArray:b.settings] && [a.modifiers isEqualToArray:b.modifiers] && [a.monitors isEqualToArray:b.monitors] &&
         [a.positions isEqualToArray:b.positions] && [a.aliases isEqualToArray:b.aliases] && [a.bindings isEqualToArray:b.bindings];
}

+ (BOOL)migrateFileAtPath:(NSString *)path backupPath:(NSString **)backupPath error:(NSError **)error {
  NSString *target = [[path stringByExpandingTildeInPath] stringByResolvingSymlinksInPath];
  NSFileManager *fm = [NSFileManager defaultManager];
  if (![fm fileExistsAtPath:target]) return NO;
  NSError *readError = nil;
  NSString *source = [NSString stringWithContentsOfFile:target encoding:NSUTF8StringEncoding error:&readError];
  if (source == nil) { if (error) *error = readError; return NO; }
  // Lenient: a file with a mistake the window would report is still converted as written.
  SlateConfigDocument *old = [SlateConfigDocument documentFromString:source lenient:YES error:error];
  if (old == nil || old.sourceVersion != 1) return NO;

  NSString *converted = [old stringRepresentation];
  SlateConfigDocument *back = [SlateConfigDocument documentFromString:converted lenient:YES error:nil];
  if (back == nil || back.sourceVersion != 2 || ![self sameContent:old as:back] || ![[back stringRepresentation] isEqualToString:converted]) {
    if (error) *error = [NSError errorWithDomain:SlateConfigDocumentErrorDomain code:SlateConfigDocumentErrorInvalid userInfo:@{
      NSLocalizedDescriptionKey: @"The configuration couldn't be converted exactly, so it was left as it is."}];
    return NO;
  }

  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  [formatter setDateFormat:@"yyyyMMdd-HHmmss"];
  NSString *backup = [target stringByAppendingFormat:@".v1-%@", [formatter stringFromDate:[NSDate date]]];
  for (NSUInteger n = 2; [fm fileExistsAtPath:backup]; n++) backup = [target stringByAppendingFormat:@".v1-%@-%lu", [formatter stringFromDate:[NSDate date]], (unsigned long)n];
  if (![fm copyItemAtPath:target toPath:backup error:error]) return NO;
  if (![converted writeToFile:target atomically:YES encoding:NSUTF8StringEncoding error:error]) return NO;
  if (backupPath) *backupPath = backup;
  return YES;
}

@end
