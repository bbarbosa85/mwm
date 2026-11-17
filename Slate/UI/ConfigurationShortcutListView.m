//
//  ConfigurationShortcutListView.m
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

#import "ConfigurationShortcutListView.h"
#import "MWMTheme.h"
#import "ConfigurationBlockView.h"
#import "ConfigurationKeyViews.h"
#import "SlateConfigDocument.h"
#import "SlateShortcutIndex.h"

static const CGFloat kFilterWidth = 220;
static const CGFloat kKeysColumnWidth = 210;

@interface ConfigurationShortcutListView () <NSSearchFieldDelegate>
@property (strong) SlateShortcutIndex *index;
@property (strong) NSStackView *filterStack;
@property (strong) NSStackView *rowsStack;
@property (strong) NSTextField *countLabel;
@property (strong) NSSearchField *search;
@end

@implementation ConfigurationShortcutListView

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _query = @"";
    [self buildInterface];
  }
  return self;
}

#pragma mark - Interface

- (NSScrollView *)scrollViewWithStack:(NSStackView *)stack {
  NSView *document = [[ConfigurationFlippedView alloc] init];
  [document setTranslatesAutoresizingMaskIntoConstraints:NO];
  [stack setTranslatesAutoresizingMaskIntoConstraints:NO];
  [document addSubview:stack];
  NSScrollView *scroll = [[NSScrollView alloc] init];
  [scroll setTranslatesAutoresizingMaskIntoConstraints:NO];
  [scroll setHasVerticalScroller:YES];
  [scroll setAutohidesScrollers:YES];
  [scroll setDrawsBackground:NO];
  NSClipView *clip = [[NSClipView alloc] init];
  [clip setDrawsBackground:NO];
  [scroll setContentView:clip];
  [scroll setDocumentView:document];
  [NSLayoutConstraint activateConstraints:@[
    [stack.topAnchor constraintEqualToAnchor:document.topAnchor], [stack.bottomAnchor constraintEqualToAnchor:document.bottomAnchor],
    [stack.leadingAnchor constraintEqualToAnchor:document.leadingAnchor], [stack.trailingAnchor constraintEqualToAnchor:document.trailingAnchor],
    [document.topAnchor constraintEqualToAnchor:clip.topAnchor], [document.leadingAnchor constraintEqualToAnchor:clip.leadingAnchor],
    [document.trailingAnchor constraintEqualToAnchor:clip.trailingAnchor],
  ]];
  return scroll;
}

- (void)buildInterface {
  self.search = [[NSSearchField alloc] init];
  [self.search setPlaceholderString:@"Search"];
  [self.search setDelegate:self];
  [self.search setTranslatesAutoresizingMaskIntoConstraints:NO];

  self.filterStack = [NSStackView stackViewWithViews:@[]];
  [self.filterStack setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [self.filterStack setAlignment:NSLayoutAttributeLeading];
  [self.filterStack setSpacing:2];
  NSScrollView *filterScroll = [self scrollViewWithStack:self.filterStack];

  NSStackView *left = [NSStackView stackViewWithViews:@[self.search, filterScroll]];
  [left setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [left setAlignment:NSLayoutAttributeLeading];
  [left setSpacing:8];
  [left setEdgeInsets:NSEdgeInsetsMake(10, 14, 12, 8)];
  [left setTranslatesAutoresizingMaskIntoConstraints:NO];
  for (NSView *view in @[self.search, filterScroll]) [[view.widthAnchor constraintEqualToAnchor:left.widthAnchor constant:-22] setActive:YES];
  [[self.filterStack.widthAnchor constraintEqualToAnchor:filterScroll.widthAnchor] setActive:YES];

  self.countLabel = [NSTextField labelWithString:@""];
  [self.countLabel setFont:[MWMTheme fontSmall]];
  [self.countLabel setTextColor:[MWMTheme textSecondary]];
  NSButton *add = [NSButton buttonWithTitle:@"New Shortcut" target:self action:@selector(newPressed:)];
  [add setImage:[NSImage imageWithSystemSymbolName:@"plus" accessibilityDescription:nil]];
  [add setImagePosition:NSImageLeft];
  [add setBezelStyle:NSBezelStyleRounded];
  NSView *spacer = [[NSView alloc] init];
  [spacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSStackView *top = [NSStackView stackViewWithViews:@[self.countLabel, spacer, add]];
  [top setAlignment:NSLayoutAttributeCenterY];

  self.rowsStack = [NSStackView stackViewWithViews:@[]];
  [self.rowsStack setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [self.rowsStack setAlignment:NSLayoutAttributeLeading];
  [self.rowsStack setSpacing:0];
  NSScrollView *rowsScroll = [self scrollViewWithStack:self.rowsStack];

  NSStackView *right = [NSStackView stackViewWithViews:@[top, rowsScroll]];
  [right setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [right setAlignment:NSLayoutAttributeLeading];
  [right setSpacing:6];
  [right setEdgeInsets:NSEdgeInsetsMake(10, 16, 12, 20)];
  [right setTranslatesAutoresizingMaskIntoConstraints:NO];
  for (NSView *view in @[top, rowsScroll]) [[view.widthAnchor constraintEqualToAnchor:right.widthAnchor constant:-36] setActive:YES];
  [[self.rowsStack.widthAnchor constraintEqualToAnchor:rowsScroll.widthAnchor] setActive:YES];

  NSBox *line = [[NSBox alloc] init];
  [line setBoxType:NSBoxSeparator];
  [line setTranslatesAutoresizingMaskIntoConstraints:NO];
  [self addSubview:left];
  [self addSubview:line];
  [self addSubview:right];
  [NSLayoutConstraint activateConstraints:@[
    [left.topAnchor constraintEqualToAnchor:self.topAnchor], [left.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    [left.leadingAnchor constraintEqualToAnchor:self.leadingAnchor], [left.widthAnchor constraintEqualToConstant:kFilterWidth],
    [line.topAnchor constraintEqualToAnchor:self.topAnchor], [line.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    [line.leadingAnchor constraintEqualToAnchor:left.trailingAnchor],
    [right.topAnchor constraintEqualToAnchor:self.topAnchor], [right.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    [right.leadingAnchor constraintEqualToAnchor:line.trailingAnchor], [right.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
  ]];
}

#pragma mark - Filters

- (void)setDocument:(SlateConfigDocument *)document {
  _document = document;
  [self reload];
}

- (void)setGroupFilter:(NSString *)group { _groupFilter = [group copy]; [self reload]; }
- (void)setKindFilter:(NSNumber *)kind { _kindFilter = kind; [self reload]; }
- (void)setConflictsOnly:(BOOL)only { _conflictsOnly = only; [self reload]; }
- (void)setQuery:(NSString *)query { _query = [query copy] ?: @""; [self.search setStringValue:_query]; [self reload]; }

- (void)controlTextDidChange:(NSNotification *)notification {
  _query = [[self.search stringValue] copy];
  [self rebuildRows];
}

- (BOOL)infoMatches:(SlateShortcutInfo *)info {
  if (self.kindFilter != nil && info.kind != (SlateShortcutKind)[self.kindFilter integerValue]) return NO;
  if (self.conflictsOnly && !info.conflict) return NO;
  if (self.groupFilter != nil) {
    BOOL custom = [self.groupFilter isEqualToString:@"Custom"] && info.groupName == nil && [info.modifierNames count] > 0;
    if (!custom && ![info.groupName isEqualToString:self.groupFilter]) return NO;
  }
  NSString *query = [[self.query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] lowercaseString];
  if ([query length] > 0) {
    NSString *haystack = [[@[info.title ?: @"", info.detail ?: @"", info.keyName ?: @"", info.groupName ?: @"", info.binding.note ?: @""] componentsJoinedByString:@" "] lowercaseString];
    if (![haystack containsString:query]) return NO;
  }
  return YES;
}

#pragma mark - Building

- (NSTextField *)labelWithText:(NSString *)text size:(CGFloat)size color:(NSColor *)color weight:(NSFontWeight)weight {
  NSTextField *label = [NSTextField labelWithString:text];
  [label setFont:[NSFont systemFontOfSize:size weight:weight]];
  [label setTextColor:color];
  [label setLineBreakMode:NSLineBreakByTruncatingTail];
  return label;
}

- (NSTextField *)heading:(NSString *)text {
  NSTextField *label = [self labelWithText:text size:11 color:[MWMTheme textTertiary] weight:NSFontWeightSemibold];
  return label;
}

// A filter row: a name and a count, optionally with modifier caps under it.
- (ConfigurationClickView *)filterRowTitle:(NSString *)title count:(NSUInteger)count caps:(nullable NSArray<NSString *> *)caps selected:(BOOL)selected action:(void (^)(void))action {
  ConfigurationClickView *row = [[ConfigurationClickView alloc] init];
  [row setTranslatesAutoresizingMaskIntoConstraints:NO];
  row.selected = selected;
  row.onClick = action;
  NSTextField *name = [self labelWithText:title size:13 color:selected ? [MWMTheme accent] : [MWMTheme textPrimary] weight:selected ? NSFontWeightMedium : NSFontWeightRegular];
  NSTextField *number = [self labelWithText:[NSString stringWithFormat:@"%lu", (unsigned long)count] size:11 color:[MWMTheme textSecondary] weight:NSFontWeightRegular];
  NSView *gap = [[NSView alloc] init];
  [gap setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSStackView *top = [NSStackView stackViewWithViews:@[name, gap, number]];
  [top setAlignment:NSLayoutAttributeFirstBaseline];
  NSMutableArray *views = [NSMutableArray arrayWithObject:top];
  if ([caps count] > 0) [views addObject:[ConfigurationKeyViews modifierCaps:caps size:18]];
  NSStackView *stack = [NSStackView stackViewWithViews:views];
  [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [stack setAlignment:NSLayoutAttributeLeading];
  [stack setSpacing:4];
  [stack setEdgeInsets:NSEdgeInsetsMake(6, 8, 6, 8)];
  [stack setTranslatesAutoresizingMaskIntoConstraints:NO];
  [[top.widthAnchor constraintEqualToAnchor:stack.widthAnchor constant:-16] setActive:YES];
  [row addSubview:stack];
  [NSLayoutConstraint activateConstraints:@[
    [stack.topAnchor constraintEqualToAnchor:row.topAnchor], [stack.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
    [stack.leadingAnchor constraintEqualToAnchor:row.leadingAnchor], [stack.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
  ]];
  return row;
}

- (void)addFilterRow:(NSView *)row {
  [self.filterStack addArrangedSubview:row];
  [[row.widthAnchor constraintEqualToAnchor:self.filterStack.widthAnchor] setActive:YES];
}

- (void)reload {
  if (self.document == nil) return;
  self.index = [SlateShortcutIndex indexForDocument:self.document];
  [self rebuildFilters];
  [self rebuildRows];
}

- (void)rebuildFilters {
  for (NSView *view in [[self.filterStack arrangedSubviews] copy]) {
    [self.filterStack removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  __weak ConfigurationShortcutListView *weakSelf = self;
  NSTextField *kindsHeading = [self heading:@"What it does"];
  [self.filterStack addArrangedSubview:kindsHeading];
  [self.filterStack setCustomSpacing:4 afterView:kindsHeading];
  [self addFilterRow:[self filterRowTitle:@"All" count:[self.index.shortcuts count] caps:nil selected:self.kindFilter == nil && !self.conflictsOnly
                                   action:^{ weakSelf.kindFilter = nil; weakSelf.conflictsOnly = NO; }]];
  SlateShortcutKind kinds[] = {SlateShortcutKindMoveToSlot, SlateShortcutKindFocusApp, SlateShortcutKindFocusWindow, SlateShortcutKindResizeNudge, SlateShortcutKindFeature, SlateShortcutKindOther};
  for (NSUInteger i = 0; i < 6; i++) {
    SlateShortcutKind kind = kinds[i];
    NSUInteger count = [self.index countOfKind:kind];
    if (count == 0) continue;
    BOOL selected = self.kindFilter != nil && (SlateShortcutKind)[self.kindFilter integerValue] == kind;
    [self addFilterRow:[self filterRowTitle:[SlateShortcutInfo kindTitle:kind] count:count caps:nil selected:selected
                                     action:^{ weakSelf.kindFilter = selected ? nil : @(kind); }]];
  }
  NSTextField *keysHeading = [self heading:@"Keys"];
  [self.filterStack addArrangedSubview:keysHeading];
  [self.filterStack setCustomSpacing:4 afterView:keysHeading];
  [self.filterStack setCustomSpacing:14 afterView:[[self.filterStack arrangedSubviews] objectAtIndex:[[self.filterStack arrangedSubviews] count] - 2]];
  for (SlateModifierGroup *group in self.index.groups) {
    BOOL selected = [self.groupFilter isEqualToString:group.name];
    NSString *name = group.name;
    [self addFilterRow:[self filterRowTitle:group.name count:group.count caps:group.custom ? nil : group.modifierNames selected:selected
                                     action:^{ weakSelf.groupFilter = selected ? nil : name; }]];
  }
  if (self.index.conflictCount > 0) {
    NSTextField *problems = [self heading:@"Problems"];
    [self.filterStack addArrangedSubview:problems];
    [self.filterStack setCustomSpacing:14 afterView:[[self.filterStack arrangedSubviews] objectAtIndex:[[self.filterStack arrangedSubviews] count] - 2]];
    [self addFilterRow:[self filterRowTitle:@"Conflicts" count:self.index.conflictCount caps:nil selected:self.conflictsOnly
                                     action:^{ weakSelf.conflictsOnly = !weakSelf.conflictsOnly; }]];
  }
}

- (void)addRowFor:(SlateShortcutInfo *)info {
  ConfigurationClickView *row = [[ConfigurationClickView alloc] init];
  [row setTranslatesAutoresizingMaskIntoConstraints:NO];
  row.cornerRadius = 8;
  __weak ConfigurationShortcutListView *weakSelf = self;
  NSUInteger bindingIndex = info.index;
  row.onClick = ^{ [weakSelf.delegate shortcutListView:weakSelf wantsToOpenBindingAtIndex:bindingIndex]; };
  [row setIdentifier:[NSString stringWithFormat:@"binding-%lu", (unsigned long)info.index]];

  NSView *keys = [ConfigurationKeyViews shortcutViewForInfo:info size:22];
  [[keys.widthAnchor constraintEqualToConstant:kKeysColumnWidth] setActive:YES];
  NSTextField *title = [self labelWithText:info.title size:13 color:[MWMTheme textPrimary] weight:NSFontWeightRegular];
  NSMutableArray *textViews = [NSMutableArray arrayWithObject:title];
  if ([info.detail length] > 0) [textViews addObject:[self labelWithText:info.detail size:12 color:[MWMTheme textSecondary] weight:NSFontWeightRegular]];
  NSStackView *text = [NSStackView stackViewWithViews:textViews];
  [text setSpacing:8];
  [text setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSMutableArray *views = [NSMutableArray arrayWithObjects:keys, text, nil];
  if (info.conflict) {
    NSImageView *warn = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:@"exclamationmark.triangle.fill" accessibilityDescription:@"Conflict"]];
    [warn setContentTintColor:[MWMTheme warning]];
    [warn setToolTip:@"Another shortcut has the same keys"];
    [views addObject:warn];
  }
  NSSwitch *toggle = [[NSSwitch alloc] init];
  [toggle setControlSize:NSControlSizeSmall];
  [toggle setState:info.binding.enabled ? NSControlStateValueOn : NSControlStateValueOff];
  [toggle setTag:(NSInteger)info.index];
  [toggle setTarget:self];
  [toggle setAction:@selector(toggled:)];
  [views addObject:toggle];
  NSStackView *content = [NSStackView stackViewWithViews:views];
  [content setSpacing:12];
  [content setAlignment:NSLayoutAttributeCenterY];
  [content setEdgeInsets:NSEdgeInsetsMake(7, 8, 7, 8)];
  [content setTranslatesAutoresizingMaskIntoConstraints:NO];
  [row addSubview:content];
  [NSLayoutConstraint activateConstraints:@[
    [content.topAnchor constraintEqualToAnchor:row.topAnchor], [content.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
    [content.leadingAnchor constraintEqualToAnchor:row.leadingAnchor], [content.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
  ]];
  [self.rowsStack addArrangedSubview:row];
  [[row.widthAnchor constraintEqualToAnchor:self.rowsStack.widthAnchor] setActive:YES];
}

- (void)rebuildRows {
  for (NSView *view in [[self.rowsStack arrangedSubviews] copy]) {
    [self.rowsStack removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  if (self.index == nil) return;
  NSUInteger shown = 0;
  SlateShortcutKind kinds[] = {SlateShortcutKindMoveToSlot, SlateShortcutKindFocusApp, SlateShortcutKindFocusWindow, SlateShortcutKindResizeNudge, SlateShortcutKindFeature, SlateShortcutKindOther};
  for (NSUInteger i = 0; i < 6; i++) {
    NSMutableArray *matching = [NSMutableArray array];
    for (SlateShortcutInfo *info in self.index.shortcuts) if (info.kind == kinds[i] && [self infoMatches:info]) [matching addObject:info];
    if ([matching count] == 0) continue;
    NSTextField *heading = [self heading:[NSString stringWithFormat:@"%@ · %lu", [SlateShortcutInfo kindTitle:kinds[i]], (unsigned long)[matching count]]];
    [self.rowsStack addArrangedSubview:heading];
    [self.rowsStack setCustomSpacing:4 afterView:heading];
    for (SlateShortcutInfo *info in matching) [self addRowFor:info];
    [self.rowsStack setCustomSpacing:16 afterView:[[self.rowsStack arrangedSubviews] lastObject]];
    shown += [matching count];
  }
  NSString *scope = self.groupFilter != nil ? [NSString stringWithFormat:@" in %@", self.groupFilter] : @"";
  [self.countLabel setStringValue:[NSString stringWithFormat:@"%lu shortcut%@%@", (unsigned long)shown, shown == 1 ? @"" : @"s", scope]];
  if (shown == 0) {
    NSTextField *empty = [self labelWithText:@"No shortcuts match." size:13 color:[MWMTheme textTertiary] weight:NSFontWeightRegular];
    [self.rowsStack addArrangedSubview:empty];
  }
}

#pragma mark - Actions

- (void)toggled:(NSSwitch *)toggle {
  NSUInteger index = (NSUInteger)[toggle tag];
  if (index >= [self.document.bindings count]) return;
  self.document.bindings[index].enabled = [toggle state] == NSControlStateValueOn;
  [self.delegate shortcutListViewDidChangeDocument:self];
  [self reload];  // conflicts change when a shortcut is switched off
}

- (void)newPressed:(id)sender {
  [self.delegate shortcutListViewWantsNewShortcut:self];
}

@end
