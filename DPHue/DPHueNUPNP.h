//
//  DPHueNUPNP.h
//  DPHue
//
//  This class is in the public domain.
//  Originally created by Dan Parsons in 2012.
//
//  https://github.com/danparsons/DPHue

// This is just a class for encapsulating data returned from the
// meethue.com discovery API.

#import <Foundation/Foundation.h>


@interface DPHueNUPNP : NSObject

@property (nonatomic, copy, readonly) NSString *hueID;
@property (nonatomic, copy, readonly) NSString *hueIP;
@property (nonatomic, copy, readonly) NSString *hueMACAddress;

@end


@interface DPHueNUPNP (HueAPIRequestGeneration)

- (NSURLRequest *)requestForDiscovery;

@end


@interface DPHueNUPNP (HueAPIJsonParsing)

- (NSURLRequest *)parseDiscovery:(id)json;

@end
