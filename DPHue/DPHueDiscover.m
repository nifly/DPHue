//
//  DPHueDiscover.m
//  DPHue
//
//  This class is in the public domain.
//  Originally created by Dan Parsons in 2012.
//
//  https://github.com/danparsons/DPHue

#import <CocoaAsyncSocket/GCDAsyncUdpSocket.h>
#import "DPHueDiscover.h"
#import "DPJSONConnection.h"
#import "DPHueNUPNP.h"
#import "WSLog.h"

@interface DPHueDiscover ()
@property (nonatomic, strong) GCDAsyncUdpSocket *udpSocket;
@property (nonatomic) BOOL foundHue;
@property (nonatomic, strong) NSMutableString *log;
@end

@implementation DPHueDiscover

- (id)initWithDelegate:(id<DPHueDiscoverDelegate>)delegate {
  self = [super init];
  if (self) {
    _delegate = delegate;
    _log = [[NSMutableString alloc] init];
  }
  return self;
}

- (void)discoverForDuration:(int)seconds withCompletion:(void (^)(NSMutableString *log))block {
  WSLog(@"Starting discovery, via meethue.com API first");
  [self appendToLog:@"Starting disovery"];
  NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.meethue.com/api/nupnp"]];
  DPHueNUPNP *pnp = [[DPHueNUPNP alloc] init];
  DPJSONConnection *connection = [[DPJSONConnection alloc] initWithRequest:req];
  connection.jsonRootObject = pnp;
  connection.completionBlock = ^(DPHueNUPNP *pnp, NSError *err) {
    if (pnp.hueIP) {
      // web service gave us a IP
      [self appendToLog:[NSString stringWithFormat:@"Received Hue IP from web service: %@", pnp.hueIP]];
      self.foundHue = YES;
      if ([self.delegate respondsToSelector:@selector(foundHueAt:discoveryLog:)]) {
        [self.delegate foundHueAt:pnp.hueIP discoveryLog:self.log];
      }
    } else {
      [self appendToLog:@"Received response from web service, but no IP, starting SSDP discovery"];
      [self startSSDPDiscovery];
    }
  };
  [self appendToLog:[NSString stringWithFormat:@"Making request to %@", req]];
  [connection start];
  // `seconds` seconds later, stop discovering
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, seconds * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
    // JPR TODO: swap the order to get full log before triggering callback
    block(self.log);
    [self stopDiscovery];
  });
}

- (void)startSSDPDiscovery {
  [self appendToLog:@"Starting SSDP discovery"];
  self.udpSocket = [self createSocket];
  NSString *msg = @"M-SEARCH * HTTP/1.1\r\nHost: 239.255.255.250:1900\r\nMan: ssdp:discover\r\nMx: 3\r\nST: \"ssdp:all\"\r\n\r\n";
  NSData *msgData = [msg dataUsingEncoding:NSUTF8StringEncoding];
  [self.udpSocket sendData:msgData toHost:@"239.255.255.250" port:1900 withTimeout:-1 tag:0];
}

- (void)stopDiscovery {
  WSLog(@"Stopping discovery");
  [self appendToLog:@"Discovery stopped"];
  [self.udpSocket close];
  self.udpSocket = nil;
}

- (GCDAsyncUdpSocket *)createSocket {
  GCDAsyncUdpSocket *socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
  NSError *error = nil;
  
  if (![socket bindToPort:0 error:&error])
    WSLog(@"Error binding: %@", error.description);
  if (![socket beginReceiving:&error])
    WSLog(@"Error receiving: %@", error.description);
  [socket enableBroadcast:YES error:&error];
  if (error)
    WSLog(@"Error enabling broadcast: %@", error.description);
  return socket;
}

- (void)searchForHueAt:(NSURL *)url {
  NSURLRequest *req = [NSURLRequest requestWithURL:url];
  DPJSONConnection *connection = [[DPJSONConnection alloc] initWithRequest:req];
  [self appendToLog:[NSString stringWithFormat:@"Searching for Hue controller at %@", url]];
  connection.completionBlock = ^(NSData *data, NSError *err) {
    NSString *msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    // If this string is found, then url == hue!
    if ([msg rangeOfString:@"Philips hue bridge 2012"].location != NSNotFound) {
      [self appendToLog:[NSString stringWithFormat:@"Found hue at %@!", url.host]];
      if ([self.delegate respondsToSelector:@selector(foundHueAt:discoveryLog:)]) {
        if (!self.foundHue) {
          [self.delegate foundHueAt:url.host discoveryLog:self.log];
          self.foundHue = YES;
        }
      }
    } else {
      // Host is not a Hue
      [self appendToLog:[NSString stringWithFormat:@"Host %@ is not a Hue", url.host]];
    }
  };
  [connection start];
}

#pragma mark - GCDAsyncUdpSocketDelegate

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {
  NSString *msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  if (msg) {
    [self appendToLog:@"Received UDP data"];
    //NSRegularExpression *reg = [[NSRegularExpression alloc] initWithPattern:@"LOCATION:(.*?)xml" options:0 error:nil];
    NSRegularExpression *reg = [[NSRegularExpression alloc] initWithPattern:@"http:\\/\\/(.*?)description\\.xml" options:0 error:nil];
    NSArray *matches = [reg matchesInString:msg options:0 range:NSMakeRange(0, msg.length)];
    if (matches.count > 0) {
      NSTextCheckingResult *result = matches[0];
      NSString *matched = [msg substringWithRange:[result rangeAtIndex:0]];
      NSURL *url = [NSURL URLWithString:matched];
      [self appendToLog:@"Possibly found a Hue controller, verifying..."];
      [self searchForHueAt:url];
    }
  }
}

#pragma mark - Helpers

- (void)appendToLog:(NSString *)message
{
  [self.log appendFormat:@"%@: %@\n", [NSDate date], message];
}

@end
