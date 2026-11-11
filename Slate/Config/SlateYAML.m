//
//  SlateYAML.m
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

#import "SlateYAML.h"

NSString *const SlateYAMLErrorDomain = @"SlateYAMLErrorDomain";
NSString *const SlateYAMLErrorLineKey = @"SlateYAMLErrorLine";

@interface SlateYAMLMapping ()
@property (strong) NSMutableArray<NSString *> *orderedKeys;
@property (strong) NSMutableDictionary<NSString *, id> *values;
@property (strong) NSMutableDictionary<NSString *, NSNumber *> *lines;
@end

@implementation SlateYAMLMapping

- (instancetype)init {
  self = [super init];
  if (self) {
    _orderedKeys = [NSMutableArray array];
    _values = [NSMutableDictionary dictionary];
    _lines = [NSMutableDictionary dictionary];
  }
  return self;
}

- (NSArray<NSString *> *)keys {
  return [self.orderedKeys copy];
}

- (id)objectForKey:(NSString *)key {
  return self.values[key];
}

- (NSUInteger)lineForKey:(NSString *)key {
  return [self.lines[key] unsignedIntegerValue];
}

- (NSString *)description {
  NSMutableArray *parts = [NSMutableArray array];
  for (NSString *key in self.orderedKeys) [parts addObject:[NSString stringWithFormat:@"%@: %@", key, self.values[key]]];
  return [NSString stringWithFormat:@"{%@}", [parts componentsJoinedByString:@", "]];
}

@end

// One significant (non-blank, non-comment) line.
@interface SlateYAMLLine : NSObject
@property (assign) NSUInteger number;  // 1-based
@property (assign) NSUInteger indent;
@property (copy) NSString *content;    // without indentation or comment
@end

@implementation SlateYAMLLine
@end

// Thrown internally and turned into an NSError by +parse:error:.
@interface SlateYAMLFailure : NSObject
@property (copy) NSString *message;
@property (assign) NSUInteger line;
@end

@implementation SlateYAMLFailure
@end

@interface SlateYAML ()
@property (strong) NSArray<SlateYAMLLine *> *lines;
@property (assign) NSUInteger index;
@property (strong, nullable) SlateYAMLFailure *failure;
@end

@implementation SlateYAML

#pragma mark - Lines

// Where a comment starts: '#' at the start or after whitespace, outside quotes.
// A quote opens a quoted scalar only where a scalar can start.
static NSUInteger CommentStart(NSString *s) {
  unichar quote = 0;
  unichar previous = ' ';
  NSUInteger length = [s length];
  for (NSUInteger i = 0; i < length; i++) {
    unichar c = [s characterAtIndex:i];
    if (quote == '"') {
      if (c == '\\') { i++; continue; }
      if (c == '"') quote = 0;
    } else if (quote == '\'') {
      if (c == '\'') quote = 0;  // '' re-opens on the next character
    } else if ((c == '"' || c == '\'') && (previous == ' ' || previous == '-' || previous == ':' || previous == '\t')) {
      quote = c;
    } else if (c == '#' && (previous == ' ' || previous == '\t')) {
      return i;
    }
    previous = c;
  }
  return NSNotFound;
}

- (BOOL)splitLines:(NSString *)text {
  NSMutableArray *lines = [NSMutableArray array];
  NSArray<NSString *> *raw = [[text stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"] componentsSeparatedByString:@"\n"];
  for (NSUInteger i = 0; i < [raw count]; i++) {
    NSString *line = raw[i];
    NSUInteger indent = 0;
    while (indent < [line length] && [line characterAtIndex:indent] == ' ') indent++;
    NSString *rest = [line substringFromIndex:indent];
    if ([rest hasPrefix:@"#"]) continue;
    NSUInteger comment = CommentStart([@" " stringByAppendingString:rest]);
    if (comment != NSNotFound) rest = [rest substringToIndex:comment - 1];
    rest = [rest stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([rest length] == 0) continue;
    if ([line length] > indent && [line characterAtIndex:indent] == '\t') {
      return [self fail:@"Indent with spaces, not tabs." line:i + 1];
    }
    if ([rest isEqualToString:@"---"] && [lines count] == 0) continue;  // document start
    if ([rest isEqualToString:@"---"] || [rest isEqualToString:@"..."] || [rest hasPrefix:@"--- "]) {
      return [self fail:@"Only one YAML document is supported." line:i + 1];
    }
    if ([rest hasPrefix:@"%"]) return [self fail:@"YAML directives aren't supported." line:i + 1];
    SlateYAMLLine *entry = [[SlateYAMLLine alloc] init];
    entry.number = i + 1;
    entry.indent = indent;
    entry.content = rest;
    [lines addObject:entry];
  }
  self.lines = lines;
  return YES;
}

- (BOOL)fail:(NSString *)message line:(NSUInteger)line {
  if (self.failure == nil) {
    self.failure = [[SlateYAMLFailure alloc] init];
    self.failure.message = message;
    self.failure.line = line;
  }
  return NO;
}

- (SlateYAMLLine *)current {
  return self.index < [self.lines count] ? self.lines[self.index] : nil;
}

static BOOL IsSequenceItem(NSString *content) {
  return [content isEqualToString:@"-"] || [content hasPrefix:@"- "];
}

#pragma mark - Blocks

// Parses the block starting at the current line, which is at `indent`.
- (id)parseBlockAtIndent:(NSUInteger)indent {
  SlateYAMLLine *line = [self current];
  if (IsSequenceItem(line.content)) return [self parseSequenceAtIndent:indent];
  if ([self keyEndIn:line.content] != NSNotFound) return [self parseMappingAtIndent:indent];
  // A lone scalar: only valid as a whole document or a sequence item.
  self.index++;
  return [self scalarFrom:line.content line:line.number];
}

- (NSArray *)parseSequenceAtIndent:(NSUInteger)indent {
  NSMutableArray *items = [NSMutableArray array];
  SlateYAMLLine *line;
  while (self.failure == nil && (line = [self current]) != nil && line.indent == indent && IsSequenceItem(line.content)) {
    NSString *rest = [line.content length] > 1 ? [line.content substringFromIndex:1] : @"";
    NSUInteger spaces = 0;
    while (spaces < [rest length] && [rest characterAtIndex:spaces] == ' ') spaces++;
    rest = [rest substringFromIndex:spaces];
    if ([rest length] == 0) {
      self.index++;
      SlateYAMLLine *next = [self current];
      if (next != nil && next.indent > indent) {
        [items addObject:[self parseBlockAtIndent:next.indent] ?: [NSNull null]];
      } else {
        [items addObject:[NSNull null]];
      }
    } else {
      // "- key: value" starts a block indented to where "key" is.
      line.indent = indent + 1 + spaces;
      line.content = rest;
      [items addObject:[self parseBlockAtIndent:line.indent] ?: [NSNull null]];
    }
    [self checkNoDeeperLineAfter:indent];
  }
  return items;
}

- (SlateYAMLMapping *)parseMappingAtIndent:(NSUInteger)indent {
  SlateYAMLMapping *mapping = [[SlateYAMLMapping alloc] init];
  mapping.line = [self current].number;
  SlateYAMLLine *line;
  while (self.failure == nil && (line = [self current]) != nil && line.indent == indent) {
    if (IsSequenceItem(line.content)) {
      [self fail:@"A list item can't be mixed into a mapping here. Check the indentation." line:line.number];
      break;
    }
    NSUInteger keyEnd = [self keyEndIn:line.content];
    if (keyEnd == NSNotFound) {
      [self fail:[NSString stringWithFormat:@"Expected \"name: value\", found \"%@\".", line.content] line:line.number];
      break;
    }
    NSString *key = [self keyFrom:[line.content substringToIndex:keyEnd] line:line.number];
    if (key == nil) break;
    if ([mapping objectForKey:key] != nil) {
      [self fail:[NSString stringWithFormat:@"\"%@\" appears twice (first on line %lu).", key, (unsigned long)[mapping lineForKey:key]] line:line.number];
      break;
    }
    NSString *rest = [[line.content substringFromIndex:keyEnd + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    id value;
    self.index++;
    if ([rest length] > 0) {
      value = [self scalarFrom:rest line:line.number];
      [self checkNoDeeperLineAfter:indent];
    } else {
      SlateYAMLLine *next = [self current];
      if (next != nil && (next.indent > indent || (next.indent == indent && IsSequenceItem(next.content)))) {
        value = [self parseBlockAtIndent:next.indent];
      } else {
        value = [NSNull null];
      }
    }
    if (self.failure != nil) break;
    [mapping.orderedKeys addObject:key];
    mapping.values[key] = value ?: [NSNull null];
    mapping.lines[key] = @(line.number);
  }
  return mapping;
}

// After a value that ends on its line, the next line can't be indented deeper.
- (void)checkNoDeeperLineAfter:(NSUInteger)indent {
  SlateYAMLLine *next = [self current];
  if (self.failure == nil && next != nil && next.indent > indent) {
    [self fail:@"Unexpected indentation. Multi-line values aren't supported; keep each value on one line." line:next.number];
  }
}

#pragma mark - Keys and scalars

// Index of the ':' that ends a mapping key, or NSNotFound.
- (NSUInteger)keyEndIn:(NSString *)content {
  NSUInteger length = [content length];
  if (length == 0) return NSNotFound;
  unichar first = [content characterAtIndex:0];
  NSUInteger start = 0;
  if (first == '"' || first == '\'') {
    NSUInteger close = [self closingQuoteIn:content];
    if (close == NSNotFound) return NSNotFound;
    start = close + 1;
  }
  for (NSUInteger i = start; i < length; i++) {
    if ([content characterAtIndex:i] != ':') continue;
    if (i + 1 == length || [content characterAtIndex:i + 1] == ' ') return i;
  }
  return NSNotFound;
}

// Index of the quote that closes the quoted scalar starting at 0.
- (NSUInteger)closingQuoteIn:(NSString *)s {
  unichar quote = [s characterAtIndex:0];
  for (NSUInteger i = 1; i < [s length]; i++) {
    unichar c = [s characterAtIndex:i];
    if (quote == '"' && c == '\\') { i++; continue; }
    if (c == quote) {
      if (quote == '\'' && i + 1 < [s length] && [s characterAtIndex:i + 1] == '\'') { i++; continue; }
      return i;
    }
  }
  return NSNotFound;
}

- (NSString *)keyFrom:(NSString *)raw line:(NSUInteger)line {
  NSString *key = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  if ([key length] == 0) {
    [self fail:@"A mapping key is empty." line:line];
    return nil;
  }
  unichar first = [key characterAtIndex:0];
  if (first == '"' || first == '\'') {
    id value = [self quotedFrom:key line:line];
    return [value isKindOfClass:[NSString class]] ? value : nil;
  }
  if ([self isUnsupportedStart:first line:line]) return nil;
  return key;
}

- (BOOL)isUnsupportedStart:(unichar)c line:(NSUInteger)line {
  switch (c) {
    case '&': case '*': [self fail:@"Anchors and aliases (& and *) aren't supported." line:line]; return YES;
    case '!': [self fail:@"Tags (!) aren't supported." line:line]; return YES;
    case '|': case '>': [self fail:@"Multi-line strings (| and >) aren't supported; quote the value on one line." line:line]; return YES;
    case '@': case '`': case '%': [self fail:[NSString stringWithFormat:@"A value can't start with \"%C\" unless it's quoted.", c] line:line]; return YES;
    case '?': [self fail:@"Complex keys (?) aren't supported." line:line]; return YES;
    default: return NO;
  }
}

- (id)quotedFrom:(NSString *)s line:(NSUInteger)line {
  NSUInteger close = [self closingQuoteIn:s];
  if (close == NSNotFound) {
    [self fail:@"A quoted value is missing its closing quote." line:line];
    return nil;
  }
  if (close != [s length] - 1) {
    [self fail:[NSString stringWithFormat:@"Unexpected text after the quoted value: \"%@\".", [s substringFromIndex:close + 1]] line:line];
    return nil;
  }
  NSString *body = [s substringWithRange:NSMakeRange(1, close - 1)];
  if ([s characterAtIndex:0] == '\'') return [body stringByReplacingOccurrencesOfString:@"''" withString:@"'"];

  NSMutableString *out = [NSMutableString string];
  for (NSUInteger i = 0; i < [body length]; i++) {
    unichar c = [body characterAtIndex:i];
    if (c != '\\') { [out appendFormat:@"%C", c]; continue; }
    if (++i >= [body length]) break;
    unichar e = [body characterAtIndex:i];
    switch (e) {
      case 'n': [out appendString:@"\n"]; break;
      case 't': [out appendString:@"\t"]; break;
      case 'r': [out appendString:@"\r"]; break;
      case '0': [out appendString:@"\0"]; break;
      case '"': [out appendString:@"\""]; break;
      case '\\': [out appendString:@"\\"]; break;
      case '/': [out appendString:@"/"]; break;
      case ' ': [out appendString:@" "]; break;
      case 'u': {
        if (i + 4 >= [body length]) {
          [self fail:@"A \\u escape needs four hex digits." line:line];
          return nil;
        }
        unsigned int code = 0;
        NSScanner *scanner = [NSScanner scannerWithString:[body substringWithRange:NSMakeRange(i + 1, 4)]];
        if (![scanner scanHexInt:&code] || ![scanner isAtEnd]) {
          [self fail:@"A \\u escape needs four hex digits." line:line];
          return nil;
        }
        [out appendFormat:@"%C", (unichar)code];
        i += 4;
        break;
      }
      default:
        [self fail:[NSString stringWithFormat:@"Unknown escape \"\\%C\" in a quoted value.", e] line:line];
        return nil;
    }
  }
  return out;
}

- (id)scalarFrom:(NSString *)s line:(NSUInteger)line {
  unichar first = [s characterAtIndex:0];
  if (first == '"' || first == '\'') return [self quotedFrom:s line:line];
  if ([s isEqualToString:@"{}"]) {
    SlateYAMLMapping *empty = [[SlateYAMLMapping alloc] init];
    empty.line = line;
    return empty;
  }
  if ([s isEqualToString:@"[]"]) return @[];
  if (first == '{' || first == '[') {
    [self fail:@"Inline lists and mappings ({...} and [...]) aren't supported; put each item on its own line." line:line];
    return nil;
  }
  if ([self isUnsupportedStart:first line:line]) return nil;
  if ([s rangeOfString:@": "].location != NSNotFound || [s hasSuffix:@":"]) {
    [self fail:[NSString stringWithFormat:@"\"%@\" has a \": \" in it. Quote the value, or check the indentation.", s] line:line];
    return nil;
  }
  return [SlateYAML resolvePlain:s];
}

+ (BOOL)matches:(NSString *)pattern string:(NSString *)s {
  return [s rangeOfString:pattern options:NSRegularExpressionSearch].location != NSNotFound;
}

+ (id)resolvePlain:(NSString *)s {
  if ([@[@"true", @"True", @"TRUE"] containsObject:s]) return @YES;
  if ([@[@"false", @"False", @"FALSE"] containsObject:s]) return @NO;
  if ([@[@"null", @"Null", @"NULL", @"~"] containsObject:s]) return [NSNull null];
  if ([self matches:@"^[-+]?[0-9]+$" string:s]) {
    return @([s longLongValue]);
  }
  if ([self matches:@"^[-+]?([0-9]+\\.[0-9]*|\\.[0-9]+)([eE][-+]?[0-9]+)?$" string:s] ||
      [self matches:@"^[-+]?[0-9]+[eE][-+]?[0-9]+$" string:s]) {
    return @([s doubleValue]);
  }
  return s;
}

#pragma mark - Parsing

+ (id)parse:(NSString *)text error:(NSError **)error {
  SlateYAML *parser = [[SlateYAML alloc] init];
  id result = [NSNull null];
  if ([parser splitLines:text] && [parser.lines count] > 0) {
    SlateYAMLLine *first = parser.lines[0];
    result = [parser parseBlockAtIndent:first.indent];
    SlateYAMLLine *left = [parser current];
    if (parser.failure == nil && left != nil) {
      [parser fail:left.indent > first.indent ? @"Unexpected indentation." : @"This line is indented less than the start of the file."
              line:left.number];
    }
  }
  if (parser.failure != nil) {
    if (error) {
      SlateYAMLFailure *failure = parser.failure;
      *error = [NSError errorWithDomain:SlateYAMLErrorDomain code:1 userInfo:@{
        NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Line %lu: %@", (unsigned long)failure.line, failure.message],
        SlateYAMLErrorLineKey: @(failure.line),
      }];
    }
    return nil;
  }
  return result ?: [NSNull null];
}

#pragma mark - Writing

+ (NSString *)quotedString:(NSString *)string {
  NSMutableString *out = [NSMutableString stringWithString:@"\""];
  for (NSUInteger i = 0; i < [string length]; i++) {
    unichar c = [string characterAtIndex:i];
    switch (c) {
      case '"': [out appendString:@"\\\""]; break;
      case '\\': [out appendString:@"\\\\"]; break;
      case '\n': [out appendString:@"\\n"]; break;
      case '\t': [out appendString:@"\\t"]; break;
      case '\r': [out appendString:@"\\r"]; break;
      default:
        if (c < 0x20 || c == 0x7f) {
          [out appendFormat:@"\\u%04x", c];
        } else {
          [out appendFormat:@"%C", c];
        }
    }
  }
  [out appendString:@"\""];
  return out;
}

+ (NSString *)key:(NSString *)key {
  BOOL plain = [self matches:@"^[A-Za-z_][A-Za-z0-9_.-]*$" string:key] &&
               [[self resolvePlain:key] isKindOfClass:[NSString class]] &&
               ![@[@"yes", @"no", @"on", @"off", @"y", @"n"] containsObject:[key lowercaseString]];
  return plain ? key : [self quotedString:key];
}

+ (NSString *)scalar:(id)value {
  if ([value isKindOfClass:[NSNumber class]]) {
    if (CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) return [value boolValue] ? @"true" : @"false";
    return [value stringValue];
  }
  if (value == nil || value == [NSNull null]) return @"null";
  return [self quotedString:[value description]];
}

@end
