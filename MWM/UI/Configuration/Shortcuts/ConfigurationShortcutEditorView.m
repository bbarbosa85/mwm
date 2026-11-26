//
//  ConfigurationShortcutEditorView.m
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

#import "ConfigurationShortcutEditorView.h"
#import "MWMAlert.h"
#import "MWMTheme.h"
#import "MWMComponents.h"
#import "ConfigurationBlockView.h"
#import "ConfigurationKeyViews.h"
#import "ConfigurationKeyboardMapView.h"
#import "MWMConfigDocument.h"
#import "MWMReservedShortcuts.h"
#import "MWMShortcut.h"
#import "MWMShortcutIndex.h"
#import "MWMSnapshots.h"
#import "MWMSlots.h"
#import "MWMDisplays.h"
#import "MWMPushOptions.h"
#import "ConfigurationPushRows.h"
#import "ConfigurationFormulaHelp.h"

// The four things most shortcuts do get a card of their own; the rest are under "More actions".
static NSArray<NSNumber *> *PrimaryKinds(void) {
  return @[@(MWMActionKindFocusApp), @(MWMActionKindMove), @(MWMActionKindThrow), @(MWMActionKindPush)];
}

static NSArray<NSNumber *> *MoreKinds(void) {
  return @[@(MWMActionKindFocusDirection), @(MWMActionKindResize), @(MWMActionKindNudge), @(MWMActionKindSnapshot), @(MWMActionKindRestoreSnapshot),
           @(MWMActionKindHint), @(MWMActionKindGrid), @(MWMActionKindSwitch), @(MWMActionKindRelaunch), @(MWMActionKindCustom)];
}

// What an action does, in a line, and the symbol that stands for it.
static NSString *SummaryForKind(MWMActionKind kind) {
  switch (kind) {
    case MWMActionKindFocusApp: return @"Bring a running app to the front.";
    case MWMActionKindMove: return @"Put the window in a named area of the screen.";
    case MWMActionKindThrow: return @"Send the window to another display.";
    case MWMActionKindPush: return @"Stick the window to a screen edge, keeping a thickness.";
    case MWMActionKindFocusDirection: return @"Focus the window next to this one.";
    case MWMActionKindResize: return @"Grow or shrink the window by a step.";
    case MWMActionKindNudge: return @"Move the window by a step.";
    case MWMActionKindSnapshot: return @"Remember where every window is.";
    case MWMActionKindRestoreSnapshot: return @"Put every window back where it was saved.";
    case MWMActionKindHint: return @"Show a letter on each window to jump to it.";
    case MWMActionKindGrid: return @"Pick a window position from a grid.";
    case MWMActionKindSwitch: return @"Switch between windows.";
    case MWMActionKindRelaunch: return @"Restart MWM.";
    case MWMActionKindCustom: return @"Write the action yourself.";
  }
}

static NSString *SymbolForKind(MWMActionKind kind) {
  switch (kind) {
    case MWMActionKindFocusApp: return @"macwindow";
    case MWMActionKindMove: return @"rectangle.split.3x1";
    case MWMActionKindThrow: return @"display.2";
    case MWMActionKindPush: return @"arrow.right.to.line";
    case MWMActionKindFocusDirection: return @"scope";
    case MWMActionKindResize: return @"arrow.up.left.and.arrow.down.right";
    case MWMActionKindNudge: return @"arrow.up.and.down.and.arrow.left.and.right";
    case MWMActionKindSnapshot: return @"camera";
    case MWMActionKindRestoreSnapshot: return @"arrow.counterclockwise";
    case MWMActionKindHint: return @"textformat.abc";
    case MWMActionKindGrid: return @"square.grid.3x3";
    case MWMActionKindSwitch: return @"rectangle.stack";
    case MWMActionKindRelaunch: return @"arrow.clockwise";
    case MWMActionKindCustom: return @"chevron.left.forwardslash.chevron.right";
  }
}

static NSArray<NSString *> *InstalledApplicationNames(void) {
  NSMutableSet *names = [NSMutableSet set];
  for (NSString *folder in @[@"/Applications", @"/System/Applications", @"/Applications/Utilities", [@"~/Applications" stringByExpandingTildeInPath]]) {
    for (NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:nil]) {
      if ([file hasSuffix:@".app"]) [names addObject:[file stringByDeletingPathExtension]];
    }
  }
  return [[names allObjects] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

@interface ConfigurationShortcutEditorView () <NSSearchFieldDelegate, NSTextFieldDelegate, ConfigurationKeyboardMapViewDelegate>
@property (strong) MWMAction *draftAction;
@property (strong) NSPopover *helpPopover;
@property (strong) ConfigurationPushRows *pushRows;   // keeps the push controls' target alive
@property (strong, nullable) MWMBindingEntry *original;   // nil for a new shortcut
@property (copy) NSString *originalSignature;
@property (assign) BOOL isNew;
@property (assign) BOOL keysChanged;

@property (strong) NSView *editorPage;
@property (strong) NSTextField *titleLabel;
@property (strong) NSStackView *kindStack;
@property (assign) BOOL moreExpanded;   // the list under "More actions" is open
@property (strong) NSStackView *keysStack;   // the keys, in a card of their own
@property (strong) NSStackView *formStack;   // the action's settings, in another
@property (strong) MWMSaveBar *saveBar;
@property (strong) NSView *pickerPage;
@property (strong) ConfigurationKeyboardMapView *picker;

@property (copy) NSString *slotQuery;
@property (assign) NSInteger slotFilter;   // 0 all, 1 presets, 2 custom
@property (strong) NSStackView *slotList;

@property (assign) BOOL recording;
@property (strong, nullable) id monitor;
@property (copy, nullable) NSString *recordedKey;
@property (copy) NSArray<NSString *> *recordedModifiers;
@end

@implementation ConfigurationShortcutEditorView

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _confirmsDiscard = YES;
    _draftModifierNames = @[];
    _recordedModifiers = @[];
    _draftAction = [MWMAction actionOfKind:MWMActionKindFocusApp];
    [self buildInterface];
  }
  return self;
}

- (void)dealloc { [self removeMonitor]; }

#pragma mark - Layout

- (NSTextField *)labelWithText:(NSString *)text size:(CGFloat)size color:(NSColor *)color weight:(NSFontWeight)weight {
  return [MWMComponents labelWithText:text font:[NSFont systemFontOfSize:size weight:weight] color:color];
}

- (NSStackView *)settingsStack {
  NSStackView *stack = [NSStackView stackViewWithViews:@[]];
  [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [stack setAlignment:NSLayoutAttributeLeading];
  [stack setSpacing:0];
  [stack setTranslatesAutoresizingMaskIntoConstraints:NO];
  return stack;
}

// A card as tall as the rows in it.
- (NSView *)cardAround:(NSStackView *)stack {
  ConfigurationBlockView *card = [[ConfigurationBlockView alloc] init];
  [card setTranslatesAutoresizingMaskIntoConstraints:NO];
  [card addSubview:stack];
  [NSLayoutConstraint activateConstraints:@[
    [stack.topAnchor constraintEqualToAnchor:card.topAnchor], [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],
    [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor], [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
  ]];
  return card;
}

- (void)buildInterface {
  MWMSublevelHeader *header = [MWMSublevelHeader headerWithBackTitle:@"Bindings" title:@"New Shortcut" target:self action:@selector(backPressed:)];
  self.titleLabel = header.titleLabel;

  // Left: what the shortcut does, as cards.
  self.kindStack = [NSStackView stackViewWithViews:@[]];
  [self.kindStack setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [self.kindStack setAlignment:NSLayoutAttributeLeading];
  [self.kindStack setSpacing:MWMSpacingS];
  NSScrollView *left = [MWMComponents scrollViewWithContent:self.kindStack trailingRoom:MWMSpacingS];   // scrolls when "More actions" is open

  // Right: the keys, then the action's settings, each in a card.
  self.keysStack = [self settingsStack];
  self.formStack = [self settingsStack];
  NSView *keysCard = [self cardAround:self.keysStack];
  NSView *formCard = [self cardAround:self.formStack];
  NSStackView *cards = [MWMComponents columnWithViews:@[keysCard, formCard] spacing:MWMSpacingM insets:NSEdgeInsetsZero];
  NSView *cardHolder = [[NSView alloc] init];
  [cardHolder setTranslatesAutoresizingMaskIntoConstraints:NO];
  [cardHolder addSubview:cards];
  [NSLayoutConstraint activateConstraints:@[
    [cards.topAnchor constraintEqualToAnchor:cardHolder.topAnchor], [cards.leadingAnchor constraintEqualToAnchor:cardHolder.leadingAnchor], [cards.trailingAnchor constraintEqualToAnchor:cardHolder.trailingAnchor],
  ]];

  MWMSaveBar *saveBar = [MWMSaveBar barWithTarget:self cancel:@selector(cancelPressed:) save:@selector(savePressed:)];
  self.saveBar = saveBar;

  self.editorPage = [[NSView alloc] init];
  [self.editorPage setTranslatesAutoresizingMaskIntoConstraints:NO];
  for (NSView *view in @[header, left, cardHolder, saveBar]) {
    [view setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.editorPage addSubview:view];
  }
  for (NSView *view in @[header, saveBar]) {
    [[view.leadingAnchor constraintEqualToAnchor:self.editorPage.leadingAnchor] setActive:YES];
    [[view.trailingAnchor constraintEqualToAnchor:self.editorPage.trailingAnchor] setActive:YES];
  }
  [NSLayoutConstraint activateConstraints:@[
    [header.topAnchor constraintEqualToAnchor:self.editorPage.topAnchor],
    [left.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:MWMSpacingS], [left.leadingAnchor constraintEqualToAnchor:self.editorPage.leadingAnchor constant:MWMSpacingXL],
    [left.widthAnchor constraintEqualToConstant:280], [left.bottomAnchor constraintEqualToAnchor:saveBar.topAnchor constant:-MWMSpacingL],
    [cardHolder.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:MWMSpacingS], [cardHolder.leadingAnchor constraintEqualToAnchor:left.trailingAnchor constant:MWMSpacingXL],
    [cardHolder.trailingAnchor constraintEqualToAnchor:self.editorPage.trailingAnchor constant:-MWMSpacingXL], [cardHolder.bottomAnchor constraintEqualToAnchor:saveBar.topAnchor constant:-MWMSpacingL],
    [saveBar.bottomAnchor constraintEqualToAnchor:self.editorPage.bottomAnchor],
  ]];

  // Picking on the map takes the page over.
  self.picker = [[ConfigurationKeyboardMapView alloc] init];
  [self.picker setDelegate:self];
  self.picker.pickerMode = YES;
  NSTextField *pickTitle = [MWMComponents titleLabel:@"Pick the keys"];
  NSStackView *pickHeader = [NSStackView stackViewWithViews:@[pickTitle]];
  [pickHeader setEdgeInsets:NSEdgeInsetsMake(14, MWMSpacingXL, 4, MWMSpacingXL)];
  self.pickerPage = [[NSView alloc] init];
  [self.pickerPage setTranslatesAutoresizingMaskIntoConstraints:NO];
  for (NSView *view in @[pickHeader, self.picker]) {
    [view setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.pickerPage addSubview:view];
    [[view.leadingAnchor constraintEqualToAnchor:self.pickerPage.leadingAnchor] setActive:YES];
    [[view.trailingAnchor constraintEqualToAnchor:self.pickerPage.trailingAnchor] setActive:YES];
  }
  [NSLayoutConstraint activateConstraints:@[
    [pickHeader.topAnchor constraintEqualToAnchor:self.pickerPage.topAnchor], [pickHeader.heightAnchor constraintEqualToConstant:48],
    [self.picker.topAnchor constraintEqualToAnchor:pickHeader.bottomAnchor constant:4], [self.picker.bottomAnchor constraintEqualToAnchor:self.pickerPage.bottomAnchor],
  ]];
  [self.pickerPage setHidden:YES];

  for (NSView *page in @[self.editorPage, self.pickerPage]) {
    [self addSubview:page];
    [NSLayoutConstraint activateConstraints:@[
      [page.topAnchor constraintEqualToAnchor:self.topAnchor], [page.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
      [page.leadingAnchor constraintEqualToAnchor:self.leadingAnchor], [page.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
    ]];
  }
}

#pragma mark - Model

- (void)setDocument:(MWMConfigDocument *)document {
  _document = document;
}

- (NSString *)signatureOfAction:(NSString *)action key:(NSString *)key modifiers:(NSString *)modifiers {
  return [NSString stringWithFormat:@"%@|%@|%@", action ?: @"", key ?: @"", modifiers ?: @""];
}

- (NSString *)draftModifiersText {
  return self.draftGroupName != nil ? [NSString stringWithFormat:@"${%@}", self.draftGroupName] : [MWMShortcut stringFromModifierNames:self.draftModifierNames];
}

- (void)editBindingAtIndex:(NSUInteger)index {
  if (index >= [self.document.bindings count]) return;
  MWMBindingEntry *binding = self.document.bindings[index];
  [self cancelRecording];
  self.original = binding;
  self.isNew = NO;
  self.draftAction = [MWMAction parse:binding.action];
  MWMShortcutInfo *info = [[MWMShortcutIndex indexForDocument:self.document] shortcutAtBindingIndex:index];
  self.draftKeyName = binding.key;
  self.draftModifierNames = info.modifierNames ?: @[];
  self.draftGroupName = info.groupName;
  self.keysChanged = NO;
  self.originalSignature = [self signatureOfAction:[self.draftAction string] key:self.draftKeyName modifiers:[self draftModifiersText]];
  [self.titleLabel setStringValue:@"Editing Shortcut"];
  [self showEditor];
  [self refresh];
}

- (void)startNewWithGroup:(NSString *)groupName keyName:(NSString *)keyName {
  [self cancelRecording];
  self.original = nil;
  self.isNew = YES;
  self.draftAction = [MWMAction actionOfKind:MWMActionKindFocusApp];
  self.draftKeyName = keyName;
  self.draftGroupName = groupName;
  NSArray *names = @[];
  for (MWMModifierGroup *group in [[MWMShortcutIndex indexForDocument:self.document] groups]) {
    if (groupName != nil && [group.name isEqualToString:groupName]) names = group.modifierNames;
  }
  self.draftModifierNames = names;
  self.keysChanged = keyName != nil;
  self.originalSignature = @"";
  [self.titleLabel setStringValue:@"New Shortcut"];
  [self showEditor];
  [self refresh];
}

- (void)showEditor {
  self.slotQuery = @"";
  self.slotFilter = 0;
  [self.pickerPage setHidden:YES];
  [self.editorPage setHidden:NO];
}

- (BOOL)hasUnsavedChanges {
  if (self.isNew) return YES;
  return ![self.originalSignature isEqualToString:[self signatureOfAction:[self.draftAction string] key:self.draftKeyName modifiers:[self draftModifiersText]]];
}

- (NSString *)problem {
  MWMAction *a = self.draftAction;
  if (self.draftKeyName == nil || [self.draftModifierNames count] == 0) return @"Choose the keys first.";
  if (self.keysChanged) {
    NSString *reason = [MWMReservedShortcuts reasonForKeyName:self.draftKeyName modifierNames:self.draftModifierNames];
    if (reason != nil) return reason;
  }
  if ((a.kind == MWMActionKindMove || a.kind == MWMActionKindFocusApp) && [a.a length] == 0) return a.kind == MWMActionKindMove ? @"Choose a slot." : @"Choose an application.";
  if (a.kind == MWMActionKindCustom && [a.a length] == 0) return @"Write the action.";
  // A move or push left as it was isn't checked again, so its shortcut can still be given other keys.
  if (a.kind == MWMActionKindCustom && (self.isNew || ![[a string] isEqualToString:self.original.action ?: @""])) {
    NSString *textProblem = nil;
    BOOL applies = NO;
    CGRect rect;
    if (![MWMAction getWindowRect:&rect forActionText:[self.document expandAliases:a.a] applies:&applies error:&textProblem] && applies) return textProblem ?: @"This isn't something MWM can work out.";
  }
  if (a.kind == MWMActionKindPush) {
    NSString *pushProblem = [[MWMPushOptions optionsFromText:a.b direction:a.a] problem];
    if (pushProblem != nil) return pushProblem;
  }
  if ((a.kind == MWMActionKindSnapshot || a.kind == MWMActionKindRestoreSnapshot) && [a.a length] == 0) return @"Name the snapshot.";
  if ((a.kind == MWMActionKindSnapshot || a.kind == MWMActionKindRestoreSnapshot) && [a.a rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]].location != NSNotFound) return @"A snapshot name can't have spaces.";
  return nil;
}

// The other shortcut that already uses the draft's keys, if any.
- (MWMShortcutInfo *)otherShortcutOnDraftKeys {
  if (self.draftKeyName == nil) return nil;
  NSString *identity = [MWMShortcut identityForKey:self.draftKeyName modifiers:[MWMShortcut stringFromModifierNames:self.draftModifierNames]];
  for (MWMShortcutInfo *info in [[MWMShortcutIndex indexForDocument:self.document] shortcuts]) {
    if (info.binding != self.original && [info.identity isEqualToString:identity] && info.binding.enabled) return info;
  }
  return nil;
}

- (void)selectKind:(MWMActionKind)kind {
  if (kind == self.draftAction.kind) return;
  NSString *before = [self.draftAction string];
  MWMAction *next = [MWMAction actionOfKind:kind];
  if (kind == MWMActionKindCustom) next.a = before;
  self.draftAction = next;
  [self refresh];
}

- (void)useKeyName:(NSString *)keyName modifierNames:(NSArray<NSString *> *)modifierNames groupName:(NSString *)groupName {
  self.draftKeyName = keyName;
  self.draftModifierNames = modifierNames ?: @[];
  self.draftGroupName = groupName;
  if (groupName == nil) {  // a set a group names exactly is that group
    for (MWMModifierGroup *group in [[MWMShortcutIndex indexForDocument:self.document] groups]) {
      if (!group.custom && [group.modifierNames isEqualToArray:self.draftModifierNames]) self.draftGroupName = group.name;
    }
  }
  self.keysChanged = YES;
  [self refresh];
}

#pragma mark - Drawing the page

- (void)refresh {
  [self rebuildKinds];
  [self rebuildForm];
  BOOL dirty = [self hasUnsavedChanges];
  [self.saveBar setDirty:dirty canSave:[self problem] == nil && !self.recording];
}

- (void)rebuildKinds {
  for (NSView *view in [[self.kindStack arrangedSubviews] copy]) {
    [self.kindStack removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  __weak ConfigurationShortcutEditorView *weakSelf = self;
  MWMActionKind current = self.draftAction.kind;
  // The four main actions, and the chosen one too when it is a lesser action, so the card says what the shortcut does.
  NSMutableArray<NSNumber *> *cards = [PrimaryKinds() mutableCopy];
  if (![cards containsObject:@(current)]) [cards addObject:@(current)];
  for (NSNumber *number in cards) {
    MWMActionKind kind = (MWMActionKind)[number integerValue];
    BOOL selected = kind == current;
    NSImageView *icon = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:SymbolForKind(kind) accessibilityDescription:nil]];
    [icon setSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:18 weight:NSFontWeightRegular]];
    [icon setContentTintColor:selected ? [MWMTheme accent] : [MWMTheme textSecondary]];
    [icon setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    [[icon.widthAnchor constraintEqualToConstant:24] setActive:YES];
    NSTextField *title = [self labelWithText:[MWMAction titleForKind:kind] size:13 color:selected ? [MWMTheme accent] : [MWMTheme textPrimary] weight:NSFontWeightMedium];
    NSTextField *summary = [MWMComponents wrappingLabelWithText:SummaryForKind(kind) size:11 color:[MWMTheme textSecondary] weight:NSFontWeightRegular];
    NSStackView *text = [MWMComponents columnWithViews:@[title, summary] spacing:2 insets:NSEdgeInsetsZero];
    NSStackView *content = [NSStackView stackViewWithViews:@[icon, text]];
    [content setSpacing:MWMSpacingM];
    [content setAlignment:NSLayoutAttributeTop];
    [summary setPreferredMaxLayoutWidth:190];   // wraps at the card's width, not the width of the longest word
    [[text.widthAnchor constraintEqualToAnchor:content.widthAnchor constant:-(24 + MWMSpacingM)] setActive:YES];
    NSView *row = [MWMComponents selectableRowWithContent:content insets:NSEdgeInsetsMake(MWMSpacingM, MWMSpacingM, MWMSpacingM, MWMSpacingM) selected:selected onClick:^{ [weakSelf selectKind:kind]; }];
    [row setIdentifier:[NSString stringWithFormat:@"kind-%ld", (long)kind]];
    [self.kindStack addArrangedSubview:row];
    [[row.widthAnchor constraintEqualToAnchor:self.kindStack.widthAnchor] setActive:YES];
  }
  // The rest, one line each, under a row that opens them.
  NSImageView *chevron = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:self.moreExpanded ? @"chevron.up" : @"chevron.down" accessibilityDescription:nil]];
  [chevron setContentTintColor:[MWMTheme textSecondary]];
  NSStackView *moreLine = [NSStackView stackViewWithViews:@[[self labelWithText:@"More actions" size:13 color:[MWMTheme textSecondary] weight:NSFontWeightRegular], [MWMComponents spacer], chevron]];
  NSView *more = [MWMComponents selectableRowWithContent:moreLine insets:NSEdgeInsetsMake(MWMSpacingM, MWMSpacingM, MWMSpacingM, MWMSpacingM) selected:NO onClick:^{ weakSelf.moreExpanded = !weakSelf.moreExpanded; [weakSelf rebuildKinds]; }];
  [more setIdentifier:@"kind-more"];
  [self.kindStack addArrangedSubview:more];
  [[more.widthAnchor constraintEqualToAnchor:self.kindStack.widthAnchor] setActive:YES];
  if (!self.moreExpanded) return;
  for (NSNumber *number in MoreKinds()) {
    MWMActionKind kind = (MWMActionKind)[number integerValue];
    if (kind == current) continue;
    NSTextField *label = [self labelWithText:[MWMAction titleForKind:kind] size:13 color:[MWMTheme textPrimary] weight:NSFontWeightRegular];
    NSView *row = [MWMComponents selectableRowWithContent:label insets:NSEdgeInsetsMake(MWMSpacingS, MWMSpacingM, MWMSpacingS, MWMSpacingM) selected:NO onClick:^{ [weakSelf selectKind:kind]; }];
    [row setIdentifier:[NSString stringWithFormat:@"kind-%ld", (long)kind]];
    [self.kindStack addArrangedSubview:row];
    [[row.widthAnchor constraintEqualToAnchor:self.kindStack.widthAnchor] setActive:YES];
  }
}

- (void)controlTextDidChange:(NSNotification *)note {
  if ([[note.object identifier] isEqualToString:@"slot-search"]) {
    self.slotQuery = [note.object stringValue];
    [self rebuildSlotList];
  }
}

#pragma mark - Form rows

- (void)addRowWithLabel:(NSString *)label content:(NSArray<NSView *> *)views identifier:(NSString *)identifier {
  [self addRowWithLabel:label content:views identifier:identifier toStack:self.formStack];
}

- (void)addRowWithLabel:(NSString *)label content:(NSArray<NSView *> *)views identifier:(NSString *)identifier toStack:(NSStackView *)stack {
  if ([[stack arrangedSubviews] count] > 0) {
    NSView *line = [MWMComponents separator];
    [stack addArrangedSubview:line];
    [[line.widthAnchor constraintEqualToAnchor:stack.widthAnchor] setActive:YES];
  }
  NSTextField *name = [self labelWithText:label size:12 color:[MWMTheme textSecondary] weight:NSFontWeightRegular];
  [name setTranslatesAutoresizingMaskIntoConstraints:NO];
  NSStackView *content = [NSStackView stackViewWithViews:views];
  [content setSpacing:10];
  [content setAlignment:NSLayoutAttributeCenterY];
  [content setTranslatesAutoresizingMaskIntoConstraints:NO];
  NSView *row = [[NSView alloc] init];
  [row setTranslatesAutoresizingMaskIntoConstraints:NO];
  [row setIdentifier:identifier];
  [row addSubview:name];
  [row addSubview:content];
  [NSLayoutConstraint activateConstraints:@[
    [row.heightAnchor constraintGreaterThanOrEqualToConstant:52],
    [name.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16], [name.widthAnchor constraintEqualToConstant:110], [name.topAnchor constraintEqualToAnchor:row.topAnchor constant:17],
    [content.leadingAnchor constraintGreaterThanOrEqualToAnchor:name.trailingAnchor constant:8], [content.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
    [content.topAnchor constraintEqualToAnchor:row.topAnchor constant:10], [content.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-10],
  ]];
  // The inputs sit at the right of the row; a list takes all the room the label leaves.
  if ([identifier isEqualToString:@"row-slot"]) {
    [[content.leadingAnchor constraintEqualToAnchor:name.trailingAnchor constant:8] setActive:YES];
    [[[views firstObject].widthAnchor constraintEqualToAnchor:content.widthAnchor] setActive:YES];
  }
  [stack addArrangedSubview:row];
  [[row.widthAnchor constraintEqualToAnchor:stack.widthAnchor] setActive:YES];
}

- (NSPopUpButton *)popupWithTitles:(NSArray<NSString *> *)titles values:(NSArray<NSString *> *)values selected:(NSString *)selected placeholder:(NSString *)placeholder action:(SEL)action {
  NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
  [popup setFont:[MWMTheme fontBody]];
  BOOL found = NO;
  if (placeholder != nil && [selected length] == 0) { [popup addItemWithTitle:placeholder]; [[popup lastItem] setRepresentedObject:@""]; found = YES; }
  for (NSUInteger i = 0; i < [titles count]; i++) {
    [popup addItemWithTitle:titles[i]];
    [[popup lastItem] setRepresentedObject:values[i]];
    if ([values[i] isEqualToString:selected]) { [popup selectItem:[popup lastItem]]; found = YES; }
  }
  if (!found) {  // keep a value the list doesn't know
    [popup addItemWithTitle:selected];
    [[popup lastItem] setRepresentedObject:selected];
    [popup selectItem:[popup lastItem]];
  }
  [popup setTarget:self];
  [popup setAction:action];
  [[popup.widthAnchor constraintGreaterThanOrEqualToConstant:200] setActive:YES];
  return popup;
}

- (NSTextField *)fieldWithText:(NSString *)text placeholder:(NSString *)placeholder width:(CGFloat)width action:(SEL)action identifier:(NSString *)identifier {
  NSTextField *field = [NSTextField textFieldWithString:text ?: @""];
  [field setFont:[MWMTheme fontMono]];
  [field setPlaceholderString:placeholder];
  [field setTarget:self];
  [field setAction:action];
  [field setDelegate:self];
  [field setIdentifier:identifier];
  [[field cell] setSendsActionOnEndEditing:YES];
  [[field.widthAnchor constraintEqualToConstant:width] setActive:YES];
  return field;
}

// Every name used for something in the document, so a new screen name is free.
- (BOOL)nameIsTaken:(NSString *)name {
  for (NSArray *section in @[self.document.modifiers, self.document.monitors, self.document.positions, self.document.aliases]) {
    for (MWMConfigEntry *entry in section) if ([entry.name isEqualToString:name]) return YES;
  }
  return NO;
}

// The screens a shortcut can name: the ones named on the Displays page, then every connected display that has no name
// yet (it gets one when the shortcut is saved). Each is {title, name, role}, with a role only for a screen not named yet.
- (NSArray<NSDictionary *> *)screenOptions {
  NSMutableArray *options = [NSMutableArray array];
  NSMutableSet *namedRoles = [NSMutableSet set];
  NSPredicate *resolution = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"[0-9]+x[0-9]+"];
  for (MWMConfigEntry *entry in self.document.monitors) {
    NSString *value = [[entry.value description] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([resolution evaluateWithObject:value]) continue;
    [options addObject:@{@"title": entry.name, @"name": entry.name}];
    [namedRoles addObject:value];
  }
  NSArray<MWMDisplay *> *connected = [MWMDisplays connected];
  NSMutableSet *proposed = [NSMutableSet set];
  for (MWMDisplay *display in connected) {
    NSString *role = [MWMDisplays roleForDisplay:display in:connected];
    if ([namedRoles containsObject:role]) continue;
    NSString *base = [MWMDisplays suggestedNameForDisplay:display in:connected], *name = base;
    for (NSUInteger i = 2; [self nameIsTaken:name] || [proposed containsObject:name]; i++) name = [NSString stringWithFormat:@"%@-%lu", base, (unsigned long)i];
    [proposed addObject:name];
    [options addObject:@{@"title": [NSString stringWithFormat:@"%@ · %@ (new)", display.name, [display sizeText]], @"name": name, @"role": role}];
  }
  return options;
}

- (NSArray<NSString *> *)screenNames {
  return [[self screenOptions] valueForKey:@"name"];
}

// Gives a connected display the name a shortcut picked for it, so the shortcut has something to point at.
- (void)nameScreensUsedByAction {
  MWMAction *m = self.draftAction;
  for (NSDictionary *option in [self screenOptions]) {
    NSString *role = option[@"role"], *name = option[@"name"];
    if (role == nil) continue;
    NSString *wrapped = [NSString stringWithFormat:@"${%@}", name];
    BOOL used = [m.a containsString:wrapped] || [m.b containsString:wrapped] || [m.b isEqualToString:name];
    if (used) [self.document.monitors addObject:[MWMConfigEntry entryWithName:name value:role]];
  }
}

// The screens as a popup lists them: what to write for each, and a way to the Displays page.
- (void)addScreenTitles:(NSMutableArray *)titles values:(NSMutableArray *)values wrapped:(BOOL)wrapped {
  for (NSDictionary *option in [self screenOptions]) {
    [titles addObject:option[@"title"]];
    [values addObject:wrapped ? [NSString stringWithFormat:@"${%@}", option[@"name"]] : option[@"name"]];
  }
}

- (void)addManageDisplaysItemTo:(NSPopUpButton *)popup {
  [[popup menu] addItem:[NSMenuItem separatorItem]];
  [popup addItemWithTitle:@"Manage displays…"];
  [[popup lastItem] setRepresentedObject:[ConfigurationPushRows manageDisplaysMarker]];
}

// Leaves the editor for the Displays page, asking first when there is something to lose.
- (void)manageDisplays {
  if (![self leaveConfirmed]) { [self refresh]; return; }
  [self close];
  if ([self.delegate respondsToSelector:@selector(shortcutEditorViewWantsDisplays:)]) [self.delegate shortcutEditorViewWantsDisplays:self];
}

- (NSArray<NSString *> *)slotNames {
  NSMutableArray *names = [NSMutableArray array];
  for (MWMSlot *preset in [MWMSlots presets]) [names addObject:preset.name];
  for (MWMConfigEntry *entry in self.document.positions) if (![names containsObject:entry.name]) [names addObject:entry.name];
  return names;
}

- (BOOL)getRect:(CGRect *)rect forSlotNamed:(NSString *)name {
  for (MWMConfigEntry *entry in self.document.positions) {
    if ([entry.name isEqualToString:name]) return [MWMSlots getRect:rect fromFormula:[entry.value description]];
  }
  MWMSlot *preset = [MWMSlots presetNamed:name];
  if (preset == nil) return NO;
  *rect = preset.rect;
  return YES;
}

- (void)rebuildForm {
  for (NSStackView *stack in @[self.formStack, self.keysStack]) {
    for (NSView *view in [[stack arrangedSubviews] copy]) {
      [stack removeArrangedSubview:view];
      [view removeFromSuperview];
    }
  }
  MWMAction *m = self.draftAction;
  switch (m.kind) {
    case MWMActionKindMove: {
      [self addRowWithLabel:@"Slot" content:@[[self slotPicker]] identifier:@"row-slot"];
      NSMutableArray *titles = [NSMutableArray arrayWithObject:@"Current screen"], *values = [NSMutableArray arrayWithObject:@""];
      [self addScreenTitles:titles values:values wrapped:NO];
      NSPopUpButton *screenPopup = [self popupWithTitles:titles values:values selected:m.b placeholder:nil action:@selector(secondChanged:)];
      [self addManageDisplaysItemTo:screenPopup];
      [self addRowWithLabel:@"On screen" content:@[screenPopup] identifier:@"row-screen"];
      break;
    }
    case MWMActionKindFocusApp: {
      [self addRowWithLabel:@"Application" content:@[[self applicationCombo:m.a]] identifier:@"row-app"];
      break;
    }
    case MWMActionKindFocusDirection:
      [self addRowWithLabel:@"Direction" content:@[[self popupWithTitles:[MWMAction directions] values:[MWMAction directions] selected:m.a placeholder:nil action:@selector(firstChanged:)]] identifier:@"row-direction"];
      break;
    case MWMActionKindThrow: {
      NSMutableArray *titles = [NSMutableArray arrayWithObjects:@"next", @"previous", nil], *values = [titles mutableCopy];
      [self addScreenTitles:titles values:values wrapped:YES];
      NSPopUpButton *screenPopup = [self popupWithTitles:titles values:values selected:m.a placeholder:nil action:@selector(firstChanged:)];
      [self addManageDisplaysItemTo:screenPopup];
      [self addRowWithLabel:@"To screen" content:@[screenPopup] identifier:@"row-throw"];
      [self addThrowStyleRows];
      break;
    }
    case MWMActionKindNudge:
    case MWMActionKindResize:
      [self addRowWithLabel:@"Horizontal" content:@[[self fieldWithText:m.a placeholder:@"+10%" width:100 action:@selector(firstChanged:) identifier:@"field-a"]] identifier:@"row-x"];
      [self addRowWithLabel:@"Vertical" content:@[[self fieldWithText:m.b placeholder:@"+0" width:100 action:@selector(secondChanged:) identifier:@"field-b"]] identifier:@"row-y"];
      break;
    case MWMActionKindPush:
      [self addRowWithLabel:@"Direction" content:@[[self popupWithTitles:[MWMAction pushDirections] values:[MWMAction pushDirections] selected:m.a placeholder:nil action:@selector(pushDirectionChanged:)]] identifier:@"row-direction"];
      [self addPushRows];
      break;
    case MWMActionKindHint:
      [self addRowWithLabel:@"Letters" content:@[[self fieldWithText:m.a placeholder:@"ASDFJKL" width:200 action:@selector(firstChanged:) identifier:@"field-a"]] identifier:@"row-letters"];
      break;
    case MWMActionKindGrid:
      [self addRowWithLabel:@"Arguments" content:@[[self fieldWithText:m.a placeholder:@"padding:5 0:6,2" width:260 action:@selector(firstChanged:) identifier:@"field-a"]] identifier:@"row-grid"];
      break;
    case MWMActionKindCustom:
      [self addCustomRows];
      break;
    case MWMActionKindSnapshot: {
      [self addRowWithLabel:@"Name" content:@[[self snapshotNameCombo:m.a]] identifier:@"row-snapshot"];
      NSButton *keep = [NSButton checkboxWithTitle:@"Keep it after MWM restarts" target:self action:@selector(keepChanged:)];
      [keep setState:[m.b isEqualToString:@"save-to-disk"] ? NSControlStateValueOn : NSControlStateValueOff];
      [keep setIdentifier:@"keep"];
      [self addRowWithLabel:@"Keep" content:@[keep] identifier:@"row-keep"];
      break;
    }
    case MWMActionKindRestoreSnapshot:
      [self addRowWithLabel:@"Snapshot" content:@[[self snapshotNameCombo:m.a]] identifier:@"row-snapshot"];
      break;
    case MWMActionKindSwitch:
    case MWMActionKindRelaunch:
      [self addRowWithLabel:@"Settings" content:@[[self labelWithText:@"This action has no settings." size:13 color:[MWMTheme textTertiary] weight:NSFontWeightRegular]] identifier:@"row-none"];
      break;
  }
  [self addKeysRow];
}

// How the window is sized on the screen it is thrown to: filling it, as it was, or a size written out.
- (void)addThrowStyleRows {
  NSString *style = self.draftAction.b ?: @"";
  NSInteger chosen = [style isEqualToString:@"resize"] ? 0 : [style hasPrefix:@"resize:"] ? 2 : 1;
  __weak ConfigurationShortcutEditorView *weakSelf = self;
  MWMOptionCards *cards = [MWMOptionCards cardsWithTitles:@[@"Fill the screen", @"Keep its size", @"Custom size"] symbols:@[@"rectangle.fill", @"rectangle", @"rectangle.dashed"] selectedIndex:chosen onChange:^(NSInteger index) {
    NSString *current = weakSelf.draftAction.b ?: @"";
    weakSelf.draftAction.b = index == 0 ? @"resize" : index == 1 ? @"noresize" : ([current hasPrefix:@"resize:"] ? current : @"resize:screenSizeX/2;screenSizeY");
    dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf refresh]; });
  }];
  [cards setIdentifier:@"throw-style"];
  [self addRowWithLabel:@"Window size" content:@[cards] identifier:@"row-style"];
  if (chosen != 2) return;
  NSArray<NSString *> *parts = [[style substringFromIndex:[@"resize:" length]] componentsSeparatedByString:@";"];
  NSTextField *width = [self fieldWithText:parts.count > 0 ? parts[0] : @"" placeholder:@"screenSizeX/2" width:220 action:@selector(throwSizeChanged:) identifier:@"throw-width"];
  NSTextField *height = [self fieldWithText:parts.count > 1 ? parts[1] : @"" placeholder:@"screenSizeY" width:220 action:@selector(throwSizeChanged:) identifier:@"throw-height"];
  [self addRowWithLabel:@"Width" content:@[width] identifier:@"row-throw-width"];
  [self addRowWithLabel:@"Height" content:@[height] identifier:@"row-throw-height"];
}

- (void)throwSizeChanged:(NSTextField *)field {
  if (![field isDescendantOf:self]) return;
  NSView *width = [self descendantWithIdentifier:@"throw-width" in:self], *height = [self descendantWithIdentifier:@"throw-height" in:self];
  NSString *w = [[(NSTextField *)width stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSString *h = [[(NSTextField *)height stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSString *value = [NSString stringWithFormat:@"resize:%@;%@", w, h];
  if ([value isEqualToString:self.draftAction.b]) return;
  self.draftAction.b = value;
  dispatch_async(dispatch_get_main_queue(), ^{ [self refresh]; });
}

- (NSView *)descendantWithIdentifier:(NSString *)identifier in:(NSView *)root {
  if ([root.identifier isEqualToString:identifier]) return root;
  for (NSView *sub in root.subviews) {
    NSView *found = [self descendantWithIdentifier:identifier in:sub];
    if (found != nil) return found;
  }
  return nil;
}

// An application: pick an installed one, or type a name (an app that isn't installed yet, or any other command).
- (NSComboBox *)applicationCombo:(NSString *)value {
  NSComboBox *combo = [[NSComboBox alloc] initWithFrame:NSZeroRect];
  [combo setFont:[MWMTheme fontBody]];
  [combo addItemsWithObjectValues:InstalledApplicationNames()];
  [combo setNumberOfVisibleItems:12];
  [combo setStringValue:value ?: @""];
  [combo setPlaceholderString:@"Choose or type an application"];
  [combo setTarget:self];
  [combo setAction:@selector(firstChanged:)];
  [combo setDelegate:self];
  [combo setIdentifier:@"field-a"];
  [combo setCompletes:YES];
  [[combo cell] setSendsActionOnEndEditing:YES];
  [[combo.widthAnchor constraintEqualToConstant:260] setActive:YES];
  return combo;
}

// A snapshot's name: type a new one, or pick one that's saved.
- (NSComboBox *)snapshotNameCombo:(NSString *)value {
  NSComboBox *combo = [[NSComboBox alloc] initWithFrame:NSZeroRect];
  [combo setFont:[MWMTheme fontBody]];
  for (MWMSnapshotInfo *info in [MWMSnapshots snapshots]) [combo addItemWithObjectValue:info.name];
  [combo setStringValue:value ?: @""];
  [combo setPlaceholderString:@"Snapshot name"];
  [combo setTarget:self];
  [combo setAction:@selector(firstChanged:)];
  [combo setDelegate:self];
  [combo setIdentifier:@"field-a"];
  [combo setCompletes:YES];
  [[combo.widthAnchor constraintEqualToConstant:240] setActive:YES];
  return combo;
}

- (void)keepChanged:(NSButton *)checkbox {
  self.draftAction.b = [checkbox state] == NSControlStateValueOn ? @"save-to-disk" : @"";
  dispatch_async(dispatch_get_main_queue(), ^{ [self refresh]; });
}

#pragma mark - Slot picker

// A search box and a kind filter over a list of rows: preview, name, size, and a check on the chosen one.
- (NSView *)slotPicker {
  NSSearchField *search = [[NSSearchField alloc] init];
  [search setPlaceholderString:@"Search slots"];
  [search setStringValue:self.slotQuery ?: @""];
  [search setDelegate:self];
  [search setIdentifier:@"slot-search"];
  [search setTranslatesAutoresizingMaskIntoConstraints:NO];
  // Which slots to list, and a way to the Slots page, in a menu beside the search.
  NSPopUpButton *filter = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
  [filter addItemsWithTitles:@[@"All slots", @"Presets", @"Custom"]];
  [filter selectItemAtIndex:self.slotFilter];
  [[filter menu] addItem:[NSMenuItem separatorItem]];
  [filter addItemWithTitle:@"Manage slots…"];
  [[filter lastItem] setRepresentedObject:[ConfigurationPushRows manageDisplaysMarker]];
  [filter setTarget:self];
  [filter setAction:@selector(slotFilterChanged:)];
  [filter setIdentifier:@"slot-filter"];
  [filter setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
  [search setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSStackView *top = [NSStackView stackViewWithViews:@[search, filter]];
  [top setSpacing:8];
  [top setAlignment:NSLayoutAttributeCenterY];

  self.slotList = [NSStackView stackViewWithViews:@[]];
  [self.slotList setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [self.slotList setAlignment:NSLayoutAttributeLeading];
  [self.slotList setSpacing:2];
  [self.slotList setTranslatesAutoresizingMaskIntoConstraints:NO];
  NSScrollView *scroll = [MWMComponents scrollViewWithContent:self.slotList];
  [scroll setBorderType:NSNoBorder];
  [scroll.heightAnchor constraintEqualToConstant:208].active = YES;
  [scroll setIdentifier:@"slot-list"];

  NSStackView *picker = [NSStackView stackViewWithViews:@[top, scroll]];
  [picker setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [picker setAlignment:NSLayoutAttributeLeading];
  [picker setSpacing:8];
  [picker setTranslatesAutoresizingMaskIntoConstraints:NO];
  [NSLayoutConstraint activateConstraints:@[[top.widthAnchor constraintEqualToAnchor:picker.widthAnchor], [scroll.widthAnchor constraintEqualToAnchor:picker.widthAnchor]]];
  [self rebuildSlotList];
  return picker;
}

// Name, area (nil when it can't be drawn) and whether it's one of the built-in presets.
- (NSArray<NSDictionary *> *)slotChoices {
  NSMutableArray *choices = [NSMutableArray array];
  NSMutableSet *seen = [NSMutableSet set];
  for (MWMConfigEntry *entry in self.document.positions) {
    CGRect rect = CGRectZero;
    BOOL readable = [MWMSlots getRect:&rect fromFormula:[entry.value description]];
    // Margins, pixel sizes and window names can't be drawn exactly, but they can be worked out for a sample screen.
    if (!readable) readable = [MWMSlots getPreviewRect:&rect fromFormula:[self.document expandAliases:[entry.value description]]];
    MWMSlot *preset = [MWMSlots presetNamed:entry.name];
    BOOL isPreset = preset != nil && readable && [MWMSlots rect:rect isSameAreaAs:preset.rect];
    [choices addObject:@{@"name": entry.name, @"rect": readable ? [NSValue valueWithRect:NSRectFromCGRect(rect)] : [NSNull null], @"preset": @(isPreset)}];
    [seen addObject:entry.name];
  }
  for (MWMSlot *preset in [MWMSlots presets]) {
    if ([seen containsObject:preset.name]) continue;
    [choices addObject:@{@"name": preset.name, @"rect": [NSValue valueWithRect:NSRectFromCGRect(preset.rect)], @"preset": @YES}];
  }
  return choices;
}

- (void)rebuildSlotList {
  for (NSView *view in [[self.slotList arrangedSubviews] copy]) {
    [self.slotList removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  NSString *query = [[self.slotQuery ?: @"" lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  __weak ConfigurationShortcutEditorView *weakSelf = self;
  NSUInteger shown = 0;
  for (NSDictionary *choice in [self slotChoices]) {
    NSString *name = choice[@"name"];
    BOOL isPreset = [choice[@"preset"] boolValue];
    if (self.slotFilter == 1 && !isPreset) continue;
    if (self.slotFilter == 2 && isPreset) continue;
    if ([query length] > 0 && ![[name lowercaseString] containsString:query]) continue;
    shown++;
    BOOL selected = [name isEqualToString:self.draftAction.a];
    BOOL hasRect = ![choice[@"rect"] isKindOfClass:[NSNull class]];
    CGRect rect = hasRect ? NSRectToCGRect([choice[@"rect"] rectValue]) : CGRectZero;

    NSView *thumb;
    if (hasRect) {
      ConfigurationSlotThumbnail *preview = [[ConfigurationSlotThumbnail alloc] init];
      preview.rect = rect;
      preview.valid = YES;
      thumb = preview;
    } else {
      thumb = [[NSView alloc] init];
    }
    [thumb setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSTextField *title = [self labelWithText:name size:13 color:selected ? [MWMTheme accent] : [MWMTheme textPrimary] weight:NSFontWeightMedium];
    NSString *summaryText = hasRect ? [[MWMSlot slotNamed:name rect:rect preset:isPreset] summary] : @"Set by a formula";
    NSTextField *summary = [self labelWithText:summaryText size:11 color:[MWMTheme textSecondary] weight:NSFontWeightRegular];
    NSStackView *texts = [NSStackView stackViewWithViews:@[title, summary]];
    [texts setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [texts setAlignment:NSLayoutAttributeLeading];
    [texts setSpacing:1];
    NSTextField *kind = [MWMComponents captionLabel:isPreset ? @"Preset" : @"Custom"];
    NSImageView *check = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:@"checkmark" accessibilityDescription:@"Chosen"]];
    [check setContentTintColor:[MWMTheme accent]];
    [check setAlphaValue:selected ? 1 : 0];   // keeps its space, so the labels don't move
    NSStackView *content = [NSStackView stackViewWithViews:@[thumb, texts, [MWMComponents spacer], kind, check]];
    [content setSpacing:MWMSpacingM];
    [content setAlignment:NSLayoutAttributeCenterY];
    [NSLayoutConstraint activateConstraints:@[[thumb.widthAnchor constraintEqualToConstant:48], [thumb.heightAnchor constraintEqualToConstant:30]]];
    NSView *row = [MWMComponents selectableRowWithContent:content insets:NSEdgeInsetsMake(7, 8, 7, 10) selected:selected onClick:^{ [weakSelf chooseSlotNamed:name]; }];
    [row setIdentifier:[@"slot-" stringByAppendingString:name]];
    [self.slotList addArrangedSubview:row];
    [[row.widthAnchor constraintEqualToAnchor:self.slotList.widthAnchor] setActive:YES];
  }
  if (shown == 0) {
    NSTextField *none = [self labelWithText:@"No slots match." size:12 color:[MWMTheme textTertiary] weight:NSFontWeightRegular];
    [self.slotList addArrangedSubview:none];
  }
}

- (void)chooseSlotNamed:(NSString *)name {
  if (self.draftAction.kind != MWMActionKindMove || [name isEqualToString:self.draftAction.a]) return;
  self.draftAction.a = name;
  dispatch_async(dispatch_get_main_queue(), ^{ [self refresh]; });
}

- (void)slotFilterChanged:(NSPopUpButton *)control {
  if ([[[control selectedItem] representedObject] isEqual:[ConfigurationPushRows manageDisplaysMarker]]) {
    dispatch_async(dispatch_get_main_queue(), ^{ [self manageSlots]; });
    [control selectItemAtIndex:self.slotFilter];
    return;
  }
  self.slotFilter = [control indexOfSelectedItem];
  [self rebuildSlotList];
}

// Leaves the editor for the Slots page, asking first when there is something to lose.
- (void)manageSlots {
  if (![self leaveConfirmed]) return;
  [self close];
  if ([self.delegate respondsToSelector:@selector(shortcutEditorViewWantsSlots:)]) [self.delegate shortcutEditorViewWantsSlots:self];
}

// The text of an advanced action. A move or a push also shows where it puts a window, with its mistakes named
// and the names a formula can use.
- (void)addCustomRows {
  MWMAction *m = self.draftAction;
  CGRect rect = CGRectZero;
  NSString *error = nil;
  BOOL applies = NO;
  BOOL worked = [MWMAction getWindowRect:&rect forActionText:[self.document expandAliases:m.a] applies:&applies error:&error];
  NSTextField *field = [self fieldWithText:m.a placeholder:@"operation" width:applies ? 460 : 320 action:@selector(firstChanged:) identifier:@"field-a"];
  if (!applies) {
    [self addRowWithLabel:@"Action" content:@[field] identifier:@"row-custom"];
    return;
  }
  NSButton *help = [NSButton buttonWithTitle:@"" target:self action:@selector(showFormulaHelp:)];
  [help setBezelStyle:NSBezelStyleHelpButton];
  [help setToolTip:@"Names you can use in a formula"];
  [help setIdentifier:@"formula-help"];
  [self addRowWithLabel:@"Action" content:@[field, help] identifier:@"row-custom"];
  ConfigurationSlotThumbnail *thumbnail = [[ConfigurationSlotThumbnail alloc] init];
  [thumbnail setTranslatesAutoresizingMaskIntoConstraints:NO];
  thumbnail.rect = worked ? rect : CGRectZero;
  thumbnail.valid = worked;
  [NSLayoutConstraint activateConstraints:@[[thumbnail.widthAnchor constraintEqualToConstant:80], [thumbnail.heightAnchor constraintEqualToConstant:50]]];
  NSString *text = worked ? @"No problems. Worked out for a sample screen." : (error ?: @"This isn't something MWM can work out.");
  NSTextField *status = [self labelWithText:text size:12 color:worked ? [MWMTheme success] : [MWMTheme warning] weight:NSFontWeightRegular];
  [status setIdentifier:@"custom-check"];
  [self addRowWithLabel:@"Result" content:@[thumbnail, status] identifier:@"row-result"];
}

- (void)showFormulaHelp:(NSButton *)sender {
  if (self.helpPopover.shown) { [self.helpPopover close]; return; }
  self.helpPopover = [ConfigurationFormulaHelp popover];
  [self.helpPopover showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSRectEdgeMaxY];
}

// What follows a push's direction: the style, thickness and screen as controls, or, for text they can't show, the text.
- (void)addPushRows {
  MWMAction *m = self.draftAction;
  MWMPushOptions *options = [MWMPushOptions optionsFromText:m.b direction:m.a];
  if (options == nil) {
    [self addRowWithLabel:@"Options" content:@[[self fieldWithText:m.b placeholder:@"bar-resize:screenSizeX/2" width:260 action:@selector(secondChanged:) identifier:@"field-b"]] identifier:@"row-options"];
    return;
  }
  __weak ConfigurationShortcutEditorView *weakSelf = self;
  NSMutableArray *screenTitles = [NSMutableArray array], *screenValues = [NSMutableArray array];
  [self addScreenTitles:screenTitles values:screenValues wrapped:YES];
  self.pushRows = [ConfigurationPushRows rowsForOptions:options direction:m.a screenTitles:screenTitles screenValues:screenValues onChange:^(MWMPushOptions *changed) {
    weakSelf.draftAction.b = [changed textForDirection:weakSelf.draftAction.a];
    dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf refresh]; });
  } onManageDisplays:^{ dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf manageDisplays]; }); }];
  for (NSDictionary *row in self.pushRows.rows) [self addRowWithLabel:row[@"label"] content:row[@"views"] identifier:row[@"identifier"]];
}

// The thickness is written for one side of the screen, so a new direction rewrites it for the other.
- (void)pushDirectionChanged:(NSPopUpButton *)popup {
  NSString *direction = [[popup selectedItem] representedObject] ?: @"";
  MWMAction *m = self.draftAction;
  if ([direction isEqualToString:m.a]) return;
  MWMPushOptions *options = [MWMPushOptions optionsFromText:m.b direction:m.a];
  if (options != nil) m.b = [options textForDirection:direction];
  m.a = direction;
  dispatch_async(dispatch_get_main_queue(), ^{ [self refresh]; });
}

- (BOOL)isManageDisplaysChoice:(id)control {
  return [control isKindOfClass:[NSPopUpButton class]] && [[[(NSPopUpButton *)control selectedItem] representedObject] isEqual:[ConfigurationPushRows manageDisplaysMarker]];
}

- (void)firstChanged:(id)control {
  if ([control isKindOfClass:[NSView class]] && ![control isDescendantOf:self]) return;   // a field of the form that was just replaced, losing focus
  if ([self isManageDisplaysChoice:control]) { dispatch_async(dispatch_get_main_queue(), ^{ [self manageDisplays]; }); return; }
  NSString *value = [control isKindOfClass:[NSPopUpButton class]] ? ([[(NSPopUpButton *)control selectedItem] representedObject] ?: @"") : [[control stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if ([value isEqualToString:self.draftAction.a]) return;
  self.draftAction.a = value;
  dispatch_async(dispatch_get_main_queue(), ^{ [self refresh]; });
}

- (void)secondChanged:(id)control {
  if ([control isKindOfClass:[NSView class]] && ![control isDescendantOf:self]) return;   // a field of the form that was just replaced, losing focus
  if ([self isManageDisplaysChoice:control]) { dispatch_async(dispatch_get_main_queue(), ^{ [self manageDisplays]; }); return; }
  NSString *value = [control isKindOfClass:[NSPopUpButton class]] ? ([[(NSPopUpButton *)control selectedItem] representedObject] ?: @"") : [[control stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if ([value isEqualToString:self.draftAction.b]) return;
  self.draftAction.b = value;
  dispatch_async(dispatch_get_main_queue(), ^{ [self refresh]; });
}

#pragma mark - Keys row

- (void)addKeysRow {
  NSMutableArray *views = [NSMutableArray array];
  NSString *message = nil;
  NSColor *messageColor = [MWMTheme textSecondary];
  if (self.recording) {
    NSMutableArray *live = [NSMutableArray array];
    if (self.recordedKey != nil || [self.recordedModifiers count] > 0) {
      if (self.recordedKey != nil) [live addObject:[ConfigurationKeyViews keyCapsForModifiers:self.recordedModifiers keyName:self.recordedKey size:26]];
      else [live addObject:[ConfigurationKeyViews modifierCaps:self.recordedModifiers size:26]];
    } else {
      [live addObject:[self labelWithText:@"Press the keys…" size:13 color:[MWMTheme textSecondary] weight:NSFontWeightRegular]];
    }
    [views addObjectsFromArray:live];
    message = @"Enter to use them, Esc to cancel.";
    if (self.recordedKey != nil) {
      NSString *reason = [MWMReservedShortcuts reasonForKeyName:self.recordedKey modifierNames:self.recordedModifiers];
      MWMShortcutInfo *other = [self otherShortcutOn:self.recordedKey modifiers:self.recordedModifiers];
      if (reason != nil) { message = reason; messageColor = [MWMTheme warning]; }
      else if (other != nil) { message = [NSString stringWithFormat:@"Already used by \"%@\". Enter uses the keys anyway.", other.title]; messageColor = [MWMTheme warning]; }
    }
    NSButton *cancel = [MWMComponents secondaryButtonWithTitle:@"Cancel" target:self action:@selector(cancelRecordingPressed:)];
    [views addObject:cancel];
  } else {
    if (self.draftKeyName != nil) {
      NSMutableArray *keyViews = [NSMutableArray array];
      if (self.draftGroupName != nil) [keyViews addObject:[ConfigurationKeyViews pillWithText:self.draftGroupName]];
      [keyViews addObject:[ConfigurationKeyViews keyCapsForModifiers:self.draftModifierNames keyName:self.draftKeyName size:26]];
      NSStackView *keys = [NSStackView stackViewWithViews:keyViews];
      [keys setSpacing:8];
      [keys setAlignment:NSLayoutAttributeCenterY];
      [views addObject:keys];
    } else {
      [views addObject:[self labelWithText:@"No keys yet" size:13 color:[MWMTheme textTertiary] weight:NSFontWeightRegular]];
    }
    NSButton *record = [MWMComponents secondaryButtonWithTitle:@"Record" target:self action:@selector(recordPressed:)];
    NSButton *pick = [MWMComponents secondaryButtonWithTitle:@"Pick on map" target:self action:@selector(pickPressed:)];
    [record setIdentifier:@"record"];
    [pick setIdentifier:@"pick"];
    [views addObject:record];
    [views addObject:pick];
    MWMShortcutInfo *other = [self otherShortcutOnDraftKeys];
    NSString *reason = self.keysChanged && self.draftKeyName != nil ? [MWMReservedShortcuts reasonForKeyName:self.draftKeyName modifierNames:self.draftModifierNames] : nil;
    if (reason != nil) { message = reason; messageColor = [MWMTheme warning]; }
    else if (other != nil) { message = [NSString stringWithFormat:@"Same keys as \"%@\". Only one can work.", other.title]; messageColor = [MWMTheme warning]; }
  }
  if (message != nil) {
    NSTextField *note = [self labelWithText:message size:12 color:messageColor weight:NSFontWeightRegular];
    [note setIdentifier:@"keys-message"];
    NSStackView *column = [NSStackView stackViewWithViews:@[[self rowOf:views], note]];
    [column setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [column setAlignment:NSLayoutAttributeLeading];
    [column setSpacing:6];
    views = [NSMutableArray arrayWithObject:column];
  }
  [self addRowWithLabel:@"Keys" content:views identifier:@"row-keys" toStack:self.keysStack];
}

- (NSStackView *)rowOf:(NSArray<NSView *> *)views {
  NSStackView *row = [NSStackView stackViewWithViews:views];
  [row setSpacing:10];
  [row setAlignment:NSLayoutAttributeCenterY];
  return row;
}

- (MWMShortcutInfo *)otherShortcutOn:(NSString *)keyName modifiers:(NSArray<NSString *> *)modifiers {
  NSString *identity = [MWMShortcut identityForKey:keyName modifiers:[MWMShortcut stringFromModifierNames:modifiers]];
  for (MWMShortcutInfo *info in [[MWMShortcutIndex indexForDocument:self.document] shortcuts]) {
    if (info.binding != self.original && [info.identity isEqualToString:identity] && info.binding.enabled) return info;
  }
  return nil;
}

#pragma mark - Recording

- (void)recordPressed:(id)sender { [self beginRecording]; }
- (void)cancelRecordingPressed:(id)sender { [self cancelRecording]; }

- (void)beginRecording {
  if (self.recording) return;
  self.recording = YES;
  self.recordedKey = nil;
  self.recordedModifiers = @[];
  __weak ConfigurationShortcutEditorView *weakSelf = self;
  self.monitor = [NSEvent addLocalMonitorForEventsMatchingMask:(NSEventMaskKeyDown | NSEventMaskFlagsChanged) handler:^NSEvent *(NSEvent *event) {
    ConfigurationShortcutEditorView *strongSelf = weakSelf;
    if (strongSelf == nil || !strongSelf.recording) return event;
    if (event.type == NSEventTypeFlagsChanged) {
      if (strongSelf.recordedKey == nil) {
        strongSelf.recordedModifiers = [MWMShortcut modifierNamesFromFlags:event.modifierFlags];
        [strongSelf refresh];
      }
      return nil;
    }
    [strongSelf recordKeyCode:event.keyCode modifierFlags:event.modifierFlags];
    return nil;
  }];
  [self refresh];
}

- (void)recordKeyCode:(UInt16)keyCode modifierFlags:(NSEventModifierFlags)flags {
  if (!self.recording) return;
  if (keyCode == 53) { [self cancelRecording]; return; }                         // Esc
  if ((keyCode == 36 || keyCode == 76) && self.recordedKey != nil) { [self confirmRecording]; return; }   // Return, Enter
  NSString *name = [MWMShortcut keyNameForKeyCode:keyCode];
  if (name == nil) return;
  self.recordedKey = name;
  self.recordedModifiers = [MWMShortcut modifierNamesFromFlags:flags];
  [self refresh];
}

// Enter: takes the keys, unless macOS keeps them.
- (void)confirmRecording {
  if (!self.recording || self.recordedKey == nil) return;
  if ([MWMReservedShortcuts reasonForKeyName:self.recordedKey modifierNames:self.recordedModifiers] != nil) return;
  NSString *key = self.recordedKey;
  NSArray *modifiers = self.recordedModifiers;
  [self endRecording];
  [self useKeyName:key modifierNames:modifiers groupName:nil];
}

- (void)cancelRecording {
  if (!self.recording) return;
  [self endRecording];
  [self refresh];
}

- (void)endRecording {
  self.recording = NO;
  self.recordedKey = nil;
  self.recordedModifiers = @[];
  [self removeMonitor];
}

- (void)removeMonitor {
  if (self.monitor != nil) { [NSEvent removeMonitor:self.monitor]; self.monitor = nil; }
}

#pragma mark - Picking on the map

- (void)pickPressed:(id)sender {
  [self cancelRecording];
  self.picker.document = self.document;
  self.picker.ignoredBinding = self.original;
  self.picker.customModifiers = self.draftGroupName == nil && [self.draftModifierNames count] > 0 ? self.draftModifierNames : @[@"ctrl"];
  self.picker.confirmsRemoval = NO;
  if (self.draftGroupName != nil) self.picker.groupName = self.draftGroupName;
  else self.picker.groupName = @"Custom";
  if (self.draftKeyName != nil) [self.picker selectKeyNamed:self.draftKeyName];
  [self.editorPage setHidden:YES];
  [self.pickerPage setHidden:NO];
}

- (void)keyboardMapView:(ConfigurationKeyboardMapView *)view didPickKey:(NSString *)keyName modifierNames:(NSArray<NSString *> *)modifierNames groupName:(NSString *)groupName {
  [self.pickerPage setHidden:YES];
  [self.editorPage setHidden:NO];
  [self useKeyName:keyName modifierNames:modifierNames groupName:groupName];
}

- (void)keyboardMapViewDidCancelPicking:(ConfigurationKeyboardMapView *)view {
  [self.pickerPage setHidden:YES];
  [self.editorPage setHidden:NO];
}

// Not used while picking.
- (void)keyboardMapViewDidChangeDocument:(ConfigurationKeyboardMapView *)view {}
- (void)keyboardMapView:(ConfigurationKeyboardMapView *)view wantsToEditBindingAtIndex:(NSUInteger)index {}
- (void)keyboardMapView:(ConfigurationKeyboardMapView *)view wantsNewShortcutInGroup:(NSString *)groupName keyName:(NSString *)keyName {}
- (void)keyboardMapViewWantsGroups:(ConfigurationKeyboardMapView *)view {}

#pragma mark - Saving and leaving

- (void)save {
  if (![self hasUnsavedChanges] || [self problem] != nil) return;
  [self cancelRecording];
  NSString *modifiers = [self draftModifiersText];
  [self nameScreensUsedByAction];
  if (self.isNew) {
    MWMBindingEntry *binding = [MWMBindingEntry bindingWithKey:self.draftKeyName modifiers:modifiers action:[self.draftAction string]];
    binding.enabled = YES;
    [self.document.bindings addObject:binding];
  } else {
    self.original.key = self.draftKeyName;
    self.original.modifiers = modifiers;
    self.original.action = [self.draftAction string];
  }
  [self.delegate shortcutEditorViewDidSave:self];
  [self.delegate shortcutEditorViewDidClose:self];
}

- (void)close {
  [self cancelRecording];
  [self.delegate shortcutEditorViewDidClose:self];
}

- (void)savePressed:(id)sender { [self save]; }
- (void)cancelPressed:(id)sender { [self close]; }

// NO when there are changes to lose and the user chose to keep editing.
- (BOOL)leaveConfirmed {
  if (self.confirmsDiscard && !self.isNew && [self hasUnsavedChanges]) {
    MWMAlert *alert = [MWMAlert alert];
    [alert setKind:MWMAlertKindConfirm];
    [alert setMessageText:@"Discard your changes?"];
    [alert setInformativeText:@"This shortcut has changes that haven't been saved."];
    [alert addButtonWithTitle:@"Keep editing"];
    [alert addDestructiveButtonWithTitle:@"Discard"];
    if ([alert runModal] == NSAlertFirstButtonReturn) return NO;
  }
  return YES;
}

- (void)backPressed:(id)sender {
  if ([self leaveConfirmed]) [self close];
}

@end
