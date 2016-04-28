//
//  DPHueDiscover.m
//  DPHue
//
//  This class is in the public domain.
//  Originally created by Dan Parsons in 2012.
//
//  https://github.com/danparsons/DPHue

#import "DPHueDiscover.h"
#import "DPJSONConnection.h"
#import "DPHueNUPNP.h"
#import "WSLog.h"
#import <CocoaAsyncSocket/GCDAsyncUdpSocket.h>

#define AppendLogStr(str, fmt, ...) { if (str) { str = [str stringByAppendingFormat:@"%@: %@\n", [NSDate date], [NSString stringWithFormat:(fmt), ##__VA_ARGS__]]; } else { str = [NSString stringWithFormat:@"%@: %@\n", [NSDate date], [NSString stringWithFormat:(fmt), ##__VA_ARGS__]]; } };

#pragma mark - C functions

NSString* _MacAddressWithSeparators(NSString* aMacAddress) {
    if (!aMacAddress)
        return nil;
    if (aMacAddress.length == 12)
        aMacAddress = [@[[aMacAddress substringToIndex:2],
                         [aMacAddress substringWithRange:(NSRange){.location=2, .length=2}],
                         [aMacAddress substringWithRange:(NSRange){.location=4, .length=2}],
                         [aMacAddress substringWithRange:(NSRange){.location=6, .length=2}],
                         [aMacAddress substringWithRange:(NSRange){.location=8, .length=2}],
                         [aMacAddress substringFromIndex:10]] componentsJoinedByString:@":"];
    return aMacAddress;
}

#pragma mark - DPHueDiscover

@implementation DPHueDiscover
{
    NSString* log;
    NSMutableDictionary* discovered;
    NSMutableSet* tested;
    GCDAsyncUdpSocket* udpSocket;
    NSError* discoveryError;
    void (^doHueFound)(NSString* host, NSString* mac);
    void (^doCompletion)(NSDictionary* discovered, NSString* log, NSError* error);
}

+ (instancetype)discoverWithDuration:(NSInteger)duration hueFound:(void(^_Nullable)(NSString* host, NSString* mac))hueFound completion:(void(^_Nullable)(NSDictionary* discovered, NSString* _Nullable log, NSError* _Nullable error))completion {
    return [[DPHueDiscover alloc] initWithDuration:duration hueFound:hueFound completion:completion];
}

- (instancetype)initWithDuration:(NSInteger)duration hueFound:(void(^_Nullable)(NSString* host, NSString* mac))hueFound completion:(void(^_Nullable)(NSDictionary* discovered, NSString* _Nullable log, NSError* _Nullable error))completion {
    self = [super init];
    if (self) {
        [self discoverHueForDuration:duration hueFound:hueFound completion:completion];
    }
    return self;
}

#pragma mark Discovery


-(void)discoverHueForDuration:(NSInteger)duration hueFound:(void(^_Nullable)(NSString* host, NSString* mac))hueFound completion:(void(^_Nullable)(NSDictionary* discovered, NSString* log, NSError* error))completion {
    assert(discovered == nil);
    discovered = [NSMutableDictionary new];
    doHueFound = hueFound;
    doCompletion = completion;
    __block DPHueDiscover* sSelf = self;
   
    AppendLogStr(log, @"Starting discovery, via meethue.com API first");
    AppendLogStr(log, @"Making request to https://www.meethue.com/api/nupnp");
    DPJSONConnection* connection = [[DPJSONConnection alloc] initWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.meethue.com/api/nupnp"]] sender:nil];
    connection.completionBlock = ^(DPHueDiscover* sender, id json, NSError* err) {
        // If there was an error, use SSDP discovery...
        if (err) {
            AppendLogStr(log, @"Error hitting web service, starting SSDP discovery");
            [self startSSDPDiscovery];
            return;
        }
        // Get the hues registered at the local network from www.meethue.com/api/nupnp
        NSInteger nFound = 0;
        if ([json respondsToSelector:@selector(objectAtIndex:)] && [json respondsToSelector:@selector(count)])
            for (id aProperties in json)
                if ([aProperties respondsToSelector:@selector(objectForKey:)] && aProperties[@"id"] && aProperties[@"internalipaddress"])
                    nFound++;
        // If no hues are found, use SSDP discovery...
        if (nFound == 0) {
            AppendLogStr(log, @"Received response from web service, but no IP, starting SSDP discovery");
            [self startSSDPDiscovery];
            return;
        }
        // Parse all hues found...
        for (id aProperties in json) {
            NSString* hueID;
            NSString* hueInternalIP;
            if ([aProperties respondsToSelector:@selector(objectForKey:)] && (hueID = aProperties[@"id"]) && (hueInternalIP = aProperties[@"internalipaddress"])) {
                NSString* hueMac = aProperties[@"macaddress"];
                // If mac address is missing, extract mac address from id (first 6 and last 6 characters)...
                if (!hueMac && (hueID.length >= 12))
                    hueMac = [[hueID substringToIndex:6] stringByAppendingString:[hueID substringFromIndex:hueID.length-6]];
                // Insert mac address separators...
                hueMac = _MacAddressWithSeparators(hueMac);
                // Log and Report...
                AppendLogStr(log, @"Received Hue IP from web service: %@ with id %@", hueInternalIP, hueID);
                if (hueMac && discovered && !discovered[hueMac]) {
                    discovered[hueMac] = hueInternalIP;
                    if (doHueFound)
                        doHueFound(hueInternalIP, hueMac);
                }
            }
        }
        // If we have not initiated an SSDP search, then stop discovery at this point...
        if (!udpSocket) {
            [self stopDiscovery];
            sSelf = nil;
        }
    };
    [connection start];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [sSelf stopDiscovery];
    });
}

- (void)startSSDPDiscovery {
    if (!udpSocket) {
        AppendLogStr(log, @"Starting SSDP discovery");
        tested = [NSMutableSet new];
        udpSocket = [self createSocket];
        NSString *msg = @"M-SEARCH * HTTP/1.1\r\nHost: 239.255.255.250:1900\r\nMan: ssdp:discover\r\nMx: 3\r\nST: \"ssdp:all\"\r\n\r\n";
        NSData *msgData = [msg dataUsingEncoding:NSUTF8StringEncoding];
        [udpSocket sendData:msgData toHost:@"239.255.255.250" port:1900 withTimeout:-1 tag:0];
    }
}

- (void)stopDiscovery {
    if (udpSocket)
        [udpSocket close];
    if (discovered) {
        AppendLogStr(log, @"Discovery stopped");
        if (doCompletion)
            doCompletion([NSDictionary dictionaryWithDictionary:discovered], log, discoveryError);
    }
    log = nil;
    udpSocket = nil;
    discovered = nil;
    tested = nil;
    discoveryError = nil;
    doHueFound = nil;
    doCompletion = nil;
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

#pragma mark - Block based, stateless discovery

-(void)searchForHueAt:(NSURL*)aURL completion:(void(^_Nonnull)(NSString* host, NSString* mac, NSString* log, NSError* error))completion {
    NSString* aLog = [NSString stringWithFormat:@"%@: Searching for Hue controller at %@\n", [NSDate date], aURL];
    [[[NSURLSession sharedSession] dataTaskWithURL:aURL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            completion(nil, nil, [aLog stringByAppendingFormat:@"%@: Error while searching for Hue controller %@\n", [NSDate date], error], error);
            return;
        }
        NSString* aMsg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if ([aMsg rangeOfString:@"Philips hue bridge 20"].location != NSNotFound) {
            // Extract serialNumber from aMsg into aHueMac...
            NSString* aHueMac;
            NSTextCheckingResult* aMatch;
            if (aMatch = [[[NSRegularExpression regularExpressionWithPattern:@"<serialNumber>(.*?)</serialNumber>" options:0 error:nil] matchesInString:aMsg options:0 range:NSMakeRange(0, aMsg.length)] firstObject])
                aHueMac = _MacAddressWithSeparators([aMsg substringWithRange:[aMatch rangeAtIndex:1]]);
            // Found a Hue, report host and mac address (latter may be nil)...
            completion(aURL.host, aHueMac, [aLog stringByAppendingFormat:@"%@: Found hue at %@ with id %@\n", [NSDate date], aURL.host, aHueMac], nil);
        } else {
            completion(nil, nil, [aLog stringByAppendingFormat:@"%@: Host %@ is not a Hue\n", [NSDate date], aURL.host], nil);
        }
    }] resume];
}

#pragma mark - GCDAsyncUdpSocketDelegate

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {
    NSString *msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (msg) {
        AppendLogStr(log, @"Received UDP data");
        NSRegularExpression *reg = [[NSRegularExpression alloc] initWithPattern:@"http:\\/\\/(.*?)description\\.xml" options:0 error:nil];
        NSArray *matches = [reg matchesInString:msg options:0 range:NSMakeRange(0, msg.length)];
        if (matches.count > 0) {
            NSTextCheckingResult *result = matches[0];
            NSString *matched = [msg substringWithRange:[result rangeAtIndex:0]];
            NSURL *url = [NSURL URLWithString:matched];
            if (tested && ![tested containsObject:url.host]) {
                AppendLogStr(log, @"Possibly found a Hue controller, verifying...");
                [tested addObject:url.host];
                [self searchForHueAt:url completion:^(NSString *aHost, NSString *aMac, NSString *aLog, NSError *aError) {
                    log = [log stringByAppendingString:aLog];
                    if (aHost && aMac && discovered && !discovered[aMac] && !aError) {
                        discovered[aMac] = aHost;
                        if (doHueFound)
                            doHueFound(aHost, aMac);
                    }
                }];
            }
        }
    }
}

@end
