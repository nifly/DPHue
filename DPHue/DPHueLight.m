//
//  DPHueLight.m
//  DPHue
//
//  This class is in the public domain.
//  Originally created by Dan Parsons in 2012.
//
//  https://github.com/danparsons/DPHue

#import "DPHueLight.h"
#import "DPHueBridge.h"
#import "DPJSONConnection.h"
#import "WSLog.h"


@interface DPHueLight ()

@property (nonatomic, strong) NSMutableDictionary *pendingChanges;
@property (nonatomic, assign) BOOL writeSuccess;
@property (nonatomic, strong) NSMutableString *writeMessage;

@end


@implementation DPHueLight

- (id)initWithBridge:(DPHueBridge *)aBridge
{
    if (self = [super init]) {
        [self performCommonInit];
        _bridge = aBridge;
    }
    return self;
}

- (void)performCommonInit
{
  _number = @-1;
  _username = @"";
  _host = @"";
  _holdUpdates = YES;
  _pendingChanges = [NSMutableDictionary new];
}

- (NSString *)description {
    NSMutableString *descr = [[NSMutableString alloc] init];
    [descr appendFormat:@"Light Name: %@\n", self.name];
    [descr appendFormat:@"\tNumber: %@\n", self.number];
    [descr appendFormat:@"\tType: %@\n", self.type];
    [descr appendFormat:@"\tVersion: %@\n", self.swversion];
    [descr appendFormat:@"\tModel ID: %@\n", self.modelid];
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


#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)coder
{
    if (self = [super init])
    {
        [self performCommonInit];
        _name = [coder decodeObjectForKey:@"name"];
        _modelid = [coder decodeObjectForKey:@"modelid"];
        _swversion = [coder decodeObjectForKey:@"swversion"];
        _brightness = [coder decodeObjectForKey:@"brightness"];
        _colorMode = [coder decodeObjectForKey:@"colorMode"];
        _hue = [coder decodeObjectForKey:@"hue"];
        _type = [coder decodeObjectForKey:@"bulbType"];
        _on = [[coder decodeObjectForKey:@"on"] boolValue];
        _xy = [coder decodeObjectForKey:@"xy"];
        _colorTemperature = [coder decodeObjectForKey:@"colorTemperature"];
        _alert = [coder decodeObjectForKey:@"alert"];
        _saturation = [coder decodeObjectForKey:@"saturation"];
        _number = [coder decodeObjectForKey:@"number"];
        _host = [coder decodeObjectForKey:@"host"];
        _username = [coder decodeObjectForKey:@"username"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_name forKey:@"name"];
    [coder encodeObject:_modelid forKey:@"modelid"];
    [coder encodeObject:_swversion forKey:@"swversion"];
    [coder encodeObject:_brightness forKey:@"brightness"];
    [coder encodeObject:_colorMode forKey:@"colorMode"];
    [coder encodeObject:_hue forKey:@"hue"];
    [coder encodeObject:_type forKey:@"bulbType"];
    [coder encodeObject:[NSNumber numberWithBool:self->_on] forKey:@"on"];
    [coder encodeObject:_xy forKey:@"xy"];
    [coder encodeObject:_colorTemperature forKey:@"colorTemperature"];
    [coder encodeObject:_alert forKey:@"alert"];
    [coder encodeObject:_saturation forKey:@"saturation"];
    [coder encodeObject:_number forKey:@"number"];
    [coder encodeObject:_host forKey:@"host"];
    [coder encodeObject:_username forKey:@"username"];
}


#pragma mark - Setters that update pendingChanges

- (void)setOn:(BOOL)on {
    _on = on;
    self.pendingChanges[@"on"] = [NSNumber numberWithBool:on];
    if (!self.holdUpdates)
        [self write];
}

- (void)setBrightness:(NSNumber *)brightness {
    self.pendingChanges[@"bri"] = (_brightness = @(_clamp_int(brightness.integerValue, 0, 255)));
    if (!self.holdUpdates)
        [self write];
}

- (void)setHue:(NSNumber *)hue {
    self.pendingChanges[@"hue"] = (_hue = @(_clamp_int(hue.integerValue, 0, 65535)));
    if (!self.holdUpdates)
        [self write];
}

// This is the closest I've ever come to unintentionally naming a method "sexy"
- (void)setXy:(NSArray *)xy {
    _xy = xy;
    self.pendingChanges[@"xy"] = xy;
    if (!self.holdUpdates)
        [self write];
}

- (void)setColorTemperature:(NSNumber *)colorTemperature {
    self.pendingChanges[@"ct"] = (_colorTemperature = @(_clamp_int(colorTemperature.integerValue, 154, 500)));
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

- (void)setSaturation:(NSNumber *)saturation {
    self.pendingChanges[@"sat"] = (_saturation = @(_clamp_int(saturation.integerValue, 0, 255)));
    if (!self.holdUpdates)
        [self write];
}

- (BOOL)hasPendingChanges {
    return self.pendingChanges.count > 0;
}

#pragma mark - Public API

- (void)alertLight {
    id pendingChanges = [self.pendingChanges copy];
    
    [self.pendingChanges removeAllObjects];
    self.pendingChanges[@"alert"] = @"select";
    
    [self write];
    
    [self.pendingChanges addEntriesFromDictionary:pendingChanges];
}

- (void)readWithCompletionHandler:(void (^ _Nullable )(NSError * _Nullable))completion {
    NSURLRequest *request = [self requestForGettingLightState];
    DPJSONConnection *connection = [[DPJSONConnection alloc] initWithRequest:request sender:self];
    connection.completionBlock = ^(DPHueLight *sender, id json, NSError *err) {
        if (err) {
            if (completion)
                completion(err);
            return;
        }

        if ([json isKindOfClass:[NSArray class]]) {
          NSString *errorDescription = ((NSArray*)json).firstObject[@"error"][@"description"];
          if (errorDescription) {
            if (completion) {
              completion([NSError errorWithDomain:@"DPHue" code:5 userInfo:@{NSLocalizedDescriptionKey: errorDescription}]);
            }
            return;
          }
        }
        
        [sender parseLightStateGet:json];
        if (completion)
            completion(nil);
    };
    
    if (_bridge) {
        [_bridge queueCommand:connection maxPerSecond:10];
    } else {
        [connection start];
    }
}

- (void)read {
    [self readWithCompletionHandler:nil];
}

- (void)writeAllWithCompletionHandler:(void (^ _Nullable )(NSError * _Nullable))completion {
    if (!self.on) {
        // If bulb is off, it forbids changes, so send none
        // except to turn it off
        self.pendingChanges[@"on"] = [NSNumber numberWithBool:self.on];
        [self writeWithCompletionHandler:completion];
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

- (void)writeWithCompletionHandler:(void(^ _Nullable )(NSError* _Nullable error))onCompleted {
  if (!self.pendingChanges.count)
    return;
  
  // This needs to be set each time you send an update, or else it uses a default
  // value of 4 (400ms):
  // http://www.developers.meethue.com/watch-transition-time
  if (self.transitionTime)
  {
    self.pendingChanges[@"transitiontime"] = self.transitionTime;
  }
  
  NSURLRequest *request = [self requestForSettingLightState:self.pendingChanges];

  DPJSONConnection *connection = [[DPJSONConnection alloc] initWithRequest:request sender:self];
  connection.completionBlock = ^(DPHueLight *sender, id json, NSError *err) {
    if ( err ) {
      if (onCompleted) {
        onCompleted(err);
      }
      return;
    }
    
    [sender parseLightStateSet:json];

    if (onCompleted) {
      if (self.writeSuccess) {
        onCompleted(nil);
      }
      else {
        onCompleted([NSError errorWithDomain:@"DPHue" code:1 userInfo:@{NSLocalizedDescriptionKey: self.writeMessage}]);
      }
    }
  };
   
    if (_bridge) {
        [_bridge queueCommand:connection maxPerSecond:10];
    } else {
        [connection start];
    }
}

- (void)write {
    [self writeWithCompletionHandler:nil];
}


#pragma mark - HueAPIJsonParsingHueAPIRequestGeneration

- (NSString*)address {
    NSAssert([self.username length], @"No username set");
    NSAssert(self.number != nil, @"No light number set");
    return [NSString stringWithFormat:@"/api/%@/lights/%@", self.username, self.number];
}

- (NSURL *)baseURL {
  NSAssert([self.host length], @"No host set");
  NSAssert([self.username length], @"No username set");
  NSAssert(self.number != nil, @"No light number set");
  
  NSString *basePath = [NSString stringWithFormat:@"http://%@/api/%@/lights/%@",
                        self.host, self.username, self.number];
  return [NSURL URLWithString:basePath];
}

- (NSURLRequest *)requestForGettingLightState {
    return [NSURLRequest requestWithURL:[self baseURL]];;
}

- (NSURLRequest *)requestForSettingLightState:(NSDictionary *)state
{
  NSURL *url = [[self baseURL] URLByAppendingPathComponent:@"state"];
  
  // JPR TODO: pass and check error
  NSData *json = [NSJSONSerialization dataWithJSONObject:state options:0 error:nil];
  NSMutableURLRequest *request = [NSMutableURLRequest new];
  request.URL = url;
  request.HTTPMethod = @"PUT";
  request.HTTPBody = json;
  return [request copy];
}


#pragma mark - HueAPIJsonParsing

// GET /lights/{id}
- (instancetype)parseLightStateGet:(id)json
{
  // Set these via ivars to avoid the 'pendingUpdates' logic in the setters
  _name = json[@"name"];
  _modelid = json[@"modelid"];
  _swversion = json[@"swversion"];
  _type = json[@"type"];
  _brightness = json[@"state"][@"bri"];
  _colorMode = json[@"state"][@"colormode"];
  _hue = json[@"state"][@"hue"];
  _on = [json[@"state"][@"on"] boolValue];
  _reachable = [json[@"state"][@"reachable"] boolValue];
  _xy = json[@"state"][@"xy"];
  _colorTemperature = json[@"state"][@"ct"];
  _alert = json[@"state"][@"alert"];
  _saturation = json[@"state"][@"sat"];
  
  return self;
}

// PUT /lights/{id}/state
- (instancetype)parseLightStateSet:(id)json
{
  // Loop through all results, if any are not successful, report the whole
  // process as a failure
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

NSInteger _clamp_int(NSInteger number, NSInteger min, NSInteger max) {
    return number < min ? min : (number > max ? max : number);
}

@end
