//
//  DPHueLightGroup.m
//  DPHue
//
//  This class is in the public domain.
//  Created by James Reichley on 6/2/15.
//
//  https://github.com/danparsons/DPHue

#import "DPHueLightGroup.h"
#import "DPJSONConnection.h"
#import "DPHueBridge.h"
#import "NSNumber+Clamp.h"

@interface DPHueLightGroup ()

@property (nonatomic, strong) NSMutableDictionary *pendingChanges;
@property (nonatomic, assign) BOOL writeSuccess;
@property (nonatomic, strong) NSMutableString *writeMessage;

@end


@implementation DPHueLightGroup

#pragma mark - Initializers

- (instancetype)initWithBridge:(DPHueBridge *)aBridge {
    if ( self = [super init] )
    {
        [self performCommonInit];
        _bridge = aBridge;
    }
    
    return self;
}

- (void)performCommonInit
{
  self.holdUpdates = YES;
  self.pendingChanges = [NSMutableDictionary new];
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)coder
{
  if ( self = [super init] )
  {
    [self performCommonInit];
    
    _name = [coder decodeObjectForKey:@"name"];
    _brightness = [coder decodeObjectForKey:@"brightness"];
    _colorMode = [coder decodeObjectForKey:@"colorMode"];
    _hue = [coder decodeObjectForKey:@"hue"];
    _on = [[coder decodeObjectForKey:@"on"] boolValue];
    _xy = [coder decodeObjectForKey:@"xy"];
    _colorTemperature = [coder decodeObjectForKey:@"colorTemperature"];
    _alert = [coder decodeObjectForKey:@"alert"];
    _saturation = [coder decodeObjectForKey:@"saturation"];
    _number = [coder decodeObjectForKey:@"number"];
    _host = [coder decodeObjectForKey:@"host"];
    _username = [coder decodeObjectForKey:@"username"];
    _lightIds = [coder decodeObjectForKey:@"lightIds"];
  }
  
  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeObject:_name forKey:@"name"];
  [coder encodeObject:_brightness forKey:@"brightness"];
  [coder encodeObject:_colorMode forKey:@"colorMode"];
  [coder encodeObject:_hue forKey:@"hue"];
  [coder encodeObject:[NSNumber numberWithBool:self->_on] forKey:@"on"];
  [coder encodeObject:_xy forKey:@"xy"];
  [coder encodeObject:_colorTemperature forKey:@"colorTemperature"];
  [coder encodeObject:_alert forKey:@"alert"];
  [coder encodeObject:_saturation forKey:@"saturation"];
  [coder encodeObject:_number forKey:@"number"];
  [coder encodeObject:_host forKey:@"host"];
  [coder encodeObject:_username forKey:@"username"];
  [coder encodeObject:_lightIds forKey:@"lightIds"];
}

#pragma mark - Setters that update pendingChanges

- (void)setOn:(BOOL)on
{
  _on = on;
  self.pendingChanges[@"on"] = [NSNumber numberWithBool:on];
  if (!self.holdUpdates)
    [self write];
}

- (void)setBrightness:(NSNumber *)brightness
{
  _brightness = [brightness clampFrom: @0 to: @255];
  self.pendingChanges[@"bri"] = _brightness;
  if (!self.holdUpdates)
    [self write];
}

- (void)setHue:(NSNumber *)hue
{
  _hue = [hue clampFrom: @0 to: @65535];
  self.pendingChanges[@"hue"] = _hue;
  if (!self.holdUpdates)
    [self write];
}

- (void)setXy:(NSArray *)xy
{
  _xy = xy;
  self.pendingChanges[@"xy"] = xy;
  if (!self.holdUpdates)
    [self write];
}

- (void)setColorTemperature:(NSNumber *)colorTemperature
{
  _colorTemperature = [colorTemperature clampFrom: @154 to: @500];
  self.pendingChanges[@"ct"] = _colorTemperature;
  if (!self.holdUpdates)
    [self write];
}

- (void)setAlert:(NSString *)alert
{
  _alert = alert;
  self.pendingChanges[@"alert"] = alert;
  if (!self.holdUpdates)
    [self write];
}

- (void)setSaturation:(NSNumber *)saturation
{
  _saturation = [saturation clampFrom: @0 to:@255];
  self.pendingChanges[@"sat"] = _saturation;
  if (!self.holdUpdates)
    [self write];
}

- (BOOL)hasPendingChanges {
    return self.pendingChanges.count > 0;
}

#pragma mark - Public API

- (void)read
{
  NSURLRequest *request = [self requestForGettingGroupState];
  DPJSONConnection *connection = [[DPJSONConnection alloc] initWithRequest:request sender:self];
  connection.completionBlock = ^(DPHueLightGroup *sender, id json, NSError *err) {
    if ( err )
      return;
    
    [sender parseGroupStateGet:json];
  };
  
    if (_bridge) {
        [_bridge queueCommand:connection maxPerSecond:1];
    } else {
        [connection start];
    }
}

- (void)writeAllWithCompletionHandler:(void (^ _Nullable )(NSError * _Nullable))completion
{
  if (!self.on)
  {
    // If bulb is off, it forbids changes, so send none
    // except to turn it off
    self.pendingChanges[@"on"] = [NSNumber numberWithBool:self.on];
    [self write];
    return;
  }
  
  self.pendingChanges[@"on"] = [NSNumber numberWithBool:self.on];
  self.pendingChanges[@"alert"] = self.alert;
  self.pendingChanges[@"bri"] = self.brightness;
  
  // colorMode is set by the bulb itself
  // whichever color value you sent it last determines the mode
  if ([self.colorMode isEqualToString:@"hue"]) {
    self.pendingChanges[@"hue"] = self.hue;
    self.pendingChanges[@"sat"] = self.saturation;
  }
  
  if ([self.colorMode isEqualToString:@"xy"]) {
    self.pendingChanges[@"xy"] = self.xy;
  }
  
  if ([self.colorMode isEqualToString:@"ct"]) {
    self.pendingChanges[@"ct"] = self.colorTemperature;
  }
  
  [self writeWithCompletionHandler:completion];
}

- (void)writeAll {
    [self writeAllWithCompletionHandler:nil];
}

- (void)writeWithCompletionHandler:(void(^ _Nullable )(NSError* _Nullable error))completion
{
  if (!self.pendingChanges.count)
    return;
  
  // This needs to be set each time you send an update, or else it uses a default
  // value of 4 (400ms):
  // http://www.developers.meethue.com/watch-transition-time
  if (self.transitionTime)
  {
    self.pendingChanges[@"transitiontime"] = self.transitionTime;
  }
  
  NSURLRequest *request = [self requestForSettingGroupState:self.pendingChanges];
  
  DPJSONConnection *connection = [[DPJSONConnection alloc] initWithRequest:request sender:self];
  connection.completionBlock = ^(DPHueLightGroup *sender, id json, NSError *err) {
    if ( err ) {
      if (completion) {
        completion(err);
      }
      return;
    }

    [sender parseGroupStateSet:json];

    if (completion) {
      if (self.writeSuccess) {
        completion(nil);
      }
      else {
        completion([NSError errorWithDomain:@"DPHue" code:2 userInfo:@{NSLocalizedDescriptionKey: self.writeMessage}]);
      }
    }
  };
  
    if (_bridge) {
        [_bridge queueCommand:connection maxPerSecond:1];
    } else {
        [connection start];
    }
}

- (void)write {
    [self writeWithCompletionHandler:nil];
}


- (NSString *)description
{
  NSMutableString *descr = [NSMutableString new];
  [descr appendFormat:@"Group Name: %@\n", self.name];
  [descr appendFormat:@"\tLights: [%@]\n", [self.lightIds componentsJoinedByString:@","]];
  [descr appendFormat:@"\tNumber: %@\n", self.number];
  [descr appendFormat:@"\tOn: %@\n", self.on ? @"True" : @"False"];
  [descr appendFormat:@"\tBrightness: %@\n", self.brightness];
  [descr appendFormat:@"\tColor Mode: %@\n", self.colorMode];
  [descr appendFormat:@"\tHue: %@\n", self.hue];
  [descr appendFormat:@"\tSaturation: %@\n", self.saturation];
  [descr appendFormat:@"\tColor Temperature: %@\n", self.colorTemperature];
  [descr appendFormat:@"\tAlert: %@\n", self.alert];
  [descr appendFormat:@"\txy: %@\n", self.xy];
  [descr appendFormat:@"\tPending changes: %@\n", self.pendingChanges];
  return descr;
}


#pragma mark - HueAPIRequestGeneration

- (NSURL *)baseURL
{
  NSAssert([self.host length], @"No host set");
  NSAssert([self.username length], @"No username set");
  NSAssert(self.number != nil, @"No light number set");
  
  NSString *basePath = [NSString stringWithFormat:@"http://%@/api/%@/groups/%@",
                        self.host, self.username, self.number];
  return [NSURL URLWithString:basePath];
}

- (NSURLRequest *)requestForCreatingWithName:(NSString *)groupName lightIds:(NSArray *)lightIds
{
  NSParameterAssert([groupName length] && lightIds.count);
  NSAssert([self.host length], @"No host set");
  NSAssert([self.username length], @"No username set");
  
  NSString *basePath = [NSString stringWithFormat:@"http://%@/api/%@/groups",
                        self.host, self.username];
  NSURL *url = [NSURL URLWithString:basePath];
  
  NSMutableArray *stringifiedLightIds = [NSMutableArray array];
  for (NSNumber *lightId in lightIds) {
    [stringifiedLightIds addObject:[lightId stringValue]];
  }
  NSDictionary *groupDict = @{@"name": groupName, @"lights": stringifiedLightIds};
  // JPR TODO: pass and check error
  NSData *groupJson = [NSJSONSerialization dataWithJSONObject:groupDict options:0 error:nil];
  NSMutableURLRequest *request = [NSMutableURLRequest new];
  request.URL = url;
  request.HTTPMethod = @"POST";
  request.HTTPBody = groupJson;
  return [request copy];
}

- (NSURLRequest *)requestForUpdatingWithName:(NSString *)groupName lightIds:(NSArray *)lightIds
{
  NSURL *url = [self baseURL];
  
  NSMutableArray *stringifiedLightIds = [NSMutableArray array];
  for (NSNumber *lightId in lightIds) {
    [stringifiedLightIds addObject:[lightId stringValue]];
  }
  NSDictionary *groupDict = @{@"name": groupName, @"lights": stringifiedLightIds};
  // JPR TODO: pass and check error
  NSData *groupJson = [NSJSONSerialization dataWithJSONObject:groupDict options:0 error:nil];
  NSMutableURLRequest *request = [NSMutableURLRequest new];
  request.URL = url;
  request.HTTPMethod = @"PUT";
  request.HTTPBody = groupJson;
  return [request copy];
}

- (NSURLRequest *)requestForGettingGroupState
{
  NSURL *url = [self baseURL];
  
  NSURLRequest *request = [NSURLRequest requestWithURL:url];
  return request;
}

- (NSURLRequest *)requestForSettingGroupState:(NSDictionary *)state
{
  NSURL *url = [[self baseURL] URLByAppendingPathComponent:@"action"];
  
  // JPR TODO: pass and check error
  NSData *json = [NSJSONSerialization dataWithJSONObject:state options:0 error:nil];
  NSMutableURLRequest *request = [NSMutableURLRequest new];
  request.URL = url;
  request.HTTPMethod = @"PUT";
  request.HTTPBody = json;
  return [request copy];
}


#pragma mark - HueAPIJsonParsing

// POST /groups
- (instancetype)parseGroupCreation:(id)json
{
  // JPR TODO: be more defensive
  NSDictionary *result = [json firstObject];
  // JPR TODO: `valueForKey` instead?
  if ( result[@"success"][@"id"] )
  {
    NSString *idStr = result[@"success"][@"id"];
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^/groups/(\\d+)$"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&error];
    NSTextCheckingResult *match;
    match = [regex firstMatchInString:idStr options:0 range:NSMakeRange(0, [idStr length])];
    if ( match && [match numberOfRanges] == 2 )
    {
      NSRange matchRange = [match rangeAtIndex:1];
      if ( matchRange.location != NSNotFound )
        _number = @([[idStr substringWithRange:matchRange] integerValue]);
    }
  }
  
  return self;
}

// PUT /groups/{id}
- (instancetype)parseGroupUpdate:(id)json
{
  return [self parseGroupStateSet:json];
}

// GET /groups/{id}
- (instancetype)parseGroupStateGet:(id)json
{
  // Set these via ivars to avoid the 'pendingUpdates' logic in the setters
  _name = json[@"name"];
  _brightness = json[@"action"][@"bri"];
  _colorMode = json[@"action"][@"colormode"];
  _hue = json[@"action"][@"hue"];
  _on = [json[@"action"][@"on"] boolValue];
  _xy = json[@"action"][@"xy"];
  _colorTemperature = json[@"action"][@"ct"];
  _alert = json[@"action"][@"alert"];
  _saturation = json[@"action"][@"sat"];
  
  NSMutableArray *tmpLights = [NSMutableArray new];
  for ( NSString *lightId in json[@"lights"] )
  {
    [tmpLights addObject:@([lightId integerValue])];
  }
  _lightIds = tmpLights;
  
  return self;
}

// PUT /groups/{id}/action
- (instancetype)parseGroupStateSet:(id)json
{
  // Loop through all results, if any are not successful, error out
  BOOL errorFound = NO;
  _writeMessage = [NSMutableString new];
  
  for ( NSDictionary *result in json )
  {
    if (result[@"error"])
    {
      errorFound = YES;
      [_writeMessage appendFormat:@"%@\n", result[@"error"]];
    }
    
    if (result[@"success"])
    {
      [_writeMessage appendFormat:@"%@\n", result[@"success"]];
    }
  }
  
  if (errorFound)
  {
    _writeSuccess = NO;
  }
  else
  {
    _writeSuccess = YES;
    // JPR TODO: should this be done unconditionally?
    [_pendingChanges removeAllObjects];
  }
  
  return self;
}

@end
