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
#import <JavaScriptCore/JavaScriptCore.h>

NSString *const SlateConfigDocumentErrorDomain = @"SlateConfigDocumentErrorDomain";
NSString *const SlateConfigDocumentErrorLineKey = @"SlateConfigDocumentErrorLine";
NSString *const SlateConfigDocumentCustomCodeMarker = @"// ---- Custom code (preserved as-is by the configuration window) ----";

// Any line starting with this is treated as the marker, so small edits to its wording still work.
static NSString *const kMarkerPrefix = @"// ---- Custom code";

static NSString *const kHeader =
  @"// Slate configuration, managed by the Slate configuration window.\n"
  @"// The window reads and writes the `config` object below, so keep it a plain\n"
  @"// object literal. Anything after the custom code marker is left untouched.\n";

// Runs before the managed block: a stand-in `slate` that only records applyConfig calls.
static NSString *const kCapturePrelude =
  @"var window = this;\n"
  @"var __slateCaptured = [];\n"
  @"var slate = { applyConfig: function(c) { __slateCaptured.push(c); } };\n"
  @"var S = slate;\n";

// Converts the captured config into ordered, plain data (objects become [{name, value}]).
static NSString *const kExportFunction =
  @"(function(c) {\n"
  @"  function pairs(o) {\n"
  @"    if (o === undefined || o === null) return [];\n"
  @"    return Object.keys(o).map(function(k) {\n"
  @"      var v = o[k];\n"
  @"      if (Array.isArray(v)) v = v.join(';');\n"
  @"      return { name: k, value: v };\n"
  @"    });\n"
  @"  }\n"
  @"  function opt(v) { return (v === undefined || v === null) ? null : String(v); }\n"
  @"  return {\n"
  @"    settings: pairs(c.settings), modifiers: pairs(c.modifiers), monitors: pairs(c.monitors),\n"
  @"    positions: pairs(c.positions), aliases: pairs(c.aliases),\n"
  @"    bindings: (c.bindings || []).map(function(b) {\n"
  @"      return { group: opt(b.group), key: b.key, mods: opt(b.mods), action: b.action, note: opt(b.note),\n"
  @"               enabled: b.enabled !== false, repeat: typeof b.repeat === 'boolean' ? b.repeat : null };\n"
  @"    })\n"
  @"  };\n"
  @"})";

static NSError *DocumentError(SlateConfigDocumentError code, NSString *message, NSNumber *line) {
  NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey];
  if (line != nil) info[SlateConfigDocumentErrorLineKey] = line;
  return [NSError errorWithDomain:SlateConfigDocumentErrorDomain code:code userInfo:info];
}

static id NilIfNull(id value) {
  return (value == nil || value == [NSNull null]) ? nil : value;
}

static BOOL IsBoolean(id value) {
  return [value isKindOfClass:[NSNumber class]] && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
}

static NSString *JSStringLiteral(NSString *s) {
  NSData *data = [NSJSONSerialization dataWithJSONObject:s
                                                 options:NSJSONWritingFragmentsAllowed | NSJSONWritingWithoutEscapingSlashes
                                                   error:nil];
  return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

static NSString *JSLiteral(id value) {
  if (IsBoolean(value)) return [value boolValue] ? @"true" : @"false";
  if ([value isKindOfClass:[NSNumber class]]) return [value stringValue];
  return JSStringLiteral([value description]);
}

static NSString *JSKey(NSString *name) {
  static NSRegularExpression *identifier;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    identifier = [NSRegularExpression regularExpressionWithPattern:@"^[A-Za-z_$][A-Za-z0-9_$]*$" options:0 error:nil];
  });
  BOOL plain = [identifier numberOfMatchesInString:name options:0 range:NSMakeRange(0, [name length])] == 1;
  return plain ? name : JSStringLiteral(name);
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
  return [NSString stringWithFormat:@"%@ = %@", self.name, JSLiteral(self.value)];
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
  return [self literal];
}

- (NSString *)literal {
  NSMutableArray *fields = [NSMutableArray array];
  if ([self.group length] > 0) [fields addObject:[@"group: " stringByAppendingString:JSStringLiteral(self.group)]];
  [fields addObject:[@"key: " stringByAppendingString:JSStringLiteral(self.key)]];
  if ([self.modifiers length] > 0) [fields addObject:[@"mods: " stringByAppendingString:JSStringLiteral(self.modifiers)]];
  [fields addObject:[@"action: " stringByAppendingString:JSStringLiteral(self.action)]];
  if (self.repeat != nil) [fields addObject:[self.repeat boolValue] ? @"repeat: true" : @"repeat: false"];
  if (!self.enabled) [fields addObject:@"enabled: false"];
  if ([self.note length] > 0) [fields addObject:[@"note: " stringByAppendingString:JSStringLiteral(self.note)]];
  return [NSString stringWithFormat:@"{ %@ }", [fields componentsJoinedByString:@", "]];
}

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
    _customCode = @"";
  }
  return self;
}

+ (NSString *)defaultPath {
  return [@"~/.slate.js" stringByExpandingTildeInPath];
}

#pragma mark - Reading

+ (instancetype)documentWithContentsOfFile:(NSString *)path error:(NSError **)error {
  NSString *source = [NSString stringWithContentsOfFile:[path stringByExpandingTildeInPath] encoding:NSUTF8StringEncoding error:error];
  if (source == nil) return nil;
  return [self documentFromString:source error:error];
}

// Finds the marker at the start of a line. Returns NSNotFound when absent.
+ (NSUInteger)markerLocationInString:(NSString *)source {
  NSUInteger searchFrom = 0;
  while (searchFrom < [source length]) {
    NSRange r = [source rangeOfString:kMarkerPrefix options:0 range:NSMakeRange(searchFrom, [source length] - searchFrom)];
    if (r.location == NSNotFound) return NSNotFound;
    if (r.location == 0 || [source characterAtIndex:r.location - 1] == '\n') return r.location;
    searchFrom = NSMaxRange(r);
  }
  return NSNotFound;
}

+ (instancetype)documentFromString:(NSString *)source error:(NSError **)error {
  NSString *managed = source;
  NSString *custom = @"";
  NSUInteger marker = [self markerLocationInString:source];
  if (marker != NSNotFound) {
    managed = [source substringToIndex:marker];
    NSRange lineEnd = [source rangeOfString:@"\n" options:0 range:NSMakeRange(marker, [source length] - marker)];
    custom = lineEnd.location == NSNotFound ? @"" : [source substringFromIndex:NSMaxRange(lineEnd)];
  }

  // The default exception handler stores each exception in context.exception.
  JSContext *context = [[JSContext alloc] init];
  NSString *runtimePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"managed-config" ofType:@"js"];
  NSString *runtime = runtimePath ? [NSString stringWithContentsOfFile:runtimePath encoding:NSUTF8StringEncoding error:nil] : nil;
  if (runtime == nil) {
    if (error) *error = DocumentError(SlateConfigDocumentErrorScript, @"Slate's managed-config.js resource is missing.", nil);
    return nil;
  }
  [context evaluateScript:runtime];
  [context evaluateScript:kCapturePrelude];

  [context evaluateScript:managed withSourceURL:[NSURL fileURLWithPath:@".slate.js"]];
  if (context.exception != nil) {
    JSValue *exception = context.exception;
    NSString *message = [exception toString];
    NSNumber *line = [exception[@"line"] isNumber] ? [exception[@"line"] toNumber] : nil;
    BOOL callsOtherSlateAPI = [message rangeOfString:@"is not a function"].location != NSNotFound &&
                              ([message hasPrefix:@"TypeError: slate."] || [message hasPrefix:@"TypeError: S."]);
    if (error) {
      *error = callsOtherSlateAPI
        ? DocumentError(SlateConfigDocumentErrorNotManaged,
                        [NSString stringWithFormat:@"The managed block can only call slate.applyConfig. Move other code below the custom code marker. (%@)", message], line)
        : DocumentError(SlateConfigDocumentErrorScript, message, line);
    }
    return nil;
  }

  NSUInteger calls = [[context[@"__slateCaptured"][@"length"] toNumber] unsignedIntegerValue];
  if (calls != 1) {
    if (error) {
      NSString *message = calls == 0
        ? @"The file doesn't call slate.applyConfig(config), so it isn't in the managed format."
        : @"The file calls slate.applyConfig more than once, so it isn't in the managed format.";
      *error = DocumentError(SlateConfigDocumentErrorNotManaged, message, nil);
    }
    return nil;
  }

  JSValue *config = context[@"__slateCaptured"][0];
  [context[@"_slateManagedConfig"][@"resolve"] callWithArguments:@[config]];
  if (context.exception != nil) {
    if (error) *error = DocumentError(SlateConfigDocumentErrorInvalid, [context.exception toString], nil);
    return nil;
  }

  NSDictionary *data = [[[context evaluateScript:kExportFunction] callWithArguments:@[config]] toDictionary];
  if (context.exception != nil || data == nil) {
    if (error) *error = DocumentError(SlateConfigDocumentErrorInvalid, [context.exception toString] ?: @"Couldn't read the config object.", nil);
    return nil;
  }

  SlateConfigDocument *doc = [[self alloc] init];
  doc.settings = [self entriesFrom:data[@"settings"]];
  doc.modifiers = [self entriesFrom:data[@"modifiers"]];
  doc.monitors = [self entriesFrom:data[@"monitors"]];
  doc.positions = [self entriesFrom:data[@"positions"]];
  doc.aliases = [self entriesFrom:data[@"aliases"]];
  for (NSDictionary *b in data[@"bindings"]) {
    SlateBindingEntry *binding = [SlateBindingEntry bindingWithKey:b[@"key"] modifiers:NilIfNull(b[@"mods"]) action:b[@"action"]];
    binding.group = NilIfNull(b[@"group"]);
    binding.note = NilIfNull(b[@"note"]);
    binding.enabled = [b[@"enabled"] boolValue];
    binding.repeat = NilIfNull(b[@"repeat"]);
    [doc.bindings addObject:binding];
  }
  doc.customCode = custom;
  return doc;
}

+ (NSMutableArray<SlateConfigEntry *> *)entriesFrom:(NSArray *)pairs {
  NSMutableArray *entries = [NSMutableArray arrayWithCapacity:[pairs count]];
  for (NSDictionary *pair in pairs) {
    [entries addObject:[SlateConfigEntry entryWithName:pair[@"name"] value:pair[@"value"]]];
  }
  return entries;
}

#pragma mark - Writing

- (void)appendSection:(NSString *)name entries:(NSArray<SlateConfigEntry *> *)entries to:(NSMutableString *)out {
  if ([entries count] == 0) {
    [out appendFormat:@"  %@: {},\n", name];
    return;
  }
  [out appendFormat:@"  %@: {\n", name];
  for (SlateConfigEntry *entry in entries) {
    [out appendFormat:@"    %@: %@,\n", JSKey(entry.name), JSLiteral(entry.value)];
  }
  [out appendString:@"  },\n"];
}

- (NSString *)stringRepresentation {
  NSMutableString *out = [NSMutableString stringWithString:kHeader];
  [out appendString:@"var config = {\n"];
  [self appendSection:@"settings" entries:self.settings to:out];
  [self appendSection:@"modifiers" entries:self.modifiers to:out];
  [self appendSection:@"monitors" entries:self.monitors to:out];
  [self appendSection:@"positions" entries:self.positions to:out];
  [self appendSection:@"aliases" entries:self.aliases to:out];
  if ([self.bindings count] == 0) {
    [out appendString:@"  bindings: [],\n"];
  } else {
    [out appendString:@"  bindings: [\n"];
    for (SlateBindingEntry *binding in self.bindings) {
      [out appendFormat:@"    %@,\n", [binding literal]];
    }
    [out appendString:@"  ],\n"];
  }
  [out appendString:@"};\n\nslate.applyConfig(config);\n\n"];
  [out appendString:SlateConfigDocumentCustomCodeMarker];
  [out appendString:@"\n"];
  [out appendString:self.customCode ?: @""];
  return out;
}

- (BOOL)writeToFile:(NSString *)path error:(NSError **)error {
  return [SlateConfigDocument writeString:[self stringRepresentation] toFile:path error:error];
}

+ (BOOL)writeString:(NSString *)contents toFile:(NSString *)path error:(NSError **)error {
  NSString *target = [[path stringByExpandingTildeInPath] stringByResolvingSymlinksInPath];
  NSFileManager *fm = [NSFileManager defaultManager];
  if ([fm fileExistsAtPath:target]) {
    NSString *backup = [target stringByAppendingString:@".bak"];
    [fm removeItemAtPath:backup error:nil];
    if (![fm copyItemAtPath:target toPath:backup error:error]) return NO;
  }
  return [contents writeToFile:target atomically:YES encoding:NSUTF8StringEncoding error:error];
}

@end
