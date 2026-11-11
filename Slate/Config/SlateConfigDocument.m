//
//  SlateConfigDocument.m
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

#import "SlateConfigDocument.h"
#import "SlateYAML.h"

NSString *const SlateConfigDocumentErrorDomain = @"SlateConfigDocumentErrorDomain";
NSString *const SlateConfigDocumentErrorLineKey = @"SlateConfigDocumentErrorLine";
NSString *const SlateConfigDocumentErrorBindingIndexKey = @"SlateConfigDocumentErrorBindingIndex";
NSString *const SlateConfigDocumentErrorEntryNameKey = @"SlateConfigDocumentErrorEntryName";

static NSString *const kHeader =
  @"# Slate configuration, managed by Slate's configuration window (Configure Slate...).\n"
  @"# The window rewrites this file when you change something there, so comments\n"
  @"# added here aren't kept. Values like ${hyper} refer to an entry in modifiers,\n"
  @"# monitors, positions or aliases.\n";

static NSArray<NSString *> *Sections(void) {
  return @[@"settings", @"modifiers", @"monitors", @"positions", @"aliases", @"bindings"];
}

static NSArray<NSString *> *BindingFields(void) {
  return @[@"group", @"key", @"mods", @"action", @"note", @"enabled", @"repeat"];
}

static NSError *DocumentError(SlateConfigDocumentError code, NSString *message, NSUInteger line, NSNumber *bindingIndex, NSString *entryName) {
  NSString *text = line > 0 ? [NSString stringWithFormat:@"Line %lu: %@", (unsigned long)line, message] : message;
  NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject:text forKey:NSLocalizedDescriptionKey];
  if (line > 0) info[SlateConfigDocumentErrorLineKey] = @(line);
  if (bindingIndex != nil) info[SlateConfigDocumentErrorBindingIndexKey] = bindingIndex;
  if (entryName != nil) info[SlateConfigDocumentErrorEntryNameKey] = entryName;
  return [NSError errorWithDomain:SlateConfigDocumentErrorDomain code:code userInfo:info];
}

static BOOL IsBoolean(id value) {
  return [value isKindOfClass:[NSNumber class]] && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
}

static BOOL IsScalarText(id value) {
  return [value isKindOfClass:[NSString class]] || ([value isKindOfClass:[NSNumber class]] && !IsBoolean(value));
}

static NSString *ScalarText(id value) {
  return [value isKindOfClass:[NSString class]] ? value : [value stringValue];
}

@implementation SlateConfigEntry

+ (instancetype)entryWithName:(NSString *)name value:(id)value {
  SlateConfigEntry *entry = [[self alloc] init];
  entry.name = name;
  entry.value = value;
  return entry;
}

- (BOOL)isEqual:(id)other {
  if (![other isKindOfClass:[SlateConfigEntry class]]) return NO;
  SlateConfigEntry *o = other;
  return [self.name isEqualToString:o.name] && [self.value isEqual:o.value] && IsBoolean(self.value) == IsBoolean(o.value);
}

- (NSUInteger)hash {
  return [self.name hash];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"%@: %@", self.name, [SlateYAML scalar:self.value]];
}

@end

@implementation SlateBindingEntry

+ (instancetype)bindingWithKey:(NSString *)key modifiers:(NSString *)modifiers action:(NSString *)action {
  SlateBindingEntry *binding = [[self alloc] init];
  binding.key = key;
  binding.modifiers = modifiers;
  binding.action = action;
  return binding;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _enabled = YES;
  }
  return self;
}

static BOOL SameOptional(id a, id b) {
  return (a == nil && b == nil) || [a isEqual:b];
}

- (BOOL)isEqual:(id)other {
  if (![other isKindOfClass:[SlateBindingEntry class]]) return NO;
  SlateBindingEntry *o = other;
  return SameOptional(self.group, o.group) && [self.key isEqualToString:o.key] &&
         SameOptional(self.modifiers, o.modifiers) && [self.action isEqualToString:o.action] &&
         SameOptional(self.note, o.note) && self.enabled == o.enabled && SameOptional(self.repeat, o.repeat);
}

- (NSUInteger)hash {
  return [self.key hash] ^ [self.action hash];
}

- (NSString *)description {
  return [[self yamlFields] componentsJoinedByString:@", "];
}

// "name: value" lines, in the order they're written.
- (NSArray<NSString *> *)yamlFields {
  NSMutableArray *fields = [NSMutableArray array];
  if ([self.group length] > 0) [fields addObject:[@"group: " stringByAppendingString:[SlateYAML quotedString:self.group]]];
  [fields addObject:[@"key: " stringByAppendingString:[SlateYAML quotedString:self.key]]];
  if ([self.modifiers length] > 0) [fields addObject:[@"mods: " stringByAppendingString:[SlateYAML quotedString:self.modifiers]]];
  [fields addObject:[@"action: " stringByAppendingString:[SlateYAML quotedString:self.action]]];
  if (self.repeat != nil) [fields addObject:[self.repeat boolValue] ? @"repeat: true" : @"repeat: false"];
  if (!self.enabled) [fields addObject:@"enabled: false"];
  if ([self.note length] > 0) [fields addObject:[@"note: " stringByAppendingString:[SlateYAML quotedString:self.note]]];
  return fields;
}

@end

@implementation SlateResolvedBinding
- (NSString *)description {
  return [NSString stringWithFormat:@"bind %@ %@", self.hotkey, self.action];
}
@end

@implementation SlateResolvedConfig
@end

@implementation SlateConfigDocument

- (instancetype)init {
  self = [super init];
  if (self) {
    _settings = [NSMutableArray array];
    _modifiers = [NSMutableArray array];
    _monitors = [NSMutableArray array];
    _positions = [NSMutableArray array];
    _aliases = [NSMutableArray array];
    _bindings = [NSMutableArray array];
  }
  return self;
}

+ (NSString *)defaultPath {
  return [@"~/.slate.yml" stringByExpandingTildeInPath];
}

#pragma mark - Reading

+ (instancetype)documentWithContentsOfFile:(NSString *)path error:(NSError **)error {
  NSString *source = [NSString stringWithContentsOfFile:[path stringByExpandingTildeInPath] encoding:NSUTF8StringEncoding error:error];
  if (source == nil) return nil;
  return [self documentFromString:source error:error];
}

+ (instancetype)documentFromString:(NSString *)source error:(NSError **)error {
  return [self documentFromString:source lenient:NO error:error];
}

+ (instancetype)documentFromString:(NSString *)source lenient:(BOOL)lenient error:(NSError **)error {
  NSError *yamlError = nil;
  id root = [SlateYAML parse:source error:&yamlError];
  if (root == nil) {
    if (error) {
      NSNumber *line = yamlError.userInfo[SlateYAMLErrorLineKey];
      NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject:[yamlError localizedDescription] forKey:NSLocalizedDescriptionKey];
      if (line != nil) info[SlateConfigDocumentErrorLineKey] = line;
      *error = [NSError errorWithDomain:SlateConfigDocumentErrorDomain code:SlateConfigDocumentErrorSyntax userInfo:info];
    }
    return nil;
  }

  SlateConfigDocument *doc = [[self alloc] init];
  NSError *problem = [doc readRoot:root];
  if (problem == nil && !lenient) {
    NSMutableArray *errors = [NSMutableArray array];
    [doc resolveCollectingErrors:errors];
    problem = [errors firstObject];
  }
  if (problem != nil) {
    if (error) *error = problem;
    return nil;
  }
  return doc;
}

// Fills the document from the parsed YAML. Returns the first structural problem.
- (NSError *)readRoot:(id)root {
  if (root == [NSNull null]) return nil;  // an empty file is an empty configuration
  if (![root isKindOfClass:[SlateYAMLMapping class]]) {
    return DocumentError(SlateConfigDocumentErrorInvalid, @"The file should be a mapping of sections (settings:, bindings:, ...).", 1, nil, nil);
  }
  SlateYAMLMapping *config = root;
  for (NSString *section in config.keys) {
    if (![Sections() containsObject:section]) {
      return DocumentError(SlateConfigDocumentErrorInvalid,
                           [NSString stringWithFormat:@"Unknown section \"%@\". Sections are %@.", section, [Sections() componentsJoinedByString:@", "]],
                           [config lineForKey:section], nil, nil);
    }
  }
  NSError *problem = [self readEntries:config section:@"settings" into:self.settings];
  for (NSString *section in @[@"modifiers", @"monitors", @"positions", @"aliases"]) {
    if (problem != nil) break;
    problem = [self readEntries:config section:section into:[self entriesForSection:section]];
  }
  return problem ?: [self readBindings:config];
}

- (NSMutableArray<SlateConfigEntry *> *)entriesForSection:(NSString *)section {
  if ([section isEqualToString:@"settings"]) return self.settings;
  if ([section isEqualToString:@"modifiers"]) return self.modifiers;
  if ([section isEqualToString:@"monitors"]) return self.monitors;
  if ([section isEqualToString:@"positions"]) return self.positions;
  return self.aliases;
}

- (NSError *)readEntries:(SlateYAMLMapping *)config section:(NSString *)section into:(NSMutableArray<SlateConfigEntry *> *)entries {
  id value = [config objectForKey:section];
  if (value == nil || value == [NSNull null]) return nil;
  if (![value isKindOfClass:[SlateYAMLMapping class]]) {
    return DocumentError(SlateConfigDocumentErrorInvalid, [NSString stringWithFormat:@"%@ should be a list of \"name: value\" lines.", section],
                         [config lineForKey:section], nil, nil);
  }
  BOOL settings = [section isEqualToString:@"settings"];
  SlateYAMLMapping *mapping = value;
  for (NSString *name in mapping.keys) {
    id item = [mapping objectForKey:name];
    NSUInteger line = [mapping lineForKey:name];
    if (settings && [item isKindOfClass:[NSArray class]]) {
      // A list is the same as its items joined with ';', as in slate.config.
      for (id part in item) {
        if (!IsScalarText(part)) {
          return DocumentError(SlateConfigDocumentErrorInvalid, [NSString stringWithFormat:@"Setting \"%@\": list items should be text or numbers.", name], line, nil, name);
        }
      }
      item = [[item valueForKey:@"description"] componentsJoinedByString:@";"];
    }
    BOOL ok = settings ? (IsScalarText(item) || IsBoolean(item)) : IsScalarText(item);
    if (!ok) {
      NSString *expected = settings ? @"text, a number, or true/false" : @"text or a number";
      NSString *what = settings ? @"Setting" : @"Alias";
      return DocumentError(SlateConfigDocumentErrorInvalid, [NSString stringWithFormat:@"%@ \"%@\" should be %@.", what, name, expected], line, nil, name);
    }
    SlateConfigEntry *entry = [SlateConfigEntry entryWithName:name value:item];
    entry.line = line;
    [entries addObject:entry];
  }
  return nil;
}

- (NSError *)readBindings:(SlateYAMLMapping *)config {
  id value = [config objectForKey:@"bindings"];
  if (value == nil || value == [NSNull null]) return nil;
  NSUInteger sectionLine = [config lineForKey:@"bindings"];
  if (![value isKindOfClass:[NSArray class]]) {
    return DocumentError(SlateConfigDocumentErrorInvalid, @"bindings should be a list, with each binding starting with \"- \".", sectionLine, nil, nil);
  }
  NSArray *items = value;
  for (NSUInteger i = 0; i < [items count]; i++) {
    id item = items[i];
    NSNumber *index = @(i);
    NSString *where = [NSString stringWithFormat:@"Binding #%lu", (unsigned long)i + 1];
    if (![item isKindOfClass:[SlateYAMLMapping class]]) {
      return DocumentError(SlateConfigDocumentErrorInvalid, [where stringByAppendingString:@" should have key: and action: lines."], sectionLine, index, nil);
    }
    SlateYAMLMapping *b = item;
    for (NSString *field in b.keys) {
      if (![BindingFields() containsObject:field]) {
        return DocumentError(SlateConfigDocumentErrorInvalid,
                             [NSString stringWithFormat:@"%@ has an unknown field \"%@\". Fields are %@.", where, field, [BindingFields() componentsJoinedByString:@", "]],
                             [b lineForKey:field], index, nil);
      }
    }
    id key = [b objectForKey:@"key"];
    if (!IsScalarText(key) || [ScalarText(key) length] == 0) {
      return DocumentError(SlateConfigDocumentErrorInvalid, [where stringByAppendingString:@" needs a key."], b.line, index, nil);
    }
    where = [NSString stringWithFormat:@"%@ (%@)", where, ScalarText(key)];
    id action = [b objectForKey:@"action"];
    if (!IsScalarText(action) || [[ScalarText(action) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0) {
      return DocumentError(SlateConfigDocumentErrorInvalid, [where stringByAppendingString:@" needs an action."], b.line, index, nil);
    }
    for (NSString *field in @[@"group", @"mods", @"note"]) {
      id text = [b objectForKey:field];
      if (text != nil && text != [NSNull null] && !IsScalarText(text)) {
        return DocumentError(SlateConfigDocumentErrorInvalid, [NSString stringWithFormat:@"%@: %@ should be text.", where, field], [b lineForKey:field], index, nil);
      }
    }
    for (NSString *field in @[@"enabled", @"repeat"]) {
      id flag = [b objectForKey:field];
      if (flag != nil && flag != [NSNull null] && !IsBoolean(flag)) {
        return DocumentError(SlateConfigDocumentErrorInvalid, [NSString stringWithFormat:@"%@: %@ should be true or false.", where, field], [b lineForKey:field], index, nil);
      }
    }
    id mods = [b objectForKey:@"mods"], group = [b objectForKey:@"group"], note = [b objectForKey:@"note"];
    id enabled = [b objectForKey:@"enabled"], repeat = [b objectForKey:@"repeat"];
    SlateBindingEntry *binding = [SlateBindingEntry bindingWithKey:ScalarText(key)
                                                         modifiers:IsScalarText(mods) ? ScalarText(mods) : nil
                                                            action:ScalarText(action)];
    binding.group = IsScalarText(group) ? ScalarText(group) : nil;
    binding.note = IsScalarText(note) ? ScalarText(note) : nil;
    binding.enabled = IsBoolean(enabled) ? [enabled boolValue] : YES;
    binding.repeat = IsBoolean(repeat) ? repeat : nil;
    binding.line = b.line;
    [self.bindings addObject:binding];
  }
  return nil;
}

#pragma mark - Resolving

static const NSUInteger kMaxAliasDepth = 20;

- (SlateResolvedConfig *)resolve:(NSError **)error {
  NSMutableArray *errors = [NSMutableArray array];
  SlateResolvedConfig *resolved = [self resolveCollectingErrors:errors];
  if ([errors count] > 0) {
    if (error) *error = errors[0];
    return nil;
  }
  return resolved;
}

// Expands ${name} references, following aliases that use other aliases, the
// way ~/.slate did: an unknown alias is an error. Returns nil on error.
- (NSString *)expand:(NSString *)text table:(NSDictionary *)table where:(NSString *)where
                line:(NSUInteger)line bindingIndex:(NSNumber *)index entryName:(NSString *)name errors:(NSMutableArray *)errors {
  static NSRegularExpression *reference;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ reference = [NSRegularExpression regularExpressionWithPattern:@"\\$\\{([^}]*)\\}" options:0 error:nil]; });
  NSString *result = text;
  for (NSUInteger depth = 0; [result rangeOfString:@"${"].location != NSNotFound; depth++) {
    if (depth >= kMaxAliasDepth) {
      [errors addObject:DocumentError(SlateConfigDocumentErrorInvalid, [NSString stringWithFormat:@"Aliases refer to each other in a loop in %@.", where], line, index, name)];
      return nil;
    }
    NSMutableString *next = [NSMutableString string];
    NSUInteger last = 0;
    for (NSTextCheckingResult *match in [reference matchesInString:result options:0 range:NSMakeRange(0, [result length])]) {
      NSString *alias = [result substringWithRange:[match rangeAtIndex:1]];
      NSString *value = table[alias];
      if (value == nil) {
        [errors addObject:DocumentError(SlateConfigDocumentErrorInvalid, [NSString stringWithFormat:@"Unknown alias ${%@} in %@.", alias, where], line, index, name)];
        return nil;
      }
      [next appendString:[result substringWithRange:NSMakeRange(last, [match range].location - last)]];
      [next appendString:value];
      last = NSMaxRange([match range]);
    }
    if (last == 0) break;  // a "${" with no closing brace: nothing more to expand
    [next appendString:[result substringFromIndex:last]];
    result = next;
  }
  return result;
}

- (SlateResolvedConfig *)resolveCollectingErrors:(NSMutableArray<NSError *> *)errors {
  NSMutableDictionary<NSString *, NSString *> *table = [NSMutableDictionary dictionary];
  for (NSArray<SlateConfigEntry *> *section in @[self.modifiers, self.monitors, self.positions, self.aliases]) {
    for (SlateConfigEntry *entry in section) {
      if (table[entry.name] != nil) {
        [errors addObject:DocumentError(SlateConfigDocumentErrorInvalid,
                                        [NSString stringWithFormat:@"The alias \"%@\" is defined more than once.", entry.name], entry.line, nil, entry.name)];
        continue;
      }
      table[entry.name] = ScalarText(entry.value);
    }
  }

  NSMutableArray *settings = [NSMutableArray array];
  for (SlateConfigEntry *entry in self.settings) {
    id value = entry.value;
    if ([value isKindOfClass:[NSString class]]) {
      value = [self expand:value table:table where:[NSString stringWithFormat:@"setting \"%@\"", entry.name]
                      line:entry.line bindingIndex:nil entryName:entry.name errors:errors];
      if (value == nil) continue;
    }
    SlateConfigEntry *expanded = [SlateConfigEntry entryWithName:entry.name value:value];
    expanded.line = entry.line;
    [settings addObject:expanded];
  }

  NSMutableArray *bindings = [NSMutableArray array];
  for (NSUInteger i = 0; i < [self.bindings count]; i++) {
    SlateBindingEntry *binding = self.bindings[i];
    if (!binding.enabled) continue;
    NSString *where = [NSString stringWithFormat:@"binding #%lu (%@)", (unsigned long)i + 1, binding.key];
    NSString *key = [self expand:binding.key table:table where:where line:binding.line bindingIndex:@(i) entryName:nil errors:errors];
    NSString *mods = [binding.modifiers length] > 0
      ? [self expand:binding.modifiers table:table where:where line:binding.line bindingIndex:@(i) entryName:nil errors:errors] : @"";
    NSString *action = [self expand:binding.action table:table where:where line:binding.line bindingIndex:@(i) entryName:nil errors:errors];
    if (key == nil || mods == nil || action == nil) continue;
    SlateResolvedBinding *resolved = [[SlateResolvedBinding alloc] init];
    resolved.hotkey = [mods length] > 0 ? [NSString stringWithFormat:@"%@:%@", key, mods] : key;
    resolved.action = [action stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    resolved.repeat = binding.repeat;
    resolved.index = i;
    [bindings addObject:resolved];
  }

  SlateResolvedConfig *config = [[SlateResolvedConfig alloc] init];
  config.settings = settings;
  config.bindings = bindings;
  return config;
}

#pragma mark - Aliases and categories

- (NSString *)expandAliases:(NSString *)text {
  NSMutableDictionary *table = [NSMutableDictionary dictionary];
  for (NSArray<SlateConfigEntry *> *section in @[self.modifiers, self.monitors, self.positions, self.aliases]) {
    for (SlateConfigEntry *entry in section) {
      if (table[entry.name] == nil) table[entry.name] = [entry.value description];
    }
  }
  NSRegularExpression *reference = [NSRegularExpression regularExpressionWithPattern:@"\\$\\{([^}]*)\\}" options:0 error:nil];
  NSString *result = text ?: @"";
  for (NSUInteger depth = 0; depth < 20; depth++) {
    __block BOOL replaced = NO;
    NSMutableString *next = [NSMutableString string];
    __block NSUInteger last = 0;
    [reference enumerateMatchesInString:result options:0 range:NSMakeRange(0, [result length])
                             usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
      NSString *value = table[[result substringWithRange:[match rangeAtIndex:1]]];
      [next appendString:[result substringWithRange:NSMakeRange(last, [match range].location - last)]];
      [next appendString:value ?: [result substringWithRange:[match range]]];
      if (value != nil) replaced = YES;
      last = NSMaxRange([match range]);
    }];
    if (!replaced) break;
    [next appendString:[result substringFromIndex:last]];
    result = next;
  }
  return result;
}

- (SlateBindingCategory)categoryOfBinding:(SlateBindingEntry *)binding {
  NSString *action = [[self expandAliases:binding.action] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  NSRange space = [action rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]];
  NSString *op = [(space.location == NSNotFound ? action : [action substringToIndex:space.location]) lowercaseString];
  NSString *rest = space.location == NSNotFound ? @"" :
    [[action substringFromIndex:space.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

  if ([op isEqualToString:@"focus"]) {
    return ([rest hasPrefix:@"'"] || [rest hasPrefix:@"\""]) ? SlateBindingCategoryApps : SlateBindingCategoryWindowActions;
  }
  NSSet *layout = [NSSet setWithObjects:@"move", @"throw", @"corner", @"chain", @"sequence", @"layout",
                   @"snapshot", @"activate-snapshot", @"delete-snapshot", nil];
  if ([layout containsObject:op]) return SlateBindingCategoryLayout;
  NSSet *window = [NSSet setWithObjects:@"resize", @"nudge", @"push", @"undo", @"hide", @"show", @"toggle", nil];
  if ([window containsObject:op]) return SlateBindingCategoryWindowActions;
  return SlateBindingCategoryFeatures;
}

#pragma mark - Writing

- (void)appendSection:(NSString *)name entries:(NSArray<SlateConfigEntry *> *)entries to:(NSMutableString *)out {
  if ([entries count] == 0) {
    [out appendFormat:@"\n%@: {}\n", name];
    return;
  }
  [out appendFormat:@"\n%@:\n", name];
  for (SlateConfigEntry *entry in entries) {
    [out appendFormat:@"  %@: %@\n", [SlateYAML key:entry.name], [SlateYAML scalar:entry.value]];
  }
}

- (NSString *)stringRepresentation {
  NSMutableString *out = [NSMutableString stringWithString:kHeader];
  [self appendSection:@"settings" entries:self.settings to:out];
  [self appendSection:@"modifiers" entries:self.modifiers to:out];
  [self appendSection:@"monitors" entries:self.monitors to:out];
  [self appendSection:@"positions" entries:self.positions to:out];
  [self appendSection:@"aliases" entries:self.aliases to:out];
  if ([self.bindings count] == 0) {
    [out appendString:@"\nbindings: []\n"];
    return out;
  }
  [out appendString:@"\nbindings:\n"];
  for (SlateBindingEntry *binding in self.bindings) {
    NSArray *fields = [binding yamlFields];
    [out appendFormat:@"  - %@\n", fields[0]];
    for (NSUInteger i = 1; i < [fields count]; i++) [out appendFormat:@"    %@\n", fields[i]];
  }
  return out;
}

- (BOOL)writeToFile:(NSString *)path error:(NSError **)error {
  return [SlateConfigDocument writeString:[self stringRepresentation] toFile:path error:error];
}

+ (BOOL)writeString:(NSString *)contents toFile:(NSString *)path error:(NSError **)error {
  return [self writeString:contents toFile:path backup:YES error:error];
}

+ (BOOL)writeString:(NSString *)contents toFile:(NSString *)path backup:(BOOL)backup error:(NSError **)error {
  NSString *target = [[path stringByExpandingTildeInPath] stringByResolvingSymlinksInPath];
  NSFileManager *fm = [NSFileManager defaultManager];
  if (backup && [fm fileExistsAtPath:target]) {
    NSString *backupPath = [target stringByAppendingString:@".bak"];
    [fm removeItemAtPath:backupPath error:nil];
    if (![fm copyItemAtPath:target toPath:backupPath error:error]) return NO;
  }
  return [contents writeToFile:target atomically:YES encoding:NSUTF8StringEncoding error:error];
}

@end
