//
//  GetMetadataForFile.m
//  ProVoc Spotlight importer
//
//  What Spotlight knows of a ProVoc document (a .pvoc package): its words, their
//  translations and comments and the names of its lessons as text content - so that
//  a document is found by any of its words, in the Finder and by ProVoc itself
//  (ProVocSpotlighter) - its two languages and its number of words.
//

#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>

// The vocabulary is a keyed archive of the objects of the application. It is read
// with stand-ins that only keep what the importer needs.
@interface PVImportedNode : NSObject <NSCoding> {
@public
	NSMutableArray *mTexts;
	NSArray *mChildren;
}
@end

@implementation PVImportedNode

-(id)initWithCoder:(NSCoder *)inCoder
{
	if (self = [super init]) {
		mTexts = [[NSMutableArray alloc] init];
		for (NSString *key in @[@"Title", @"ProVocSourceWord", @"ProVocTargetWord", @"ProVocComment", @"SourceLanguage", @"TargetLanguage"])
			if ([inCoder containsValueForKey:key]) {
				id text = [inCoder decodeObjectForKey:key];
				if ([text isKindOfClass:[NSString class]] && [text length] > 0)
					[mTexts addObject:text];
			}
		for (NSString *key in @[@"RootChapter", @"Children", @"Words"])
			if ([inCoder containsValueForKey:key]) {
				id children = [inCoder decodeObjectForKey:key];
				mChildren = [[children isKindOfClass:[NSArray class]] ? children : children ? @[children] : @[] retain];
			}
	}
	return self;
}

-(void)encodeWithCoder:(NSCoder *)inCoder
{
}

-(void)dealloc
{
	[mTexts release];
	[mChildren release];
	[super dealloc];
}

-(void)addTextsTo:(NSMutableArray *)ioTexts
{
	[ioTexts addObjectsFromArray:mTexts];
	for (id child in mChildren)
		if ([child isKindOfClass:[PVImportedNode class]])
			[child addTextsTo:ioTexts];
}

@end

@interface PVImportedData : PVImportedNode
@end
@implementation PVImportedData
@end

@interface PVImportedWord : PVImportedNode
@end
@implementation PVImportedWord
@end

// Whatever else is in the archive (and is of no interest here)
@interface PVImportedOther : NSObject <NSCoding>
@end
@implementation PVImportedOther
-(id)initWithCoder:(NSCoder *)inCoder { return [super init]; }
-(void)encodeWithCoder:(NSCoder *)inCoder { }
@end

@interface PVImporterDelegate : NSObject <NSKeyedUnarchiverDelegate>
@end
@implementation PVImporterDelegate
-(Class)unarchiver:(NSKeyedUnarchiver *)inUnarchiver cannotDecodeObjectOfClassName:(NSString *)inName originalClasses:(NSArray *)inClassNames
{
	return [PVImportedOther class];
}
@end

static void PVCountWords(PVImportedNode *inNode, NSUInteger *ioCount)
{
	if ([inNode isKindOfClass:[PVImportedWord class]])
		(*ioCount)++;
	for (id child in inNode->mChildren)
		if ([child isKindOfClass:[PVImportedNode class]])
			PVCountWords(child, ioCount);
}

Boolean GetMetadataForFile(void *thisInterface, CFMutableDictionaryRef attributes, CFStringRef contentTypeUTI, CFStringRef pathToFile)
{
	Boolean imported = false;
	@autoreleasepool {
		@try {
			NSData *data = [NSData dataWithContentsOfFile:[(NSString *)pathToFile stringByAppendingPathComponent:@"Data"]];
			if (data) {
				NSKeyedUnarchiver *unarchiver = [[[NSKeyedUnarchiver alloc] initForReadingWithData:data] autorelease];
				PVImporterDelegate *delegate = [[[PVImporterDelegate alloc] init] autorelease];
				[unarchiver setDelegate:delegate];
				[unarchiver setClass:[PVImportedData class] forClassName:@"ProVocData"];
				[unarchiver setClass:[PVImportedNode class] forClassName:@"ProVocChapter"];
				[unarchiver setClass:[PVImportedNode class] forClassName:@"ProVocPage"];
				[unarchiver setClass:[PVImportedWord class] forClassName:@"ProVocWord"];
				PVImportedData *root = [unarchiver decodeObjectForKey:@"root"];
				[unarchiver finishDecoding];
				if ([root isKindOfClass:[PVImportedData class]]) {
					NSMutableArray *texts = [NSMutableArray array];
					for (id child in root->mChildren)
						if ([child isKindOfClass:[PVImportedNode class]])
							[child addTextsTo:texts];
					NSUInteger words = 0;
					PVCountWords(root, &words);
					NSMutableDictionary *values = (NSMutableDictionary *)attributes;
					values[(id)kMDItemTextContent] = [texts componentsJoinedByString:@"\n"];
					values[@"ch_arizonasoftware_provoc_numberofwords"] = @(words);
					// the two languages come first in the texts of the root object
					if ([root->mTexts count] > 0) {
						values[@"ch_arizonasoftware_provoc_languages"] = root->mTexts;
						values[(id)kMDItemLanguages] = root->mTexts;
					}
					values[(id)kMDItemKind] = @"ProVoc Document";
					imported = true;
				}
			}
		} @catch (NSException *exception) {
			NSLog(@"ProVoc importer: %@: %@", pathToFile, exception);
		}
	}
	return imported;
}
