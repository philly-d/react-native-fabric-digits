#import <DigitsKit/DigitsKit.h>
#import "RCTDigitsManager.h"

@implementation RCTDigitsManager

RCT_EXPORT_MODULE()

- (unsigned int)intFromHexString:(NSString *)hexStr {
    unsigned int hexInt = 0;

    // Create scanner
    NSScanner *scanner = [NSScanner scannerWithString:hexStr];

    // Tell scanner to skip the # character
    [scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@"#"]];

    // Scan hex value
    [scanner scanHexInt:&hexInt];

    return hexInt;
}

- (UIColor *)getUIColorObjectFromHexString:(NSString *)hexStr alpha:(CGFloat)alpha
{
    // Convert hex string to an integer
    unsigned int hexint = [self intFromHexString:hexStr];

    // Create color object, specifying alpha as well
    UIColor *color =
    [UIColor colorWithRed:((CGFloat) ((hexint & 0xFF0000) >> 16))/255
                    green:((CGFloat) ((hexint & 0xFF00) >> 8))/255
                     blue:((CGFloat) (hexint & 0xFF))/255
                    alpha:alpha];

    return color;
}

- (void)setColorToApparence:(DGTAppearance *)appearance
           withKeyApparence:(NSString *)keyAppearance
                fromOptions:(NSDictionary *)options
                 withKeyHex:(NSString *)keyHex
                andKeyAlpha:(NSString *)keyAlpha {
    id hex = [options valueForKeyPath:keyHex];
    id alpha = [options valueForKeyPath:keyAlpha];

    if (hex && alpha && [hex isKindOfClass:[NSString class]] && [alpha isKindOfClass:[NSNumber class]]) {
        [appearance setValue:[self getUIColorObjectFromHexString: (NSString *)hex alpha:[(NSNumber *)alpha doubleValue]] forKey:keyAppearance];
    }
}

- (void)setFontToApparence:(DGTAppearance *)appearance
          withKeyApparence:(NSString *)keyAppearance
               fromOptions:(NSDictionary *)options
               withKeyName:(NSString *)keyName
                andKeySize:(NSString *)keySize {
    id fontName = [options valueForKeyPath:keyName];
    id fontSize = [options valueForKeyPath:keySize];

    if (fontName && [fontName isKindOfClass:[NSString class]] && [fontSize isKindOfClass:[NSNumber class]]) {
        [appearance setValue:[UIFont fontWithName:(NSString *)fontName size:[(NSNumber *)fontSize doubleValue]] forKey:keyAppearance];
    }
}

- (void)setImageToApparence:(DGTAppearance *)appearance
           withKeyApparence:(NSString *)keyAppearance
                fromOptions:(NSDictionary *)options
           withKeyImageName:(NSString *)keyImageName {
    id imageName = [options valueForKeyPath:keyImageName];

    if (imageName && imageName && [imageName isKindOfClass:[NSString class]]) {
        [appearance setValue:[UIImage imageNamed:imageName] forKey:keyAppearance];
    }
}

RCT_REMAP_METHOD(launchAuthentication,
                 view:(NSDictionary*)options
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject) {

    DGTAppearance *appearance = [[DGTAppearance alloc] init];
    DGTAuthenticationConfiguration *configuration = [[DGTAuthenticationConfiguration alloc] initWithAccountFields:(options[@"email"]) ? DGTAccountFieldsEmail : DGTAccountFieldsDefaultOptionMask];

    [self setColorToApparence:appearance withKeyApparence:@"backgroundColor" fromOptions:options withKeyHex:@"appearance.backgroundColor.hex" andKeyAlpha:@"appearance.backgroundColor.alpha"];
    [self setColorToApparence:appearance withKeyApparence:@"accentColor" fromOptions:options withKeyHex:@"appearance.accentColor.hex" andKeyAlpha:@"appearance.accentColor.alpha"];
    [self setFontToApparence:appearance withKeyApparence:@"headerFont" fromOptions:options withKeyName:@"appearance.headerFont.name" andKeySize:@"appearance.headerFont.size"];
    [self setFontToApparence:appearance withKeyApparence:@"labelFont" fromOptions:options withKeyName:@"appearance.labelFont.name" andKeySize:@"appearance.labelFont.size"];
    [self setFontToApparence:appearance withKeyApparence:@"bodyFont" fromOptions:options withKeyName:@"appearance.bodyFont.name" andKeySize:@"appearance.bodyFont.size"];
    [self setImageToApparence:appearance withKeyApparence:@"logoImage" fromOptions:options withKeyImageName:@"appearance.logoImageName"];

    configuration.title = options[@"title"];
    configuration.phoneNumber = options[@"phoneNumber"];
    configuration.appearance = appearance;

    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *root = [[[[UIApplication sharedApplication] delegate] window] rootViewController];

        [[Digits sharedInstance] authenticateWithViewController:root configuration:configuration completion:^(DGTSession *session, NSError *error) {
            if (error) {
                reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
            } else {
                Digits *digits = [Digits sharedInstance];
                DGTOAuthSigning *oauthSigning = [[DGTOAuthSigning alloc] initWithAuthConfig:digits.authConfig authSession:session];
                NSDictionary *authHeaders = [oauthSigning OAuthEchoHeadersToVerifyCredentials];
                resolve(authHeaders);
            }
        }];
    });
}

RCT_EXPORT_METHOD(logout) {
    [[Digits sharedInstance] logOut];
}

RCT_EXPORT_METHOD(enableSandbox) {
    Digits *digits = [Digits sharedInstance];
    DGTSession *session = [DGTDebugConfiguration defaultDebugSession];
    digits.debugOverrides = [[DGTDebugConfiguration alloc] initSuccessStateWithDigitsSession:session];
}

RCT_EXPORT_METHOD(sessionDetails:(RCTResponseSenderBlock)callback) {
    DGTSession* session =[[Digits sharedInstance] session];
    if (session) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[^0-9]"
                                                                               options:NSRegularExpressionCaseInsensitive
                                                                                 error:nil];
        NSString *phoneNumber = [regex stringByReplacingMatchesInString:session.phoneNumber
                                                                options:0
                                                                  range:NSMakeRange(0, session.phoneNumber.length)
                                                           withTemplate:@""];
        NSDictionary *events = @{
                                 @"authToken": session.authToken,
                                 @"authTokenSecret": session.authTokenSecret,
                                 @"userID": session.userID,
                                 @"phoneNumber": phoneNumber,
                                 @"emailAddress": (session.emailAddress ? session.emailAddress : @""),
                                 @"emailAddressIsVerified": @(session.emailAddressIsVerified)
                                 };
        callback(@[[NSNull null], events]);
    } else {
        callback(@[[NSNull null], [NSNull null]]);
    }
}

RCT_EXPORT_METHOD(uploadContacts:(RCTResponseSenderBlock)callback) {
    DGTSession *userSession = [Digits sharedInstance].session;
    DGTContacts *contacts = [[DGTContacts alloc] initWithUserSession:userSession];
    
    [contacts startContactsUploadWithCompletion:^(DGTContactsUploadResult *result, NSError *error) {
        // Inspect results and error objects to determine if upload succeeded.
        if (error) {
            callback(@[[error localizedDescription], [NSNull null]]);
        } else if (!result) {
            callback(@[[NSNull null], [NSNull null]]);
        } else {
            callback(@[[NSNull null], @{
                           @"totalContacts": [NSNumber numberWithInteger:result.totalContacts],
                           @"numberOfUploadedContacts": [NSNumber numberWithInteger:result.numberOfUploadedContacts]
                           }]);
        }
    }];
}

RCT_EXPORT_METHOD(findFriends:(NSString *)cursor callback:(RCTResponseSenderBlock)callback) {
    DGTSession *userSession = [Digits sharedInstance].session;
    DGTContacts *contacts = [[DGTContacts alloc] initWithUserSession:userSession];
    
    [contacts lookupContactMatchesWithCursor:cursor completion:^(NSArray *matches, NSString *nextCursor, NSError *error) {
        // matches is an Array of DGTUser objects.
        // Use nextCursor in a follow-up call to this method to offset the results.
        if (error) {
            callback(@[[error localizedDescription], [NSNull null]]);
        } else {
            
            NSMutableArray *friends = [NSMutableArray arrayWithCapacity:[matches count]];
            [matches enumerateObjectsUsingBlock:^(DGTUser* user, NSUInteger idx, BOOL *stop) {
                [friends addObject:@{
                                     @"userID": user.userID
                                     }];
            }];
            
            NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
            result[@"matches"] = friends;
            if (nextCursor) {
                result[@"nextCursor"] = nextCursor;
            }
            
            callback(@[[NSNull null], result]);
        }
    }];
}


@end
