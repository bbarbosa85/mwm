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
#import "NSAlert+MWM.h"
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

// What the shortcut can do, in the order the list shows them.
static NSArray<NSNumber *> *KindsInOrder(void) {
  return @[@(MWMActionKindFocusApp), @(MWMActionKindMove), @(MWMActionKindFocusDirection), @(MWMActionKindResize), @(MWMActionKindNudge),
           @(MWMActionKindPush), @(MWMActionKindThrow), @(MWMActionKindSnapshot), @(MWMActionKindRestoreSnapshot), @(MWMActionKindHint), @(MWMActionKindGrid), @(MWMActionKindSwitch),
           @(MWMActionKindRelaunch), @(MWMActionKindCustom)];
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
@property (strong, nullable) MWMBindingEntry *original;   // nil for a new shortcut
@property (copy) NSString *originalSignature;
@property (assign) BOOL isNew;
@property (assign) BOOL keysChanged;

@property (strong) NSView *editorPage;
@property (strong) NSTextField *titleLabel;
@property (strong) NSSearchField *kindSearch;
@property (strong) NSStackView *kindStack;
@property (strong) NSStackView *formStack;
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

- (void)buildInterface {
  MWMSublevelHeader *header = [MWMSublevelHeader headerWithBackTitle:@"Keyboard" title:@"New Shortcut" target:self action:@selector(backPressed:)];
  self.titleLabel = header.titleLabel;

  // Left: what the shortcut does.
  self.kindSearch = [[NSSearchField alloc] init];
  [self.kindSearch setPlaceholderString:@"Filter"];
  [self.kindSearch setDelegate:self];
  [self.kindSearch setIdentifier:@"kind-search"];
  [self.kindSearch setTranslatesAutoresizingMaskIntoConstraints:NO];
  self.kindStack = [NSStackView stackViewWithViews:@[]];
  [self.kindStack setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [self.kindStack setAlignment:NSLayoutAttributeLeading];
  [self.kindStack setSpacing:2];
  NSView *spacer = [[NSView alloc] init];
  [spacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationVertical];
  NSStackView *left = [NSStackView stackViewWithViews:@[self.kindSearch, self.kindStack, spacer]];
  [left setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [left setAlignment:NSLayoutAttributeLeading];
  [left setSpacing:10];
  [left setTranslatesAutoresizingMaskIntoConstraints:NO];
  [[self.kindSearch.widthAnchor constraintEqualToAnchor:left.widthAnchor] setActive:YES];
  [[self.kindStack.widthAnchor constraintEqualToAnchor:left.widthAnchor] setActive:YES];

  // Right: the settings, as rows in a card.
  self.formStack = [NSStackView stackViewWithViews:@[]];
  [self.formStack setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [self.formStack setAlignment:NSLayoutAttributeLeading];
  [self.formStack setSpacing:0];
  [self.formStack setTranslatesAutoresizingMaskIntoConstraints:NO];
  ConfigurationBlockView *card = [[ConfigurationBlockView alloc] init];
  [card setTranslatesAutoresizingMaskIntoConstraints:NO];
  [card addSubview:self.formStack];
  [NSLayoutConstraint activateConstraints:@[
    [self.formStack.topAnchor constraintEqualToAnchor:card.topAnchor], [self.formStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],
    [self.formStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor], [self.formStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
  ]];
  NSView *cardHolder = [[NSView alloc] init];
  [cardHolder setTranslatesAutoresizingMaskIntoConstraints:NO];
  [cardHolder addSubview:card];
  [NSLayoutConstraint activateConstraints:@[
    [card.topAnchor constraintEqualToAnchor:cardHolder.topAnchor], [card.leadingAnchor constraintEqualToAnchor:cardHolder.leadingAnchor], [card.trailingAnchor constraintEqualToAnchor:cardHolder.trailingAnchor],
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
    [left.widthAnchor constraintEqualToConstant:210], [left.bottomAnchor constraintEqualToAnchor:saveBar.topAnchor constant:-MWMSpacingL],
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
  [self.kindSearch setStringValue:@""];
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
  NSString *query = [[self.kindSearch stringValue] lowercaseString];
  __weak ConfigurationShortcutEditorView *weakSelf = self;
  for (NSNumber *number in KindsInOrder()) {
    MWMActionKind kind = (MWMActionKind)[number integerValue];
    NSString *title = [MWMAction titleForKind:kind];
    if ([query length] > 0 && ![[title lowercaseString] containsString:query]) continue;
    BOOL selected = kind == self.draftAction.kind;
    NSTextField *label = [self labelWithText:title size:13 color:selected ? [MWMTheme accent] : [MWMTheme textPrimary] weight:selected ? NSFontWeightMedium : NSFontWeightRegular];
    NSView *row = [MWMComponents selectableRowWithContent:label insets:NSEdgeInsetsMake(8, 12, 8, 8) selected:selected onClick:^{ [weakSelf selectKind:kind]; }];
    [row setIdentifier:[NSString stringWithFormat:@"kind-%ld", (long)kind]];
    [self.kindStack addArrangedSubview:row];
    [[row.widthAnchor constraintEqualToAnchor:self.kindStack.widthAnchor] setActive:YES];
  }
}

- (void)controlTextDidChange:(NSNotification *)note {
  if (note.object == self.kindSearch) [self rebuildKinds];
  else if ([[note.object identifier] isEqualToString:@"slot-search"]) {
    self.slotQuery = [note.object stringValue];
    [self rebuildSlotList];
  }
}

#pragma mark - Form rows

- (void)addRowWithLabel:(NSString *)label content:(NSArray<NSView *> *)views identifier:(NSString *)identifier {
  if ([[self.formStack arrangedSubviews] count] > 0) {
    NSView *line = [MWMComponents separator];
    [self.formStack addArrangedSubview:line];
    [[line.widthAnchor constraintEqualToAnchor:self.formStack.widthAnchor] setActive:YES];
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
    [content.leadingAnchor constraintEqualToAnchor:name.trailingAnchor constant:8], [content.trailingAnchor constraintLessThanOrEqualToAnchor:row.trailingAnchor constant:-16],
    [content.topAnchor constraintEqualToAnchor:row.topAnchor constant:10], [content.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-10],
  ]];
  [self.formStack addArrangedSubview:row];
  [[row.widthAnchor constraintEqualToAnchor:self.formStack.widthAnchor] setActive:YES];
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

- (NSArray<NSString *> *)screenNames {
  NSMutableArray *names = [NSMutableArray array];
  for (MWMConfigEntry *entry in self.document.monitors) if (![[entry.value description] containsString:@"x"]) [names addObject:entry.name];
  return names;
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
  for (NSView *view in [[self.formStack arrangedSubviews] copy]) {
    [self.formStack removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  MWMAction *m = self.draftAction;
  switch (m.kind) {
    case MWMActionKindMove: {
      [self addRowWithLabel:@"Slot" content:@[[self slotPicker]] identifier:@"row-slot"];
      NSMutableArray *titles = [NSMutableArray arrayWithObject:@"Current screen"], *values = [NSMutableArray arrayWithObject:@""];
      for (NSString *name in [self screenNames]) { [titles addObject:name]; [values addObject:name]; }
      [self addRowWithLabel:@"On screen" content:@[[self popupWithTitles:titles values:values selected:m.b placeholder:nil action:@selector(secondChanged:)]] identifier:@"row-screen"];
      break;
    }
    case MWMActionKindFocusApp: {
      NSArray *apps = InstalledApplicationNames();
      [self addRowWithLabel:@"Application" content:@[[self popupWithTitles:apps values:apps selected:m.a placeholder:@"Choose an application" action:@selector(firstChanged:)]] identifier:@"row-app"];
      break;
    }
    case MWMActionKindFocusDirection:
      [self addRowWithLabel:@"Direction" content:@[[self popupWithTitles:[MWMAction directions] values:[MWMAction directions] selected:m.a placeholder:nil action:@selector(firstChanged:)]] identifier:@"row-direction"];
      break;
    case MWMActionKindThrow: {
      NSMutableArray *titles = [NSMutableArray arrayWithObjects:@"next", @"previous", nil], *values = [titles mutableCopy];
      for (NSString *name in [self screenNames]) { [titles addObject:name]; [values addObject:[NSString stringWithFormat:@"${%@}", name]]; }
      [self addRowWithLabel:@"To screen" content:@[[self popupWithTitles:titles values:values selected:m.a placeholder:nil action:@selector(firstChanged:)]] identifier:@"row-throw"];
      [self addRowWithLabel:@"Style" content:@[[self fieldWithText:m.b placeholder:@"resize" width:200 action:@selector(secondChanged:) identifier:@"field-b"]] identifier:@"row-style"];
      break;
    }
    case MWMActionKindNudge:
    case MWMActionKindResize:
      [self addRowWithLabel:@"Horizontal" content:@[[self fieldWithText:m.a placeholder:@"+10%" width:100 action:@selector(firstChanged:) identifier:@"field-a"]] identifier:@"row-x"];
      [self addRowWithLabel:@"Vertical" content:@[[self fieldWithText:m.b placeholder:@"+0" width:100 action:@selector(secondChanged:) identifier:@"field-b"]] identifier:@"row-y"];
      break;
    case MWMActionKindPush:
      [self addRowWithLabel:@"Direction" content:@[[self popupWithTitles:[MWMAction pushDirections] values:[MWMAction pushDirections] selected:m.a placeholder:nil action:@selector(firstChanged:)]] identifier:@"row-direction"];
      [self addRowWithLabel:@"Options" content:@[[self fieldWithText:m.b placeholder:@"bar-resize:screenSizeX/2" width:260 action:@selector(secondChanged:) identifier:@"field-b"]] identifier:@"row-options"];
      break;
    case MWMActionKindHint:
      [self addRowWithLabel:@"Letters" content:@[[self fieldWithText:m.a placeholder:@"ASDFJKL" width:200 action:@selector(firstChanged:) identifier:@"field-a"]] identifier:@"row-letters"];
      break;
    case MWMActionKindGrid:
      [self addRowWithLabel:@"Arguments" content:@[[self fieldWithText:m.a placeholder:@"padding:5 0:6,2" width:260 action:@selector(firstChanged:) identifier:@"field-a"]] identifier:@"row-grid"];
      break;
    case MWMActionKindCustom:
      [self addRowWithLabel:@"Action" content:@[[self fieldWithText:m.a placeholder:@"operation" width:320 action:@selector(firstChanged:) identifier:@"field-a"]] identifier:@"row-custom"];
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
  NSSegmentedControl *filter = [NSSegmentedControl segmentedControlWithLabels:@[@"All", @"Presets", @"Custom"] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(slotFilterChanged:)];
  [filter setSelectedSegment:self.slotFilter];
  [filter setIdentifier:@"slot-filter"];
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
  [NSLayoutConstraint activateConstraints:@[[picker.widthAnchor constraintEqualToConstant:420], [top.widthAnchor constraintEqualToAnchor:picker.widthAnchor], [scroll.widthAnchor constraintEqualToAnchor:picker.widthAnchor]]];
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

- (void)slotFilterChanged:(NSSegmentedControl *)control {
  self.slotFilter = [control selectedSegment];
  [self rebuildSlotList];
}

- (void)firstChanged:(id)control {
  NSString *value = [control isKindOfClass:[NSPopUpButton class]] ? ([[(NSPopUpButton *)control selectedItem] representedObject] ?: @"") : [[control stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if ([value isEqualToString:self.draftAction.a]) return;
  self.draftAction.a = value;
  dispatch_async(dispatch_get_main_queue(), ^{ [self refresh]; });
}

- (void)secondChanged:(id)control {
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
  [self addRowWithLabel:@"Keys" content:views identifier:@"row-keys"];
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

- (void)backPressed:(id)sender {
  if (self.confirmsDiscard && !self.isNew && [self hasUnsavedChanges]) {
    NSAlert *alert = [NSAlert mwm_alert];
    [alert setMessageText:@"Discard your changes?"];
    [alert setInformativeText:@"This shortcut has changes that haven't been saved."];
    [alert addButtonWithTitle:@"Keep Editing"];
    [alert addButtonWithTitle:@"Discard"];
    if ([alert runModal] == NSAlertFirstButtonReturn) return;
  }
  [self close];
}

@end
