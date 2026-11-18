//
//  SlateAction.m
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

#import "SlateAction.h"

static NSString *Trim(NSString *text) {
  return [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

// The first match of a pattern as its groups (without group 0), or nil.
static NSArray<NSString *> *Match(NSString *pattern, NSString *text) {
  NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
  NSTextCheckingResult *result = [regex firstMatchInString:text options:0 range:NSMakeRange(0, [text length])];
  if (result == nil) return nil;
  NSMutableArray *groups = [NSMutableArray array];
  for (NSUInteger i = 1; i < [result numberOfRanges]; i++) {
    NSRange range = [result rangeAtIndex:i];
    [groups addObject:range.location == NSNotFound ? @"" : [text substringWithRange:range]];
  }
  return groups;
}

@implementation SlateAction

+ (NSArray<NSNumber *> *)allKinds {
  return @[@(SlateActionKindMove), @(SlateActionKindFocusApp), @(SlateActionKindFocusDirection), @(SlateActionKindThrow),
           @(SlateActionKindNudge), @(SlateActionKindResize), @(SlateActionKindPush), @(SlateActionKindHint),
           @(SlateActionKindGrid), @(SlateActionKindSwitch), @(SlateActionKindRelaunch), @(SlateActionKindSnapshot), @(SlateActionKindRestoreSnapshot),
           @(SlateActionKindCustom)];
}

+ (NSString *)titleForKind:(SlateActionKind)kind {
  switch (kind) {
    case SlateActionKindMove: return @"Move to";
    case SlateActionKindFocusApp: return @"Focus app";
    case SlateActionKindFocusDirection: return @"Focus window";
    case SlateActionKindThrow: return @"Throw to screen";
    case SlateActionKindNudge: return @"Nudge";
    case SlateActionKindResize: return @"Resize";
    case SlateActionKindPush: return @"Push";
    case SlateActionKindHint: return @"Window hints";
    case SlateActionKindGrid: return @"Grid";
    case SlateActionKindSwitch: return @"Switch windows";
    case SlateActionKindRelaunch: return @"Relaunch";
    case SlateActionKindSnapshot: return @"Save snapshot";
    case SlateActionKindRestoreSnapshot: return @"Restore snapshot";
    case SlateActionKindCustom: return @"Advanced…";
  }
}

+ (NSArray<NSString *> *)directions { return @[@"left", @"right", @"up", @"down", @"behind"]; }
+ (NSArray<NSString *> *)pushDirections { return @[@"up", @"down", @"left", @"right"]; }

+ (SlateAction *)actionOfKind:(SlateActionKind)kind {
  SlateAction *action = [[SlateAction alloc] init];
  action.kind = kind;
  action.a = @"";
  action.b = @"";
  switch (kind) {
    case SlateActionKindFocusDirection: action.a = @"left"; break;
    case SlateActionKindThrow: action.a = @"next"; action.b = @"resize"; break;
    case SlateActionKindNudge: action.a = @"+10%"; action.b = @"+0"; break;
    case SlateActionKindResize: action.a = @"+5%"; action.b = @"+0"; break;
    case SlateActionKindPush: action.a = @"left"; action.b = @"bar-resize:screenSizeX/2"; break;
    case SlateActionKindHint: action.a = @"ASDFJKLQWERUIOP"; break;
    case SlateActionKindSnapshot: action.b = @"save-to-disk"; break;
    default: break;
  }
  return action;
}

+ (SlateAction *)parse:(NSString *)source {
  NSString *text = Trim(source ?: @"");
  SlateAction *action = [self actionOfKind:SlateActionKindCustom];
  action.a = text;
  NSArray<NSString *> *g;

  if ((g = Match(@"^\\$\\{([^}]+)\\}(?:\\s+\\$\\{([^}]+)\\})?$", text))) {
    action.kind = SlateActionKindMove; action.a = g[0]; action.b = g[1];
  } else if ((g = Match(@"^focus\\s+'([^']*)'$", text)) || (g = Match(@"^focus\\s+\"([^\"]*)\"$", text))) {
    action.kind = SlateActionKindFocusApp; action.a = g[0];
  } else if ((g = Match(@"^focus\\s+(left|right|up|down|behind)$", text))) {
    action.kind = SlateActionKindFocusDirection; action.a = g[0];
  } else if ((g = Match(@"^throw\\s+(\\S+)\\s*(.*)$", text))) {
    action.kind = SlateActionKindThrow; action.a = g[0]; action.b = g[1];
  } else if ((g = Match(@"^(nudge|resize)\\s+(\\S+)\\s+(\\S+)$", text))) {
    action.kind = [g[0] isEqualToString:@"nudge"] ? SlateActionKindNudge : SlateActionKindResize; action.a = g[1]; action.b = g[2];
  } else if ((g = Match(@"^push\\s+(up|down|left|right)\\s*(.*)$", text))) {
    action.kind = SlateActionKindPush; action.a = g[0]; action.b = g[1];
  } else if ((g = Match(@"^hint\\s*(.*)$", text))) {
    action.kind = SlateActionKindHint; action.a = g[0];
  } else if ((g = Match(@"^grid\\s*(.*)$", text))) {
    action.kind = SlateActionKindGrid; action.a = g[0];
  } else if ((g = Match(@"^snapshot\\s+(\\S+)(?:\\s+(save-to-disk))?$", text))) {
    action.kind = SlateActionKindSnapshot; action.a = g[0]; action.b = g[1];
  } else if ((g = Match(@"^activate-snapshot\\s+(\\S+)$", text))) {
    action.kind = SlateActionKindRestoreSnapshot; action.a = g[0];
  } else if ([text isEqualToString:@"switch"]) {
    action.kind = SlateActionKindSwitch; action.a = @"";
  } else if ([text isEqualToString:@"relaunch"]) {
    action.kind = SlateActionKindRelaunch; action.a = @"";
  }
  return action;
}

- (NSString *)string {
  NSString *a = Trim(self.a ?: @""), *b = Trim(self.b ?: @"");
  switch (self.kind) {
    case SlateActionKindMove: return [b length] > 0 ? [NSString stringWithFormat:@"${%@} ${%@}", a, b] : [NSString stringWithFormat:@"${%@}", a];
    case SlateActionKindFocusApp: return [NSString stringWithFormat:@"focus '%@'", a];
    case SlateActionKindFocusDirection: return [@"focus " stringByAppendingString:a];
    case SlateActionKindThrow: return [b length] > 0 ? [NSString stringWithFormat:@"throw %@ %@", a, b] : [@"throw " stringByAppendingString:a];
    case SlateActionKindNudge: return [NSString stringWithFormat:@"nudge %@ %@", a, b];
    case SlateActionKindResize: return [NSString stringWithFormat:@"resize %@ %@", a, b];
    case SlateActionKindPush: return [b length] > 0 ? [NSString stringWithFormat:@"push %@ %@", a, b] : [@"push " stringByAppendingString:a];
    case SlateActionKindHint: return [a length] > 0 ? [@"hint " stringByAppendingString:a] : @"hint";
    case SlateActionKindGrid: return [a length] > 0 ? [@"grid " stringByAppendingString:a] : @"grid";
    case SlateActionKindSwitch: return @"switch";
    case SlateActionKindRelaunch: return @"relaunch";
    case SlateActionKindSnapshot: return [b length] > 0 ? [NSString stringWithFormat:@"snapshot %@ %@", a, b] : [@"snapshot " stringByAppendingString:a];
    case SlateActionKindRestoreSnapshot: return [@"activate-snapshot " stringByAppendingString:a];
    case SlateActionKindCustom: return a;
  }
}

#pragma mark - Preview

// A tiny arithmetic parser: numbers, + - * /, parentheses, and the screen variables.
@end

@interface SlateExpression : NSObject
- (instancetype)initWithText:(NSString *)text;
- (BOOL)evaluate:(double *)value;
@end

@implementation SlateExpression {
  NSString *_text;
  NSUInteger _pos;
  BOOL _failed;
}
- (instancetype)initWithText:(NSString *)text { if ((self = [super init])) _text = text; return self; }
- (unichar)peek { while (_pos < [_text length] && [_text characterAtIndex:_pos] == ' ') _pos++; return _pos < [_text length] ? [_text characterAtIndex:_pos] : 0; }
- (BOOL)evaluate:(double *)value {
  _pos = 0; _failed = NO;
  double result = [self sum];
  if (_failed || [self peek] != 0) return NO;
  *value = result;
  return YES;
}
- (double)sum {
  double left = [self product];
  for (;;) {
    unichar c = [self peek];
    if (c == '+') { _pos++; left += [self product]; }
    else if (c == '-') { _pos++; left -= [self product]; }
    else return left;
  }
}
- (double)product {
  double left = [self factor];
  for (;;) {
    unichar c = [self peek];
    if (c == '*') { _pos++; left *= [self factor]; }
    else if (c == '/') { _pos++; double d = [self factor]; if (d == 0) _failed = YES; else left /= d; }
    else return left;
  }
}
- (double)factor {
  unichar c = [self peek];
  if (c == '(') {
    _pos++;
    double inner = [self sum];
    if ([self peek] != ')') _failed = YES; else _pos++;
    return inner;
  }
  if (c == '-') { _pos++; return -[self factor]; }
  NSUInteger start = _pos;
  if ((c >= '0' && c <= '9') || c == '.') {
    while (_pos < [_text length] && (([_text characterAtIndex:_pos] >= '0' && [_text characterAtIndex:_pos] <= '9') || [_text characterAtIndex:_pos] == '.')) _pos++;
    return [[_text substringWithRange:NSMakeRange(start, _pos - start)] doubleValue];
  }
  while (_pos < [_text length] && [[NSCharacterSet letterCharacterSet] characterIsMember:[_text characterAtIndex:_pos]]) _pos++;
  NSString *name = [_text substringWithRange:NSMakeRange(start, _pos - start)];
  if ([name isEqualToString:@"screenOriginX"] || [name isEqualToString:@"screenOriginY"]) return 0;
  if ([name isEqualToString:@"screenSizeX"] || [name isEqualToString:@"screenSizeY"]) return 1;
  _failed = YES;
  return 0;
}
@end

@implementation SlateAction (Preview)

+ (BOOL)previewForPositionText:(NSString *)text rect:(CGRect *)rect {
  NSArray<NSString *> *g = Match(@"^move\\s+(\\S+)\\s+(\\S+)", Trim(text ?: @""));
  if (g == nil) return NO;
  NSArray *origin = [g[0] componentsSeparatedByString:@";"], *size = [g[1] componentsSeparatedByString:@";"];
  if ([origin count] != 2 || [size count] != 2) return NO;
  double values[4];
  NSArray *parts = @[origin[0], origin[1], size[0], size[1]];
  for (int i = 0; i < 4; i++) {
    if (![[[SlateExpression alloc] initWithText:parts[i]] evaluate:&values[i]]) return NO;
  }
  *rect = CGRectMake(values[0], values[1], values[2], values[3]);
  return YES;
}

@end
