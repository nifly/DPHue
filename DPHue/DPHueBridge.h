//
//  DPHueBridge.h
//  DPHueBridge
//
//  This class is in the public domain.
//  Originally created by Dan Parsons in 2012.
//
//  https://github.com/danparsons/DPHue

#import <Foundation/Foundation.h>

@class DPHueLight;
@class DPHueLightGroup;


@interface DPHueBridge : NSObject <NSCoding>


#pragma mark - Properties you may be interested in setting

/**
 The API username DPHueBridge will use when communicating with the Hue controller.
 The Hue API requires this be an MD5 hash of something.
 */
@property (nonatomic, copy) NSString *generatedUsername;

/// The hostname (or IP address) that DPHueBridge will talk to.
@property (nonatomic, copy) NSString *host;


#pragma mark - Properties you may be interested in reading

/**
 The "name" of the Hue controller, as returned by the API.
 
 This can actually be changed via the Hue API if necessary,
 but I didn't implement that feature.
 */
@property (nonatomic, readonly, copy) NSString *name;

/// Firmware version
@property (nonatomic, readonly, copy) NSString *swversion;

/**
 An array of DPHueLight objects representing all the lights
 that the controller is aware of.
 */
@property (nonatomic, readonly, copy) NSArray *lights;

/**
 An array of DPHueLightGroup objects representing all the groups
 that the controller is aware of.
 */
@property (nonatomic, readonly, copy) NSArray *groups;

/// Whether or not we have been fully registered with the controller.
@property (nonatomic, readonly, assign) BOOL authenticated;


#pragma mark - Methods

/**
 * Generate a DPHueBridge object with the given parameters.
 *
 * @param host
 *          The hostname or IP of the Hue controller you want to talk to.
 * @param generatedUsername
 *          An md5 string from a previously successful call to @p [DPHueBridge registerDevice].
 *          If this is your first time interacting with the controller, use @p nil.
 */
- (id)initWithHueHost:(NSString *)host generatedUsername:(NSString *)generatedUsername;

/**
 Download the complete state of the Hue controller, including the state
 of all lights and groups. @p block is called when the operation is complete.
 This normally takes only 1 to 3 seconds.
 */
- (void)readWithCompletion:(void (^)(DPHueBridge *hue, NSError *err))block;

/**
 * This will attempt to register @p self.deviceType with the Hue controller.
 * This will fail unless the physical button on the Hue controller has
 * been pressed within the last 30 seconds. The workflow for this method
 * is a loop: tell the user to press the button on their controller, call
 * this method, then check self.authenticated. If NO, keep calling this
 * method. See @p DPQuickHue for implementation example.
 * 
 * Once authenticated, you should be sure to save off the value of @p DPHueBridge.generatedUsername
 * so you can reconnect to the controller later without re-registering.
 */
- (void)registerDevice;

/**
 Triggers the Touchlink feature in a Hue controller, which causes it to
 pair with all lamps it can find, even thoughs that belong to another
 controller. To limit the possibility of "stealing" someone else's lamps,
 the range of this function is limited (by Philips, in the controller firmware)
 to a short distance from the controller.
 
 Calls block when a response is received from the controller.
 */
- (void)triggerTouchlinkWithCompletion:(void (^)(BOOL success, NSString *result))block;

/**
 Search for the light with given @p lightId in @p self.lights
 
 @return The found light, or nil
 */
- (DPHueLight *)lightWithId:(NSNumber *)lightId;

/**
 Search for the light with given @p lightName in @p self.lights
 
 @return The found light, or nil
 */
- (DPHueLight *)lightWithName:(NSString *)lightName;

/**
 Search for the group with given @p groupId in @p self.groups
 
 @return The found group, or nil
 */
- (DPHueLightGroup *)groupWithId:(NSNumber *)groupId;

/**
 Search for the group with given @p groupName in @p self.groups
 
 @return The found group, or nil
 */
- (DPHueLightGroup *)groupWithName:(NSString *)groupName;

// JPR TODO: create a `createOrUpdateGroupWithName` method

/**
 Create a group on the controller.
 @param name
          The group name you want. If this is already taken, then the controller
          will automatically append an auto-incrementing number to this. So,
          'Jimmy 1' instead of 'Jimmy'.
 @param lightIds
          The @p NSNumber light ids of the lights which you want to belong to
          this group.
 @param onCompletionBlock
          Optional callback to be triggered after the creation process completes.<br />
          <br />
          The completion block takes two parameters:
          <ul>
          <li>success<br />
                Indicates whether the creation succeeded according to the controller
          </li>
          <li>group<br />
                The resultant group.
          </li>
          </ul>
 */
- (void)createGroupWithName:(NSString *)name lightIds:(NSArray *)lightIds onCompletion:(void (^)(BOOL success, DPHueLightGroup* group))onCompletionBlock;

/**
 Update the given group on the controller.
 @param name
          The group name you want to update to. If this is nil, the existing name
          is used.
 @param lightIds
          The @p NSNumber light ids of the lights which you want to belong to
          this group.
 @param onCompletionBlock
          Optional callback to be triggered after the creation process completes.<br />
          <br />
          The completion block takes two parameters:
          <ul>
          <li>success<br />
                Indicates whether the update succeeded according to the controller
          </li>
          <li>group<br />
                The resultant group.
          </li>
          </ul>
 */
- (void)updateGroup:(DPHueLightGroup *)group withName:(NSString *)name lightIds:(NSArray *)lightIds onCompletion:(void (^)(BOOL success, DPHueLightGroup* group))onCompletionBlock;

@end


@interface DPHueBridge (HueAPIRequestGeneration)

- (NSURLRequest *)requestForRegisteringDevice:(NSString *)deviceType;
- (NSURLRequest *)requestForReadingControllerState;

@end


@interface DPHueBridge (HueAPIJsonParsing)

// POST /
- (instancetype)parseDeviceRegistration:(id)json;
// GET /{username}
- (instancetype)parseControllerState:(id)json;

@end
