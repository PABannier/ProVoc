//
//  ProVocImporterTests.m
//
//  The Spotlight importer shipped in the application (Contents/Library/Spotlight),
//  loaded and called the way Spotlight does: as a CFPlugIn with the importer interface.
//

#import <XCTest/XCTest.h>
#import <CoreServices/CoreServices.h>
#import <CoreFoundation/CFPlugInCOM.h>
#import "PVTestSupport.h"

@interface ProVocImporterTests : XCTestCase
@end

@implementation ProVocImporterTests

-(NSString *)importerPath
{
	return [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/Library/Spotlight/ProVoc.mdimporter"];
}

-(NSDictionary *)attributesOfFile:(NSString *)inPath
{
	CFPlugInRef plugIn = CFPlugInCreate(kCFAllocatorDefault, (CFURLRef)[NSURL fileURLWithPath:[self importerPath]]);
	XCTAssertTrue(plugIn != NULL, @"the importer is not a plug-in");
	if (!plugIn)
		return nil;
	NSArray *factories = [(NSArray *)CFPlugInFindFactoriesForPlugInTypeInPlugIn(kMDImporterTypeID, plugIn) autorelease];
	XCTAssertEqual([factories count], 1u, @"factories of the importer");
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	if ([factories count] == 1) {
		IUnknownVTbl **unknown = CFPlugInInstanceCreate(kCFAllocatorDefault, (CFUUIDRef)factories[0], kMDImporterTypeID);
		XCTAssertTrue(unknown != NULL, @"the importer cannot be instantiated");
		MDImporterInterfaceStruct **importer = NULL;
		if (unknown) {
			(*unknown)->QueryInterface(unknown, CFUUIDGetUUIDBytes(kMDImporterInterfaceID), (LPVOID *)&importer);
			(*unknown)->Release(unknown);
		}
		XCTAssertTrue(importer != NULL, @"the plug-in has no importer interface");
		if (importer) {
			Boolean imported = (*importer)->ImporterImportData(importer, (CFMutableDictionaryRef)attributes, CFSTR("ch.arizona-software.provoc.vocabulary"), (CFStringRef)inPath);
			if (!imported)
				attributes = nil;
			(*importer)->Release(importer);
		}
	}
	return attributes;
}

-(void)testImporterIsNativeAndDeclaresTheDocumentType
{
	NSBundle *importer = [NSBundle bundleWithPath:[self importerPath]];
	XCTAssertNotNil(importer, @"no importer at %@", [self importerPath]);
	XCTAssertTrue([[importer executableArchitectures] containsObject:@(NSBundleExecutableArchitectureARM64)], @"the importer is not built for arm64: %@", [importer executableArchitectures]);
	NSArray *types = [[[importer infoDictionary] objectForKey:@"CFBundleDocumentTypes"] valueForKeyPath:@"@unionOfArrays.LSItemContentTypes"];
	XCTAssertEqualObjects(types, (@[@"ch.arizona-software.provoc.vocabulary"]));
	// the type of .pvoc documents, exported by the application
	NSArray *exported = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"UTExportedTypeDeclarations"];
	XCTAssertTrue([[exported valueForKey:@"UTTypeIdentifier"] containsObject:@"ch.arizona-software.provoc.vocabulary"], @"%@", [exported valueForKey:@"UTTypeIdentifier"]);
	XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[[self importerPath] stringByAppendingPathComponent:@"Contents/Resources/schema.xml"]], @"no schema.xml in the importer");
}

-(void)testImporterGivesWordsLanguagesAndCount
{
	NSString *fixtures = [PVTestSourceRoot() stringByAppendingPathComponent:@"fixtures/generated"];
	NSDictionary *attributes = [self attributesOfFile:[fixtures stringByAppendingPathComponent:@"Rich.pvoc"]];
	XCTAssertNotNil(attributes, @"Rich.pvoc was not imported");
	NSString *text = attributes[(id)kMDItemTextContent];
	for (NSString *word in @[@"house", @"maison", @"grand / gros", @"(to) eat", @"a season; masculine", @"oiseau", @"Unit 1", @"Animals", @"Extras"])
		XCTAssertTrue([text rangeOfString:word].location != NSNotFound, @"%@ is not in the text content: %@", word, text);
	XCTAssertEqualObjects(attributes[@"ch_arizonasoftware_provoc_numberofwords"], @10);
	XCTAssertEqual([attributes[@"ch_arizonasoftware_provoc_languages"] count], 2u, @"%@", attributes[@"ch_arizonasoftware_provoc_languages"]);

	attributes = [self attributesOfFile:[fixtures stringByAppendingPathComponent:@"Accents.pvoc"]];
	text = attributes[(id)kMDItemTextContent];
	for (NSString *word in @[@"garçon", @"cœur", @"ελληνικά", @"日本語", @"Straße"])
		XCTAssertTrue([text rangeOfString:word].location != NSNotFound, @"%@ is not in the text content", word);
	XCTAssertEqualObjects(attributes[@"ch_arizonasoftware_provoc_numberofwords"], @15);

	// every real deck is read too
	NSString *decks = [PVTestSourceRoot() stringByAppendingPathComponent:@"fixtures/user-decks"];
	for (NSString *name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:decks error:NULL])
		if ([[name pathExtension] isEqualToString:@"pvoc"]) {
			attributes = [self attributesOfFile:[decks stringByAppendingPathComponent:name]];
			XCTAssertTrue([attributes[@"ch_arizonasoftware_provoc_numberofwords"] intValue] > 0 && [attributes[(id)kMDItemTextContent] length] > 0, @"%@ was not imported: %@", name, attributes[@"ch_arizonasoftware_provoc_numberofwords"]);
		}

	// something that is not a ProVoc document
	XCTAssertNil([self attributesOfFile:NSTemporaryDirectory()], @"a folder without vocabulary was imported");
}

@end
