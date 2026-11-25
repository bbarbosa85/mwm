//
//  MWMConfigDocument.m
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

#import "MWMConfigDocument.h"
#import "MWMConfigurations.h"
#import "MWMDisplays.h"
#import "MWMConfigFormat.h"
#import "MWMSlots.h"
#import "MWMYAML.h"

NSString *const MWMConfigDocumentErrorDomain = @"MWMConfigDocumentErrorDomain";
NSString *const MWMConfigDocumentErrorLineKey = @"MWMConfigDocumentErrorLine";
NSString *const MWMConfigDocumentErrorBindingIndexKey = @"MWMConfigDocumentErrorBindingIndex";
NSString *const MWMConfigDocumentErrorEntryNameKey = @"MWMConfigDocumentErrorEntryName";

static NSString *const kHeader =
  @"# MWM configuration, managed by the configuration window (Settings...).\n"
  @"# The window rewrites this file when you change something there, so comments\n"
  @"# added here aren't kept. In free text, ${name} refers to an entry in modifiers,\n"
  @"# monitors, slots or aliases.\n";

static NSArray<NSString *> *Sections(void) {
  return @[@"settings", @"modifiers", @"monitors", @"positions", @"aliases", @"bindings"];
}

static NSArray<NSString *> *BindingFields(void) {
  return @[@"group", @"key", @"mods", @"action", @"note", @"enabled", @"repeat"];
}

static NSError *DocumentError(MWMConfigDocumentError code, NSString *message, NSUInteger line, NSNumber *bindingIndex, NSString *entryName) {
  NSString *text = line > 0 ? [NSString stringWithFormat:@"Line %lu: %@", (unsigned long)line, message] : message;
  NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject:text forKey:NSLocalizedDescriptionKey];
  if (line > 0) info[MWMConfigDocumentErrorLineKey] = @(line);
  if (bindingIndex != nil) info[MWMConfigDocumentErrorBindingIndexKey] = bindingIndex;
  if (entryName != nil) info[MWMConfigDocumentErrorEntryNameKey] = entryName;
  return [NSError errorWithDomain:MWMConfigDocumentErrorDomain code:code userInfo:info];
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

@implementation MWMConfigEntry

+ (instancetype)entryWithName:(NSString *)name value:(id)value {
  MWMConfigEntry *entry = [[self alloc] init];
  entry.name = name;
  entry.value = value;
  return entry;
}

- (BOOL)isEqual:(id)other {
  if (![other isKindOfClass:[MWMConfigEntry class]]) return NO;
  MWMConfigEntry *o = other;
  return [self.name isEqualToString:o.name] && [self.value isEqual:o.value] && IsBoolean(self.value) == IsBoolean(o.value);
}

- (NSUInteger)hash {
  return [self.name hash];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"%@: %@", self.name, [MWMYAML scalar:self.value]];
}

@end

@implementation MWMBindingEntry

+ (instancetype)bindingWithKey:(NSString *)key modifiers:(NSString *)modifiers action:(NSString *)action {
  MWMBindingEntry *binding = [[self alloc] init];
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
  if (![other isKindOfClass:[MWMBindingEntry class]]) return NO;
  MWMBindingEntry *o = other;
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
  if ([self.group length] > 0) [fields addObject:[@"group: " stringByAppendingString:[MWMYAML quotedString:self.group]]];
  [fields addObject:[@"key: " stringByAppendingString:[MWMYAML quotedString:self.key]]];
  if ([self.modifiers length] > 0) [fields addObject:[@"mods: " stringByAppendingString:[MWMYAML quotedString:self.modifiers]]];
  [fields addObject:[@"action: " stringByAppendingString:[MWMYAML quotedString:self.action]]];
  if (self.repeat != nil) [fields addObject:[self.repeat boolValue] ? @"repeat: true" : @"repeat: false"];
  if (!self.enabled) [fields addObject:@"enabled: false"];
  if ([self.note length] > 0) [fields addObject:[@"note: " stringByAppendingString:[MWMYAML quotedString:self.note]]];
  return fields;
}

@end

@implementation MWMResolvedBinding
- (NSString *)description {
  return [NSString stringWithFormat:@"bind %@ %@", self.hotkey, self.action];
}
@end

@implementation MWMResolvedConfig
@end

@interface MWMConfigDocument ()
@property (assign) NSInteger sourceVersion;
@end

@implementation MWMConfigDocument

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
  return [MWMConfigurations activePath];
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
  id root = [MWMYAML parse:source error:&yamlError];
  if (root == nil) {
    if (error) {
      NSNumber *line = yamlError.userInfo[MWMYAMLErrorLineKey];
      NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject:[yamlError localizedDescription] forKey:NSLocalizedDescriptionKey];
      if (line != nil) info[MWMConfigDocumentErrorLineKey] = line;
      *error = [NSError errorWithDomain:MWMConfigDocumentErrorDomain code:MWMConfigDocumentErrorSyntax userInfo:info];
    }
    return nil;
  }

  MWMConfigDocument *doc = [[self alloc] init];
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
  if (![root isKindOfClass:[MWMYAMLMapping class]]) {
    return DocumentError(MWMConfigDocumentErrorInvalid, @"The file should be a mapping of sections (settings:, bindings:, ...).", 1, nil, nil);
  }
  MWMYAMLMapping *config = root;
  self.sourceVersion = 1;
  id version = [config objectForKey:@"version"];
  if (version != nil) {
    if (![version isKindOfClass:[NSNumber class]] || ([version integerValue] != 1 && [version integerValue] != 2) || IsBoolean(version)) {
      return DocumentError(MWMConfigDocumentErrorInvalid, @"version should be 1 or 2.", [config lineForKey:@"version"], nil, nil);
    }
    self.sourceVersion = [version integerValue];
  }
  if (self.sourceVersion == 2) {
    NSError *conversionError = nil;
    MWMYAMLMapping *tree = [MWMConfigFormat versionOneTreeFromVersionTwo:config error:&conversionError];
    if (tree == nil) return conversionError;
    config = tree;
  }
  for (NSString *section in config.keys) {
    if ([section isEqualToString:@"version"]) continue;
    if (![Sections() containsObject:section]) {
      return DocumentError(MWMConfigDocumentErrorInvalid,
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

- (NSMutableArray<MWMConfigEntry *> *)entriesForSection:(NSString *)section {
  if ([section isEqualToString:@"settings"]) return self.settings;
  if ([section isEqualToString:@"modifiers"]) return self.modifiers;
  if ([section isEqualToString:@"monitors"]) return self.monitors;
  if ([section isEqualToString:@"positions"]) return self.positions;
  return self.aliases;
}

- (NSError *)readEntries:(MWMYAMLMapping *)config section:(NSString *)section into:(NSMutableArray<MWMConfigEntry *> *)entries {
  id value = [config objectForKey:section];
  if (value == nil || value == [NSNull null]) return nil;
  if (![value isKindOfClass:[MWMYAMLMapping class]]) {
    return DocumentError(MWMConfigDocumentErrorInvalid, [NSString stringWithFormat:@"%@ should be a list of \"name: value\" lines.", section],
                         [config lineForKey:section], nil, nil);
  }
  BOOL settings = [section isEqualToString:@"settings"];
  MWMYAMLMapping *mapping = value;
  for (NSString *name in mapping.keys) {
    id item = [mapping objectForKey:name];
    NSUInteger line = [mapping lineForKey:name];
    if (settings && [item isKindOfClass:[NSArray class]]) {
      // A list is the same as its items joined with ';', as in slate.config.
      for (id part in item) {
        if (!IsScalarText(part)) {
          return DocumentError(MWMConfigDocumentErrorInvalid, [NSString stringWithFormat:@"Setting \"%@\": list items should be text or numbers.", name], line, nil, name);
        }
      }
      item = [[item valueForKey:@"description"] componentsJoinedByString:@";"];
    }
    BOOL ok = settings ? (IsScalarText(item) || IsBoolean(item)) : IsScalarText(item);
    if (!ok) {
      NSString *expected = settings ? @"text, a number, or true/false" : @"text or a number";
      NSString *what = settings ? @"Setting" : @"Alias";
      return DocumentError(MWMConfigDocumentErrorInvalid, [NSString stringWithFormat:@"%@ \"%@\" should be %@.", what, name, expected], line, nil, name);
    }
    MWMConfigEntry *entry = [MWMConfigEntry entryWithName:name value:item];
    entry.line = line;
    [entries addObject:entry];
  }
  return nil;
}

- (NSError *)readBindings:(MWMYAMLMapping *)config {
  id value = [config objectForKey:@"bindings"];
  if (value == nil || value == [NSNull null]) return nil;
  NSUInteger sectionLine = [config lineForKey:@"bindings"];
  if (![value isKindOfClass:[NSArray class]]) {
    return DocumentError(MWMConfigDocumentErrorInvalid, @"bindings should be a list, with each binding starting with \"- \".", sectionLine, nil, nil);
  }
  NSArray *items = value;
  for (NSUInteger i = 0; i < [items count]; i++) {
    id item = items[i];
    NSNumber *index = @(i);
    NSString *where = [NSString stringWithFormat:@"Binding #%lu", (unsigned long)i + 1];
    if (![item isKindOfClass:[MWMYAMLMapping class]]) {
      return DocumentError(MWMConfigDocumentErrorInvalid, [where stringByAppendingString:@" should have key: and action: lines."], sectionLine, index, nil);
    }
    MWMYAMLMapping *b = item;
    for (NSString *field in b.keys) {
      if (![BindingFields() containsObject:field]) {
        return DocumentError(MWMConfigDocumentErrorInvalid,
                             [NSString stringWithFormat:@"%@ has an unknown field \"%@\". Fields are %@.", where, field, [BindingFields() componentsJoinedByString:@", "]],
                             [b lineForKey:field], index, nil);
      }
    }
    id key = [b objectForKey:@"key"];
    if (!IsScalarText(key) || [ScalarText(key) length] == 0) {
      return DocumentError(MWMConfigDocumentErrorInvalid, [where stringByAppendingString:@" needs a key."], b.line, index, nil);
    }
    where = [NSString stringWithFormat:@"%@ (%@)", where, ScalarText(key)];
    id action = [b objectForKey:@"action"];
    if (!IsScalarText(action) || [[ScalarText(action) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0) {
      return DocumentError(MWMConfigDocumentErrorInvalid, [where stringByAppendingString:@" needs an action."], b.line, index, nil);
    }
    for (NSString *field in @[@"group", @"mods", @"note"]) {
      id text = [b objectForKey:field];
      if (text != nil && text != [NSNull null] && !IsScalarText(text)) {
        return DocumentError(MWMConfigDocumentErrorInvalid, [NSString stringWithFormat:@"%@: %@ should be text.", where, field], [b lineForKey:field], index, nil);
      }
    }
    for (NSString *field in @[@"enabled", @"repeat"]) {
      id flag = [b objectForKey:field];
      if (flag != nil && flag != [NSNull null] && !IsBoolean(flag)) {
        return DocumentError(MWMConfigDocumentErrorInvalid, [NSString stringWithFormat:@"%@: %@ should be true or false.", where, field], [b lineForKey:field], index, nil);
      }
    }
    id mods = [b objectForKey:@"mods"], group = [b objectForKey:@"group"], note = [b objectForKey:@"note"];
    id enabled = [b objectForKey:@"enabled"], repeat = [b objectForKey:@"repeat"];
    MWMBindingEntry *binding = [MWMBindingEntry bindingWithKey:ScalarText(key)
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

- (MWMResolvedConfig *)resolve:(NSError **)error {
  NSMutableArray *errors = [NSMutableArray array];
  MWMResolvedConfig *resolved = [self resolveCollectingErrors:errors];
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
      [errors addObject:DocumentError(MWMConfigDocumentErrorInvalid, [NSString stringWithFormat:@"Aliases refer to each other in a loop in %@.", where], line, index, name)];
      return nil;
    }
    NSMutableString *next = [NSMutableString string];
    NSUInteger last = 0;
    for (NSTextCheckingResult *match in [reference matchesInString:result options:0 range:NSMakeRange(0, [result length])]) {
      NSString *alias = [result substringWithRange:[match rangeAtIndex:1]];
      NSString *value = table[alias];
      if (value == nil) {
        [errors addObject:DocumentError(MWMConfigDocumentErrorInvalid, [NSString stringWithFormat:@"Unknown alias ${%@} in %@.", alias, where], line, index, name)];
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

- (MWMResolvedConfig *)resolveCollectingErrors:(NSMutableArray<NSError *> *)errors {
  NSMutableDictionary<NSString *, NSString *> *table = [NSMutableDictionary dictionary];
  NSArray<MWMDisplay *> *displays = [MWMDisplays connected];
  for (NSArray<MWMConfigEntry *> *section in @[self.modifiers, self.monitors, self.positions, self.aliases]) {
    for (MWMConfigEntry *entry in section) {
      if (table[entry.name] != nil) {
        [errors addObject:DocumentError(MWMConfigDocumentErrorInvalid,
                                        [NSString stringWithFormat:@"The alias \"%@\" is defined more than once.", entry.name], entry.line, nil, entry.name)];
        continue;
      }
      table[entry.name] = section == self.monitors ? [MWMDisplays referenceForValue:ScalarText(entry.value) displays:displays] : ScalarText(entry.value);
    }
  }
  // The built-in slots (${full}, ${lefthalf}, ...) work without being in the file.
  for (MWMSlot *preset in [MWMSlots presets]) {
    if (table[preset.name] == nil) table[preset.name] = preset.formula;
  }

  NSMutableArray *settings = [NSMutableArray array];
  for (MWMConfigEntry *entry in self.settings) {
    id value = entry.value;
    if ([value isKindOfClass:[NSString class]]) {
      value = [self expand:value table:table where:[NSString stringWithFormat:@"setting \"%@\"", entry.name]
                      line:entry.line bindingIndex:nil entryName:entry.name errors:errors];
      if (value == nil) continue;
    }
    MWMConfigEntry *expanded = [MWMConfigEntry entryWithName:entry.name value:value];
    expanded.line = entry.line;
    [settings addObject:expanded];
  }

  NSMutableArray *bindings = [NSMutableArray array];
  for (NSUInteger i = 0; i < [self.bindings count]; i++) {
    MWMBindingEntry *binding = self.bindings[i];
    if (!binding.enabled) continue;
    NSString *where = [NSString stringWithFormat:@"binding #%lu (%@)", (unsigned long)i + 1, binding.key];
    NSString *key = [self expand:binding.key table:table where:where line:binding.line bindingIndex:@(i) entryName:nil errors:errors];
    NSString *mods = [binding.modifiers length] > 0
      ? [self expand:binding.modifiers table:table where:where line:binding.line bindingIndex:@(i) entryName:nil errors:errors] : @"";
    NSString *action = [self expand:binding.action table:table where:where line:binding.line bindingIndex:@(i) entryName:nil errors:errors];
    if (key == nil || mods == nil || action == nil) continue;
    MWMResolvedBinding *resolved = [[MWMResolvedBinding alloc] init];
    resolved.hotkey = [mods length] > 0 ? [NSString stringWithFormat:@"%@:%@", key, mods] : key;
    resolved.action = [action stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    resolved.repeat = binding.repeat;
    resolved.index = i;
    [bindings addObject:resolved];
  }

  MWMResolvedConfig *config = [[MWMResolvedConfig alloc] init];
  config.settings = settings;
  config.bindings = bindings;
  return config;
}

#pragma mark - Aliases and categories

- (NSString *)expandAliases:(NSString *)text {
  NSMutableDictionary *table = [NSMutableDictionary dictionary];
  for (NSArray<MWMConfigEntry *> *section in @[self.modifiers, self.monitors, self.positions, self.aliases]) {
    for (MWMConfigEntry *entry in section) {
      if (table[entry.name] != nil) continue;
      NSString *text = [entry.value description];
      table[entry.name] = section == self.monitors ? [MWMDisplays referenceForValue:text] : text;
    }
  }
  for (MWMSlot *preset in [MWMSlots presets]) {
    if (table[preset.name] == nil) table[preset.name] = preset.formula;
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

- (MWMBindingCategory)categoryOfBinding:(MWMBindingEntry *)binding {
  NSString *action = [[self expandAliases:binding.action] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  NSRange space = [action rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]];
  NSString *op = [(space.location == NSNotFound ? action : [action substringToIndex:space.location]) lowercaseString];
  NSString *rest = space.location == NSNotFound ? @"" :
    [[action substringFromIndex:space.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

  if ([op isEqualToString:@"focus"]) {
    return ([rest hasPrefix:@"'"] || [rest hasPrefix:@"\""]) ? MWMBindingCategoryApps : MWMBindingCategoryWindowActions;
  }
  NSSet *layout = [NSSet setWithObjects:@"move", @"throw", @"corner", @"chain", @"sequence", @"layout",
                   @"snapshot", @"activate-snapshot", @"delete-snapshot", nil];
  if ([layout containsObject:op]) return MWMBindingCategoryLayout;
  NSSet *window = [NSSet setWithObjects:@"resize", @"nudge", @"push", @"undo", @"hide", @"show", @"toggle", nil];
  if ([window containsObject:op]) return MWMBindingCategoryWindowActions;
  return MWMBindingCategoryFeatures;
}

#pragma mark - Writing

- (void)appendSection:(NSString *)name entries:(NSArray<MWMConfigEntry *> *)entries to:(NSMutableString *)out {
  if ([entries count] == 0) {
    [out appendFormat:@"\n%@: {}\n", name];
    return;
  }
  [out appendFormat:@"\n%@:\n", name];
  for (MWMConfigEntry *entry in entries) {
    [out appendFormat:@"  %@: %@\n", [MWMYAML key:entry.name], [MWMYAML scalar:entry.value]];
  }
}

- (NSString *)stringRepresentation {
  return [MWMConfigFormat textForDocument:self header:kHeader];
}

- (void)renameReferencesFrom:(NSString *)from to:(NSString *)to {
  NSString *old = [NSString stringWithFormat:@"${%@}", from], *new = [NSString stringWithFormat:@"${%@}", to];
  for (MWMBindingEntry *binding in self.bindings) {
    binding.action = [binding.action stringByReplacingOccurrencesOfString:old withString:new];
    if (binding.key) binding.key = [binding.key stringByReplacingOccurrencesOfString:old withString:new];
    if (binding.modifiers) binding.modifiers = [binding.modifiers stringByReplacingOccurrencesOfString:old withString:new];
  }
  for (NSArray *section in @[self.modifiers, self.monitors, self.positions, self.aliases]) {
    for (MWMConfigEntry *entry in section) {
      if ([entry.value isKindOfClass:[NSString class]]) entry.value = [entry.value stringByReplacingOccurrencesOfString:old withString:new];
    }
  }
}

- (BOOL)writeToFile:(NSString *)path error:(NSError **)error {
  return [MWMConfigDocument writeString:[self stringRepresentation] toFile:path error:error];
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
