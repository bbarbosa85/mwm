//
//  ConfigurationFormView.m
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

#import "ConfigurationFormView.h"
#import "SlateConfigDocument.h"
#import "SlateConfig.h"
#import "SlateShortcut.h"
#import "ConfigurationShortcutView.h"

static NSString *const kColEnabled = @"enabled";
static NSString *const kColModifiers = @"mods";
static NSString *const kColKey = @"key";
static NSString *const kColShortcut = @"shortcut";
static NSString *const kColAction = @"action";
static NSString *const kColNote = @"note";
static NSString *const kColName = @"name";
static NSString *const kColValue = @"value";
static NSString *const kColDefault = @"default";
static const CGFloat kSidebarWidth = 190;

// Only ever holds string literals, so unretained is safe under ARC.
typedef struct {
  __unsafe_unretained NSString *title;
  __unsafe_unretained NSString *symbol;
  __unsafe_unretained NSString *info;
} SectionInfo;

static SectionInfo InfoFor(ConfigurationFormSection section) {
  switch (section) {
    case ConfigurationFormSectionGeneral:
      return (SectionInfo){@"General", @"gearshape", @"Global settings. Anything not listed uses MWM's default."};
    case ConfigurationFormSectionModifiers:
      return (SectionInfo){@"Modifiers", @"command", @"Named modifier combinations, used as ${name} in bindings."};
    case ConfigurationFormSectionMonitors:
      return (SectionInfo){@"Monitors", @"display.2", @"Screen references and resolutions, used as ${name} in bindings and positions."};
    case ConfigurationFormSectionPositions:
      return (SectionInfo){@"Positions", @"rectangle.split.3x1", @"Named window positions, used as ${name} in bindings."};
    case ConfigurationFormSectionAliases:
      return (SectionInfo){@"Other aliases", @"curlybraces", @"Other named values, used as ${name}."};
    case ConfigurationFormSectionApps:
      return (SectionInfo){@"Apps", @"square.grid.2x2", @"Shortcuts that bring an app to the front."};
    case ConfigurationFormSectionLayout:
      return (SectionInfo){@"Layout bindings", @"keyboard", @"Shortcuts that move windows to a position or monitor."};
    case ConfigurationFormSectionWindowActions:
      return (SectionInfo){@"Window actions", @"arrow.up.and.down.and.arrow.left.and.right", @"Resize, nudge, push, and focus by direction."};
    default:
      return (SectionInfo){@"Features", @"sparkles", @"Window hints, grid, app switcher, relaunch, and other operations."};
  }
}

static BOOL IsBoolean(id value) {
  return [value isKindOfClass:[NSNumber class]] && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
}

// "true" -> YES, "0.4" -> 0.4, anything else stays a string.
static id TypedSettingValue(NSString *text) {
  if ([text isEqualToString:@"true"]) return @YES;
  if ([text isEqualToString:@"false"]) return @NO;
  NSRegularExpression *number = [NSRegularExpression regularExpressionWithPattern:@"^-?[0-9]+(\\.[0-9]+)?$" options:0 error:nil];
  if ([number numberOfMatchesInString:text options:0 range:NSMakeRange(0, [text length])] == 1) return @([text doubleValue]);
  return text;
}

static NSString *DisplayValue(id value) {
  if (IsBoolean(value)) return [value boolValue] ? @"true" : @"false";
  return [value description] ?: @"";
}

@interface ConfigurationFormView () <ConfigurationShortcutViewDelegate>
@property (strong) NSTableView *sidebar;
@property (strong) NSView *detail;
@property (strong) NSTextField *titleLabel;
@property (strong) NSTextField *infoLabel;
@property (strong) NSButton *addButton;
@property (strong) NSButton *removeButton;
@property (strong) NSScrollView *tableScroll;
@property (strong) NSTableView *table;
@property (strong) NSView *unavailableView;
@property (strong) NSTextField *unavailableLabel;
// Rows of the current section: entries for name/value sections, bindings otherwise.
@property (strong) NSArray *rows;
@end

@implementation ConfigurationFormView

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _rows = @[];
    [self buildInterface];
  }
  return self;
}

- (NSView *)initialFirstResponder {
  return self.sidebar;
}

#pragma mark - Interface

- (NSScrollView *)scrollViewFor:(NSView *)documentView {
  NSScrollView *scroll = [[NSScrollView alloc] init];
  [scroll setTranslatesAutoresizingMaskIntoConstraints:NO];
  [scroll setHasVerticalScroller:YES];
  [scroll setAutohidesScrollers:YES];
  [scroll setDrawsBackground:NO];
  [scroll setDocumentView:documentView];
  return scroll;
}

- (NSButton *)symbolButton:(NSString *)symbol tip:(NSString *)tip action:(SEL)action {
  NSButton *button = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:tip] target:self action:action];
  [button setTranslatesAutoresizingMaskIntoConstraints:NO];
  [button setBezelStyle:NSBezelStyleRounded];
  [button setToolTip:tip];
  return button;
}

- (void)buildInterface {
  // Sidebar
  self.sidebar = [[NSTableView alloc] init];
  [self.sidebar addTableColumn:[[NSTableColumn alloc] initWithIdentifier:@"section"]];
  [self.sidebar setHeaderView:nil];
  [self.sidebar setStyle:NSTableViewStyleSourceList];
  [self.sidebar setRowHeight:28];
  [self.sidebar setDataSource:self];
  [self.sidebar setDelegate:self];
  NSScrollView *sidebarScroll = [self scrollViewFor:self.sidebar];

  NSBox *divider = [[NSBox alloc] init];
  [divider setBoxType:NSBoxSeparator];
  [divider setTranslatesAutoresizingMaskIntoConstraints:NO];

  // Detail: header, then the table
  self.detail = [[NSView alloc] init];
  [self.detail setTranslatesAutoresizingMaskIntoConstraints:NO];
  self.titleLabel = [NSTextField labelWithString:@""];
  [self.titleLabel setFont:[NSFont boldSystemFontOfSize:15]];
  [self.titleLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
  self.infoLabel = [NSTextField wrappingLabelWithString:@""];
  [self.infoLabel setTextColor:[NSColor secondaryLabelColor]];
  [self.infoLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
  self.addButton = [self symbolButton:@"plus" tip:@"Add" action:@selector(add:)];
  self.removeButton = [self symbolButton:@"minus" tip:@"Remove the selected rows" action:@selector(remove:)];

  self.table = [[NSTableView alloc] init];
  [self.table setStyle:NSTableViewStyleInset];
  [self.table setUsesAlternatingRowBackgroundColors:YES];
  [self.table setAllowsMultipleSelection:YES];
  [self.table setRowHeight:24];
  [self.table setColumnAutoresizingStyle:NSTableViewLastColumnOnlyAutoresizingStyle];
  [self.table setDataSource:self];
  [self.table setDelegate:self];
  self.tableScroll = [self scrollViewFor:self.table];

  for (NSView *view in @[self.titleLabel, self.infoLabel, self.addButton, self.removeButton, self.tableScroll]) {
    [self.detail addSubview:view];
  }

  // Shown instead of everything else when the file can't be a form
  self.unavailableLabel = [NSTextField wrappingLabelWithString:@""];
  [self.unavailableLabel setAlignment:NSTextAlignmentCenter];
  [self.unavailableLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
  NSButton *openEditor = [NSButton buttonWithTitle:@"Open in Text Editor" target:self action:@selector(openInTextEditor:)];
  NSButton *reload = [NSButton buttonWithTitle:@"Reload" target:self action:@selector(reload:)];
  NSStackView *buttons = [NSStackView stackViewWithViews:@[openEditor, reload]];
  [buttons setTranslatesAutoresizingMaskIntoConstraints:NO];
  self.unavailableView = [[NSView alloc] init];
  [self.unavailableView setTranslatesAutoresizingMaskIntoConstraints:NO];
  [self.unavailableView addSubview:self.unavailableLabel];
  [self.unavailableView addSubview:buttons];
  [self.unavailableView setHidden:YES];

  for (NSView *view in @[sidebarScroll, divider, self.detail, self.unavailableView]) {
    [self addSubview:view];
  }

  [NSLayoutConstraint activateConstraints:@[
    [sidebarScroll.topAnchor constraintEqualToAnchor:self.topAnchor],
    [sidebarScroll.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    [sidebarScroll.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
    [sidebarScroll.widthAnchor constraintEqualToConstant:kSidebarWidth],
    [divider.topAnchor constraintEqualToAnchor:self.topAnchor],
    [divider.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    [divider.leadingAnchor constraintEqualToAnchor:sidebarScroll.trailingAnchor],
    [self.detail.topAnchor constraintEqualToAnchor:self.topAnchor],
    [self.detail.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    [self.detail.leadingAnchor constraintEqualToAnchor:divider.trailingAnchor],
    [self.detail.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],

    [self.titleLabel.topAnchor constraintEqualToAnchor:self.detail.topAnchor constant:16],
    [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.detail.leadingAnchor constant:20],
    [self.infoLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
    [self.infoLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
    [self.infoLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.addButton.leadingAnchor constant:-16],
    [self.removeButton.trailingAnchor constraintEqualToAnchor:self.detail.trailingAnchor constant:-20],
    [self.removeButton.centerYAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor],
    [self.addButton.trailingAnchor constraintEqualToAnchor:self.removeButton.leadingAnchor constant:-6],
    [self.addButton.centerYAnchor constraintEqualToAnchor:self.removeButton.centerYAnchor],

    [self.tableScroll.topAnchor constraintEqualToAnchor:self.infoLabel.bottomAnchor constant:10],
    [self.tableScroll.leadingAnchor constraintEqualToAnchor:self.detail.leadingAnchor],
    [self.tableScroll.trailingAnchor constraintEqualToAnchor:self.detail.trailingAnchor],
    [self.tableScroll.bottomAnchor constraintEqualToAnchor:self.detail.bottomAnchor],


    [self.unavailableView.topAnchor constraintEqualToAnchor:self.topAnchor],
    [self.unavailableView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    [self.unavailableView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
    [self.unavailableView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
    [self.unavailableLabel.centerXAnchor constraintEqualToAnchor:self.unavailableView.centerXAnchor],
    [self.unavailableLabel.centerYAnchor constraintEqualToAnchor:self.unavailableView.centerYAnchor constant:-20],
    [self.unavailableLabel.widthAnchor constraintLessThanOrEqualToConstant:460],
    [buttons.topAnchor constraintEqualToAnchor:self.unavailableLabel.bottomAnchor constant:14],
    [buttons.centerXAnchor constraintEqualToAnchor:self.unavailableView.centerXAnchor],
  ]];
}

#pragma mark - Document and sections

- (void)setDocument:(SlateConfigDocument *)document {
  _document = document;
  [self.unavailableView setHidden:YES];
  for (NSView *view in [self subviews]) {
    if (view != self.unavailableView) [view setHidden:NO];
  }
  [self.sidebar reloadData];
  [self.sidebar selectRowIndexes:[NSIndexSet indexSetWithIndex:self.selectedSection] byExtendingSelection:NO];
  [self showSection];
}

- (void)showUnavailableMessage:(NSString *)message {
  _document = nil;
  [self.unavailableLabel setStringValue:message];
  for (NSView *view in [self subviews]) [view setHidden:view != self.unavailableView];
}

- (void)setSelectedSection:(ConfigurationFormSection)section {
  if (section < 0 || section >= ConfigurationFormSectionCount) section = ConfigurationFormSectionGeneral;
  _selectedSection = section;
  if ([self.sidebar selectedRow] != section) {
    [self.sidebar selectRowIndexes:[NSIndexSet indexSetWithIndex:section] byExtendingSelection:NO];
  }
  [self showSection];
}

- (BOOL)isBindingSection:(ConfigurationFormSection)section {
  return section >= ConfigurationFormSectionApps && section <= ConfigurationFormSectionFeatures;
}

- (SlateBindingCategory)categoryForSection:(ConfigurationFormSection)section {
  switch (section) {
    case ConfigurationFormSectionApps: return SlateBindingCategoryApps;
    case ConfigurationFormSectionLayout: return SlateBindingCategoryLayout;
    case ConfigurationFormSectionWindowActions: return SlateBindingCategoryWindowActions;
    default: return SlateBindingCategoryFeatures;
  }
}

- (NSMutableArray<SlateConfigEntry *> *)entriesForSection:(ConfigurationFormSection)section {
  switch (section) {
    case ConfigurationFormSectionGeneral: return self.document.settings;
    case ConfigurationFormSectionModifiers: return self.document.modifiers;
    case ConfigurationFormSectionMonitors: return self.document.monitors;
    case ConfigurationFormSectionPositions: return self.document.positions;
    case ConfigurationFormSectionAliases: return self.document.aliases;
    default: return nil;
  }
}

- (NSArray<SlateBindingEntry *> *)bindingsForSection:(ConfigurationFormSection)section {
  SlateBindingCategory category = [self categoryForSection:section];
  NSMutableArray *result = [NSMutableArray array];
  for (SlateBindingEntry *binding in self.document.bindings) {
    if ([self.document categoryOfBinding:binding] == category) [result addObject:binding];
  }
  return result;
}

- (NSUInteger)countForSection:(ConfigurationFormSection)section {
  if (self.document == nil) return 0;
  if ([self isBindingSection:section]) return [[self bindingsForSection:section] count];
  return [[self entriesForSection:section] count];
}

- (NSTableColumn *)column:(NSString *)identifier title:(NSString *)title width:(CGFloat)width {
  NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:identifier];
  [column setTitle:title];
  [column setWidth:width];
  [column setMinWidth:MIN(width, 40)];
  return column;
}

- (void)showSection {
  ConfigurationFormSection section = self.selectedSection;
  SectionInfo info = InfoFor(section);
  [self.titleLabel setStringValue:info.title];
  [self.infoLabel setStringValue:info.info];

  // Empty the table first: changing columns makes it redraw, and the old
  // section's rows don't fit the new section's columns.
  self.rows = @[];
  [self.table reloadData];
  while ([[self.table tableColumns] count] > 0) [self.table removeTableColumn:[[self.table tableColumns] lastObject]];
  if ([self isBindingSection:section]) {
    [self.table addTableColumn:[self column:kColEnabled title:@"On" width:34]];
    [self.table addTableColumn:[self column:kColShortcut title:@"Shortcut" width:250]];
    [self.table addTableColumn:[self column:kColAction title:@"Action" width:330]];
    [self.table addTableColumn:[self column:kColNote title:@"Note" width:180]];
  } else if (section == ConfigurationFormSectionGeneral) {
    [self.table addTableColumn:[self column:kColName title:@"Setting" width:230]];
    [self.table addTableColumn:[self column:kColValue title:@"Value" width:200]];
    [self.table addTableColumn:[self column:kColDefault title:@"Default" width:180]];
  } else {
    [self.table addTableColumn:[self column:kColName title:@"Name" width:200]];
    [self.table addTableColumn:[self column:kColValue title:@"Value" width:460]];
  }
  [self reloadRows];
}

- (void)reloadRows {
  ConfigurationFormSection section = self.selectedSection;
  if ([self isBindingSection:section]) {
    self.rows = [self bindingsForSection:section];
  } else {
    self.rows = [[self entriesForSection:section] copy] ?: @[];
  }
  [self.table reloadData];
}

// Section counts change as rows are added, removed, or move between categories.
- (void)reloadSidebarKeepingSelection {
  [self.sidebar reloadData];
  [self.sidebar selectRowIndexes:[NSIndexSet indexSetWithIndex:self.selectedSection] byExtendingSelection:NO];
}

- (void)documentChanged {
  [self reloadSidebarKeepingSelection];
  [self.delegate formViewDidChangeDocument:self];
}

#pragma mark - Table data

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
  if (tableView == self.sidebar) return self.document ? ConfigurationFormSectionCount : 0;
  return [self.rows count];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
  if ([notification object] != self.sidebar) return;
  NSInteger row = [self.sidebar selectedRow];
  if (row >= 0 && row != self.selectedSection) {
    _selectedSection = row;
    [self showSection];
  }
}

- (NSView *)sidebarCellForRow:(NSInteger)row {
  NSTableCellView *cell = [[NSTableCellView alloc] init];
  SectionInfo info = InfoFor(row);
  NSImageView *icon = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:info.symbol accessibilityDescription:nil]];
  NSTextField *title = [NSTextField labelWithString:info.title];
  [title setLineBreakMode:NSLineBreakByTruncatingTail];
  NSUInteger count = [self countForSection:row];
  NSTextField *countLabel = [NSTextField labelWithString:count > 0 ? [NSString stringWithFormat:@"%lu", (unsigned long)count] : @""];
  [countLabel setTextColor:[NSColor secondaryLabelColor]];
  [countLabel setFont:[NSFont monospacedDigitSystemFontOfSize:[NSFont smallSystemFontSize] weight:NSFontWeightRegular]];
  for (NSView *view in @[icon, title, countLabel]) {
    [view setTranslatesAutoresizingMaskIntoConstraints:NO];
    [cell addSubview:view];
  }
  [cell setImageView:icon];
  [cell setTextField:title];
  [NSLayoutConstraint activateConstraints:@[
    [icon.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:4],
    [icon.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
    [icon.widthAnchor constraintEqualToConstant:18],
    [title.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:6],
    [title.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
    [countLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:title.trailingAnchor constant:6],
    [countLabel.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-6],
    [countLabel.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
  ]];
  return cell;
}

// Wraps a control so it's vertically centered in its row.
- (NSView *)cellWith:(NSView *)control {
  NSTableCellView *cell = [[NSTableCellView alloc] init];
  [control setTranslatesAutoresizingMaskIntoConstraints:NO];
  [cell addSubview:control];
  [NSLayoutConstraint activateConstraints:@[
    [control.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:2],
    [control.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-2],
    [control.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
  ]];
  return cell;
}

- (NSView *)textCell:(NSString *)text column:(NSString *)column monospaced:(BOOL)monospaced placeholder:(NSString *)placeholder {
  NSTextField *field = [NSTextField textFieldWithString:text ?: @""];
  [field setBordered:NO];
  [field setDrawsBackground:NO];
  [field setEditable:YES];
  [field setIdentifier:column];
  [field setTarget:self];
  [field setAction:@selector(cellEdited:)];
  [field setPlaceholderString:placeholder];
  [field setLineBreakMode:NSLineBreakByTruncatingTail];
  [[field cell] setSendsActionOnEndEditing:YES];
  [field setFont:monospaced ? [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular] : [NSFont systemFontOfSize:13]];
  return [self cellWith:field];
}

- (NSView *)checkboxCell:(BOOL)on action:(SEL)action {
  NSButton *box = [NSButton checkboxWithTitle:@"" target:self action:action];
  [box setState:on ? NSControlStateValueOn : NSControlStateValueOff];
  return [self cellWith:box];
}

- (BOOL)isBooleanSetting:(SlateConfigEntry *)entry {
  if (IsBoolean(entry.value)) return YES;
  NSString *fallback = [[SlateConfig getInstance] getConfigDefault:entry.name];
  return [entry.value isKindOfClass:[NSString class]] && ([fallback isEqualToString:@"true"] || [fallback isEqualToString:@"false"]) &&
         ([entry.value isEqualToString:@"true"] || [entry.value isEqualToString:@"false"]);
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
  if (tableView == self.sidebar) return [self sidebarCellForRow:row];
  NSString *column = [tableColumn identifier];

  if ([self isBindingSection:self.selectedSection]) {
    SlateBindingEntry *binding = self.rows[row];
    if ([column isEqualToString:kColEnabled]) return [self checkboxCell:binding.enabled action:@selector(enabledToggled:)];
    if ([column isEqualToString:kColShortcut]) return [self shortcutCellForBinding:binding];
    if ([column isEqualToString:kColAction]) return [self textCell:binding.action column:column monospaced:YES placeholder:@"operation"];
    return [self textCell:binding.note column:column monospaced:NO placeholder:@""];
  }

  SlateConfigEntry *entry = self.rows[row];
  if ([column isEqualToString:kColName]) return [self textCell:entry.name column:column monospaced:NO placeholder:@"name"];
  if ([column isEqualToString:kColDefault]) {
    NSString *fallback = [[SlateConfig getInstance] getConfigDefault:entry.name];
    NSTextField *label = [NSTextField labelWithString:fallback == nil ? @"Unknown setting" : ([fallback length] > 0 ? fallback : @"(empty)")];
    [label setTextColor:fallback == nil ? [NSColor systemOrangeColor] : [NSColor secondaryLabelColor]];
    [label setLineBreakMode:NSLineBreakByTruncatingTail];
    return [self cellWith:label];
  }
  if (self.selectedSection == ConfigurationFormSectionGeneral && [self isBooleanSetting:entry]) {
    return [self checkboxCell:[DisplayValue(entry.value) isEqualToString:@"true"] action:@selector(settingToggled:)];
  }
  return [self textCell:DisplayValue(entry.value) column:column monospaced:YES placeholder:@""];
}

#pragma mark - Shortcuts

// Shortcuts that fire on the same keys, from every enabled binding: identity -> bindings.
- (NSDictionary<NSString *, NSArray<SlateBindingEntry *> *> *)bindingsByShortcut {
  NSMutableDictionary *groups = [NSMutableDictionary dictionary];
  for (SlateBindingEntry *binding in self.document.bindings) {
    if (!binding.enabled) continue;
    NSString *identity = [SlateShortcut identityForKey:[self.document expandAliases:binding.key]
                                             modifiers:[self.document expandAliases:binding.modifiers ?: @""]];
    if (identity == nil) continue;
    groups[identity] = [(groups[identity] ?: @[]) arrayByAddingObject:binding];
  }
  return groups;
}

- (NSString *)conflictTextForBinding:(SlateBindingEntry *)binding groups:(NSDictionary *)groups {
  if (!binding.enabled) return nil;
  NSString *identity = [SlateShortcut identityForKey:[self.document expandAliases:binding.key]
                                           modifiers:[self.document expandAliases:binding.modifiers ?: @""]];
  NSArray<SlateBindingEntry *> *same = identity ? groups[identity] : nil;
  if ([same count] < 2) return nil;
  NSMutableArray *others = [NSMutableArray array];
  for (SlateBindingEntry *other in same) {
    if (other != binding) [others addObject:[NSString stringWithFormat:@"“%@”", other.action]];
  }
  return [NSString stringWithFormat:@"Same shortcut as %@", [others componentsJoinedByString:@", "]];
}

- (NSView *)shortcutCellForBinding:(SlateBindingEntry *)binding {
  ConfigurationShortcutView *view = [[ConfigurationShortcutView alloc] init];
  [view setDelegate:self];
  NSString *key = [self.document expandAliases:binding.key];
  NSString *expandedMods = [self.document expandAliases:binding.modifiers ?: @""];
  NSArray *names = [SlateShortcut modifierNamesFromString:expandedMods];
  BOOL known = [SlateShortcut identityForKey:key modifiers:nil] != nil && names != nil;
  if (known) {
    NSString *alias = nil;
    NSRegularExpression *single = [NSRegularExpression regularExpressionWithPattern:@"^\\$\\{([^}]*)\\}$" options:0 error:nil];
    NSTextCheckingResult *match = [single firstMatchInString:binding.modifiers ?: @"" options:0 range:NSMakeRange(0, [binding.modifiers length])];
    if (match) alias = [binding.modifiers substringWithRange:[match rangeAtIndex:1]];
    [view setKeyName:key modifierNames:names aliasName:alias
            conflict:[self conflictTextForBinding:binding groups:[self bindingsByShortcut]]];
  } else {
    [view showRawText:[binding.modifiers length] > 0 ? [NSString stringWithFormat:@"%@ + %@", binding.modifiers, binding.key] : binding.key];
  }
  NSMenu *menu = [[NSMenu alloc] init];
  [[menu addItemWithTitle:@"Edit as Text…" action:@selector(editShortcutAsText:) keyEquivalent:@""] setTarget:self];
  [view setMenu:menu];
  return [self cellWith:view];
}

- (void)shortcutViewWillBeginRecording:(ConfigurationShortcutView *)view {
  NSInteger row = [self.table rowForView:view];
  if (row >= 0) [self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
}

- (void)shortcutView:(ConfigurationShortcutView *)view didRecordKey:(NSString *)keyName modifierNames:(NSArray<NSString *> *)modifierNames {
  NSInteger row = [self.table rowForView:view];
  if (row < 0 || row >= (NSInteger)[self.rows count]) return;
  SlateBindingEntry *binding = self.rows[row];
  // A named group (like ${hyper}) that matches keeps the file readable.
  NSString *alias = [SlateShortcut aliasForModifierNames:modifierNames inEntries:self.document.modifiers];
  NSString *modifiers = alias ?: ([modifierNames count] > 0 ? [SlateShortcut stringFromModifierNames:modifierNames] : nil);
  if ([binding.key isEqualToString:keyName] && ((modifiers == nil && [binding.modifiers length] == 0) || [modifiers isEqualToString:binding.modifiers])) return;
  binding.key = keyName;
  binding.modifiers = modifiers;
  dispatch_async(dispatch_get_main_queue(), ^{ [self reloadRows]; });  // conflicts may have changed on other rows
  [self documentChanged];
}

- (void)beginRecordingRow:(NSInteger)row {
  [self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
  [self.table scrollRowToVisible:row];
  if ([self window] == nil) return;
  NSInteger columnIndex = [self.table columnWithIdentifier:kColShortcut];
  if (columnIndex < 0) return;
  NSView *cell = [self.table viewAtColumn:columnIndex row:row makeIfNecessary:YES];
  for (NSView *view in [cell subviews]) {
    if ([view isKindOfClass:[ConfigurationShortcutView class]]) [(ConfigurationShortcutView *)view beginRecording];
  }
}

// For what can't be recorded: a key with no physical equivalent, or a modal key (name:modal).
- (void)editShortcutAsText:(NSMenuItem *)item {
  NSInteger row = [self.table clickedRow];
  if (row < 0 || row >= (NSInteger)[self.rows count]) return;
  SlateBindingEntry *binding = self.rows[row];
  NSTextField *keyField = [NSTextField textFieldWithString:binding.key ?: @""];
  NSTextField *modifiersField = [NSTextField textFieldWithString:binding.modifiers ?: @""];
  [keyField setPlaceholderString:@"r, pad5, left"];
  [modifiersField setPlaceholderString:@"ctrl;alt;cmd or ${hyper}"];
  NSStackView *fields = [NSStackView stackViewWithViews:@[
    [NSTextField labelWithString:@"Key"], keyField, [NSTextField labelWithString:@"Modifiers"], modifiersField,
  ]];
  [fields setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [fields setAlignment:NSLayoutAttributeLeading];
  [fields setFrameSize:NSMakeSize(300, 100)];
  [keyField setFrameSize:NSMakeSize(300, 22)];
  [modifiersField setFrameSize:NSMakeSize(300, 22)];
  NSAlert *alert = [[NSAlert alloc] init];
  [alert setMessageText:@"Edit shortcut as text"];
  [alert addButtonWithTitle:@"Save"];
  [alert addButtonWithTitle:@"Cancel"];
  [alert setAccessoryView:fields];
  if ([self window] == nil) return;
  [alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse response) {
    if (response != NSAlertFirstButtonReturn) return;
    NSString *key = [[keyField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *mods = [[modifiersField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([key length] == 0) {
      NSBeep();
      return;
    }
    binding.key = key;
    binding.modifiers = [mods length] > 0 ? mods : nil;
    [self reloadRows];
    [self documentChanged];
  }];
}

#pragma mark - Editing

- (void)cellEdited:(NSTextField *)field {
  NSInteger row = [self.table rowForView:field];
  if (row < 0 || row >= (NSInteger)[self.rows count]) return;
  NSString *column = [field identifier];
  NSString *text = [[field stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  BOOL changed = NO;

  if ([self isBindingSection:self.selectedSection]) {
    SlateBindingEntry *binding = self.rows[row];
    SlateBindingCategory before = [self.document categoryOfBinding:binding];
    if ([column isEqualToString:kColKey] || [column isEqualToString:kColAction]) {
      NSString *current = [column isEqualToString:kColKey] ? binding.key : binding.action;
      if ([text length] == 0) {  // a binding always needs both
        NSBeep();
        [field setStringValue:current];
        return;
      }
      changed = ![text isEqualToString:current];
      if ([column isEqualToString:kColKey]) binding.key = text; else binding.action = text;
    } else {
      NSString *value = [text length] > 0 ? text : nil;
      NSString *current = [column isEqualToString:kColModifiers] ? binding.modifiers : binding.note;
      changed = !((value == nil && current == nil) || [value isEqualToString:current]);
      if ([column isEqualToString:kColModifiers]) binding.modifiers = value; else binding.note = value;
    }
    if (changed && [self.document categoryOfBinding:binding] != before) {
      // The binding now belongs in another section; refresh once editing ends.
      dispatch_async(dispatch_get_main_queue(), ^{ [self reloadRows]; });
    }
  } else {
    SlateConfigEntry *entry = self.rows[row];
    if ([column isEqualToString:kColName]) {
      if ([text length] == 0) {
        NSBeep();
        [field setStringValue:entry.name];
        return;
      }
      changed = ![text isEqualToString:entry.name];
      entry.name = text;
      if (self.selectedSection == ConfigurationFormSectionGeneral) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self reloadRows]; });  // default column follows the name
      }
    } else {
      id value = self.selectedSection == ConfigurationFormSectionGeneral ? TypedSettingValue(text) : text;
      changed = ![DisplayValue(value) isEqualToString:DisplayValue(entry.value)] || IsBoolean(value) != IsBoolean(entry.value);
      entry.value = value;
    }
  }
  if (changed) [self documentChanged];
}

- (void)enabledToggled:(NSButton *)box {
  NSInteger row = [self.table rowForView:box];
  if (row < 0) return;
  SlateBindingEntry *binding = self.rows[row];
  binding.enabled = [box state] == NSControlStateValueOn;
  [self documentChanged];
}

- (void)settingToggled:(NSButton *)box {
  NSInteger row = [self.table rowForView:box];
  if (row < 0) return;
  SlateConfigEntry *entry = self.rows[row];
  entry.value = [box state] == NSControlStateValueOn ? @YES : @NO;
  [self documentChanged];
}

- (NSString *)uniqueName:(NSString *)base {
  NSMutableSet *taken = [NSMutableSet set];
  for (NSArray<SlateConfigEntry *> *section in @[self.document.modifiers, self.document.monitors, self.document.positions, self.document.aliases]) {
    [taken addObjectsFromArray:[section valueForKey:@"name"]];
  }
  NSString *name = base;
  for (NSUInteger i = 2; [taken containsObject:name]; i++) name = [NSString stringWithFormat:@"%@%lu", base, (unsigned long)i];
  return name;
}

- (SlateBindingEntry *)newBindingForSection:(ConfigurationFormSection)section {
  NSString *hyper = [self.document.modifiers count] > 0 ? [NSString stringWithFormat:@"${%@}", self.document.modifiers[0].name] : @"ctrl;alt;cmd";
  switch (section) {
    case ConfigurationFormSectionApps:
      return [SlateBindingEntry bindingWithKey:@"f12" modifiers:@"alt;shift" action:@"focus 'Finder'"];
    case ConfigurationFormSectionLayout: {
      NSString *position = [self.document.positions count] > 0 ? [NSString stringWithFormat:@"${%@}", self.document.positions[0].name]
                                                                : @"move screenOriginX;screenOriginY screenSizeX;screenSizeY";
      return [SlateBindingEntry bindingWithKey:@"f12" modifiers:hyper action:position];
    }
    case ConfigurationFormSectionWindowActions:
      return [SlateBindingEntry bindingWithKey:@"f12" modifiers:hyper action:@"resize +10% +0"];
    default:
      return [SlateBindingEntry bindingWithKey:@"f12" modifiers:hyper action:@"relaunch"];
  }
}

- (void)beginEditingRow:(NSInteger)row column:(NSString *)column {
  [self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
  [self.table scrollRowToVisible:row];
  if ([self window] == nil) return;
  NSInteger columnIndex = [self.table columnWithIdentifier:column];
  if (columnIndex >= 0) [self.table editColumn:columnIndex row:row withEvent:nil select:YES];
}

- (IBAction)add:(id)sender {
  ConfigurationFormSection section = self.selectedSection;
  if (section == ConfigurationFormSectionGeneral) {
    [self showSettingsMenu];
    return;
  }
  if ([self isBindingSection:section]) {
    SlateBindingEntry *binding = [self newBindingForSection:section];
    NSArray *existing = [self bindingsForSection:section];
    // Keep a category's bindings together in the file.
    NSUInteger index = [existing count] > 0 ? [self.document.bindings indexOfObjectIdenticalTo:[existing lastObject]] + 1 : [self.document.bindings count];
    binding.group = [existing count] > 0 ? [(SlateBindingEntry *)[existing lastObject] group] : nil;
    [self.document.bindings insertObject:binding atIndex:index];
    [self reloadRows];
    [self documentChanged];
    [self beginRecordingRow:[self.rows indexOfObjectIdenticalTo:binding]];
    return;
  }
  NSDictionary *defaults = @{
    @(ConfigurationFormSectionModifiers): @[@"modifier", @"ctrl;alt;cmd"],
    @(ConfigurationFormSectionMonitors): @[@"monitor", @"0"],
    @(ConfigurationFormSectionPositions): @[@"position", @"move screenOriginX;screenOriginY screenSizeX;screenSizeY"],
    @(ConfigurationFormSectionAliases): @[@"alias", @""],
  };
  NSArray *pair = defaults[@(section)];
  SlateConfigEntry *entry = [SlateConfigEntry entryWithName:[self uniqueName:pair[0]] value:pair[1]];
  [[self entriesForSection:section] addObject:entry];
  [self reloadRows];
  [self documentChanged];
  [self beginEditingRow:[self.rows count] - 1 column:kColName];
}

- (void)showSettingsMenu {
  NSDictionary *defaults = [[SlateConfig getInstance] configDefaults];
  NSSet *present = [NSSet setWithArray:[self.document.settings valueForKey:@"name"]];
  NSMenu *menu = [[NSMenu alloc] init];
  for (NSString *name in [[defaults allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]) {
    if ([present containsObject:name]) continue;
    NSMenuItem *item = [menu addItemWithTitle:name action:@selector(addSetting:) keyEquivalent:@""];
    [item setTarget:self];
    [item setRepresentedObject:name];
  }
  if ([menu numberOfItems] == 0) {
    [menu addItemWithTitle:@"Every setting is already listed" action:nil keyEquivalent:@""];
  }
  [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, NSHeight([self.addButton bounds]) + 4) inView:self.addButton];
}

- (void)addSetting:(NSMenuItem *)item {
  NSString *name = [item representedObject];
  NSString *fallback = [[SlateConfig getInstance] getConfigDefault:name] ?: @"";
  [self.document.settings addObject:[SlateConfigEntry entryWithName:name value:TypedSettingValue(fallback)]];
  [self reloadRows];
  [self documentChanged];
  [self beginEditingRow:[self.rows count] - 1 column:kColValue];
}

- (IBAction)remove:(id)sender {
  NSIndexSet *selected = [self.table selectedRowIndexes];
  if ([selected count] == 0) {
    NSBeep();
    return;
  }
  NSArray *doomed = [self.rows objectsAtIndexes:selected];
  NSMutableArray *list = [self isBindingSection:self.selectedSection] ? (NSMutableArray *)self.document.bindings
                                                                      : (NSMutableArray *)[self entriesForSection:self.selectedSection];
  for (id row in doomed) [list removeObjectIdenticalTo:row];
  [self reloadRows];
  [self documentChanged];
}

- (IBAction)openInTextEditor:(id)sender {
  [self.delegate formViewWantsTextEditor:self];
}

- (IBAction)reload:(id)sender {
  [self.delegate formViewWantsReload:self];
}

#pragma mark - Revealing

- (void)selectRowObject:(id)object {
  NSUInteger row = [self.rows indexOfObjectIdenticalTo:object];
  if (row == NSNotFound) return;
  [self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
  [self.table scrollRowToVisible:row];
  if ([self window] != nil) [[self window] makeFirstResponder:self.table];
}

- (void)revealBindingAtIndex:(NSUInteger)index {
  if (self.document == nil || index >= [self.document.bindings count]) return;
  SlateBindingEntry *binding = self.document.bindings[index];
  SlateBindingCategory category = [self.document categoryOfBinding:binding];
  for (ConfigurationFormSection section = ConfigurationFormSectionApps; section <= ConfigurationFormSectionFeatures; section++) {
    if ([self categoryForSection:section] != category) continue;
    [self setSelectedSection:section];
    [self selectRowObject:binding];
    return;
  }
}

- (void)revealEntryNamed:(NSString *)name {
  if (self.document == nil) return;
  for (ConfigurationFormSection section = ConfigurationFormSectionGeneral; section <= ConfigurationFormSectionAliases; section++) {
    for (SlateConfigEntry *entry in [self entriesForSection:section]) {
      if (![entry.name isEqualToString:name]) continue;
      [self setSelectedSection:section];
      [self selectRowObject:entry];
      return;
    }
  }
}

@end
