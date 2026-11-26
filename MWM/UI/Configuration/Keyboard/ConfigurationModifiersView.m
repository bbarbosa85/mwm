//
//  ConfigurationModifiersView.m
//  MWM
//
//  The Modifiers page: your modifier groups (hyper and the like) as cards, and an editor where a group is
//  built by clicking modifier keys on a drawn Mac keyboard, then named and saved.
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

#import "ConfigurationModifiersView.h"
#import "MWMAlert.h"
#import "MWMTheme.h"
#import "MWMComponents.h"
#import "ConfigurationBlockView.h"
#import "ConfigurationKeyViews.h"
#import "ConfigurationMacKeyboard.h"
#import "MWMConfigDocument.h"
#import "MWMShortcut.h"
#import "MWMShortcutIndex.h"
#import "MWMReservedShortcuts.h"

@interface ConfigurationModifiersView () <NSTextFieldDelegate>
@property (strong) NSStackView *listStack;
@property (strong) NSView *listPage;
@property (strong) NSView *editorPage;
@property (strong) MWMSublevelHeader *header;
@property (strong) NSTextField *nameField;
@property (strong) NSTextField *previewName;
@property (strong) NSView *previewCaps;
@property (strong) NSStackView *previewRow;
@property (strong) NSTextField *messageLabel;
@property (strong) ConfigurationMacKeyboard *keyboard;
@property (strong) MWMSaveBar *saveBar;
@property (assign) BOOL isNew;
@property (assign) BOOL lastEditing;
@property (copy, nullable) NSString *originalName;
@property (copy) NSArray<NSString *> *originalModifiers;
@property (readwrite) BOOL editing;
@end

@implementation ConfigurationModifiersView

@synthesize draftName = _draftName, draftModifiers = _draftModifiers;

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _showsAlerts = YES;
    _draftModifiers = @[];
    _originalModifiers = @[];
    [self buildListPage];
    [self buildEditorPage];
    [self addSubview:self.listPage];
    [self addSubview:self.editorPage];
    for (NSView *page in @[self.listPage, self.editorPage]) [MWMComponents pinView:page toEdgesOf:self insets:NSEdgeInsetsMake(0, 0, 0, 0)];
    [self.editorPage setHidden:YES];
  }
  return self;
}

#pragma mark - The model

- (NSArray<NSString *> *)orderedModifiers:(NSArray<NSString *> *)names {
  NSArray *parsed = [MWMShortcut modifierNamesFromString:[names componentsJoinedByString:@";"]];
  return parsed ?: @[];
}

- (MWMConfigEntry *)entryNamed:(NSString *)name {
  for (MWMConfigEntry *entry in self.document.modifiers) if ([entry.name isEqualToString:name]) return entry;
  return nil;
}

- (NSArray<NSString *> *)modifiersOf:(MWMConfigEntry *)entry {
  return [self orderedModifiers:[MWMShortcut modifierNamesFromString:[entry.value description]] ?: @[]];
}

- (NSSet<NSString *> *)allNamesExcept:(NSString *)own {
  NSMutableSet *names = [NSMutableSet set];
  for (NSArray *section in @[self.document.modifiers, self.document.monitors, self.document.positions, self.document.aliases]) {
    for (MWMConfigEntry *entry in section) [names addObject:entry.name];
  }
  if (own != nil) [names removeObject:own];
  return names;
}

// How many shortcuts (and aliases) write the group as ${name}.
- (NSUInteger)usesOfGroupNamed:(NSString *)name {
  NSString *reference = [NSString stringWithFormat:@"${%@}", name];
  NSUInteger uses = 0;
  for (MWMBindingEntry *binding in self.document.bindings) if ([binding.modifiers containsString:reference] || [binding.action containsString:reference]) uses++;
  for (MWMConfigEntry *entry in self.document.aliases) if ([[entry.value description] containsString:reference]) uses++;
  return uses;
}

- (void)setDocument:(MWMConfigDocument *)document {
  _document = document;
  [self closeEditor];
  [self reload];
}

#pragma mark - The list

- (NSButton *)smallButton:(NSString *)title symbol:(NSString *)symbol action:(SEL)action name:(NSString *)name {
  NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
  if (symbol) [button setImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:title]];
  [button setImagePosition:symbol ? NSImageLeading : NSNoImage];
  [button setIdentifier:name];
  return button;
}

- (void)buildListPage {
  self.listStack = [NSStackView stackViewWithViews:@[]];
  [self.listStack setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [self.listStack setAlignment:NSLayoutAttributeLeading];
  [self.listStack setSpacing:10];
  [self.listStack setEdgeInsets:NSEdgeInsetsMake(8, 20, 20, 20)];
  [self.listStack setTranslatesAutoresizingMaskIntoConstraints:NO];
  NSScrollView *scroll = [MWMComponents scrollViewWithContent:self.listStack];
  self.listPage = [[NSView alloc] init];
  [self.listPage addSubview:scroll];
  [MWMComponents pinView:scroll toEdgesOf:self.listPage insets:NSEdgeInsetsMake(0, 0, 0, 0)];
}

// Every card has the same columns: name, keys, then (pushed to the right) where it is used, Edit and Remove.
static const CGFloat kNameColumn = 150;
static const CGFloat kKeysColumn = 300;
static const CGFloat kUsedColumn = 150;

- (NSView *)cardForEntry:(MWMConfigEntry *)entry {
  NSArray *modifiers = [self modifiersOf:entry];
  NSUInteger uses = [self usesOfGroupNamed:entry.name];
  NSTextField *name = [MWMComponents labelWithText:entry.name size:15 color:[MWMTheme textPrimary] weight:NSFontWeightSemibold];
  NSView *caps = [ConfigurationKeyViews modifierCaps:modifiers size:26];
  NSString *usage = uses == 0 ? @"Not used yet" : [NSString stringWithFormat:@"Used in %lu shortcut%@", (unsigned long)uses, uses == 1 ? @"" : @"s"];
  NSTextField *used = [MWMComponents labelWithText:usage size:13 color:[MWMTheme textSecondary] weight:NSFontWeightRegular];
  [used setAlignment:NSTextAlignmentRight];
  NSView *grow = [[NSView alloc] init];
  [grow setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSButton *edit = [self smallButton:@"Edit" symbol:nil action:@selector(editPressed:) name:entry.name];
  NSButton *remove = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"trash" accessibilityDescription:@"Remove"] target:self action:@selector(removePressed:)];
  [remove setBordered:NO];
  [remove setIdentifier:entry.name];
  [remove setToolTip:uses > 0 ? @"A shortcut uses this group" : @"Remove this group"];

  // The caps sit at the start of a fixed-width column, so the next column starts in the same place on every card.
  NSView *keysColumn = [[NSView alloc] init];
  [keysColumn setTranslatesAutoresizingMaskIntoConstraints:NO];
  [caps setTranslatesAutoresizingMaskIntoConstraints:NO];
  [keysColumn addSubview:caps];
  [NSLayoutConstraint activateConstraints:@[
    [keysColumn.widthAnchor constraintEqualToConstant:kKeysColumn],
    [caps.leadingAnchor constraintEqualToAnchor:keysColumn.leadingAnchor],
    [caps.centerYAnchor constraintEqualToAnchor:keysColumn.centerYAnchor],
    [keysColumn.heightAnchor constraintEqualToAnchor:caps.heightAnchor],
  ]];
  [[name.widthAnchor constraintEqualToConstant:kNameColumn] setActive:YES];
  [[used.widthAnchor constraintEqualToConstant:kUsedColumn] setActive:YES];

  NSStackView *row = [NSStackView stackViewWithViews:@[name, keysColumn, grow, used, edit, remove]];
  [row setSpacing:14];
  [row setAlignment:NSLayoutAttributeCenterY];
  [row setEdgeInsets:NSEdgeInsetsMake(14, 18, 14, 14)];
  [row setTranslatesAutoresizingMaskIntoConstraints:NO];
  ConfigurationBlockView *card = [[ConfigurationBlockView alloc] init];
  [card setTranslatesAutoresizingMaskIntoConstraints:NO];
  [card addSubview:row];
  [MWMComponents pinView:row toEdgesOf:card insets:NSEdgeInsetsMake(0, 0, 0, 0)];
  [card setIdentifier:[@"group-" stringByAppendingString:entry.name]];
  return card;
}

- (void)reload {
  for (NSView *view in [[self.listStack arrangedSubviews] copy]) {
    [self.listStack removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  if (self.document == nil) return;
  NSButton *add = [NSButton buttonWithTitle:@"New Group" target:self action:@selector(newPressed:)];
  [add setImage:[NSImage imageWithSystemSymbolName:@"plus" accessibilityDescription:@"New group"]];
  [add setImagePosition:NSImageLeading];
  [add setBezelColor:[MWMTheme accent]];
  [add setIdentifier:@"new-group"];
  NSTextField *intro = [MWMComponents wrappingLabelWithText:@"A group names a set of modifier keys, like hyper. Pick it by name when you add a shortcut, instead of pressing every key." size:13 color:[MWMTheme textSecondary] weight:NSFontWeightRegular];
  NSView *grow = [[NSView alloc] init];
  [grow setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSStackView *top = [NSStackView stackViewWithViews:@[intro, grow, add]];
  [top setSpacing:16];
  [top setAlignment:NSLayoutAttributeCenterY];
  [self.listStack addArrangedSubview:top];
  [[top.widthAnchor constraintEqualToAnchor:self.listStack.widthAnchor constant:-40] setActive:YES];
  if ([self.document.modifiers count] == 0) {
    NSTextField *none = [MWMComponents wrappingLabelWithText:@"No groups yet. Press New Group to build your first one on the keyboard." size:13 color:[MWMTheme textTertiary] weight:NSFontWeightRegular];
    [self.listStack addArrangedSubview:none];
  }
  for (MWMConfigEntry *entry in self.document.modifiers) {
    NSView *card = [self cardForEntry:entry];
    [self.listStack addArrangedSubview:card];
    [[card.widthAnchor constraintEqualToAnchor:self.listStack.widthAnchor constant:-40] setActive:YES];
  }
}

- (void)newPressed:(id)sender { [self startNewGroup]; }
- (void)editPressed:(NSButton *)sender { [self editGroupNamed:sender.identifier]; }
- (void)removePressed:(NSButton *)sender { [self removeGroupNamed:sender.identifier]; }

- (void)removeGroupNamed:(NSString *)name {
  MWMConfigEntry *entry = [self entryNamed:name];
  if (entry == nil) return;
  NSUInteger uses = [self usesOfGroupNamed:name];
  if (uses > 0) {
    if (!self.showsAlerts) return;
    MWMAlert *alert = [MWMAlert alert];
    [alert setMessageText:[NSString stringWithFormat:@"\"%@\" is in use", name]];
    [alert setInformativeText:[NSString stringWithFormat:@"%lu shortcut%@ use%@ it. Change %@ first, then remove the group.", (unsigned long)uses, uses == 1 ? @"" : @"s", uses == 1 ? @"s" : @"", uses == 1 ? @"it" : @"them"]];
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
    return;
  }
  [self.document.modifiers removeObjectIdenticalTo:entry];
  [self.delegate modifiersViewDidChangeDocument:self];
  [self reload];
}

#pragma mark - The editor

- (void)buildEditorPage {
  self.header = [MWMSublevelHeader headerWithBackTitle:@"Modifiers" title:@"New Group" target:self action:@selector(backPressed:)];

  MWMNameField *nameField = [MWMNameField nameFieldWithPlaceholder:@"Name this group, like hyper" identifier:@"group-name" compact:NO];
  self.nameField = nameField;
  [self.nameField setDelegate:self];
  NSStackView *nameBlock = [MWMComponents nameBlockWithField:nameField width:360];

  self.previewName = [MWMComponents labelWithText:@"" size:14 color:[MWMTheme textPrimary] weight:NSFontWeightSemibold];
  self.previewCaps = [[NSView alloc] init];
  self.previewRow = [NSStackView stackViewWithViews:@[self.previewName]];
  [self.previewRow setSpacing:10];
  [self.previewRow setAlignment:NSLayoutAttributeCenterY];
  self.messageLabel = [NSTextField wrappingLabelWithString:@""];
  [self.messageLabel setFont:[MWMTheme fontCaption]];

  NSTextField *hint = [MWMComponents wrappingLabelWithText:@"Click the modifier keys you want in the group: ctrl, opt, shift and ⌘ on the left of the keyboard." size:12 color:[MWMTheme textTertiary] weight:NSFontWeightRegular];

  self.keyboard = [[ConfigurationMacKeyboard alloc] init];
  self.keyboard.unitsWide = kMacKeyboardCompactUnitsWide;   // no number pad: it can't hold a modifier
  [self.keyboard setTranslatesAutoresizingMaskIntoConstraints:NO];
  ConfigurationBlockView *keyboardCard = [[ConfigurationBlockView alloc] init];
  [keyboardCard setTranslatesAutoresizingMaskIntoConstraints:NO];
  [keyboardCard addSubview:self.keyboard];
  NSLayoutConstraint *fill = [self.keyboard.widthAnchor constraintEqualToAnchor:keyboardCard.widthAnchor constant:-32];
  fill.priority = 750;
  [NSLayoutConstraint activateConstraints:@[
    fill,
    [self.keyboard.widthAnchor constraintLessThanOrEqualToConstant:kMacKeyboardCompactUnitsWide * 40],
    [self.keyboard.widthAnchor constraintGreaterThanOrEqualToConstant:kMacKeyboardCompactUnitsWide * 20],
    [self.keyboard.heightAnchor constraintEqualToAnchor:self.keyboard.widthAnchor multiplier:kMacKeyboardUnitsTall / kMacKeyboardCompactUnitsWide],
    [self.keyboard.topAnchor constraintEqualToAnchor:keyboardCard.topAnchor constant:16],
    [self.keyboard.bottomAnchor constraintEqualToAnchor:keyboardCard.bottomAnchor constant:-16],
    [self.keyboard.centerXAnchor constraintEqualToAnchor:keyboardCard.centerXAnchor],
  ]];
  NSArray *keys = [ConfigurationMacKeyboard buildCompactKeys];
  for (ConfigurationMapKey *key in keys) [self.keyboard addSubview:key];
  self.keyboard.keys = keys;
  __weak ConfigurationModifiersView *weakSelf = self;
  [self.keyboard showModifierPickerWithSelected:@[] dimOthers:YES toggle:^(NSString *name) { [weakSelf toggleModifier:name]; }];

  NSView *grow = [[NSView alloc] init];
  [grow setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationVertical];
  NSStackView *content = [NSStackView stackViewWithViews:@[nameBlock, hint, keyboardCard, self.previewRow, self.messageLabel, grow]];
  [content setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [content setAlignment:NSLayoutAttributeLeading];
  [content setSpacing:12];
  [content setEdgeInsets:NSEdgeInsetsMake(8, 20, 16, 20)];
  [content setTranslatesAutoresizingMaskIntoConstraints:NO];
  for (NSView *view in @[hint, keyboardCard, self.messageLabel]) [[view.widthAnchor constraintEqualToAnchor:content.widthAnchor constant:-40] setActive:YES];

  self.saveBar = [MWMSaveBar barWithTarget:self cancel:@selector(cancelPressed:) save:@selector(savePressed:)];

  self.editorPage = [[NSView alloc] init];
  for (NSView *view in @[self.header, content, self.saveBar]) {
    [view setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.editorPage addSubview:view];
    [[view.leadingAnchor constraintEqualToAnchor:self.editorPage.leadingAnchor] setActive:YES];
    [[view.trailingAnchor constraintEqualToAnchor:self.editorPage.trailingAnchor] setActive:YES];
  }
  [NSLayoutConstraint activateConstraints:@[
    [self.header.topAnchor constraintEqualToAnchor:self.editorPage.topAnchor],
    [content.topAnchor constraintEqualToAnchor:self.header.bottomAnchor],
    [content.bottomAnchor constraintEqualToAnchor:self.saveBar.topAnchor],
    [self.saveBar.bottomAnchor constraintEqualToAnchor:self.editorPage.bottomAnchor],
  ]];
}

- (void)startNewGroup {
  if (self.document == nil) return;
  self.isNew = YES;
  self.originalName = nil;
  self.originalModifiers = @[];
  self.draftName = @"";
  self.draftModifiers = @[];
  [self openEditor];
}

- (void)editGroupNamed:(NSString *)name {
  MWMConfigEntry *entry = [self entryNamed:name];
  if (entry == nil) return;
  self.isNew = NO;
  self.originalName = name;
  self.originalModifiers = [self modifiersOf:entry];
  self.draftName = name;
  self.draftModifiers = self.originalModifiers;
  [self openEditor];
}

- (void)openEditor {
  self.editing = YES;
  [self.nameField setStringValue:self.draftName ?: @""];
  [self refresh];
}

- (void)closeEditor {
  self.editing = NO;
  self.isNew = NO;
  self.originalName = nil;
  self.draftName = nil;
  self.draftModifiers = @[];
  [self refresh];
}

- (NSString *)draftName { return _draftName; }
- (void)setDraftName:(NSString *)name { _draftName = [name copy]; if (self.editing) [self refresh]; }
- (NSArray<NSString *> *)draftModifiers { return _draftModifiers; }
- (void)setDraftModifiers:(NSArray<NSString *> *)names { _draftModifiers = [self orderedModifiers:names]; if (self.editing) [self refresh]; }

- (void)toggleModifier:(NSString *)name {
  NSMutableArray *names = [self.draftModifiers mutableCopy];
  if ([names containsObject:name]) [names removeObject:name]; else [names addObject:name];
  self.draftModifiers = names;
}

- (NSString *)trimmedName {
  return [(self.draftName ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (BOOL)hasUnsavedChanges {
  if (!self.editing) return NO;
  if (self.isNew) return YES;
  return ![[self trimmedName] isEqualToString:self.originalName ?: @""] || ![self.draftModifiers isEqualToArray:self.originalModifiers];
}

- (NSString *)problem {
  if (![self hasUnsavedChanges]) return nil;
  NSString *name = [self trimmedName];
  if ([name length] == 0) return @"Give the group a name.";
  if ([name rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"${}:;,#'\"\\ \t"]].location != NSNotFound) return @"Use letters, numbers and dashes in the name.";
  if ([[self allNamesExcept:self.originalName] containsObject:name]) return [NSString stringWithFormat:@"The name \"%@\" is already used.", name];
  if ([self.draftModifiers count] == 0) return @"Click at least one modifier key.";
  NSString *mine = [MWMShortcut stringFromModifierNames:self.draftModifiers];
  for (MWMConfigEntry *entry in self.document.modifiers) {
    if ([entry.name isEqualToString:self.originalName ?: @""]) continue;
    if ([[MWMShortcut stringFromModifierNames:[self modifiersOf:entry]] isEqualToString:mine]) return [NSString stringWithFormat:@"Same keys as \"%@\".", entry.name];
  }
  return nil;
}

static NSString *Combo(MWMShortcutInfo *info) {
  NSMutableString *combo = [NSMutableString string];
  for (NSString *name in info.modifierNames) [combo appendString:[MWMShortcut symbolForModifierName:name]];
  [combo appendString:@" "];
  [combo appendString:[MWMShortcut displayForKeyName:info.keyName]];
  return combo;
}

// Shortcuts that would end up on the same keys as another one, or on keys macOS keeps, if this group's keys became
// the draft: the document with the change applied, compared with the document as it is.
- (NSArray<NSString *> *)warnings {
  if (!self.editing || self.isNew || ![self hasUnsavedChanges] || [self.draftModifiers count] == 0) return @[];
  MWMConfigDocument *changed = [MWMConfigDocument documentFromString:[self.document stringRepresentation] lenient:YES error:nil];
  for (MWMConfigEntry *entry in changed.modifiers) {
    if ([entry.name isEqualToString:self.originalName]) entry.value = [MWMShortcut stringFromModifierNames:self.draftModifiers];
  }
  MWMShortcutIndex *before = [MWMShortcutIndex indexForDocument:self.document], *after = [MWMShortcutIndex indexForDocument:changed];
  NSMutableSet *wasConflict = [NSMutableSet set], *wasReserved = [NSMutableSet set];
  for (MWMShortcutInfo *info in before.shortcuts) {
    if (info.conflict) [wasConflict addObject:@(info.index)];
    if ([MWMReservedShortcuts reasonForKeyName:info.keyName modifierNames:info.modifierNames] != nil) [wasReserved addObject:@(info.index)];
  }
  NSMutableArray *lines = [NSMutableArray array];
  NSMutableDictionary<NSString *, NSMutableArray *> *clashes = [NSMutableDictionary dictionary];
  NSMutableArray *order = [NSMutableArray array];
  for (MWMShortcutInfo *info in after.shortcuts) {
    NSString *reason = [MWMReservedShortcuts reasonForKeyName:info.keyName modifierNames:info.modifierNames];
    if (reason != nil && ![wasReserved containsObject:@(info.index)]) {
      reason = [reason stringByReplacingOccurrencesOfString:@" Pick another combo." withString:@""];
      [lines addObject:[NSString stringWithFormat:@"“%@” would be on %@, which macOS keeps.", info.title, Combo(info)]];
    }
    if (info.conflict && ![wasConflict containsObject:@(info.index)]) {
      NSString *key = Combo(info);
      if (clashes[key] == nil) { clashes[key] = [NSMutableArray array]; [order addObject:key]; }
      [clashes[key] addObject:[NSString stringWithFormat:@"“%@”", info.title]];
    }
  }
  for (NSString *key in order) {
    [lines insertObject:[NSString stringWithFormat:@"%@ would fire for %@. Only one can work.", key, [clashes[key] componentsJoinedByString:@" and "]] atIndex:0];
  }
  if ([lines count] > 4) lines = [[[lines subarrayWithRange:NSMakeRange(0, 4)] arrayByAddingObject:[NSString stringWithFormat:@"…and %lu more.", (unsigned long)([lines count] - 4)]] mutableCopy];
  return lines;
}

- (void)save {
  if (![self hasUnsavedChanges] || [self problem] != nil) return;
  NSString *name = [self trimmedName];
  NSString *value = [MWMShortcut stringFromModifierNames:self.draftModifiers];
  if (self.isNew) {
    [self.document.modifiers addObject:[MWMConfigEntry entryWithName:name value:value]];
  } else {
    MWMConfigEntry *entry = [self entryNamed:self.originalName];
    if (entry == nil) return;
    if (![name isEqualToString:self.originalName]) [self.document renameReferencesFrom:self.originalName to:name];
    entry.name = name;
    entry.value = value;
  }
  [self.delegate modifiersViewDidChangeDocument:self];
  [self closeEditor];
  [self reload];
}

- (void)revert {
  self.draftName = self.originalName ?: @"";
  self.draftModifiers = self.originalModifiers;
  [self.nameField setStringValue:self.draftName ?: @""];
}

- (void)backPressed:(id)sender {
  if ([self hasUnsavedChanges] && self.showsAlerts) {
    MWMAlert *alert = [MWMAlert alert];
    [alert setKind:MWMAlertKindConfirm];
    [alert setMessageText:@"Discard your changes?"];
    [alert setInformativeText:@"This group has changes that haven't been saved."];
    [alert addButtonWithTitle:@"Keep editing"];
    [alert addDestructiveButtonWithTitle:@"Discard"];
    if ([alert runModal] == NSAlertFirstButtonReturn) return;
  }
  [self closeEditor];
}
// Cancel throws away the changes and goes back to the list.
- (void)cancelPressed:(id)sender { [self closeEditor]; }
- (void)savePressed:(id)sender { [self save]; }

- (void)controlTextDidChange:(NSNotification *)notification {
  if (notification.object == self.nameField) self.draftName = [self.nameField stringValue];
}

// Redraws the editor (or the list) from the draft.
- (void)refresh {
  [self.listPage setHidden:self.editing];
  [self.editorPage setHidden:!self.editing];
  if (self.editing != self.lastEditing) {
    self.lastEditing = self.editing;
    if ([self.delegate respondsToSelector:@selector(modifiersView:didChangeEditing:)]) [self.delegate modifiersView:self didChangeEditing:self.editing];
  }
  if (!self.editing) return;
  [self.header.titleLabel setStringValue:self.isNew ? @"New Group" : @"Editing Group"];
  [self.keyboard setSelectedModifiers:self.draftModifiers];
  for (NSView *view in [[self.previewRow arrangedSubviews] copy]) { [self.previewRow removeArrangedSubview:view]; [view removeFromSuperview]; }
  NSString *name = [self trimmedName];
  [self.previewName setStringValue:[name length] > 0 ? [name stringByAppendingString:@" ="] : @"This group ="];
  [self.previewRow addArrangedSubview:self.previewName];
  if ([self.draftModifiers count] > 0) [self.previewRow addArrangedSubview:[ConfigurationKeyViews modifierCaps:self.draftModifiers size:24]];
  else [self.previewRow addArrangedSubview:[MWMComponents labelWithText:@"no keys yet" size:13 color:[MWMTheme textTertiary] weight:NSFontWeightRegular]];
  NSString *problem = [self problem];
  NSArray *warnings = problem == nil ? [self warnings] : @[];
  [self.messageLabel setStringValue:problem ?: ([warnings count] > 0 ? [@"⚠︎ " stringByAppendingString:[warnings componentsJoinedByString:@"\n⚠︎ "]] : @"")];
  [self.messageLabel setTextColor:[MWMTheme warning]];
  [self.saveBar setDirty:[self hasUnsavedChanges] canSave:problem == nil];
  if ([self.nameField currentEditor] == nil && ![[self.nameField stringValue] isEqualToString:self.draftName ?: @""]) [self.nameField setStringValue:self.draftName ?: @""];
}

@end
