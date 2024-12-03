//
//  main.m
//  get1Resource
//
//  Created by Peter Hosey on 2024-12-03.
//

#import <Foundation/Foundation.h>
#import <sysexits.h>

int main(int argc, const char * argv[]) {
	@autoreleasepool {
		NSEnumerator <NSString *> *_Nonnull const argsEnum = [[NSProcessInfo processInfo].arguments objectEnumerator];
		[argsEnum nextObject];

		bool useDF = false;
		NSFileHandle *_Nullable outputFH = nil;
		bool expectOutputPath = false;
		NSURL *_Nullable inputURL = nil;
		NSString *_Nullable resourceTypeString = nil;
		NSString *_Nullable resourceIDString = nil;

		for (NSString *_Nonnull const arg in argsEnum) {
			if (expectOutputPath) {
				if ([arg isEqualToString:@"-"]) {
					outputFH = [NSFileHandle fileHandleWithStandardOutput];
				} else {
					outputFH = [NSFileHandle fileHandleForWritingAtPath:arg];
				}
				expectOutputPath = false;
			}
			if ([arg isEqualToString:@"-useDF"]) {
				useDF = true;
			} else if ([arg isEqualToString:@"-o"]) {
				expectOutputPath = true;
			} else {
				if (inputURL == nil) {
					inputURL = [NSURL fileURLWithPath:arg isDirectory:false];
				} else if (resourceTypeString == nil) {
					resourceTypeString = arg;
				} else if (resourceIDString == nil) {
					resourceIDString = arg;
				} else {
					fprintf(stderr, "Too many arguments!\n");
					return EX_USAGE;
				}
			}
		}

		FSRef inputRef;
		if (! CFURLGetFSRef((__bridge CFURLRef)inputURL, &inputRef)) {
			fprintf(stderr, "Couldn't get FSRef\n");
			return EX_NOINPUT;
		}

		if (! [resourceTypeString hasPrefix:@"'"]) {
			resourceTypeString = [NSString stringWithFormat:@"'%@'", resourceTypeString];
		}

		ResType const resType = NSHFSTypeCodeFromFileType(resourceTypeString);
		ResID const resID = [resourceIDString integerValue];

		OSStatus err = noErr;
		HFSUniStr255 forkName;
		if (useDF) {
			err = FSGetDataForkName(&forkName);
		} else {
			err = FSGetResourceForkName(&forkName);
		}
		if (err != noErr) {
			fprintf(stderr, "Couldn't get %s fork name: %i/%s\n", useDF ? "data" : "resource", err, GetMacOSStatusCommentString(err));
			return EX_OSERR;
		}

		ResFileRefNum refnum = -1;
		err = FSOpenResourceFile(&inputRef, forkName.length, forkName.unicode, fsRdPerm, &refnum);
		if (err != noErr) {
			fprintf(stderr, "Couldn't open %s fork: %i/%s\n", useDF ? "data" : "resource", err, GetMacOSStatusCommentString(err));
			return EX_NOINPUT;
		}

		if (outputFH == nil) {
			NSString *_Nonnull const outputFilename = [NSString stringWithFormat:@"Resource-%@-%i.dat", resourceTypeString, resID];
			[[NSFileManager defaultManager] createFileAtPath:outputFilename contents:nil attributes:nil];
			outputFH = [NSFileHandle fileHandleForWritingAtPath:outputFilename];
		}

		Handle const resHandle = Get1Resource(resType, resID);
		if (! resHandle) {
			err = ResError();
			fprintf(stderr, "Couldn't get %s resource %i: %i/%s\n", resourceTypeString.UTF8String, resID, err, GetMacOSStatusCommentString(err));
			return EX_DATAERR;
		}
		HLock(resHandle);
		NSData *_Nonnull const resData = [NSData dataWithBytesNoCopy:*resHandle length:GetHandleSize(resHandle) freeWhenDone:false];
		NSError *_Nullable error = nil;
		bool const wrote = [outputFH writeData:resData error:&error];
		HUnlock(resHandle);
		if (! wrote) {
			fprintf(stderr, "Couldn't write resource data: %s\n", error.localizedDescription);
			return EX_IOERR;
		}
	}
	return EXIT_SUCCESS;
}
