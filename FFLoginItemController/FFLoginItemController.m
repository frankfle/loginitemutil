//
//  FFLoginItemController.m
//  loginitemutil
//
//  Created by Frank Fleschner on 4/12/12.
//  Copyright (c) 2012 Frank Fleschner. All rights reserved.
//

#import "FFLoginItemController.h"
#import <ApplicationServices/ApplicationServices.h> /* For all the shared list stuff (ie, the good stuff) */
#import <pwd.h> /* For username to uid_t conversion */
#import <OpenDirectory/OpenDirectory.h> /* For iterating over users */

#pragma mark - Private Methods
@interface FFLoginItemController (Private)

// Our core methods that wrap the LSSharedFileList API
- (BOOL)addUrlToSessionLoginItems:(NSURL *)aURL;
- (BOOL)removeUrlFromSessionLoginItems:(NSURL *)aURL;
- (BOOL)urlExistsInSessionLoginItems:(NSURL *)aURL;

// Basically a little helper method.
- (uid_t)uidForString:(NSString *)str;

// Little helper method that gets all users with UID > 500 and respects the
// ignoredUsers property.  The way this works is pretty dependent on the OS
// version.  Unfortunately it's pretty hard until Lion.  Who knew....
- (NSArray *)getAllUsers;

// Methods for adding items for multiple users:
- (BOOL)_addItemForUsers;
- (BOOL)_addItemForAllUsers;

// Methods for removing items for multiple users:
- (BOOL)_removeItemForUsers;
- (BOOL)_removeItemForAllUsers;
@end

@implementation FFLoginItemController

#pragma mark - Synthesized properties
@synthesize targetedUsers;
@synthesize ignoredUsers;
@synthesize allUsers;
@synthesize theURL;
@synthesize shouldBeHidden;
@synthesize verboseLogging;

#pragma mark - LSSharedFileList wrappers
// Adds the URL to the login items of the curreint user
- (BOOL)addUrlToSessionLoginItems:(NSURL *)aURL
{
    if (self.verboseLogging)
    {
        NSLog(@"Adding %@ to %@'s login items.", [aURL path], NSUserName());
    }
    
    
    // Get the login items.
    LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL,
                                                            kLSSharedFileListSessionLoginItems,
                                                            NULL);
    // Fail if we can't.
    if (!loginItems)
    {
        NSLog(@"ERROR: couldn't get login items for %@!", NSUserName());
        return NO;
    }
    
    CFDictionaryRef properties = NULL;
    
    // Give it the hidden property, if it needs it.
    if (self.shouldBeHidden)
    {
        CFStringRef* keys = {&kLSSharedFileListLoginItemHidden};
        const CFBooleanRef* values = {&kCFBooleanTrue};
        
        CFDictionaryRef newDict = CFDictionaryCreate(kCFAllocatorDefault,
                                                     (const void **)keys,
                                                     (const void **)values,
                                                     1,
                                                     &kCFTypeDictionaryKeyCallBacks,
                                                     &kCFTypeDictionaryValueCallBacks);
        if (newDict != NULL)
        {
            properties = newDict;
        }
    }
    
    // Insert the item.
	LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItems,
                                                                 kLSSharedFileListItemLast,
                                                                 NULL,
                                                                 NULL,
                                                                 (__bridge CFURLRef) aURL,
                                                                 properties,
                                                                 NULL);		
	
    if (properties)
    {
        // If we had some properties, we're done with them now!
        CFRelease(properties);
    }
    
    // Fail if we can't.  If we did, go ahead and release it, we're done with it
    if (item)
    {
		CFRelease(item);
    }
    else
    {
        NSLog(@"Error: failed in during insertion for %@!", NSUserName());
        CFRelease(loginItems);
        return NO;
    }

    // Make sure we release the login items ref before we're done.
    CFRelease(loginItems);
    return YES;
}

- (BOOL)removeUrlFromSessionLoginItems:(NSURL *)aURL
{
    // Get the login items.
    LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL,
                                                            kLSSharedFileListSessionLoginItems,
                                                            NULL);
    // Fail if we can't.
    if (!loginItems)
    {
        return NO;
    }

    UInt32 snapshotSeed;
	CFURLRef currPath = NULL;

	// Grab a snopshot of the Array.
    CFArrayRef loginItemsArray = LSSharedFileListCopySnapshot(loginItems, &snapshotSeed);
	
    if (!loginItemsArray)
    {
        CFRelease(loginItems);
        return NO;
    }
    
    // Go through it
    for (id currItem in (__bridge NSArray *)loginItemsArray)
    {		
		LSSharedFileListItemRef currItemRef = (__bridge LSSharedFileListItemRef)currItem;
		
        if (LSSharedFileListItemResolve(currItemRef,
                                        kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes,
                                        (CFURLRef*) &currPath,
                                        NULL) == noErr)
        {
			// If it's a match, let's nuke it.
            if ([[(__bridge NSURL *)currPath path] isEqualToString:[aURL path]])
            {
				LSSharedFileListItemRemove(loginItems, currItemRef); // Deleting the item
                // But we keep going.  If it's there, we remove more than once.
			}
			
            CFRelease(currPath);
		}		
	}
	
    CFRelease(loginItemsArray);
    CFRelease(loginItems);
    
    return YES;
}

- (BOOL)urlExistsInSessionLoginItems:(NSURL *)aURL
{
    // Get the login items.
    LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL,
                                                            kLSSharedFileListSessionLoginItems,
                                                            NULL);
    // Fail if we can't.
    if (!loginItems)
    {
        return NO;
    }
    
    BOOL retVal = NO;  
	UInt32 snapshotSeed;
	CFURLRef currPath = NULL;
    
    // Grab a snapshot of the Array.
	CFArrayRef loginItemsArray = LSSharedFileListCopySnapshot(loginItems, &snapshotSeed);
    
    if (!loginItemsArray)
    {
        CFRelease(loginItems);
        return NO;
    }
    
    // Go through them.
	for (id currItem in (__bridge NSArray *)loginItemsArray)
    {    
		LSSharedFileListItemRef currItemRef = (__bridge LSSharedFileListItemRef)currItem;
		
        if (LSSharedFileListItemResolve(currItemRef,
                                        kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes,
                                        (CFURLRef*) &currPath,
                                        NULL) == noErr)
        {
            // If we find it, we're done!
			if ([[(__bridge NSURL *)currPath path] isEqualToString:[aURL path]])
            {
				retVal = YES;
				break;
			}

            CFRelease(currPath);
		}
	}
	
    CFRelease(loginItemsArray);
    CFRelease(loginItems);
    
	return retVal;
}

- (NSArray *)allLoginItemPaths
{
    LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL,
                                                            kLSSharedFileListSessionLoginItems,
                                                            NULL);
    // Fail if we can't.
    if (!loginItems)
    {
        return nil;
    }
    
    NSMutableArray *retVal = [NSMutableArray array];  
	UInt32 snapshotSeed;
	CFURLRef currPath = NULL;
    
    // Grab a snapshot of the Array.
	CFArrayRef loginItemsArray = LSSharedFileListCopySnapshot(loginItems, &snapshotSeed);
    
    if (!loginItemsArray)
    {
        CFRelease(loginItems);
        return nil;
    }
    
    // Go through them.
	for (id currItem in (__bridge NSArray *)loginItemsArray)
    {    
		LSSharedFileListItemRef currItemRef = (__bridge LSSharedFileListItemRef)currItem;
		
        if (LSSharedFileListItemResolve(currItemRef,
                                        kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes,
                                        (CFURLRef*) &currPath,
                                        NULL) == noErr)
        {
            // If we find it, we're done!
            [retVal addObject:[(__bridge NSURL *)currPath path]];
            
            CFRelease(currPath);
		}
	}
	
    CFRelease(loginItemsArray);
    CFRelease(loginItems);
    
	return retVal;

}

#pragma mark - Helper methods
- (uid_t)uidForString:(NSString *)str
{
    // Let's see if it's a UID already...
    NSInteger intValue = [str integerValue];
    if (intValue != 0)
    {
        // We have some sort of int, let's just go with it...
        return (uid_t)intValue;
    }
    
    // Ok, let's try to convert a username into a UID...
    const char *cStr = [str cStringUsingEncoding:NSUTF8StringEncoding];
    
    struct passwd *pw_entry = getpwnam(cStr);
    if (pw_entry != NULL)
    {
        uid_t retVal = pw_entry->pw_uid;

        endpwent();

        return retVal;
    }

    // Cleanup...
    endpwent();

    // We failed....
    return 0;
}

- (NSArray *)allLeopardUsers
{
    NSMutableArray *finalResults = [NSMutableArray array];
    
    NSFileManager *fileMan = [NSFileManager defaultManager];
    
    NSArray *filesInUsersFolder = [fileMan contentsOfDirectoryAtPath:@"/Users/" error:nil];
    
    // Let's go through them and make sure they're a directory....
    for (NSString *file in filesInUsersFolder)
    {
        BOOL isDir = NO;
        
        if ([fileMan fileExistsAtPath:[NSString stringWithFormat:@"/Users/%@", file] isDirectory:&isDir])
        {
            // Filter out anything that isn't a directory and that is named "Shared"
            if (isDir && !([file isEqualToString:@"Shared"]))
            {
                [finalResults addObject:file];
            }
        }
    }
    
    return finalResults;
}

- (NSArray *)getAllUsers
{
    // Figure out OS version here
    SInt32 minorVersion;
    Gestalt(gestaltSystemVersionMinor, &minorVersion);
    
    BOOL isLionOrLater = (minorVersion >= 7);
    BOOL isLeopard = (minorVersion == 5);
    
    // If we have Leopard, let's get out right now!
    if (isLeopard)
    {
        return [self allLeopardUsers];
    }
    
    // Otherwise, let's go ahead and do the  more proper OD dance!
    ODSession *mySession = [ODSession defaultSession];
	NSError *err;
    
    ODNode *myUsersNode = [ODNode nodeWithSession:mySession
                                             name:@"/Search"
                                            error:&err];
    
    if (err)
    {
        NSLog(@"Error getting all users: %@", err);
        return NO;
    }
    
    ODQuery *myQuery = nil;
    
    // Let's work around a SL bug:
    if (!isLionOrLater)
    {
        // This could be potentially bad, but is the best I can figure out in SL to be able to do
        // this without too much work up front.
        
        // It'd probably be better to actually get all the users and compare unique id's manually.
        // TODO -- See above!
        myQuery = [ODQuery queryWithNode:myUsersNode
                          forRecordTypes:kODRecordTypeUsers
                               attribute:kODAttributeTypeNFSHomeDirectory
                               matchType:kODMatchBeginsWith
                             queryValues:@"/Users/"
                        returnAttributes:kODAttributeTypeStandardOnly
                          maximumResults:0
                                   error:&err];
    }
    else
    {
        // This seems better.  Maybe still not optimal for weird setups, basically all users with
        // a UID of 500 or higher.  This should get everyone on a machine except system users,
        // whether they're local users or AD/OD users.
        myQuery = [ODQuery queryWithNode:myUsersNode
                          forRecordTypes:kODRecordTypeUsers
                               attribute:kODAttributeTypeUniqueID
                               matchType:kODMatchGreaterThan
                             queryValues:@"500"
                        returnAttributes:kODAttributeTypeStandardOnly
                          maximumResults:0
                                   error:&err];
    }
    
    if (err)
	{
		NSLog(@"Error getting all users: %@", err);
        return NO;
	}
	
	NSArray *myResults = [myQuery resultsAllowingPartial:NO error:&err];
	
	if (err)
	{
		NSLog(@"Error getting all users: %@", err);
        return NO;
	}
	
	NSMutableArray *results = [NSMutableArray arrayWithCapacity:[myResults count]];
	
	for (ODRecord *record in myResults)
	{
        NSArray *userNames = [record valuesForAttribute:kODAttributeTypeRecordName error:&err];
        NSString *userName = userNames[0];
        
        if (err)
        {
            // Couldn't get username...continue. on.
            continue;
        }
        
        // Look to see if it's ignored.
        BOOL userIsIgnored = NO;
        for (NSString *currIgnoredUser in self.ignoredUsers)
        {
            if ([currIgnoredUser isEqualToString:userName])
            {
                userIsIgnored = YES;
                break;
            }
        }
        
        if (!userIsIgnored)
        {
            [results addObject:userName];
        }
	}
    
    return results;
}

#pragma mark - Internal implementations
- (BOOL)_addItemForUsers
{
    for (NSString *user in self.targetedUsers)
    {
        if (self.verboseLogging)
        {
            NSLog(@"Setting for %@", user);
        }
        
        uid_t currUid, savedUid;
        int status;
        
        currUid = [self uidForString:user];
        
        // Save our uid, so we can set it back...
        savedUid = geteuid();
        
        status = seteuid(currUid);
        
        // If we cant' setuid, let's just bail out of the whole thing...
        if (status != 0)
        {
            if (errno == EINVAL)
            {
                // Invalid, let's continue on...
                NSLog(@"ERROR: invalide UID (%d) for user (%@)!", currUid, user);
            }
            if (errno == EPERM)
            {
                // We can't even do this...
                // In theory, we shouldn't get here, because the caller should
                // make sure that getuid and/or geteuid is == to 0.
                NSLog(@"ERROR: couldn't setuid for %@ (%d)!", user, currUid);
            }
        }
        else
        {
            [self addUrlToSessionLoginItems:self.theURL];
        }
        
        seteuid(savedUid);
    }
    
    return YES;
}

- (BOOL)_addItemForAllUsers
{
    if (self.verboseLogging)
    {
        NSLog(@"Adding item for all users...");
    }
    
    self.targetedUsers = [self getAllUsers];
    
    return [self _addItemForUsers];
}

- (BOOL)_removeItemForUsers
{  
    for (NSString *user in self.targetedUsers)
    {
        if (self.verboseLogging)
        {
            NSLog(@"Removing for %@", user);
        }
        
        uid_t currUid, savedUid;
        int status;
        
        currUid = [self uidForString:user];
        savedUid = geteuid();
        
        status = seteuid(currUid);
        
        // If we cant' setuid, let's just bail out of the whole thing...
        if (status != 0)
        {
            if (errno == EINVAL)
            {
                // Invalid, let's continue on...
                NSLog(@"ERROR: invalide UID (%d) for user (%@)!", currUid, user);
            }
            if (errno == EPERM)
            {
                // We can't even do this...
                // In theory, we shouldn't get here, because the caller should
                // make sure that getuid and/or geteuid is == to 0.
                NSLog(@"ERROR: we couldn't setuid for %@ (%d)!", user, currUid);
            }
        }    
        else
        {
            [self removeUrlFromSessionLoginItems:self.theURL];
        }
        
        seteuid(savedUid);
    }
    
    return YES;
}

- (BOOL)_removeItemForAllUsers
{
    if (self.verboseLogging)
    {
        NSLog(@"Removing item for all users...");
    }
    
    self.targetedUsers = [self getAllUsers];
    
    return [self _removeItemForUsers];
}

#pragma mark - Externally available methods
- (BOOL)addItem
{
    if (!(self.theURL))
    {
        return NO;
    }
    
    if (self.allUsers)
    {  
        return [self _addItemForAllUsers];
    }
    else if ([self.targetedUsers count] > 0)
    {
        return [self _addItemForUsers];
    }
    return [self addUrlToSessionLoginItems:self.theURL];
}

- (BOOL)removeItem
{
    if (!(self.theURL))
    {
        return NO;
    }
    
    if (self.allUsers)
    {
        return [self _removeItemForAllUsers];
    }
    else if ([self.targetedUsers count] > 0)
    {
        return [self _removeItemForUsers];
    }
    return [self removeUrlFromSessionLoginItems:self.theURL];
}

- (BOOL)itemExists
{
    return [self urlExistsInSessionLoginItems:self.theURL];
}

- (NSArray *)allLoginItems
{
    return [self allLoginItemPaths];
}

@end
