//
//  JSController.m
//  Slate
//
//  Created by Alex Morega on 2013-01-16.
//

#import "JSController.h"
#import "Binding.h"
#import "SlateLogger.h"
#import "SlateConfig.h"
#import "JSInfoWrapper.h"
#import "JSScreenWrapper.h"
#import "Constants.h"
#import "JSOperation.h"
#import "ShellUtils.h"
#import "JSApplicationWrapper.h"
#import "JSOperationWrapper.h"

@implementation JSController

@synthesize context;
@synthesize functions;
@synthesize eventCallbacks;

static JSController *_instance = nil;

- (JSController *) init {
  self = [super init];
  if (self) {
    inited = NO;
    self.functions = [NSMutableDictionary dictionary];
    self.eventCallbacks = [NSMutableDictionary dictionary];
  }
  return self;
}

- (id)run:(NSString*)code {
  [self initializeWebView];
  JSValue *data = [context evaluateScript:code];
  if (context.exception) {
    NSString *reason = [context.exception toString];
    context.exception = nil;
    @throw([NSException exceptionWithName:@"JavaScript Error" reason:reason userInfo:nil]);
  }
  return [self unmarshall:data];
}

- (NSString *)genFuncKey {
  return [NSString stringWithFormat:@"javascript:function[%ld]", [functions count]];
}

- (NSString *)addCallableFunction:(JSValue *)function {
  NSString *key = [self genFuncKey];
  [functions setObject:function forKey:key];
  return key;
}

- (id)runCallableFunction:(NSString *)key {
  JSValue *func = [functions objectForKey:key];
  if (func == nil) { return nil; }
  return [self runFunction:func];
}

- (id)runFunction:(JSValue *)function {
  if (function == nil || [function isUndefined] || [function isNull]) return nil;
  JSValue *res = [function callWithArguments:@[]];
  return [self unmarshall:res];
}

- (id)runFunction:(JSValue *)function withArg:(id)arg {
  if (function == nil || [function isUndefined] || [function isNull]) return nil;
  id mArg = [self marshall:arg];
  JSValue *res = [function callWithArguments:(mArg ? @[mArg] : @[])];
  return [self unmarshall:res];
}

- (id)runFunction:(JSValue *)function withArg:(id)arg secondArg:(id)arg2 {
  if (function == nil || [function isUndefined] || [function isNull]) return nil;
  id m1 = [self marshall:arg];
  id m2 = [self marshall:arg2];
  NSMutableArray *args = [NSMutableArray array];
  if (m1) [args addObject:m1];
  if (m2) [args addObject:m2];
  JSValue *res = [function callWithArguments:args];
  return [self unmarshall:res];
}

- (BOOL)runFile:(NSString*)path {
  NSError *err = nil;
  NSString *fileString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
  if (err == nil && fileString != nil) {
    [context evaluateScript:fileString];
    if (context.exception) {
      NSString *reason = [context.exception toString];
      context.exception = nil;
      @throw([NSException exceptionWithName:@"JavaScript Error" reason:reason userInfo:nil]);
    }
    return YES;
  }
  return NO;
}

- (void)initializeWebView {
  if (inited) { return; }
  context = [[JSContext alloc] init];
  context.exceptionHandler = ^(JSContext *ctx, JSValue *exception) {
    SlateLogger(@"JavaScript Exception: %@", exception);
  };
  context[@"window"] = context.globalObject;
  context[@"_controller"] = self;
  context[@"_info"] = [JSInfoWrapper getInstance];

  @try {
    [self runFile:[[NSBundle mainBundle] pathForResource:@"underscore" ofType:@"js"]];
    [self runFile:[[NSBundle mainBundle] pathForResource:@"utils" ofType:@"js"]];
    [self runFile:[[NSBundle mainBundle] pathForResource:@"managed-config" ofType:@"js"]];
    [self runFile:[[NSBundle mainBundle] pathForResource:@"initialize" ofType:@"js"]];
  } @catch (NSException *ex) {
    SlateLogger(@"   ERROR %@",[ex name]);
    NSAlert *alert = [SlateConfig warningAlertWithKeyEquivalents: [NSArray arrayWithObjects:@"Quit", @"Skip", nil]];
    [alert setMessageText:[ex name]];
    [alert setInformativeText:[ex reason]];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
      SlateLogger(@"User selected exit");
      [NSApp terminate:nil];
    }
  }
  inited = YES;
}

- (BOOL)loadConfigFileWithPath:(NSString *)path {
  [self initializeWebView];
  @try {
    return [self runFile:[path stringByExpandingTildeInPath]];
  } @catch (NSException *ex) {
    SlateLogger(@"   ERROR %@",[ex name]);
    NSAlert *alert = [SlateConfig warningAlertWithKeyEquivalents: [NSArray arrayWithObjects:@"Quit", @"Skip", nil]];
    [alert setMessageText:[ex name]];
    [alert setInformativeText:[ex reason]];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
      SlateLogger(@"User selected exit");
      [NSApp terminate:nil];
    }
  }
  return NO;
}

- (void)configFunction:(NSString *)key callback:(JSValue *)callback {
  NSString *fkey = [self addCallableFunction:callback];
  [[[SlateConfig getInstance] configs] setValue:[NSString stringWithFormat:@"_javascript_::%@", fkey] forKey:key];
}

- (void)configNative:(NSString *)key callback:(id)callback {
  [[[SlateConfig getInstance] configs] setValue:[NSString stringWithFormat:@"%@", callback] forKey:key];
}

- (void)bindFunction:(NSString *)hotkey callback:(JSValue *)callback repeat:(id)_repeat {
  JSOperation *op = [JSOperation jsOperationWithFunction:callback];
  BOOL repeat = NO;
  if (_repeat != nil && ([_repeat isKindOfClass:[NSNumber class]] || [_repeat isKindOfClass:[NSValue class]] || [_repeat isKindOfClass:[NSString class]])) {
    repeat = [_repeat boolValue];
  } else {
    repeat = [Operation isRepeatOnHoldOp:[op opName]];
  }
  @try {
    Binding *bind = [[Binding alloc] initWithKeystroke:hotkey operation:op repeat:repeat];
    [[SlateConfig getInstance] addBinding:bind];
  } @catch (NSException *ex) {
    SlateLogger(@"   ERROR %@",[ex name]);
    NSAlert *alert = [SlateConfig warningAlertWithKeyEquivalents: [NSArray arrayWithObjects:@"Quit", @"Skip", nil]];
    [alert setMessageText:[ex name]];
    [alert setInformativeText:[ex reason]];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
      SlateLogger(@"User selected exit");
      [NSApp terminate:nil];
    }
  }
}

- (void)bindNative:(NSString *)hotkey callback:(JSOperationWrapper *)opWrapper repeat:(id)_repeat {
  Operation *op = [opWrapper op];
  BOOL repeat = NO;
  if (_repeat != nil && ([_repeat isKindOfClass:[NSNumber class]] || [_repeat isKindOfClass:[NSValue class]] || [_repeat isKindOfClass:[NSString class]])) {
    repeat = [_repeat boolValue];
  } else {
    repeat = [Operation isRepeatOnHoldOp:[op opName]];
  }
  @try {
    Binding *bind = [[Binding alloc] initWithKeystroke:hotkey operation:op repeat:repeat];
    [[SlateConfig getInstance] addBinding:bind];
  } @catch (NSException *ex) {
    SlateLogger(@"   ERROR %@",[ex name]);
    NSAlert *alert = [SlateConfig warningAlertWithKeyEquivalents: [NSArray arrayWithObjects:@"Quit", @"Skip", nil]];
    [alert setMessageText:[ex name]];
    [alert setInformativeText:[ex reason]];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
      SlateLogger(@"User selected exit");
      [NSApp terminate:nil];
    }
  }
}

// Binds a legacy-style operation string, going through the same parser as
// `bind` lines in ~/.slate so behavior (default repeat, switch modifiers) matches.
- (void)bindString:(NSString *)hotkey operation:(NSString *)opString repeat:(id)_repeat {
  @try {
    Binding *bind = [[Binding alloc] initWithString:[NSString stringWithFormat:@"bind %@ %@", hotkey, opString]];
    if ([_repeat isKindOfClass:[NSNumber class]]) {
      [bind setRepeat:[_repeat boolValue]];
    }
    [[SlateConfig getInstance] addBinding:bind];
  } @catch (NSException *ex) {
    SlateLogger(@"   ERROR %@",[ex name]);
    NSAlert *alert = [SlateConfig warningAlertWithKeyEquivalents: [NSArray arrayWithObjects:@"Quit", @"Skip", nil]];
    [alert setMessageText:[ex name]];
    [alert setInformativeText:[ex reason]];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
      SlateLogger(@"User selected exit");
      [NSApp terminate:nil];
    }
  }
}

- (NSString *)layout:(NSString *)name hash:(id)hash {
  NSMutableDictionary *dict = [[self unmarshall:hash] mutableCopy];
  if (![dict isKindOfClass:[NSDictionary class]]) return nil;
  for (NSString *app in [dict allKeys]) {
    id tmpDict = [dict objectForKey:app];
    if (![tmpDict isKindOfClass:[NSDictionary class]]) {
      continue;
    }
    NSMutableDictionary *appDict = [tmpDict mutableCopy];
    if ([appDict objectForKey:OPT_OPERATIONS] == nil) {
      continue;
    }
    id _operations = [appDict objectForKey:OPT_OPERATIONS];
    NSMutableArray *ops = [NSMutableArray array];
    if ([_operations isKindOfClass:[Operation class]]) {
      [ops addObject:_operations];
    } else if ([_operations isKindOfClass:[JSValue class]]) {
      Operation *op = [JSOperation jsOperationWithFunction:_operations];
      if (op != nil) { [ops addObject:op]; }
    } else if ([_operations isKindOfClass:[NSArray class]]) {
      for (id obj in _operations) {
        if ([obj isKindOfClass:[Operation class]]) {
          [ops addObject:obj];
        } else if ([obj isKindOfClass:[JSValue class]]) {
          Operation *op = [JSOperation jsOperationWithFunction:obj];
          if (op != nil) { [ops addObject:op]; }
        }
      }
    }
    if ([ops count] == 0) { continue; }
    [appDict setObject:ops forKey:OPT_OPERATIONS];
    [dict setObject:appDict forKey:app];
  }
  if (![[SlateConfig getInstance] addLayout:name dict:dict]) { return nil; }
  return name;
}

- (void)defaultAction:(id)config toAction:(id)_action {
  id screenConfig = [self unmarshall:config];
  if (![screenConfig isKindOfClass:[NSNumber class]] && ![screenConfig isKindOfClass:[NSValue class]] &&
      ![screenConfig isKindOfClass:[NSString class]] && ![screenConfig isKindOfClass:[NSArray class]]) {
    return;
  }
  id action = [self unmarshall:_action];
  id name = nil;
  if ([action isKindOfClass:[NSString class]]) {
    name = action;
  } else if ([action isKindOfClass:[JSValue class]]) {
    name = [JSOperation jsOperationWithFunction:action];
  } else {
    return;
  }
  [[SlateConfig getInstance] addDefault:screenConfig layout:name];
}

- (NSString *)shell:(NSString *)commandAndArgs wait:(id)wait path:(id)path {
  BOOL shouldWait = NO;
  if (wait != nil && ![wait isKindOfClass:[NSNull class]]) {
    shouldWait = [wait boolValue];
  }
  NSString *targetPath = nil;
  if (path != nil && [path isKindOfClass:[NSString class]]) {
    targetPath = path;
  }
  return [ShellUtils run:commandAndArgs wait:shouldWait path:targetPath];
}

- (JSOperationWrapper *)operation:(NSString *)name options:(id)opts {
  @try {
    return [JSOperationWrapper operation:name options:opts];
  } @catch (NSException *ex) {
    SlateLogger(@"   ERROR %@",[ex name]);
    NSAlert *alert = [SlateConfig warningAlertWithKeyEquivalents: [NSArray arrayWithObjects:@"Quit", @"Skip", nil]];
    [alert setMessageText:[ex name]];
    [alert setInformativeText:[ex reason]];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
      SlateLogger(@"User selected exit");
      [NSApp terminate:nil];
    }
  }
  return nil;
}

- (BOOL)doOperation:(NSString *)op options:(id)opts {
  @try {
    id options = [self unmarshall:opts];
    if ([options isKindOfClass:[NSDictionary class]]) {
      return [Operation doOperation:op options:options aw:[[AccessibilityWrapper alloc] init] sw:[[ScreenWrapper alloc] init]];
    }
  } @catch (NSException *ex) {
    SlateLogger(@"   ERROR %@",[ex name]);
    NSAlert *alert = [SlateConfig warningAlertWithKeyEquivalents: [NSArray arrayWithObjects:@"Quit", @"Skip", nil]];
    [alert setMessageText:[ex name]];
    [alert setInformativeText:[ex reason]];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
      SlateLogger(@"User selected exit");
      [NSApp terminate:nil];
    }
  }
  return NO;
}

- (JSOperationWrapper *)operationFromString:(NSString *)opString {
  return [JSOperationWrapper operationFromString:opString];
}

- (BOOL)source:(NSString *)path {
  return [[SlateConfig getInstance] loadConfigFileWithPath:path];
}

- (void)log:(id)msg {
  NSLog(@"%@", msg);
}

- (BOOL)isValidEvent:(NSString *)what {
  return [what isEqualToString:@"windowClosed"] || [what isEqualToString:@"windowMoved"] || [what isEqualToString:@"windowResized"] ||
         [what isEqualToString:@"windowOpened"] || [what isEqualToString:@"windowFocused"] || [what isEqualToString:@"windowTitleChanged"] ||
         [what isEqualToString:@"appClosed"] || [what isEqualToString:@"appOpened"] || [what isEqualToString:@"appHidden"] ||
         [what isEqualToString:@"appUnhidden"] || [what isEqualToString:@"appDeactivated"] || [what isEqualToString:@"appActivated"] ||
         [what isEqualToString:@"screenConfigurationChanged"];
}

- (void)on:(NSString *)what do:(JSValue *)callback {
  if (![self isValidEvent:what]) {
    SlateLogger(@"   ERROR: Invalid Event %@",what);
    NSAlert *alert = [SlateConfig warningAlertWithKeyEquivalents: [NSArray arrayWithObjects:@"Quit", @"Skip", nil]];
    [alert setMessageText:@"ERROR: Invalid Event"];
    [alert setInformativeText:what];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
      SlateLogger(@"User selected exit");
      [NSApp terminate:nil];
    }
  }
  if ([what isEqualToString:@"windowMoved"]) {
    [[SlateConfig getInstance] setConfig:JS_RECEIVE_MOVE_EVENT to:@"true"];
  } else if ([what isEqualToString:@"windowResized"]) {
    [[SlateConfig getInstance] setConfig:JS_RECEIVE_RESIZE_EVENT to:@"true"];
  }
  NSMutableArray *callbacks = [[self eventCallbacks] objectForKey:what];
  if (callbacks == nil) {
    callbacks = [NSMutableArray array];
    [[self eventCallbacks] setObject:callbacks forKey:what];
  }
  [callbacks addObject:callback];
}

- (void)runCallbacks:(NSString *)what payload:(id)payload {
  NSArray *callbacks = [[self eventCallbacks] objectForKey:what];
  if (callbacks == nil || [callbacks count] == 0) { return; }
  for (JSValue *callback in callbacks) {
    [self runFunction:callback withArg:what secondArg:payload];
  }
}

- (id)marshall:(id)obj {
  if (obj == nil) {
    return [JSValue valueWithUndefinedInContext:context];
  }
  if ([obj isKindOfClass:[JSValue class]]) {
    return obj;
  }
  return [JSValue valueWithObject:obj inContext:context];
}

- (id)unmarshall:(id)obj {
  if (obj == nil) {
    return nil;
  }
  if ([obj isKindOfClass:[JSValue class]]) {
    JSValue *val = (JSValue *)obj;
    if ([val isUndefined] || [val isNull]) return nil;
    if ([val isBoolean]) return [NSNumber numberWithBool:[val toBool]];
    if ([val isNumber]) return [val toNumber];
    if ([val isString]) return [val toString];
    if ([val isArray]) {
      NSArray *arr = [val toArray];
      NSMutableArray *res = [NSMutableArray arrayWithCapacity:[arr count]];
      for (id item in arr) {
        id u = [self unmarshall:item];
        if (u) [res addObject:u];
      }
      return res;
    }
    id nativeObj = [val toObject];
    if ([nativeObj isKindOfClass:[JSOperationWrapper class]]) {
      return [nativeObj op];
    }
    if ([nativeObj isKindOfClass:[JSScreenWrapper class]] || [nativeObj isKindOfClass:[JSApplicationWrapper class]]) {
      return [nativeObj toString];
    }
    NSString *type = [self jsTypeof:val];
    if ([@"function" isEqualToString:type]) {
      return val;
    }
    if ([val isObject]) {
      NSDictionary *dict = [val toDictionary];
      NSMutableDictionary *res = [NSMutableDictionary dictionaryWithCapacity:[dict count]];
      for (NSString *key in [dict allKeys]) {
        id u = [self unmarshall:[dict objectForKey:key]];
        if (u) [res setObject:u forKey:key];
      }
      return res;
    }
    return [val toObject];
  }
  if ([obj isKindOfClass:[JSOperationWrapper class]]) {
    return [obj op];
  }
  return obj;
}

- (NSString *)jsTypeof:(id)obj {
  if ([obj isKindOfClass:[JSValue class]]) {
    JSValue *val = (JSValue *)obj;
    if ([val isString]) return @"string";
    if ([val isArray]) return @"array";
    if ([val isNumber]) return @"number";
    if ([val isBoolean]) return @"boolean";
    if ([val isUndefined]) return @"undefined";
    if ([val isNull]) return @"null";
    if ([val isObject]) {
      JSValue *typeOfFunc = [context evaluateScript:@"(function(x) { return typeof x; })"];
      JSValue *res = [typeOfFunc callWithArguments:@[val]];
      return [res toString];
    }
  }
  return @"unknown";
}

+ (JSController *)getInstance {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _instance = [[[JSController class] alloc] init];
  });
  return _instance;
}

@end
