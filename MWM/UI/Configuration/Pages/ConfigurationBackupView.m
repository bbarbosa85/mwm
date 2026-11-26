//
//  ConfigurationBackupView.m
//
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

#import "ConfigurationBackupView.h"
#import "MWMAlert.h"
#import "MWMComponents.h"
#import "MWMGist.h"
#import "MWMSyncPresenter.h"
#import "MWMTheme.h"

@interface ConfigurationBackupView ()
@property (strong) NSStackView *rows;
@property (strong) NSTextField *tokenField;
@property (strong) NSButton *syncButton;
@property (copy) NSArray<MWMSyncItem *> *items;
@property (copy, nullable) NSString *problem;
@property (strong, nullable) MWMSyncReport *lastReport;
@property (assign) BOOL loading;
@property (assign) BOOL loaded;
@property (assign) BOOL editingToken;
@property (assign) BOOL busy;
@end

@implementation ConfigurationBackupView

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _interactive = YES;
    _items = @[];
    _tokenField = [NSSecureTextField textFieldWithString:@""];
    [_tokenField setPlaceholderString:@"ghp_…"];
    [_tokenField setIdentifier:@"backup-token"];
    [_tokenField setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    _rows = [NSStackView stackViewWithViews:@[]];
    [_rows setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [_rows setAlignment:NSLayoutAttributeLeading];
    [_rows setSpacing:MWMSpacingM];
    [_rows setEdgeInsets:NSEdgeInsetsMake(8, MWMSpacingXL, MWMSpacingXL, MWMSpacingXL)];
    NSScrollView *scroll = [MWMComponents scrollViewWithContent:_rows];
    [self addSubview:scroll];
    [MWMComponents pinView:scroll toEdgesOf:self insets:NSEdgeInsetsMake(0, 0, 0, 0)];
    [self rebuild];
  }
  return self;
}

- (void)viewDidMoveToWindow {
  [super viewDidMoveToWindow];
  if (self.window != nil && !self.loaded && [MWMGist token] != nil) [self refresh:nil];
}

#pragma mark - Page

static NSString *const kNewTokenURL = @"https://github.com/settings/tokens/new?description=MWM%20backup&scopes=gist";
static NSString *const kTokensURL = @"https://github.com/settings/tokens";

// A step: an icon tile, a title, a line of help and, when there is one, a control under it.
- (NSView *)stepCardNumber:(NSUInteger)number symbol:(NSString *)symbol title:(NSString *)title help:(NSString *)help extra:(NSArray<NSView *> *)extra {
  NSView *circle = [MWMComponents iconTileWithSymbol:symbol color:[MWMTheme accent] size:34];
  NSMutableArray *column = [NSMutableArray arrayWithObject:[MWMComponents labelWithText:title font:[MWMTheme fontBodyStrong] color:[MWMTheme textPrimary]]];
  if (help != nil) [column addObject:[MWMComponents wrappingLabelWithText:help size:12 color:[MWMTheme textSecondary] weight:NSFontWeightRegular]];
  [column addObjectsFromArray:extra];
  NSStackView *text = [NSStackView stackViewWithViews:column];
  [text setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [text setAlignment:NSLayoutAttributeLeading];
  [text setSpacing:MWMSpacingS];
  for (NSView *view in column) if ([view isKindOfClass:[NSTextField class]] || [view isKindOfClass:[NSStackView class]]) [[view.widthAnchor constraintLessThanOrEqualToAnchor:text.widthAnchor] setActive:YES];
  [text setCustomSpacing:MWMSpacingM afterView:column.count > 1 ? column[1] : column[0]];
  NSStackView *row = [NSStackView stackViewWithViews:@[circle, text]];
  [row setAlignment:NSLayoutAttributeTop];
  [row setSpacing:MWMSpacingM];
  NSView *card = [MWMComponents card];
  [card setIdentifier:[NSString stringWithFormat:@"backup-step-%lu", (unsigned long)number]];
  [card addSubview:row];
  [MWMComponents pinView:row toEdgesOf:card insets:NSEdgeInsetsMake(MWMSpacingL, MWMSpacingL, MWMSpacingL, MWMSpacingL)];
  return card;
}

- (NSView *)tokenBlock {
  BOOL has = [MWMGist token] != nil;
  NSTextField *title = [MWMComponents labelWithText:has ? @"Use a different token" : @"Connect your GitHub account" font:[MWMTheme fontBodyStrong] color:[MWMTheme textPrimary]];
  NSTextField *intro = [MWMComponents wrappingLabelWithText:@"Backups live in a private gist that only you can see. MWM needs a token to read and write it. This takes about a minute." size:12 color:[MWMTheme textSecondary] weight:NSFontWeightRegular];

  NSButton *open = [MWMComponents secondaryButtonWithTitle:@"Create token on GitHub" symbol:@"arrow.up.right.square" target:self action:@selector(createTokenPressed:)];
  [open setIdentifier:@"backup-create-token"];
  NSTextField *classic = [MWMComponents wrappingLabelWithText:@"It has to be a classic token. Fine-grained tokens can't reach gists." size:11 color:[MWMTheme textTertiary] weight:NSFontWeightRegular];
  NSView *one = [self stepCardNumber:1 symbol:@"link" title:@"Create a token on GitHub" help:@"The page opens with the name “MWM backup” and the gist permission already ticked. Pick an expiration and choose Generate token." extra:@[open, classic]];
  NSView *two = [self stepCardNumber:2 symbol:@"doc.on.doc" title:@"Copy the token" help:@"It starts with ghp_. GitHub shows it only once, so copy it before you leave the page." extra:@[]];

  NSButton *connect = [MWMComponents accentButtonWithTitle:has ? @"Save token" : @"Connect" symbol:nil target:self action:@selector(connectPressed:)];
  [connect setIdentifier:@"backup-connect"];
  NSStackView *form = [NSStackView stackViewWithViews:@[self.tokenField, connect]];
  [form setSpacing:MWMSpacingS];
  [form setAlignment:NSLayoutAttributeCenterY];
  NSView *three = [self stepCardNumber:3 symbol:@"key" title:@"Paste it here" help:nil extra:@[form]];
  [[form.widthAnchor constraintEqualToAnchor:three.widthAnchor constant:-(2 * MWMSpacingL + 34 + MWMSpacingM)] setActive:YES];

  NSMutableAttributedString *note = [[NSMutableAttributedString alloc] initWithString:@"The token is kept in your Keychain and used only for one private gist called “MWM backup”. You can revoke it any time in your GitHub token settings." attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:12], NSForegroundColorAttributeName: [MWMTheme textSecondary]}];
  NSRange link = [[note string] rangeOfString:@"your GitHub token settings"];
  [note addAttributes:@{NSLinkAttributeName: [NSURL URLWithString:kTokensURL], NSForegroundColorAttributeName: [MWMTheme accent]} range:link];
  NSTextField *keychain = [NSTextField wrappingLabelWithString:@""];
  [keychain setAttributedStringValue:note];
  [keychain setSelectable:YES];
  [keychain setAllowsEditingTextAttributes:YES];
  [keychain setIdentifier:@"backup-keychain-note"];

  NSStackView *column = [NSStackView stackViewWithViews:@[title, intro, one, two, three, keychain]];
  [column setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [column setAlignment:NSLayoutAttributeLeading];
  [column setSpacing:MWMSpacingL];
  [column setCustomSpacing:MWMSpacingXS afterView:title];
  [column setCustomSpacing:MWMSpacingXL afterView:intro];
  [column setCustomSpacing:MWMSpacingXL afterView:three];
  for (NSView *view in @[intro, one, two, three, keychain]) [[view.widthAnchor constraintEqualToAnchor:column.widthAnchor] setActive:YES];
  [column setIdentifier:@"backup-token-card"];
  return column;
}

- (void)createTokenPressed:(id)sender { [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:kNewTokenURL]]; }


#pragma mark - The list

static NSString *StatusTitle(MWMSyncStatus status) {
  switch (status) {
    case MWMSyncStatusSynced: return @"Synced";
    case MWMSyncStatusChangedHere: return @"Changed here";
    case MWMSyncStatusNewerInGist: return @"Newer in the gist";
    case MWMSyncStatusOnlyHere: return @"Only here";
    case MWMSyncStatusOnlyInGist: return @"Only in the gist";
    case MWMSyncStatusDeletedHere: return @"Deleted here";
    case MWMSyncStatusDeletedInGist: return @"Deleted in the gist";
  }
}

static NSString *StatusNote(MWMSyncStatus status) {
  switch (status) {
    case MWMSyncStatusSynced: return @"Nothing to do";
    case MWMSyncStatusChangedHere: case MWMSyncStatusOnlyHere: return @"Will be sent";
    case MWMSyncStatusNewerInGist: case MWMSyncStatusOnlyInGist: return @"Will be received";
    case MWMSyncStatusDeletedHere: return @"Still in the gist";
    case MWMSyncStatusDeletedInGist: return @"Still on this computer";
  }
}

static NSColor *StatusColor(MWMSyncStatus status) {
  switch (status) {
    case MWMSyncStatusSynced: return [MWMTheme success];
    case MWMSyncStatusDeletedHere: case MWMSyncStatusDeletedInGist: return [MWMTheme warning];
    default: return [MWMTheme accent];
  }
}

// A name, a status chip, the date it was last edited, and what the next sync will do: one row of columns.
- (NSView *)rowForItem:(MWMSyncItem *)item {
  NSTextField *name = [MWMComponents labelWithText:item.name font:[MWMTheme fontBodyStrong] color:[MWMTheme textPrimary]];
  [name setLineBreakMode:NSLineBreakByTruncatingTail];
  [name setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  [name setContentCompressionResistancePriority:250 forOrientation:NSLayoutConstraintOrientationHorizontal];
  MWMChipView *chip = [MWMChipView chipWithText:StatusTitle(item.status) color:StatusColor(item.status)];
  [chip setIdentifier:[@"backup-status-" stringByAppendingString:item.name]];
  NSView *chipColumn = [[NSView alloc] init];
  [chipColumn setTranslatesAutoresizingMaskIntoConstraints:NO];
  [chipColumn addSubview:chip];
  [chip setTranslatesAutoresizingMaskIntoConstraints:NO];
  [NSLayoutConstraint activateConstraints:@[[chip.leadingAnchor constraintEqualToAnchor:chipColumn.leadingAnchor], [chip.centerYAnchor constraintEqualToAnchor:chipColumn.centerYAnchor],
                                            [chipColumn.widthAnchor constraintEqualToConstant:170], [chipColumn.heightAnchor constraintEqualToConstant:22]]];
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  [formatter setLocalizedDateFormatFromTemplate:@"d MMM yyyy"];
  NSDate *date = item.local.modified ?: item.remote.modified;
  NSTextField *edited = [MWMComponents labelWithText:date != nil && ![date isEqualToDate:[NSDate distantPast]] ? [formatter stringFromDate:date] : @"—" font:[MWMTheme fontSmall] color:[MWMTheme textSecondary]];
  [edited setIdentifier:@"backup-date"];
  [[edited.widthAnchor constraintEqualToConstant:100] setActive:YES];
  NSTextField *note = [MWMComponents labelWithText:StatusNote(item.status) font:[MWMTheme fontSmall] color:[MWMTheme textSecondary]];
  [note setIdentifier:@"backup-note"];
  [[note.widthAnchor constraintEqualToConstant:150] setActive:YES];
  NSStackView *columns = [NSStackView stackViewWithViews:@[name, chipColumn, edited, note]];
  [columns setSpacing:MWMSpacingM];
  [columns setAlignment:NSLayoutAttributeCenterY];
  NSView *card = [MWMComponents card];
  [card setIdentifier:[@"backup-item-" stringByAppendingString:item.name]];
  [card addSubview:columns];
  [MWMComponents pinView:columns toEdgesOf:card insets:NSEdgeInsetsMake(MWMSpacingM + 2, MWMSpacingL, MWMSpacingM + 2, MWMSpacingL)];
  return card;
}

- (NSString *)lastSyncLine {
  NSDate *date = [MWMSync lastSyncDate];
  if (date == nil) return @"Not synced yet. Sync now sends your profiles to your gist and brings back any it has.";
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  [formatter setDateStyle:NSDateFormatterMediumStyle];
  [formatter setTimeStyle:NSDateFormatterShortStyle];
  [formatter setDoesRelativeDateFormatting:YES];
  NSString *summary = [MWMSync lastSummary];
  return [NSString stringWithFormat:@"Last synced %@%@", [formatter stringFromDate:date], summary ? [@" · " stringByAppendingString:summary] : @""];
}

- (NSView *)syncCard {
  NSTextField *title = [MWMComponents labelWithText:@"Sync your profiles" font:[MWMTheme fontBodyStrong] color:[MWMTheme textPrimary]];
  NSTextField *line = [MWMComponents secondaryLabel:[self lastSyncLine]];
  [line setIdentifier:@"backup-lastsync"];
  NSStackView *text = [NSStackView stackViewWithViews:@[title, line]];
  [text setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [text setAlignment:NSLayoutAttributeLeading];
  [text setSpacing:3];
  self.syncButton = [MWMComponents accentButtonWithTitle:self.busy ? @"Syncing…" : @"Sync now" symbol:@"arrow.triangle.2.circlepath" target:self action:@selector(syncPressed:)];
  [self.syncButton setIdentifier:@"backup-sync"];
  [self.syncButton setEnabled:!self.busy];
  NSStackView *row = [NSStackView stackViewWithViews:@[text, [MWMComponents spacer], self.syncButton]];
  [row setSpacing:MWMSpacingM];
  [row setAlignment:NSLayoutAttributeCenterY];
  NSView *card = [MWMComponents dashedCard];
  [card setIdentifier:@"backup-sync-card"];
  [card addSubview:row];
  [MWMComponents pinView:row toEdgesOf:card insets:NSEdgeInsetsMake(MWMSpacingL, MWMSpacingL, MWMSpacingL, MWMSpacingL)];
  return card;
}

- (void)rebuild {
  for (NSView *view in [[self.rows arrangedSubviews] copy]) {
    [self.rows removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  BOOL connected = [MWMGist token] != nil;
  void (^add)(NSView *) = ^(NSView *view) {
    [self.rows addArrangedSubview:view];
    [[view.widthAnchor constraintEqualToAnchor:self.rows.widthAnchor constant:-2 * MWMSpacingXL] setActive:YES];
  };
  if (!connected || self.editingToken) {
    add([self tokenBlock]);
  } else {
    NSButton *change = [MWMComponents secondaryButtonWithTitle:@"Change token" target:self action:@selector(changeTokenPressed:)];
    [change setIdentifier:@"backup-change-token"];
    NSStackView *bar = [NSStackView stackViewWithViews:@[[MWMComponents secondaryLabel:@"Private GitHub gist · token saved in your Keychain"], change, [MWMComponents spacer]]];
    [bar setSpacing:MWMSpacingM];
    [bar setAlignment:NSLayoutAttributeCenterY];
    add(bar);
  }
  if (!connected) return;
  add([self syncCard]);
  [self.rows setCustomSpacing:MWMSpacingXL afterView:self.rows.arrangedSubviews.lastObject];
  if (self.problem != nil) {
    NSTextField *error = [MWMComponents wrappingLabelWithText:self.problem size:13 color:[MWMTheme danger] weight:NSFontWeightRegular];
    [error setIdentifier:@"backup-problem"];
    NSButton *retry = [MWMComponents secondaryButtonWithTitle:@"Try again" target:self action:@selector(retryPressed:)];
    [retry setIdentifier:@"backup-retry"];
    NSStackView *line = [NSStackView stackViewWithViews:@[error, retry]];
    [line setSpacing:MWMSpacingM];
    [line setAlignment:NSLayoutAttributeCenterY];
    add(line);
  } else if (self.loading && !self.loaded) {
    NSTextField *wait = [MWMComponents secondaryLabel:@"Looking at your gist…"];
    [wait setIdentifier:@"backup-loading"];
    add(wait);
  } else if ([self.items count] == 0) {
    NSTextField *none = [MWMComponents wrappingLabelWithText:@"Nothing to sync yet. Make a profile in Settings, then choose Sync now." size:13 color:[MWMTheme textSecondary] weight:NSFontWeightRegular];
    [none setIdentifier:@"backup-empty"];
    add(none);
  } else {
    for (MWMSyncItem *item in self.items) add([self rowForItem:item]);
  }
}

#pragma mark - Actions

- (void)changeTokenPressed:(id)sender { self.editingToken = YES; [self rebuild]; }
- (void)connectPressed:(id)sender { [self connectWithToken:[self.tokenField stringValue] completion:nil]; }
- (void)retryPressed:(id)sender { [self refresh:nil]; }
- (void)syncPressed:(id)sender { [self syncWithCompletion:nil]; }

- (void)showProblem:(NSString *)message title:(NSString *)title {
  if (!self.interactive) return;
  MWMAlert *alert = [MWMAlert alert];
  [alert setKind:MWMAlertKindWarning];
  [alert setMessageText:title];
  [alert setInformativeText:message];
  [alert runModal];
}

- (void)refresh:(void (^)(void))done {
  self.loading = YES;
  self.problem = nil;
  [self rebuild];
  [MWMSync preview:^(NSArray<MWMSyncItem *> *items, NSString *problem) {
    self.loading = NO;
    self.loaded = problem == nil;
    self.problem = problem;
    self.items = items;
    [self rebuild];
    if (done) done();
  }];
}

- (void)connectWithToken:(NSString *)token completion:(void (^)(void))done {
  NSString *trimmed = [token stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if ([trimmed length] == 0) { if (done) done(); return; }
  [MWMGist checkToken:trimmed completion:^(NSString *problem) {
    if (problem != nil) {
      [self showProblem:problem title:@"That token didn't work"];
    } else {
      [MWMGist setToken:trimmed];
      [self.tokenField setStringValue:@""];
      self.editingToken = NO;
      self.loaded = NO;
      [self rebuild];
      [self refresh:done];
      return;
    }
    if (done) done();
  }];
}

- (void)syncWithCompletion:(void (^)(void))done {
  if (self.busy) { if (done) done(); return; }
  self.busy = YES;
  [self rebuild];
  void (^finished)(MWMSyncReport *) = ^(MWMSyncReport *report) {
    self.busy = NO;
    self.lastReport = report;
    if (report.received > 0 || [report.flagged count] > 0) [self.delegate backupViewDidChangeFiles:self];
    [self refresh:done];
  };
  if (self.interactive) [MWMSyncPresenter runWithCompletion:finished];
  else [MWMSync syncWithCompletion:finished];
}

@end
