//
//  ConfigurationShortcutView.m
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

#import "ConfigurationShortcutView.h"
#import "SlateShortcut.h"

static const UInt16 kEscapeKeyCode = 53;

@interface ConfigurationShortcutView ()
@property (strong) NSStackView *stack;
@property (assign) BOOL recording;
@property (copy) NSString *keyName;
@property (copy) NSArray<NSString *> *modifierNames;
@property (copy) NSString *aliasName;
@property (copy) NSString *conflict;
@property (copy) NSString *rawText;
// Modifiers held down while recording.
@property (copy) NSArray<NSString *> *heldModifiers;
@property (copy) NSString *hint;
@property (strong) id eventMonitor;
@end

@implementation ConfigurationShortcutView

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _modifierNames = @[];
    _heldModifiers = @[];
    _stack = [NSStackView stackViewWithViews:@[]];
    [_stack setOrientation:NSUserInterfaceLayoutOrientationHorizontal];
    [_stack setSpacing:4];
    [_stack setAlignment:NSLayoutAttributeCenterY];
    [_stack setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:_stack];
    [NSLayoutConstraint activateConstraints:@[
      [_stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4],
      [_stack.topAnchor constraintEqualToAnchor:self.topAnchor constant:2],
      [_stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-2],
      [_stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-4],
    ]];
    [self setWantsLayer:YES];
    [[self layer] setCornerRadius:5];
  }
  return self;
}

- (void)dealloc {
  [self stopMonitoring];
}

#pragma mark - Showing

- (void)setKeyName:(NSString *)keyName modifierNames:(NSArray<NSString *> *)modifierNames
         aliasName:(NSString *)aliasName conflict:(NSString *)conflict {
  self.keyName = keyName;
  self.modifierNames = modifierNames ?: @[];
  self.aliasName = aliasName;
  self.conflict = conflict;
  _rawText = nil;
  [self rebuild];
}

- (void)showRawText:(NSString *)text {
  _rawText = [text copy];
  self.keyName = nil;
  self.conflict = nil;
  [self rebuild];
}

- (NSView *)chipWithText:(NSString *)text {
  NSTextField *label = [NSTextField labelWithString:text];
  [label setFont:[NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightMedium]];
  [label setTranslatesAutoresizingMaskIntoConstraints:NO];
  NSView *chip = [[NSView alloc] init];
  [chip setWantsLayer:YES];
  [[chip layer] setCornerRadius:4];
  [[chip layer] setBorderWidth:1];
  [[chip layer] setBorderColor:[[NSColor separatorColor] CGColor]];
  [[chip layer] setBackgroundColor:[[NSColor controlBackgroundColor] CGColor]];
  [chip addSubview:label];
  [NSLayoutConstraint activateConstraints:@[
    [label.leadingAnchor constraintEqualToAnchor:chip.leadingAnchor constant:6],
    [label.trailingAnchor constraintEqualToAnchor:chip.trailingAnchor constant:-6],
    [label.topAnchor constraintEqualToAnchor:chip.topAnchor constant:1],
    [label.bottomAnchor constraintEqualToAnchor:chip.bottomAnchor constant:-1],
  ]];
  return chip;
}

- (NSTextField *)noteWithText:(NSString *)text color:(NSColor *)color {
  NSTextField *label = [NSTextField labelWithString:text];
  [label setTextColor:color];
  [label setFont:[NSFont systemFontOfSize:12]];
  [label setLineBreakMode:NSLineBreakByTruncatingTail];
  return label;
}

- (void)rebuild {
  for (NSView *view in [[self.stack arrangedSubviews] copy]) {
    [self.stack removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  [[self layer] setBackgroundColor:self.recording ? [[[NSColor controlAccentColor] colorWithAlphaComponent:0.12] CGColor] : [[NSColor clearColor] CGColor]];
  [[self layer] setBorderWidth:self.recording ? 1 : 0];
  [[self layer] setBorderColor:[[NSColor controlAccentColor] CGColor]];

  if (self.recording) {
    for (NSString *name in self.heldModifiers) [self.stack addArrangedSubview:[self chipWithText:[SlateShortcut symbolForModifierName:name]]];
    [self.stack addArrangedSubview:[self noteWithText:self.hint ?: ([self.heldModifiers count] > 0 ? @"…" : @"Press the keys")
                                                color:self.hint ? [NSColor systemOrangeColor] : [NSColor secondaryLabelColor]]];
    [self setToolTip:@"Esc to cancel"];
    return;
  }

  [self setToolTip:self.conflict ?: @"Click to record a shortcut"];
  if (self.rawText != nil) {
    NSTextField *raw = [self noteWithText:self.rawText color:[NSColor systemOrangeColor]];
    [raw setFont:[NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular]];
    [self.stack addArrangedSubview:raw];
    return;
  }
  for (NSString *name in self.modifierNames) [self.stack addArrangedSubview:[self chipWithText:[SlateShortcut symbolForModifierName:name]]];
  [self.stack addArrangedSubview:[self chipWithText:[SlateShortcut displayForKeyName:self.keyName ?: @"?"]]];
  if ([self.aliasName length] > 0) [self.stack addArrangedSubview:[self noteWithText:self.aliasName color:[NSColor secondaryLabelColor]]];
  if (self.conflict != nil) {
    NSImageView *warning = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:@"exclamationmark.triangle.fill" accessibilityDescription:@"Conflict"]];
    [warning setContentTintColor:[NSColor systemOrangeColor]];
    [self.stack addArrangedSubview:warning];
  }
}

#pragma mark - Recording

// The key caps are only drawing: every click in the cell starts recording.
- (NSView *)hitTest:(NSPoint)point {
  return [self mouse:[self convertPoint:point fromView:[self superview]] inRect:[self bounds]] ? self : nil;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
  return YES;
}

- (void)mouseDown:(NSEvent *)event {
  if (self.recording) return;
  [self beginRecording];
}

- (void)beginRecording {
  if (self.recording) return;
  if ([self.delegate respondsToSelector:@selector(shortcutViewWillBeginRecording:)]) [self.delegate shortcutViewWillBeginRecording:self];
  self.recording = YES;
  self.heldModifiers = @[];
  self.hint = nil;
  [self rebuild];

  __weak ConfigurationShortcutView *weakSelf = self;
  self.eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown | NSEventMaskFlagsChanged | NSEventMaskLeftMouseDown
                                                             handler:^NSEvent *(NSEvent *event) {
    return [weakSelf handleEvent:event];
  }];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cancelRecording)
                                               name:NSWindowDidResignKeyNotification object:[self window]];
}

- (void)stopMonitoring {
  if (self.eventMonitor != nil) {
    [NSEvent removeMonitor:self.eventMonitor];
    self.eventMonitor = nil;
  }
  [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResignKeyNotification object:nil];
}

- (void)cancelRecording {
  if (!self.recording) return;
  [self stopMonitoring];
  self.recording = NO;
  [self rebuild];
}

// Swallows the keys while recording, so ⌘W or ⌘Q can be recorded instead of acting.
- (NSEvent *)handleEvent:(NSEvent *)event {
  if (!self.recording) return event;
  NSEventModifierFlags flags = [event modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask;
  switch ([event type]) {
    case NSEventTypeLeftMouseDown: {
      NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
      if (![self mouse:point inRect:[self bounds]]) {
        [self cancelRecording];
        return event;  // the click still does what it was for
      }
      return nil;
    }
    case NSEventTypeFlagsChanged:
      self.heldModifiers = [SlateShortcut modifierNamesFromFlags:flags];
      self.hint = nil;
      [self rebuild];
      return nil;
    case NSEventTypeKeyDown:
      if ([event isARepeat]) return nil;
      if ([event keyCode] == kEscapeKeyCode && [[SlateShortcut modifierNamesFromFlags:flags] count] == 0) {
        [self cancelRecording];
        return nil;
      }
      [self finishRecordingWithKeyCode:[event keyCode] modifierFlags:flags];
      return nil;
    default:
      return event;
  }
}

- (void)finishRecordingWithKeyCode:(UInt16)keyCode modifierFlags:(NSEventModifierFlags)flags {
  NSString *name = [SlateShortcut keyNameForKeyCode:keyCode];
  if (name == nil) {
    NSBeep();
    self.hint = @"MWM can't use that key";
    [self rebuild];
    return;
  }
  [self stopMonitoring];
  self.recording = NO;
  NSArray *modifiers = [SlateShortcut modifierNamesFromFlags:flags];
  self.keyName = name;
  self.modifierNames = modifiers;
  self.aliasName = nil;
  _rawText = nil;
  [self rebuild];
  [self.delegate shortcutView:self didRecordKey:name modifierNames:modifiers];
}

@end
