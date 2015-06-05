//
//  DPHue.m
//  DPHue
//
//  This class is in the public domain.
//  Originally created by Dan Parsons in 2012.
//
//  https://github.com/danparsons/DPHue

#import "DPHue.h"
#import "DPHueLight.h"
#import "DPJSONConnection.h"
#import "NSString+MD5.h"
#import "WSLog.h"
#import <CocoaAsyncSocket/GCDAsyncSocket.h>


@interface DPHue () <GCDAsyncSocketDelegate>

// JPR TODO: allow setting from the outside
@property (nonatomic, strong) NSString *deviceType;
@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (nonatomic, copy) void (^touchLightCompletionBlock)(BOOL success, NSString *result);

@end


@implementation DPHue

- (id)initWithHueHost:(NSString *)host username:(NSString *)username
{
    if ( self = [super init] )
    {
        _deviceType = @"QuickHue";
        _authenticated = NO;
        _host = host;
        _username = username;
    }
  
    return self;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)a {
  self = [super init];
  if (self) {
    _deviceType = @"QuickHue";
    _username = [a decodeObjectForKey:@"username"];
    _host = [a decodeObjectForKey:@"host"];
    _lights = [a decodeObjectForKey:@"lights"];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)a {
  [a encodeObject:_host forKey:@"host"];
  [a encodeObject:_lights forKey:@"lights"];
  [a encodeObject:_username forKey:@"username"];
}

- (void)setUsername:(NSString *)username
{
  _username = username;
  
  // As each DPHueLight maintains its own access URLs, they too must be updated
  // if URLs change.
  for (DPHueLight *light in self.lights)
  {
    light.username = username;
  }
}

- (void)setHost:(NSString *)host
{
  _host = host;
  
  // As each DPHueLight maintains its own access URLs, they too must be updated
  // if URLs change.
  for (DPHueLight *light in self.lights)
  {
    light.host = host;
  }
}

- (void)readWithCompletion:(void (^)(DPHue *, NSError *))block
{
  // Cut down on if-checks within completionBlock
  void (^innerBlock)(DPHue *, NSError *) = ^(DPHue *hue, NSError *error) {
    if ( block )
      block(hue, error);
  };
  
  NSURLRequest *request = [self requestForReadingControllerState];
  
  DPJSONConnection *connection = [[DPJSONConnection alloc] initWithRequest:request sender:self];
  connection.completionBlock = ^(DPHue *sender, id json, NSError *err) {
    if ( err )
    {
      innerBlock( nil, err );
      return;
    }
    
    [sender parseControllerState:json];
    innerBlock( sender, nil );
  };
  
  [connection start];
}

- (void)registerUsername
{
  NSURLRequest *request = [self requestForRegisteringUsername:self.username
                                               withDeviceType:self.deviceType];
  
  DPJSONConnection *connection = [[DPJSONConnection alloc] initWithRequest:request sender:self];
  connection.completionBlock = ^(DPHue *sender, id json, NSError *err) {
    if ( err )
      return;
    
    [sender parseUsernameRegistration:json];
  };
  
  [connection start];
}

+ (NSString *)generateUsername {
    return [[[NSProcessInfo processInfo] globallyUniqueString] MD5String];
}

- (NSString *)description {
    NSMutableString *descr = [[NSMutableString alloc] init];
    [descr appendFormat:@"Name: %@\n", self.name];
    [descr appendFormat:@"Version: %@\n", self.swversion];
    [descr appendFormat:@"Number of lights: %lu\n", (unsigned long)self.lights.count];
    for (DPHueLight *light in self.lights) {
        [descr appendString:light.description];
        [descr appendString:@"\n"];
    }

    return descr;
}

- (void)triggerTouchlinkWithCompletion:(void (^)(BOOL success, NSString *))block {
    WSLog(@"Triggering Touchlink");
    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    NSError *err = nil;
    if (![self.socket connectToHost:self.host onPort:30000 withTimeout:5 error:&err]) {
        WSLog(@"Error connecting to %@:30000 %@", self.host, err);
        return;
    }
    self.touchLightCompletionBlock = block;
    // After 10 seconds, stop
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 10), dispatch_get_main_queue(), ^{
        if (self.socket) {
            self.touchLightCompletionBlock(NO, @"No response after 10 sec");
            [self.socket disconnect];
            self.socket = nil;
        }
    });
}

- (DPHueLight *)lightWithId:(NSNumber *)lightId
{
  for ( DPHueLight *light in self.lights )
  {
    if ( [light.number isEqualToNumber:lightId] )
      return light;
  }
  
  return nil;
}

- (DPHueLight *)lightWithName:(NSString *)lightName
{
  for ( DPHueLight *light in self.lights )
  {
    if ( [light.name isEqualToString:lightName] )
      return light;
  }
  
  return nil;
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    WSLog(@"Connected to %@:%d", host, port);
    NSData *data = [@"[Link,Touchlink]\n" dataUsingEncoding:NSUTF8StringEncoding];
    [sock writeData:data withTimeout:-1 tag:-1];
    NSMutableData *buffy = [[NSMutableData alloc] init];
    [self.socket readDataToData:[GCDAsyncSocket LFData] withTimeout:5 buffer:buffy bufferOffset:0 tag:-1];
    WSLog(@"Sending: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
}

- (void)socket:(GCDAsyncSocket *)sender didReadData:(NSData *)data withTag:(long)tag {
    NSMutableData *buffy = [[NSMutableData alloc] init];
    NSString *resultMsg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    WSLog(@"Received string: %@", resultMsg);
    if ([resultMsg rangeOfString:@"[Link,Touchlink,success"].location != NSNotFound) {
        // Touchlink found bulbs
        self.touchLightCompletionBlock(YES, resultMsg);
        [self.socket disconnect];
        self.socket = nil;
    } else if ([resultMsg rangeOfString:@"[Link,Touchlink,failed"].location != NSNotFound) {
        // Touchlink failed to find bulbs
        self.touchLightCompletionBlock(NO, resultMsg);
        [self.socket disconnect];
        self.socket = nil;
    } else {
        // We do not have a Touchlink result message yet, so keep receiving
        [self.socket readDataToData:[GCDAsyncSocket LFData] withTimeout:5 buffer:buffy bufferOffset:0 tag:-1];
    }
}


#pragma mark - HueAPIRequestGeneration

- (NSURL *)baseURL
{
  NSAssert([self.host length], @"No host set");
  NSAssert([self.username length], @"No username set");
  
  NSString *basePath = [NSString stringWithFormat:@"http://%@/api/%@",
                        self.host, self.username];
  
  return [NSURL URLWithString:basePath];
}

- (NSURLRequest *)requestForRegisteringUsername:(NSString *)username withDeviceType:(NSString *)deviceType
{
  NSAssert([self.host length], @"No host set");
  
  NSString *urlPath = [NSString stringWithFormat:@"http://%@/api", self.host];
  NSURL *url = [NSURL URLWithString:urlPath];
  
  NSDictionary *usernameDict = @{@"devicetype": deviceType, @"username": username};
  // JPR TODO: pass and check error
  NSData *usernameJson = [NSJSONSerialization dataWithJSONObject:usernameDict options:0 error:nil];
  NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
  request.HTTPMethod = @"POST";
  request.HTTPBody = usernameJson;
  
  return request;
}

- (NSURLRequest *)requestForReadingControllerState
{
  NSURL *url = [self baseURL];
  
  NSURLRequest *request = [NSURLRequest requestWithURL:url];
  return request;
}


#pragma mark - HueAPIJsonParsing

// POST /
- (instancetype)parseUsernameRegistration:(id)json
{
  // JPR TODO: do something here
  return self;
}

// GET /
- (instancetype)parseControllerState:(id)json
{
  if ( ![json respondsToSelector:@selector(objectForKeyedSubscript:)] )
  {
    // We were given an array, not a dict, which means
    // Hue is giving us a result array, which (in this case)
    // means error: not authenticated
    _authenticated = NO;
    return self;
  }
  
  _name = json[@"config"][@"name"];
  if ( _name )
  {
    _authenticated = YES;
  }
  
  _swversion = json[@"config"][@"swversion"];
  
  NSNumberFormatter *f = [NSNumberFormatter new];
  f.numberStyle = NSNumberFormatterDecimalStyle;
  
  NSMutableArray *tmpLights = [NSMutableArray new];
  for ( NSString *lightItem in json[@"lights"] )
  {
    DPHueLight *light = [DPHueLight new];
    [light parseLightStateGet:json[@"lights"][lightItem]];
    light.number = [f numberFromString:lightItem];
    light.username = self.username;
    light.host = self.host;
    [tmpLights addObject:light];
  }
  _lights = tmpLights;
  
  return self;
}

@end
