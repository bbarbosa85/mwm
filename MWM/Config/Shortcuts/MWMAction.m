//
//  MWMAction.m
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

#import "MWMAction.h"

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

@implementation MWMAction

+ (NSArray<NSNumber *> *)allKinds {
  return @[@(MWMActionKindMove), @(MWMActionKindFocusApp), @(MWMActionKindFocusDirection), @(MWMActionKindThrow),
           @(MWMActionKindNudge), @(MWMActionKindResize), @(MWMActionKindPush), @(MWMActionKindHint),
           @(MWMActionKindGrid), @(MWMActionKindSwitch), @(MWMActionKindRelaunch), @(MWMActionKindSnapshot), @(MWMActionKindRestoreSnapshot),
           @(MWMActionKindCustom)];
}

+ (NSString *)titleForKind:(MWMActionKind)kind {
  switch (kind) {
    case MWMActionKindMove: return @"Move to";
    case MWMActionKindFocusApp: return @"Focus app";
    case MWMActionKindFocusDirection: return @"Focus window";
    case MWMActionKindThrow: return @"Throw to screen";
    case MWMActionKindNudge: return @"Nudge";
    case MWMActionKindResize: return @"Resize";
    case MWMActionKindPush: return @"Push";
    case MWMActionKindHint: return @"Window hints";
    case MWMActionKindGrid: return @"Grid";
    case MWMActionKindSwitch: return @"Switch windows";
    case MWMActionKindRelaunch: return @"Relaunch";
    case MWMActionKindSnapshot: return @"Save snapshot";
    case MWMActionKindRestoreSnapshot: return @"Restore snapshot";
    case MWMActionKindCustom: return @"Advanced…";
  }
}

+ (NSArray<NSString *> *)directions { return @[@"left", @"right", @"up", @"down", @"behind"]; }
+ (NSArray<NSString *> *)pushDirections { return @[@"up", @"down", @"left", @"right"]; }

+ (MWMAction *)actionOfKind:(MWMActionKind)kind {
  MWMAction *action = [[MWMAction alloc] init];
  action.kind = kind;
  action.a = @"";
  action.b = @"";
  switch (kind) {
    case MWMActionKindFocusDirection: action.a = @"left"; break;
    case MWMActionKindThrow: action.a = @"next"; action.b = @"resize"; break;
    case MWMActionKindNudge: action.a = @"+10%"; action.b = @"+0"; break;
    case MWMActionKindResize: action.a = @"+5%"; action.b = @"+0"; break;
    case MWMActionKindPush: action.a = @"left"; action.b = @"bar-resize:screenSizeX/2"; break;
    case MWMActionKindHint: action.a = @"ASDFJKLQWERUIOP"; break;
    case MWMActionKindSnapshot: action.b = @"save-to-disk"; break;
    default: break;
  }
  return action;
}

+ (MWMAction *)parse:(NSString *)source {
  NSString *text = Trim(source ?: @"");
  MWMAction *action = [self actionOfKind:MWMActionKindCustom];
  action.a = text;
  NSArray<NSString *> *g;

  if ((g = Match(@"^\\$\\{([^}]+)\\}(?:\\s+\\$\\{([^}]+)\\})?$", text))) {
    action.kind = MWMActionKindMove; action.a = g[0]; action.b = g[1];
  } else if ((g = Match(@"^focus\\s+'([^']*)'$", text)) || (g = Match(@"^focus\\s+\"([^\"]*)\"$", text))) {
    action.kind = MWMActionKindFocusApp; action.a = g[0];
  } else if ((g = Match(@"^focus\\s+(left|right|up|down|behind)$", text))) {
    action.kind = MWMActionKindFocusDirection; action.a = g[0];
  } else if ((g = Match(@"^throw\\s+(\\S+)\\s*(.*)$", text))) {
    action.kind = MWMActionKindThrow; action.a = g[0]; action.b = g[1];
  } else if ((g = Match(@"^(nudge|resize)\\s+(\\S+)\\s+(\\S+)$", text))) {
    action.kind = [g[0] isEqualToString:@"nudge"] ? MWMActionKindNudge : MWMActionKindResize; action.a = g[1]; action.b = g[2];
  } else if ((g = Match(@"^push\\s+(up|down|left|right)\\s*(.*)$", text))) {
    action.kind = MWMActionKindPush; action.a = g[0]; action.b = g[1];
  } else if ((g = Match(@"^hint\\s*(.*)$", text))) {
    action.kind = MWMActionKindHint; action.a = g[0];
  } else if ((g = Match(@"^grid\\s*(.*)$", text))) {
    action.kind = MWMActionKindGrid; action.a = g[0];
  } else if ((g = Match(@"^snapshot\\s+(\\S+)(?:\\s+(save-to-disk))?$", text))) {
    action.kind = MWMActionKindSnapshot; action.a = g[0]; action.b = g[1];
  } else if ((g = Match(@"^activate-snapshot\\s+(\\S+)$", text))) {
    action.kind = MWMActionKindRestoreSnapshot; action.a = g[0];
  } else if ([text isEqualToString:@"switch"]) {
    action.kind = MWMActionKindSwitch; action.a = @"";
  } else if ([text isEqualToString:@"relaunch"]) {
    action.kind = MWMActionKindRelaunch; action.a = @"";
  }
  return action;
}

- (NSString *)string {
  NSString *a = Trim(self.a ?: @""), *b = Trim(self.b ?: @"");
  switch (self.kind) {
    case MWMActionKindMove: return [b length] > 0 ? [NSString stringWithFormat:@"${%@} ${%@}", a, b] : [NSString stringWithFormat:@"${%@}", a];
    case MWMActionKindFocusApp: return [NSString stringWithFormat:@"focus '%@'", a];
    case MWMActionKindFocusDirection: return [@"focus " stringByAppendingString:a];
    case MWMActionKindThrow: return [b length] > 0 ? [NSString stringWithFormat:@"throw %@ %@", a, b] : [@"throw " stringByAppendingString:a];
    case MWMActionKindNudge: return [NSString stringWithFormat:@"nudge %@ %@", a, b];
    case MWMActionKindResize: return [NSString stringWithFormat:@"resize %@ %@", a, b];
    case MWMActionKindPush: return [b length] > 0 ? [NSString stringWithFormat:@"push %@ %@", a, b] : [@"push " stringByAppendingString:a];
    case MWMActionKindHint: return [a length] > 0 ? [@"hint " stringByAppendingString:a] : @"hint";
    case MWMActionKindGrid: return [a length] > 0 ? [@"grid " stringByAppendingString:a] : @"grid";
    case MWMActionKindSwitch: return @"switch";
    case MWMActionKindRelaunch: return @"relaunch";
    case MWMActionKindSnapshot: return [b length] > 0 ? [NSString stringWithFormat:@"snapshot %@ %@", a, b] : [@"snapshot " stringByAppendingString:a];
    case MWMActionKindRestoreSnapshot: return [@"activate-snapshot " stringByAppendingString:a];
    case MWMActionKindCustom: return a;
  }
}

#pragma mark - Preview

// A tiny arithmetic parser: numbers, + - * /, parentheses, and the screen variables.
@end

@interface MWMExpression : NSObject
- (instancetype)initWithText:(NSString *)text;
- (BOOL)evaluate:(double *)value;
@end

@implementation MWMExpression {
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

@implementation MWMAction (Preview)

+ (BOOL)previewForPositionText:(NSString *)text rect:(CGRect *)rect {
  NSArray<NSString *> *g = Match(@"^move\\s+(\\S+)\\s+(\\S+)", Trim(text ?: @""));
  if (g == nil) return NO;
  NSArray *origin = [g[0] componentsSeparatedByString:@";"], *size = [g[1] componentsSeparatedByString:@";"];
  if ([origin count] != 2 || [size count] != 2) return NO;
  double values[4];
  NSArray *parts = @[origin[0], origin[1], size[0], size[1]];
  for (int i = 0; i < 4; i++) {
    if (![[[MWMExpression alloc] initWithText:parts[i]] evaluate:&values[i]]) return NO;
  }
  *rect = CGRectMake(values[0], values[1], values[2], values[3]);
  return YES;
}

@end
