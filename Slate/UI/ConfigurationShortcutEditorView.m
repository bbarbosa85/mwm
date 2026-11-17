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
#import "ConfigurationBlockView.h"
#import "ConfigurationKeyViews.h"
#import "ConfigurationKeyboardMapView.h"
#import "SlateConfigDocument.h"
#import "SlateReservedShortcuts.h"
#import "SlateShortcut.h"
#import "SlateShortcutIndex.h"
#import "SlateSlots.h"

// What the shortcut can do, in the order the list shows them.
static NSArray<NSNumber *> *KindsInOrder(void) {
  return @[@(SlateActionKindFocusApp), @(SlateActionKindMove), @(SlateActionKindFocusDirection), @(SlateActionKindResize), @(SlateActionKindNudge),
           @(SlateActionKindPush), @(SlateActionKindThrow), @(SlateActionKindHint), @(SlateActionKindGrid), @(SlateActionKindSwitch),
           @(SlateActionKindRelaunch), @(SlateActionKindCustom)];
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
@property (strong) SlateAction *draftAction;
@property (strong, nullable) SlateBindingEntry *original;   // nil for a new shortcut
@property (copy) NSString *originalSignature;
@property (assign) BOOL isNew;
@property (assign) BOOL keysChanged;

@property (strong) NSView *editorPage;
@property (strong) NSTextField *titleLabel;
@property (strong) NSSearchField *kindSearch;
@property (strong) NSStackView *kindStack;
@property (strong) NSStackView *formStack;
@property (strong) NSTextField *changesLabel;
@property (strong) NSView *changesPill;
@property (strong) NSButton *saveButton;
@property (strong) NSButton *cancelButton;
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
    _draftAction = [SlateAction actionOfKind:SlateActionKindFocusApp];
    [self buildInterface];
  }
  return self;
}

- (void)dealloc { [self removeMonitor]; }

#pragma mark - Layout

- (NSTextField *)labelWithText:(NSString *)text size:(CGFloat)size color:(NSColor *)color weight:(NSFontWeight)weight {
  NSTextField *label = [NSTextField labelWithString:text];
  [label setFont:[NSFont systemFontOfSize:size weight:weight]];
  [label setTextColor:color];
  [label setLineBreakMode:NSLineBreakByTruncatingTail];
  return label;
}

- (void)buildInterface {
  NSButton *back = [NSButton buttonWithTitle:@"Keyboard" target:self action:@selector(backPressed:)];
  [back setImage:[NSImage imageWithSystemSymbolName:@"chevron.left" accessibilityDescription:@"Back"]];
  [back setImagePosition:NSImageLeft];
  [back setBordered:NO];
  [back setContentTintColor:[NSColor controlAccentColor]];
  [back setFont:[NSFont systemFontOfSize:15 weight:NSFontWeightMedium]];
  self.titleLabel = [self labelWithText:@"New Shortcut" size:17 color:[NSColor labelColor] weight:NSFontWeightMedium];
  NSView *headerSpacer = [[NSView alloc] init];
  [headerSpacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSStackView *header = [NSStackView stackViewWithViews:@[back, self.titleLabel, headerSpacer]];
  [header setSpacing:14];
  [header setAlignment:NSLayoutAttributeCenterY];
  [header setEdgeInsets:NSEdgeInsetsMake(14, 20, 4, 20)];

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

  // Save bar under a line.
  NSBox *saveLine = [[NSBox alloc] init];
  [saveLine setBoxType:NSBoxSeparator];
  self.changesLabel = [self labelWithText:@"No changes" size:11 color:[NSColor tertiaryLabelColor] weight:NSFontWeightMedium];
  [self.changesLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
  self.changesPill = [[NSView alloc] init];
  [self.changesPill setWantsLayer:YES];
  [[self.changesPill layer] setCornerRadius:10];
  [self.changesPill setTranslatesAutoresizingMaskIntoConstraints:NO];
  [self.changesPill addSubview:self.changesLabel];
  [NSLayoutConstraint activateConstraints:@[
    [self.changesLabel.leadingAnchor constraintEqualToAnchor:self.changesPill.leadingAnchor constant:10], [self.changesLabel.trailingAnchor constraintEqualToAnchor:self.changesPill.trailingAnchor constant:-10],
    [self.changesLabel.topAnchor constraintEqualToAnchor:self.changesPill.topAnchor constant:3], [self.changesLabel.bottomAnchor constraintEqualToAnchor:self.changesPill.bottomAnchor constant:-3],
  ]];
  self.cancelButton = [NSButton buttonWithTitle:@"Cancel" target:self action:@selector(cancelPressed:)];
  self.saveButton = [NSButton buttonWithTitle:@"Save" target:self action:@selector(savePressed:)];
  [self.saveButton setKeyEquivalent:@"\r"];
  for (NSButton *button in @[self.cancelButton, self.saveButton]) [button setBezelStyle:NSBezelStyleRounded];
  NSView *barSpacer = [[NSView alloc] init];
  [barSpacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSStackView *saveBar = [NSStackView stackViewWithViews:@[self.changesPill, barSpacer, self.cancelButton, self.saveButton]];
  [saveBar setSpacing:8];
  [saveBar setAlignment:NSLayoutAttributeCenterY];
  [saveBar setEdgeInsets:NSEdgeInsetsMake(10, 20, 12, 20)];

  self.editorPage = [[NSView alloc] init];
  [self.editorPage setTranslatesAutoresizingMaskIntoConstraints:NO];
  for (NSView *view in @[header, left, cardHolder, saveLine, saveBar]) {
    [view setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.editorPage addSubview:view];
  }
  for (NSView *view in @[header, saveLine, saveBar]) {
    [[view.leadingAnchor constraintEqualToAnchor:self.editorPage.leadingAnchor] setActive:YES];
    [[view.trailingAnchor constraintEqualToAnchor:self.editorPage.trailingAnchor] setActive:YES];
  }
  [NSLayoutConstraint activateConstraints:@[
    [header.topAnchor constraintEqualToAnchor:self.editorPage.topAnchor], [header.heightAnchor constraintEqualToConstant:48],
    [left.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:8], [left.leadingAnchor constraintEqualToAnchor:self.editorPage.leadingAnchor constant:20],
    [left.widthAnchor constraintEqualToConstant:210], [left.bottomAnchor constraintEqualToAnchor:saveLine.topAnchor constant:-16],
    [cardHolder.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:8], [cardHolder.leadingAnchor constraintEqualToAnchor:left.trailingAnchor constant:20],
    [cardHolder.trailingAnchor constraintEqualToAnchor:self.editorPage.trailingAnchor constant:-20], [cardHolder.bottomAnchor constraintEqualToAnchor:saveLine.topAnchor constant:-16],
    [saveLine.bottomAnchor constraintEqualToAnchor:saveBar.topAnchor],
    [saveBar.bottomAnchor constraintEqualToAnchor:self.editorPage.bottomAnchor], [saveBar.heightAnchor constraintEqualToConstant:48],
  ]];

  // Picking on the map takes the page over.
  self.picker = [[ConfigurationKeyboardMapView alloc] init];
  [self.picker setDelegate:self];
  self.picker.pickerMode = YES;
  NSTextField *pickTitle = [self labelWithText:@"Pick the keys" size:17 color:[NSColor labelColor] weight:NSFontWeightMedium];
  NSStackView *pickHeader = [NSStackView stackViewWithViews:@[pickTitle]];
  [pickHeader setEdgeInsets:NSEdgeInsetsMake(14, 20, 4, 20)];
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

- (void)setDocument:(SlateConfigDocument *)document {
  _document = document;
}

- (NSString *)signatureOfAction:(NSString *)action key:(NSString *)key modifiers:(NSString *)modifiers {
  return [NSString stringWithFormat:@"%@|%@|%@", action ?: @"", key ?: @"", modifiers ?: @""];
}

- (NSString *)draftModifiersText {
  return self.draftGroupName != nil ? [NSString stringWithFormat:@"${%@}", self.draftGroupName] : [SlateShortcut stringFromModifierNames:self.draftModifierNames];
}

- (void)editBindingAtIndex:(NSUInteger)index {
  if (index >= [self.document.bindings count]) return;
  SlateBindingEntry *binding = self.document.bindings[index];
  [self cancelRecording];
  self.original = binding;
  self.isNew = NO;
  self.draftAction = [SlateAction parse:binding.action];
  SlateShortcutInfo *info = [[SlateShortcutIndex indexForDocument:self.document] shortcutAtBindingIndex:index];
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
  self.draftAction = [SlateAction actionOfKind:SlateActionKindFocusApp];
  self.draftKeyName = keyName;
  self.draftGroupName = groupName;
  NSArray *names = @[];
  for (SlateModifierGroup *group in [[SlateShortcutIndex indexForDocument:self.document] groups]) {
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
  SlateAction *a = self.draftAction;
  if (self.draftKeyName == nil || [self.draftModifierNames count] == 0) return @"Choose the keys first.";
  if (self.keysChanged) {
    NSString *reason = [SlateReservedShortcuts reasonForKeyName:self.draftKeyName modifierNames:self.draftModifierNames];
    if (reason != nil) return reason;
  }
  if ((a.kind == SlateActionKindMove || a.kind == SlateActionKindFocusApp) && [a.a length] == 0) return a.kind == SlateActionKindMove ? @"Choose a slot." : @"Choose an application.";
  if (a.kind == SlateActionKindCustom && [a.a length] == 0) return @"Write the action.";
  return nil;
}

// The other shortcut that already uses the draft's keys, if any.
- (SlateShortcutInfo *)otherShortcutOnDraftKeys {
  if (self.draftKeyName == nil) return nil;
  NSString *identity = [SlateShortcut identityForKey:self.draftKeyName modifiers:[SlateShortcut stringFromModifierNames:self.draftModifierNames]];
  for (SlateShortcutInfo *info in [[SlateShortcutIndex indexForDocument:self.document] shortcuts]) {
    if (info.binding != self.original && [info.identity isEqualToString:identity] && info.binding.enabled) return info;
  }
  return nil;
}

- (void)selectKind:(SlateActionKind)kind {
  if (kind == self.draftAction.kind) return;
  NSString *before = [self.draftAction string];
  SlateAction *next = [SlateAction actionOfKind:kind];
  if (kind == SlateActionKindCustom) next.a = before;
  self.draftAction = next;
  [self refresh];
}

- (void)useKeyName:(NSString *)keyName modifierNames:(NSArray<NSString *> *)modifierNames groupName:(NSString *)groupName {
  self.draftKeyName = keyName;
  self.draftModifierNames = modifierNames ?: @[];
  self.draftGroupName = groupName;
  if (groupName == nil) {  // a set a group names exactly is that group
    for (SlateModifierGroup *group in [[SlateShortcutIndex indexForDocument:self.document] groups]) {
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
  [self.saveButton setEnabled:dirty && [self problem] == nil && !self.recording];
  [self.changesLabel setStringValue:dirty ? @"● Unsaved changes" : @"No changes"];
  [self.changesLabel setTextColor:dirty ? [NSColor systemOrangeColor] : [NSColor tertiaryLabelColor]];
  [[self.changesPill layer] setBackgroundColor:dirty ? [[[NSColor systemOrangeColor] colorWithAlphaComponent:0.16] CGColor] : [[NSColor clearColor] CGColor]];
}

- (void)rebuildKinds {
  for (NSView *view in [[self.kindStack arrangedSubviews] copy]) {
    [self.kindStack removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  NSString *query = [[self.kindSearch stringValue] lowercaseString];
  __weak ConfigurationShortcutEditorView *weakSelf = self;
  for (NSNumber *number in KindsInOrder()) {
    SlateActionKind kind = (SlateActionKind)[number integerValue];
    NSString *title = [SlateAction titleForKind:kind];
    if ([query length] > 0 && ![[title lowercaseString] containsString:query]) continue;
    BOOL selected = kind == self.draftAction.kind;
    NSView *row = [[NSView alloc] init];
    [row setTranslatesAutoresizingMaskIntoConstraints:NO];
    ConfigurationClickView *click = [[ConfigurationClickView alloc] init];
    click.cornerRadius = 8;
    click.selected = selected;
    click.onClick = ^{ [weakSelf selectKind:kind]; };
    NSTextField *label = [self labelWithText:title size:13 color:selected ? [NSColor controlAccentColor] : [NSColor labelColor] weight:selected ? NSFontWeightMedium : NSFontWeightRegular];
    [label setTranslatesAutoresizingMaskIntoConstraints:NO];
    [row addSubview:label];
    [row addSubview:click];
    [click setTranslatesAutoresizingMaskIntoConstraints:NO];
    [NSLayoutConstraint activateConstraints:@[
      [row.heightAnchor constraintEqualToConstant:32],
      [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:12], [label.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-8], [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
      [click.topAnchor constraintEqualToAnchor:row.topAnchor], [click.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
      [click.leadingAnchor constraintEqualToAnchor:row.leadingAnchor], [click.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
    ]];
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
    NSBox *line = [[NSBox alloc] init];
    [line setBoxType:NSBoxSeparator];
    [line setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.formStack addArrangedSubview:line];
    [[line.widthAnchor constraintEqualToAnchor:self.formStack.widthAnchor] setActive:YES];
  }
  NSTextField *name = [self labelWithText:label size:12 color:[NSColor secondaryLabelColor] weight:NSFontWeightRegular];
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
  [popup setFont:[NSFont systemFontOfSize:13]];
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
  [field setFont:[NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular]];
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
  for (SlateConfigEntry *entry in self.document.monitors) if (![[entry.value description] containsString:@"x"]) [names addObject:entry.name];
  return names;
}

- (NSArray<NSString *> *)slotNames {
  NSMutableArray *names = [NSMutableArray array];
  for (SlateSlot *preset in [SlateSlots presets]) [names addObject:preset.name];
  for (SlateConfigEntry *entry in self.document.positions) if (![names containsObject:entry.name]) [names addObject:entry.name];
  return names;
}

- (BOOL)getRect:(CGRect *)rect forSlotNamed:(NSString *)name {
  for (SlateConfigEntry *entry in self.document.positions) {
    if ([entry.name isEqualToString:name]) return [SlateSlots getRect:rect fromFormula:[entry.value description]];
  }
  SlateSlot *preset = [SlateSlots presetNamed:name];
  if (preset == nil) return NO;
  *rect = preset.rect;
  return YES;
}

- (void)rebuildForm {
  for (NSView *view in [[self.formStack arrangedSubviews] copy]) {
    [self.formStack removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  SlateAction *m = self.draftAction;
  switch (m.kind) {
    case SlateActionKindMove: {
      [self addRowWithLabel:@"Slot" content:@[[self slotPicker]] identifier:@"row-slot"];
      NSMutableArray *titles = [NSMutableArray arrayWithObject:@"Current screen"], *values = [NSMutableArray arrayWithObject:@""];
      for (NSString *name in [self screenNames]) { [titles addObject:name]; [values addObject:name]; }
      [self addRowWithLabel:@"On screen" content:@[[self popupWithTitles:titles values:values selected:m.b placeholder:nil action:@selector(secondChanged:)]] identifier:@"row-screen"];
      break;
    }
    case SlateActionKindFocusApp: {
      NSArray *apps = InstalledApplicationNames();
      [self addRowWithLabel:@"Application" content:@[[self popupWithTitles:apps values:apps selected:m.a placeholder:@"Choose an application" action:@selector(firstChanged:)]] identifier:@"row-app"];
      break;
    }
    case SlateActionKindFocusDirection:
      [self addRowWithLabel:@"Direction" content:@[[self popupWithTitles:[SlateAction directions] values:[SlateAction directions] selected:m.a placeholder:nil action:@selector(firstChanged:)]] identifier:@"row-direction"];
      break;
    case SlateActionKindThrow: {
      NSMutableArray *titles = [NSMutableArray arrayWithObjects:@"next", @"previous", nil], *values = [titles mutableCopy];
      for (NSString *name in [self screenNames]) { [titles addObject:name]; [values addObject:[NSString stringWithFormat:@"${%@}", name]]; }
      [self addRowWithLabel:@"To screen" content:@[[self popupWithTitles:titles values:values selected:m.a placeholder:nil action:@selector(firstChanged:)]] identifier:@"row-throw"];
      [self addRowWithLabel:@"Style" content:@[[self fieldWithText:m.b placeholder:@"resize" width:200 action:@selector(secondChanged:) identifier:@"field-b"]] identifier:@"row-style"];
      break;
    }
    case SlateActionKindNudge:
    case SlateActionKindResize:
      [self addRowWithLabel:@"Horizontal" content:@[[self fieldWithText:m.a placeholder:@"+10%" width:100 action:@selector(firstChanged:) identifier:@"field-a"]] identifier:@"row-x"];
      [self addRowWithLabel:@"Vertical" content:@[[self fieldWithText:m.b placeholder:@"+0" width:100 action:@selector(secondChanged:) identifier:@"field-b"]] identifier:@"row-y"];
      break;
    case SlateActionKindPush:
      [self addRowWithLabel:@"Direction" content:@[[self popupWithTitles:[SlateAction pushDirections] values:[SlateAction pushDirections] selected:m.a placeholder:nil action:@selector(firstChanged:)]] identifier:@"row-direction"];
      [self addRowWithLabel:@"Options" content:@[[self fieldWithText:m.b placeholder:@"bar-resize:screenSizeX/2" width:260 action:@selector(secondChanged:) identifier:@"field-b"]] identifier:@"row-options"];
      break;
    case SlateActionKindHint:
      [self addRowWithLabel:@"Letters" content:@[[self fieldWithText:m.a placeholder:@"ASDFJKL" width:200 action:@selector(firstChanged:) identifier:@"field-a"]] identifier:@"row-letters"];
      break;
    case SlateActionKindGrid:
      [self addRowWithLabel:@"Arguments" content:@[[self fieldWithText:m.a placeholder:@"padding:5 0:6,2" width:260 action:@selector(firstChanged:) identifier:@"field-a"]] identifier:@"row-grid"];
      break;
    case SlateActionKindCustom:
      [self addRowWithLabel:@"Action" content:@[[self fieldWithText:m.a placeholder:@"operation" width:320 action:@selector(firstChanged:) identifier:@"field-a"]] identifier:@"row-custom"];
      break;
    case SlateActionKindSwitch:
    case SlateActionKindRelaunch:
      [self addRowWithLabel:@"Settings" content:@[[self labelWithText:@"This action has no settings." size:13 color:[NSColor tertiaryLabelColor] weight:NSFontWeightRegular]] identifier:@"row-none"];
      break;
  }
  [self addKeysRow];
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
  NSScrollView *scroll = [[NSScrollView alloc] init];
  [scroll setHasVerticalScroller:YES];
  [scroll setDrawsBackground:NO];
  [scroll setBorderType:NSNoBorder];
  [scroll setTranslatesAutoresizingMaskIntoConstraints:NO];
  ConfigurationFlippedView *document = [[ConfigurationFlippedView alloc] init];
  [document setTranslatesAutoresizingMaskIntoConstraints:NO];
  [document addSubview:self.slotList];
  [scroll setDocumentView:document];
  [NSLayoutConstraint activateConstraints:@[
    [self.slotList.topAnchor constraintEqualToAnchor:document.topAnchor], [self.slotList.bottomAnchor constraintEqualToAnchor:document.bottomAnchor],
    [self.slotList.leadingAnchor constraintEqualToAnchor:document.leadingAnchor], [self.slotList.trailingAnchor constraintEqualToAnchor:document.trailingAnchor],
    [document.leadingAnchor constraintEqualToAnchor:scroll.contentView.leadingAnchor], [document.trailingAnchor constraintEqualToAnchor:scroll.contentView.trailingAnchor],
    [document.topAnchor constraintEqualToAnchor:scroll.contentView.topAnchor],
    [scroll.heightAnchor constraintEqualToConstant:208],
  ]];
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
  for (SlateConfigEntry *entry in self.document.positions) {
    CGRect rect = CGRectZero;
    BOOL readable = [SlateSlots getRect:&rect fromFormula:[entry.value description]];
    SlateSlot *preset = [SlateSlots presetNamed:entry.name];
    BOOL isPreset = preset != nil && readable && [SlateSlots rect:rect isSameAreaAs:preset.rect];
    [choices addObject:@{@"name": entry.name, @"rect": readable ? [NSValue valueWithRect:NSRectFromCGRect(rect)] : [NSNull null], @"preset": @(isPreset)}];
    [seen addObject:entry.name];
  }
  for (SlateSlot *preset in [SlateSlots presets]) {
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

    NSView *row = [[NSView alloc] init];
    [row setTranslatesAutoresizingMaskIntoConstraints:NO];
    [row setIdentifier:[@"slot-" stringByAppendingString:name]];
    ConfigurationClickView *click = [[ConfigurationClickView alloc] init];
    click.cornerRadius = 8;
    click.selected = selected;
    click.onClick = ^{ [weakSelf chooseSlotNamed:name]; };
    [click setTranslatesAutoresizingMaskIntoConstraints:NO];
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
    NSTextField *title = [self labelWithText:name size:13 color:selected ? [NSColor controlAccentColor] : [NSColor labelColor] weight:NSFontWeightMedium];
    NSString *summaryText = hasRect ? [[SlateSlot slotNamed:name rect:rect preset:isPreset] summary] : @"Set by a formula";
    NSTextField *summary = [self labelWithText:summaryText size:11 color:[NSColor secondaryLabelColor] weight:NSFontWeightRegular];
    NSStackView *texts = [NSStackView stackViewWithViews:@[title, summary]];
    [texts setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [texts setAlignment:NSLayoutAttributeLeading];
    [texts setSpacing:1];
    [texts setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSTextField *kind = [self labelWithText:isPreset ? @"Preset" : @"Custom" size:11 color:[NSColor tertiaryLabelColor] weight:NSFontWeightRegular];
    [kind setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSImageView *check = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:@"checkmark" accessibilityDescription:@"Chosen"]];
    [check setContentTintColor:[NSColor controlAccentColor]];
    [check setHidden:!selected];
    [check setTranslatesAutoresizingMaskIntoConstraints:NO];
    for (NSView *view in @[thumb, texts, kind, check, click]) [row addSubview:view];
    [NSLayoutConstraint activateConstraints:@[
      [row.heightAnchor constraintEqualToConstant:44],
      [thumb.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:8], [thumb.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
      [thumb.widthAnchor constraintEqualToConstant:48], [thumb.heightAnchor constraintEqualToConstant:30],
      [texts.leadingAnchor constraintEqualToAnchor:thumb.trailingAnchor constant:12], [texts.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
      [check.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-10], [check.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
      [kind.trailingAnchor constraintEqualToAnchor:check.leadingAnchor constant:-12], [kind.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
      [click.topAnchor constraintEqualToAnchor:row.topAnchor], [click.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
      [click.leadingAnchor constraintEqualToAnchor:row.leadingAnchor], [click.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
    ]];
    [self.slotList addArrangedSubview:row];
    [[row.widthAnchor constraintEqualToAnchor:self.slotList.widthAnchor] setActive:YES];
  }
  if (shown == 0) {
    NSTextField *none = [self labelWithText:@"No slots match." size:12 color:[NSColor tertiaryLabelColor] weight:NSFontWeightRegular];
    [self.slotList addArrangedSubview:none];
  }
}

- (void)chooseSlotNamed:(NSString *)name {
  if (self.draftAction.kind != SlateActionKindMove || [name isEqualToString:self.draftAction.a]) return;
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
  NSColor *messageColor = [NSColor secondaryLabelColor];
  if (self.recording) {
    NSMutableArray *live = [NSMutableArray array];
    if (self.recordedKey != nil || [self.recordedModifiers count] > 0) {
      if (self.recordedKey != nil) [live addObject:[ConfigurationKeyViews keyCapsForModifiers:self.recordedModifiers keyName:self.recordedKey size:26]];
      else [live addObject:[ConfigurationKeyViews modifierCaps:self.recordedModifiers size:26]];
    } else {
      [live addObject:[self labelWithText:@"Press the keys…" size:13 color:[NSColor secondaryLabelColor] weight:NSFontWeightRegular]];
    }
    [views addObjectsFromArray:live];
    message = @"Enter to use them, Esc to cancel.";
    if (self.recordedKey != nil) {
      NSString *reason = [SlateReservedShortcuts reasonForKeyName:self.recordedKey modifierNames:self.recordedModifiers];
      SlateShortcutInfo *other = [self otherShortcutOn:self.recordedKey modifiers:self.recordedModifiers];
      if (reason != nil) { message = reason; messageColor = [NSColor systemOrangeColor]; }
      else if (other != nil) { message = [NSString stringWithFormat:@"Already used by \"%@\". Enter uses the keys anyway.", other.title]; messageColor = [NSColor systemOrangeColor]; }
    }
    NSButton *cancel = [NSButton buttonWithTitle:@"Cancel" target:self action:@selector(cancelRecordingPressed:)];
    [cancel setBezelStyle:NSBezelStyleRounded];
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
      [views addObject:[self labelWithText:@"No keys yet" size:13 color:[NSColor tertiaryLabelColor] weight:NSFontWeightRegular]];
    }
    NSButton *record = [NSButton buttonWithTitle:@"Record" target:self action:@selector(recordPressed:)];
    NSButton *pick = [NSButton buttonWithTitle:@"Pick on map" target:self action:@selector(pickPressed:)];
    [record setIdentifier:@"record"];
    [pick setIdentifier:@"pick"];
    for (NSButton *button in @[record, pick]) [button setBezelStyle:NSBezelStyleRounded];
    [views addObject:record];
    [views addObject:pick];
    SlateShortcutInfo *other = [self otherShortcutOnDraftKeys];
    NSString *reason = self.keysChanged && self.draftKeyName != nil ? [SlateReservedShortcuts reasonForKeyName:self.draftKeyName modifierNames:self.draftModifierNames] : nil;
    if (reason != nil) { message = reason; messageColor = [NSColor systemOrangeColor]; }
    else if (other != nil) { message = [NSString stringWithFormat:@"Same keys as \"%@\". Only one can work.", other.title]; messageColor = [NSColor systemOrangeColor]; }
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

- (SlateShortcutInfo *)otherShortcutOn:(NSString *)keyName modifiers:(NSArray<NSString *> *)modifiers {
  NSString *identity = [SlateShortcut identityForKey:keyName modifiers:[SlateShortcut stringFromModifierNames:modifiers]];
  for (SlateShortcutInfo *info in [[SlateShortcutIndex indexForDocument:self.document] shortcuts]) {
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
        strongSelf.recordedModifiers = [SlateShortcut modifierNamesFromFlags:event.modifierFlags];
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
  NSString *name = [SlateShortcut keyNameForKeyCode:keyCode];
  if (name == nil) return;
  self.recordedKey = name;
  self.recordedModifiers = [SlateShortcut modifierNamesFromFlags:flags];
  [self refresh];
}

// Enter: takes the keys, unless macOS keeps them.
- (void)confirmRecording {
  if (!self.recording || self.recordedKey == nil) return;
  if ([SlateReservedShortcuts reasonForKeyName:self.recordedKey modifierNames:self.recordedModifiers] != nil) return;
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
    SlateBindingEntry *binding = [SlateBindingEntry bindingWithKey:self.draftKeyName modifiers:modifiers action:[self.draftAction string]];
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
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Discard your changes?"];
    [alert setInformativeText:@"This shortcut has changes that haven't been saved."];
    [alert addButtonWithTitle:@"Keep Editing"];
    [alert addButtonWithTitle:@"Discard"];
    if ([alert runModal] == NSAlertFirstButtonReturn) return;
  }
  [self close];
}

@end
