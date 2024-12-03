//
//  main.m
//  get1Resource
//
//  Created by Peter Hosey on 2024-12-03.
//

#import <Foundation/Foundation.h>
#import <sysexits.h>

static bool dumpResource(Handle _Nonnull const resHandle, NSFileHandle *_Nonnull const outputFH, NSError *_Nullable *_Nonnull const outError);

int main(int argc, const char * argv[]) {
	@autoreleasepool {
		NSEnumerator <NSString *> *_Nonnull const argsEnum = [[NSProcessInfo processInfo].arguments objectEnumerator];
		[argsEnum nextObject];

		bool useDF = false;
		bool expectOutputPath = false;
		NSString *_Nullable outputPath = nil;
		NSFileHandle *_Nullable outputFH = nil;
		NSURL *_Nullable inputURL = nil;
		NSString *_Nullable resourceTypeString = nil;
		NSString *_Nullable resourceIDString = nil;

		for (NSString *_Nonnull const arg in argsEnum) {
			if (expectOutputPath) {
				outputPath = arg;
				expectOutputPath = false;
			} else if ([arg isEqualToString:@"-useDF"]) {
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
			fprintf(stderr, "Couldn't get FSRef for %s\n", inputURL.path.UTF8String);
			return EX_NOINPUT;
		}

		if (! [resourceTypeString hasPrefix:@"'"]) {
			resourceTypeString = [NSString stringWithFormat:@"'%@'", resourceTypeString];
		}

		ResType const resType = NSHFSTypeCodeFromFileType(resourceTypeString);

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

		if (resourceIDString != nil) {
			if ([outputPath isEqualToString:@"-"]) {
				outputFH = [NSFileHandle fileHandleWithStandardOutput];
			} else {
				outputFH = [NSFileHandle fileHandleForWritingAtPath:outputPath];
			}

			ResID const resID = [resourceIDString integerValue];

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
			NSError *_Nullable error = nil;
			if (! dumpResource(resHandle, outputFH, &error)) {
				fprintf(stderr, "Couldn't write resource data: %s\n", error.localizedDescription);
				return EX_IOERR;
			}
		} else /*Dump all resources of some type.*/ {
			if (outputPath == nil) {
				outputPath = [inputURL.path stringByAppendingPathComponent:@"rsrcd"];
			}
			NSURL *_Nonnull const outputDirectoryURL = [NSURL fileURLWithPath:outputPath isDirectory:true];

			NSError *_Nullable error = nil;
			NSFileManager *_Nonnull const mgr = [NSFileManager defaultManager];
			bool const createdOutputDir = [mgr createDirectoryAtURL:outputDirectoryURL withIntermediateDirectories:false attributes:nil error:&error];
			if (! createdOutputDir) {
				if (error.domain != NSCocoaErrorDomain || error.code != NSFileWriteFileExistsError) {
					fprintf(stderr, "Couldn't create output directory at %s: %s\n", outputDirectoryURL.path.UTF8String, error.localizedDescription.UTF8String);
					return EX_CANTCREAT;
				}
			}

			for (ResourceIndex idx = 1, numRsrcs = Count1Resources(resType); idx <= numRsrcs; ++idx) {
				Handle const resHandle = Get1IndResource(resType, idx);
				if (! resHandle) {
					err = ResError();
					fprintf(stderr, "Couldn't get %i'th %s resource: %i/%s\n", idx, resourceTypeString.UTF8String, err, GetMacOSStatusCommentString(err));
					return EX_DATAERR;
				}

				ResID resID = -1;
				GetResInfo(resHandle, &resID, /*type*/ NULL, /*name*/ NULL);
				NSString *_Nonnull const ext = @"dat";
				NSString *_Nonnull const outputFilename = [NSString stringWithFormat:@"Resource-%@-%i.%@", resourceTypeString, resID, ext];
				NSURL *_Nonnull const outputFileURL = [outputDirectoryURL URLByAppendingPathComponent:outputFilename isDirectory:false];
				[mgr createFileAtPath:outputFileURL.path contents:nil attributes:nil];
				outputFH = [NSFileHandle fileHandleForWritingToURL:outputFileURL error:&error];
				if (outputFH == nil) {
					fprintf(stderr, "Couldn't open output file %s: %s\n", outputFileURL.path.UTF8String, error.localizedDescription.UTF8String);
					return EX_CANTCREAT;
				}

				if (! dumpResource(resHandle, outputFH, &error)) {
					fprintf(stderr, "Couldn't write resource data: %s\n", error.localizedDescription);
					return EX_IOERR;
				}
			}
		}
	}
	return EXIT_SUCCESS;
}

static bool dumpResource(Handle _Nonnull const resHandle, NSFileHandle *_Nonnull const outputFH, NSError *_Nullable *_Nonnull const outError) {
	HLock(resHandle);
	NSData *_Nonnull const resData = [NSData dataWithBytesNoCopy:*resHandle length:GetHandleSize(resHandle) freeWhenDone:false];
	bool const wrote = [outputFH writeData:resData error:outError];
	HUnlock(resHandle);
	return wrote;
}
