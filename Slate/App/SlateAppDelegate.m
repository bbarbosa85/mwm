//
//  SlateAppDelegate.m
//  Slate
//
//  Created by Jigish Patel on 5/18/11.
//  Copyright 2011 Jigish Patel. All rights reserved.
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

#import <ServiceManagement/ServiceManagement.h>
#import "Constants.h"
#import "SlateAppDelegate.h"
#import "SlateConfig.h"
#import "JSController.h"
#import "Binding.h"
#import "HintOperation.h"
#import "SlateLogger.h"
#import "SnapshotList.h"
#import "SnapshotOperation.h"
#import "ActivateSnapshotOperation.h"
#import "DeleteSnapshotOperation.h"
#import "SwitchOperation.h"
#import "RunningApplications.h"
#import "GridOperation.h"
#import "ConfigurationWindowController.h"

@implementation SlateAppDelegate

@synthesize currentHintOperation, currentGridOperation, currentSwitchBinding;
@synthesize cmdTabBinding, cmdShiftTabBinding, modalHotKeyRefs, modalIdToKey;
@synthesize currentModalKey, currentModalHotKeyRefs, undoSnapshotOperation, undoDeleteSnapshotOperation, hasUndoOperation;

static NSObject *timerLock = nil;
static NSObject *keyUpLock = nil;
static NSTimer *currentTimer = nil;
static EventHotKeyID currentHotKey;
static SlateAppDelegate *selfRef = nil;
static EventHandlerRef modifiersEvent;

// The menu bar symbol, as a template image so macOS colors it for light and dark menu bars.
- (NSImage *)statusImageNamed:(NSString *)name {
  NSImage *image = [NSImage imageNamed:name];
  [image setTemplate:YES];
  return image;
}

- (IBAction)updateLaunchState {
  if ([launchOnLoginItem state] == NSControlStateValueOn) {
    // currently on
    [self deleteFromLoginItems];
    [self setLaunchOnLoginItemStatus];
  } else {
    // currently off
    [self addToLoginItems];
    [self setLaunchOnLoginItemStatus];
  }
}

- (IBAction)relaunch {
  NSString *appPath = [[NSBundle mainBundle] bundlePath];
  NSString *processID = [NSString stringWithFormat:@"%d", [[NSProcessInfo processInfo] processIdentifier]];
  NSString *relaunchScript = [NSString stringWithFormat:@"while kill -0 %@ 2>/dev/null; do sleep 0.1; done; open -n \"%@\"", processID, appPath];
  [NSTask launchedTaskWithLaunchPath:@"/bin/sh" arguments:[NSArray arrayWithObjects:@"-c", relaunchScript, nil]];
  [NSApp terminate:self];
}

- (IBAction)configureSlate {
  [[ConfigurationWindowController sharedController] showConfiguration];
}

- (void)loadConfig {
  [self setHasUndoOperation:NO];
  [[SlateConfig getInstance] load];
}

- (void)registerHotKeys {
  SlateLogger(@"Registering HotKeys...");
  EventTypeSpec eventType;
  EventTypeSpec eventReleasedType;
  eventType.eventClass = kEventClassKeyboard;
  eventType.eventKind = kEventHotKeyPressed;
  eventReleasedType.eventClass = kEventClassKeyboard;
  eventReleasedType.eventKind = kEventHotKeyReleased;

  InstallEventHandler(GetEventMonitorTarget(), &OnHotKeyEvent, 1, &eventType, (__bridge void *)self, NULL);
  InstallEventHandler(GetEventMonitorTarget(), &OnHotKeyReleasedEvent, 1, &eventReleasedType, (__bridge void *)self, NULL);

  NSMutableArray *bindings = [[SlateConfig getInstance] bindings];

  for (NSInteger i = 0; i < [bindings count]; i++) {
    Binding *binding = [bindings objectAtIndex:i];
    SlateLogger(@"REGISTERING KEY: %u, MODIFIERS: %u", [binding keyCode], [binding modifiers]);
    if ([binding keyCode] == 48 && [binding modifiers] == cmdKey) {
      cmdTabBinding = i;
      SlateLogger(@"Found CMD+Tab binding!");
    } else if ([binding keyCode] == 48 && [binding modifiers] == (cmdKey + shiftKey)) {
      cmdShiftTabBinding = i;
      SlateLogger(@"Found CMD+Shift+Tab binding!");
    }
    EventHotKeyID myHotKeyID;
    EventHotKeyRef myHotKeyRef;
    myHotKeyID.signature = *[[NSString stringWithFormat:@"hotkey%li",i] cStringUsingEncoding:NSASCIIStringEncoding];
    myHotKeyID.id = (UInt32)i;
    RegisterEventHotKey([binding keyCode], [binding modifiers], myHotKeyID, GetEventMonitorTarget(), 0, &myHotKeyRef);
    [binding setHotKeyRef:myHotKeyRef];
  }

  NSArray *modalKeys = [[[SlateConfig getInstance] modalBindings] allKeys];
  NSInteger i = MODAL_BEGIN_ID;
  for (NSString *modalHashKey in modalKeys) {
    SlateLogger(@"REGISTERING MODAL KEY: %@", modalHashKey);
    NSArray *modalKeyArr = [Binding modalHashKeyToKeyAndModifiers:modalHashKey];
    if (modalKeyArr == nil) continue;
    EventHotKeyID myHotKeyID;
    EventHotKeyRef myHotKeyRef;
    myHotKeyID.signature = *[[NSString stringWithFormat:@"hotkey%li",i] cStringUsingEncoding:NSASCIIStringEncoding];
    myHotKeyID.id = (UInt32)i;
    RegisterEventHotKey([[modalKeyArr objectAtIndex:0] unsignedIntValue], [[modalKeyArr objectAtIndex:1] unsignedIntValue], myHotKeyID, GetEventMonitorTarget(), 0, &myHotKeyRef);
    [[self modalHotKeyRefs] setObject:[NSValue valueWithPointer:myHotKeyRef] forKey:modalHashKey];
    [[self modalIdToKey] setObject:modalHashKey forKey:[NSNumber numberWithInteger:i]];
    i++;
  }
  SlateLogger(@"HotKeys registered.");
}

- (void)createSnapshotOperations {
  SnapshotOperation *undoSnapOp = [SnapshotOperation operationFromString:[NSString stringWithFormat:@"snapshot %@ save-to-disk;stack", UNDO_SNAPSHOT]];
  [undoSnapOp setStackSize:[[SlateConfig getInstance] getIntegerConfig:UNDO_MAX_STACK_SIZE]];
  [self setUndoSnapshotOperation:undoSnapOp];
  [self setUndoDeleteSnapshotOperation:[DeleteSnapshotOperation operationFromString:[NSString stringWithFormat:@"delete-snapshot %@ all", UNDO_SNAPSHOT]]];
  [[self undoDeleteSnapshotOperation] doOperation];
}

- (IBAction)aboutWindow {
  [NSApp orderFrontStandardAboutPanel:self];
  NSArray *windows = [NSApp windows];
  for (NSWindow *window in windows) {
    [window setLevel:(NSScreenSaverWindowLevel - 1)];
  }
}

- (OSStatus)timerActivateBinding:(NSTimer *)timer {
  return [self activateBinding:currentHotKey isRepeat:YES];
}

- (void)resetModalKey {
  // clear out bindings
  for (NSValue *hotKeyRef in [self currentModalHotKeyRefs]) {
    UnregisterEventHotKey([hotKeyRef pointerValue]);
  }
  // reset status image
  [[statusItem button] setImage:[self statusImageNamed:@"status"]];
  currentModalKey = nil;
}

- (OSStatus)activateBinding:(EventHotKeyID)hkCom isRepeat:(BOOL)isRepeat {
  SlateLogger(@"ACTIVATING BINDING: %u", hkCom.id);
  // check if there is a currently open binding
  HintOperation *hintop = [self currentHintOperation];
  GridOperation *gridop = [self currentGridOperation];
  Binding *switchop = [self currentSwitchBinding];
  if (hintop != nil) {
    [hintop activateHintKey:hkCom.id];
    return noErr;
  }
  if (gridop != nil) {
    [gridop activateGridKey:hkCom.id];
    return noErr;
  }
  if (switchop != nil) {
    [(SwitchOperation *)[switchop op] activateSwitchKey:hkCom isRepeat:isRepeat];
    @synchronized(timerLock) {
      if (currentTimer != nil) {
        [currentTimer invalidate];
        currentTimer = nil;
      }
      // Setup timer to repeat operation
      currentHotKey = hkCom;
      currentTimer = [NSTimer scheduledTimerWithTimeInterval:[[SlateConfig getInstance] getDoubleConfig:(isRepeat ? SWITCH_SECONDS_BETWEEN_REPEAT : SWITCH_SECONDS_BEFORE_REPEAT)]
                                                      target:selfRef
                                                    selector:@selector(timerActivateBinding:)
                                                    userInfo:nil
                                                     repeats:NO];
    }
    return noErr;
  }

  // check modal stuffs
  NSNumber *hkId = [NSNumber numberWithInteger:hkCom.id];
  NSString *modalKey = [[self modalIdToKey] objectForKey:hkId];
  if (modalKey != nil) {
    if (currentModalKey != nil && [modalKey isEqualToString:currentModalKey]) {
      [self resetModalKey];
      return noErr;
    } else if (currentModalKey == nil) {
      SlateLogger(@"FOUND MODAL KEY BINDING, REGISTERING!");
      // register all these bindings
      [[self currentModalHotKeyRefs] removeAllObjects];
      NSArray *modalOperations = [[[SlateConfig getInstance] modalBindings] objectForKey:modalKey];
      NSInteger i = CURRENT_MODAL_BEGIN_ID;
      for (Binding *binding in modalOperations) {
        EventHotKeyID myHotKeyID;
        EventHotKeyRef myHotKeyRef;
        myHotKeyID.signature = *[[NSString stringWithFormat:@"hotkey%li",i] cStringUsingEncoding:NSASCIIStringEncoding];
        myHotKeyID.id = (UInt32)i;
        RegisterEventHotKey([binding keyCode], 0, myHotKeyID, GetEventMonitorTarget(), 0, &myHotKeyRef);
        [binding setHotKeyRef:myHotKeyRef];
        [[self currentModalHotKeyRefs] addObject:[NSValue valueWithPointer:myHotKeyRef]];
        i++;
      }
      if (![EMPTY isEqualToString:[[SlateConfig getInstance] getConfig:MODAL_ESCAPE_KEY]]) {
        EventHotKeyID myHotKeyID;
        EventHotKeyRef myHotKeyRef;
        myHotKeyID.signature = *[[NSString stringWithFormat:@"hotkey%li",MODAL_ESCAPE_ID] cStringUsingEncoding:NSASCIIStringEncoding];
        myHotKeyID.id = (UInt32)MODAL_ESCAPE_ID;
        NSArray *keyarr = [Binding getKeystrokeFromString:[[SlateConfig getInstance] getConfig:MODAL_ESCAPE_KEY]];
        RegisterEventHotKey([[keyarr objectAtIndex:0] unsignedIntValue], [[keyarr objectAtIndex:1] unsignedIntValue], myHotKeyID, GetEventMonitorTarget(), 0, &myHotKeyRef);
        [[self currentModalHotKeyRefs] addObject:[NSValue valueWithPointer:myHotKeyRef]];
      }
      [self setCurrentModalKey:modalKey];
      // change status image
      [[statusItem button] setImage:[self statusImageNamed:@"statusActive"]];
      return noErr;
    }
  }

  if (hkCom.id >= [[[SlateConfig getInstance] bindings] count]) {
    if (currentModalKey != nil) {
      if (hkCom.id == MODAL_ESCAPE_ID) {
        [self resetModalKey];
      } else {
        NSInteger potentialId = hkCom.id - CURRENT_MODAL_BEGIN_ID;
        if (potentialId >= 0 && potentialId < [[[[SlateConfig getInstance] modalBindings] objectForKey:currentModalKey] count]) {
          Binding *binding = [[[[SlateConfig getInstance] modalBindings] objectForKey:currentModalKey] objectAtIndex:potentialId];
          [binding doOperation];
          if (![binding toggle]) {
            // clear out bindings
            [self resetModalKey];
          }
        }
      }
    }
    return noErr;
  }

  Binding *binding = [[[SlateConfig getInstance] bindings] objectAtIndex:hkCom.id];
  if (binding) {
    SlateLogger(@"Running Operation %@", [[[SlateConfig getInstance] bindings] objectAtIndex:hkCom.id]);
    if ([[binding op] isKindOfClass:[SwitchOperation class]]) {
      // makes sure that if switch is called immediately after opening slate we don't run into issues
      NSArray *currentApps = [[RunningApplications getInstance] apps];
      if ([currentApps count] > 0) {
        [AccessibilityWrapper focusApp:[currentApps objectAtIndex:0]];
      }
      [self setCurrentSwitchBinding:binding];
      EventTypeSpec modifiersChangedType;
      modifiersChangedType.eventClass = kEventClassKeyboard;
      modifiersChangedType.eventKind = kEventRawKeyModifiersChanged;
      InstallEventHandler(GetEventMonitorTarget(), &OnModifiersChangedEvent, 1, &modifiersChangedType, (__bridge void *)self, &modifiersEvent);
    }
    [binding doOperation];
    if (!(cmdTabBinding > 0 && [[[SlateConfig getInstance] bindings] objectAtIndex:cmdTabBinding] == binding) &&
        !(cmdShiftTabBinding > 0 && [[[SlateConfig getInstance] bindings] objectAtIndex:cmdShiftTabBinding] == binding) &&
        ([binding repeat] || [[binding op] isKindOfClass:[SwitchOperation class]])) {
      @synchronized(timerLock) {
        if (currentTimer != nil) {
          [currentTimer invalidate];
          currentTimer = nil;
        }
        // Setup timer to repeat operation
        currentHotKey = hkCom;
        if (![[binding op] isKindOfClass:[SwitchOperation class]] || !keyUpSeen) {
          currentTimer = [NSTimer scheduledTimerWithTimeInterval:[[SlateConfig getInstance] getDoubleConfig:([[binding op] isKindOfClass:[SwitchOperation class]] ?
                                                                                                             (isRepeat ? SWITCH_SECONDS_BETWEEN_REPEAT : SWITCH_SECONDS_BEFORE_REPEAT) :
                                                                                                             (isRepeat ? SECONDS_BETWEEN_REPEAT : SECONDS_BEFORE_REPEAT))]
                                                          target:selfRef
                                                        selector:@selector(timerActivateBinding:)
                                                        userInfo:nil
                                                         repeats:NO];
        }
      }
    }
  }
  return noErr;
}

// Quartz Event Tap for reserved key bindings (CMD+Tab or CMD+Shift+Tab)
static const NSTimeInterval KEY_UP_BUFFER = -0.020;
static BOOL keyUpSeen = YES;
static NSDate *keyUpTime = nil;
CGEventRef EatAppSwitcherCallback(CGEventTapProxy proxy, CGEventType type,  CGEventRef event, void *refcon) {
  @synchronized(keyUpLock) {
    CGEventFlags flags = CGEventGetFlags(event);
    int64_t keyCode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    SlateLogger(@"KEY DOWN - FLAGS: %llu, KEYCODE: %lld", (uint64_t)flags, keyCode);
    // 48 is tab key code
    if (keyCode == 48 &&
        ((flags & kCGEventFlagMaskCommand) == kCGEventFlagMaskCommand) &&
        ((flags & kCGEventFlagMaskAlternate) != kCGEventFlagMaskAlternate) &&
        ((flags & kCGEventFlagMaskControl) != kCGEventFlagMaskControl) &&
        ((flags & kCGEventFlagMaskAlphaShift) != kCGEventFlagMaskAlphaShift) &&
        ((flags & kCGEventFlagMaskHelp) != kCGEventFlagMaskHelp) &&
        ((flags & kCGEventFlagMaskNumericPad) != kCGEventFlagMaskNumericPad) &&
        ((flags & kCGEventFlagMaskSecondaryFn) != kCGEventFlagMaskSecondaryFn)) {
      SlateLogger(@"  IS CMD+TAB");
      if (keyUpSeen) {
        SlateLogger(@"    KEY UP SEEN: %f", [keyUpTime timeIntervalSinceNow]);
        if (keyUpTime && [keyUpTime timeIntervalSinceNow] > KEY_UP_BUFFER) {
          return NULL;
        }
        @synchronized(timerLock) {
          if (currentTimer != nil) {
            [currentTimer invalidate];
            currentTimer = nil;
          }
        }
        keyUpSeen = NO;
        keyUpTime = nil;
        SlateAppDelegate *del = (__bridge SlateAppDelegate *)refcon;
        EventHotKeyID myHotKeyID;
        NSInteger hotkeyID = ((flags & kCGEventFlagMaskShift) == kCGEventFlagMaskShift) ? [del cmdShiftTabBinding] : [del cmdTabBinding];
        if (hotkeyID < 0) return NULL;
        myHotKeyID.signature = *[[NSString stringWithFormat:@"hotkey%li",hotkeyID] cStringUsingEncoding:NSASCIIStringEncoding];
        myHotKeyID.id = (UInt32)hotkeyID;
        [del activateBinding:myHotKeyID isRepeat:NO];
      } else {
        SlateLogger(@"    KEY UP NOT SEEN");
        @synchronized(timerLock) {
          if (currentTimer != nil) {
            [currentTimer invalidate];
            currentTimer = nil;
          }
        }
        SlateAppDelegate *del = (__bridge SlateAppDelegate *)refcon;
        EventHotKeyID myHotKeyID;
        NSInteger hotkeyID = ((flags & kCGEventFlagMaskShift) == kCGEventFlagMaskShift) ? [del cmdShiftTabBinding] : [del cmdTabBinding];
        if (hotkeyID < 0) return NULL;
        myHotKeyID.signature = *[[NSString stringWithFormat:@"hotkey%li",hotkeyID] cStringUsingEncoding:NSASCIIStringEncoding];
        myHotKeyID.id = (UInt32)hotkeyID;
        [del activateBinding:myHotKeyID isRepeat:YES];
      }
      return NULL;
    }
    return event;
  }
}

CGEventRef EatAppSwitcherResetCallback(CGEventTapProxy proxy, CGEventType type,  CGEventRef event, void *refcon) {
  @synchronized(keyUpLock) {
    SlateLogger(@"KEY UP");
    @synchronized(timerLock) {
      if (currentTimer != nil) {
        [currentTimer invalidate];
        currentTimer = nil;
      }
    }
    keyUpSeen = YES;
    keyUpTime = [NSDate date];
    return event;
  }
}

OSStatus OnHotKeyEvent(EventHandlerCallRef nextHandler, EventRef theEvent, void *userData) {
  @synchronized(timerLock) {
    if (currentTimer != nil) {
      [currentTimer invalidate];
      currentTimer = nil;
    }
  }
  if (![(__bridge id)userData isKindOfClass:[SlateAppDelegate class]]) return noErr;
  EventHotKeyID hkCom;
  GetEventParameter(theEvent, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(hkCom), NULL, &hkCom);
  return [(__bridge SlateAppDelegate *)userData activateBinding:hkCom isRepeat:NO];
}

OSStatus OnHotKeyReleasedEvent(EventHandlerCallRef nextHandler, EventRef theEvent, void *userData) {
  @synchronized(timerLock) {
    if (currentTimer != nil) {
      [currentTimer invalidate];
      currentTimer = nil;
    }
  }
  return noErr;
}

OSStatus OnModifiersChangedEvent(EventHandlerCallRef nextHandler, EventRef theEvent, void *userData) {
  SlateLogger(@"Modifiers changed");
  @synchronized(timerLock) {
    if (currentTimer != nil) {
      [currentTimer invalidate];
      currentTimer = nil;
    }
  }
  Binding *currSwitch = [(__bridge SlateAppDelegate *)userData currentSwitchBinding];
  UInt32 modifiers;
  GetEventParameter(theEvent, kEventParamKeyModifiers, typeUInt32, NULL, sizeof(modifiers), NULL, &modifiers);
  if (currSwitch != nil) {
    if ([(SwitchOperation *)[currSwitch op] modifiersChanged:[currSwitch modifiers] new:modifiers]) {
      [(__bridge SlateAppDelegate *)userData setCurrentSwitchBinding:nil];
      RemoveEventHandler(modifiersEvent);
      keyUpSeen = YES;
    }
  }
  return noErr;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  if (NSClassFromString(@"XCTestCase") != nil ||
      [[[NSProcessInfo processInfo] environment] objectForKey:@"XCTestConfigurationFilePath"] != nil) {
    return;
  }
  if (cmdTabBinding > 0 || cmdShiftTabBinding > 0) {
    CFMachPortRef keyDownEventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, 0, CGEventMaskBit(kCGEventKeyDown), EatAppSwitcherCallback, (__bridge void *)self);
    if (keyDownEventTap != NULL) {
      CFRunLoopSourceRef keyDownRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, keyDownEventTap, 0);
      CFRunLoopAddSource(CFRunLoopGetCurrent(), keyDownRunLoopSource, kCFRunLoopCommonModes);
      CGEventTapEnable(keyDownEventTap, true);
      CFRelease(keyDownEventTap);
      if (keyDownRunLoopSource) CFRelease(keyDownRunLoopSource);
    }

    CFMachPortRef keyUpEventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, 0, CGEventMaskBit(kCGEventKeyUp), EatAppSwitcherResetCallback, (__bridge void *)self);
    if (keyUpEventTap != NULL) {
      CFRunLoopSourceRef keyUpRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, keyUpEventTap, 0);
      CFRunLoopAddSource(CFRunLoopGetCurrent(), keyUpRunLoopSource, kCFRunLoopCommonModes);
      CGEventTapEnable(keyUpEventTap, true);
      CFRelease(keyUpEventTap);
      if (keyUpRunLoopSource) CFRelease(keyUpRunLoopSource);
    }
  }
}

- (void)setLaunchOnLoginItemStatus {
  if ([self isInLoginItems]) [launchOnLoginItem setState:NSControlStateValueOn];
  else [launchOnLoginItem setState:NSControlStateValueOff];
}

#pragma mark - Menus

- (NSMenuItem *)addItem:(NSString *)title action:(SEL)action key:(NSString *)key to:(NSMenu *)menu {
  NSMenuItem *item = [menu addItemWithTitle:title action:action keyEquivalent:key];
  [item setTarget:self];
  return item;
}

// The status bar menu: everything MWM offers, in three short groups.
- (NSMenu *)buildStatusMenu {
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@"MWM"];
  [self addItem:@"About MWM" action:@selector(aboutWindow) key:@"" to:menu];
  [menu addItem:[NSMenuItem separatorItem]];
  [self addItem:@"Configure MWM…" action:@selector(configureSlate) key:@"," to:menu];
  [[self addItem:@"Reload Configuration" action:@selector(relaunch) key:@"" to:menu]
    setToolTip:@"Restart MWM to load the configuration file again"];
  launchOnLoginItem = [self addItem:@"Launch MWM at Login" action:@selector(updateLaunchState) key:@"" to:menu];
  [self setLaunchOnLoginItemStatus];
  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:@"Quit MWM" action:@selector(terminate:) keyEquivalent:@"q"];
  return menu;
}

// The app menus, shown only while an MWM window is in front. They carry the
// standard shortcuts that window's text fields and tables need.
- (NSMenu *)buildMainMenu {
  NSMenu *main = [[NSMenu alloc] initWithTitle:@"Main"];

  NSMenu *app = [[NSMenu alloc] initWithTitle:@"MWM"];
  [self addItem:@"About MWM" action:@selector(aboutWindow) key:@"" to:app];
  [app addItem:[NSMenuItem separatorItem]];
  [self addItem:@"Configure MWM…" action:@selector(configureSlate) key:@"," to:app];
  [app addItem:[NSMenuItem separatorItem]];
  [app addItemWithTitle:@"Hide MWM" action:@selector(hide:) keyEquivalent:@"h"];
  [[app addItemWithTitle:@"Hide Others" action:@selector(hideOtherApplications:) keyEquivalent:@"h"]
    setKeyEquivalentModifierMask:NSEventModifierFlagCommand | NSEventModifierFlagOption];
  [app addItemWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];
  [app addItem:[NSMenuItem separatorItem]];
  [app addItemWithTitle:@"Quit MWM" action:@selector(terminate:) keyEquivalent:@"q"];

  NSMenu *edit = [[NSMenu alloc] initWithTitle:@"Edit"];
  [edit addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
  [[edit addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"z"]
    setKeyEquivalentModifierMask:NSEventModifierFlagCommand | NSEventModifierFlagShift];
  [edit addItem:[NSMenuItem separatorItem]];
  [edit addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
  [edit addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
  [edit addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
  [edit addItemWithTitle:@"Delete" action:@selector(delete:) keyEquivalent:@""];
  [edit addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];

  NSMenu *window = [[NSMenu alloc] initWithTitle:@"Window"];
  [window addItemWithTitle:@"Close" action:@selector(performClose:) keyEquivalent:@"w"];
  [window addItemWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
  [window addItemWithTitle:@"Zoom" action:@selector(performZoom:) keyEquivalent:@""];
  [window addItem:[NSMenuItem separatorItem]];
  [window addItemWithTitle:@"Bring All to Front" action:@selector(arrangeInFront:) keyEquivalent:@""];
  [NSApp setWindowsMenu:window];

  for (NSMenu *submenu in @[app, edit, window]) {
    NSMenuItem *item = [main addItemWithTitle:[submenu title] action:nil keyEquivalent:@""];
    [item setSubmenu:submenu];
  }
  return main;
}

#pragma mark - Launch

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
  [NSApp setMainMenu:[self buildMainMenu]];
  if (NSClassFromString(@"XCTestCase") != nil ||
      [[[NSProcessInfo processInfo] environment] objectForKey:@"XCTestConfigurationFilePath"] != nil) {
    return;
  }
  cmdTabBinding = -1;
  cmdShiftTabBinding = -1;
  currentHintOperation = nil;
  currentGridOperation = nil;

  [self setModalHotKeyRefs:[NSMutableDictionary dictionary]];
  [self setModalIdToKey:[NSMutableDictionary dictionary]];
  [self setCurrentModalHotKeyRefs:[NSMutableArray array]];

  statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength: NSVariableStatusItemLength];
  [statusItem setMenu:[self buildStatusMenu]];
  [[statusItem button] setImage:[self statusImageNamed:@"status"]];

  // Ensure no timer exists
  @synchronized(timerLock) {
    currentTimer = nil;
    timerLock = [[NSObject alloc] init];
  }

  @synchronized(keyUpLock) {
    keyUpLock = [[NSObject alloc] init];
  }

  // Check if Accessibility API is enabled
  NSDictionary *options = @{(__bridge id)kAXTrustedCheckOptionPrompt: @YES};
  BOOL isTrusted = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
  if (!isTrusted) {
    SlateLogger(@"Accessibility permission not yet granted; system authorization prompt requested.");
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Accessibility Permission Required"];
    [alert setInformativeText:@"MWM requires Accessibility permissions to manage windows.\n\nIf MWM is already enabled in System Settings, macOS requires you to remove it (using the '-' button) and re-add it because the application binary has been updated."];
    [alert setAlertStyle:NSAlertStyleWarning];
    [alert addButtonWithTitle:@"Open System Settings"];
    [alert addButtonWithTitle:@"Continue Anyway"];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
      [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
    }
  }

  // Read Config
  [self loadConfig];

  // Register Hot Keys
  [self registerHotKeys];

  [self createSnapshotOperations];

  // Setup App list
  NSArray *rapps = [[RunningApplications getInstance] apps];
  if ([rapps count] > 0) [AccessibilityWrapper focusMainWindow:[rapps objectAtIndex:0]];

  selfRef = self;
}

- (BOOL)isInLoginItems {
  if (@available(macOS 13.0, *)) {
    return [[SMAppService mainAppService] status] == SMAppServiceStatusEnabled;
  }
  return [self legacyIsInLoginItems];
}

- (void)addToLoginItems {
  if (@available(macOS 13.0, *)) {
    NSError *error = nil;
    if (![[SMAppService mainAppService] registerAndReturnError:&error]) {
      SlateLogger(@"ERROR: Could not add MWM to login items: %@", error);
    }
    return;
  }
  [self legacyAddToLoginItems];
}

- (void)deleteFromLoginItems {
  if (@available(macOS 13.0, *)) {
    NSError *error = nil;
    if (![[SMAppService mainAppService] unregisterAndReturnError:&error]) {
      SlateLogger(@"ERROR: Could not remove MWM from login items: %@", error);
    }
    return;
  }
  [self legacyDeleteFromLoginItems];
}

// Fallback for macOS 12, where SMAppService is unavailable. LSSharedFileList is
// deprecated but is the only way to manage login items there without a helper app.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

- (BOOL)legacyIsInLoginItems {
  NSString *appPath = [[NSBundle mainBundle] bundlePath];
  LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
  if (!loginItems) return NO;
  BOOL found = NO;
  UInt32 seedValue;
  NSArray *loginItemsArray = CFBridgingRelease(LSSharedFileListCopySnapshot(loginItems, &seedValue));
  for (id item in loginItemsArray) {
    CFURLRef url = NULL;
    if (LSSharedFileListItemResolve((__bridge LSSharedFileListItemRef)item, 0, &url, NULL) == noErr && url) {
      NSString *urlPath = [(__bridge NSURL *)url path];
      CFRelease(url);
      if ([urlPath isEqualToString:appPath]) {
        found = YES;
        break;
      }
    }
  }
  CFRelease(loginItems);
  return found;
}

- (void)legacyAddToLoginItems {
  NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
  LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
  if (!loginItems) return;
  LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemLast, NULL, NULL,
                                                               (__bridge CFURLRef)url, NULL, NULL);
  if (item) CFRelease(item);
  CFRelease(loginItems);
}

- (void)legacyDeleteFromLoginItems {
  NSString *appPath = [[NSBundle mainBundle] bundlePath];
  LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
  if (!loginItems) return;
  UInt32 seedValue;
  NSArray *loginItemsArray = CFBridgingRelease(LSSharedFileListCopySnapshot(loginItems, &seedValue));
  for (id item in loginItemsArray) {
    LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)item;
    CFURLRef url = NULL;
    if (LSSharedFileListItemResolve(itemRef, 0, &url, NULL) == noErr && url) {
      NSString *urlPath = [(__bridge NSURL *)url path];
      CFRelease(url);
      if ([urlPath isEqualToString:appPath]) {
        LSSharedFileListItemRemove(loginItems, itemRef);
      }
    }
  }
  CFRelease(loginItems);
}

#pragma clang diagnostic pop

@end
