//
//  ProVocAnswerTests.m
//
//  The rules that decide whether a typed answer is right (-isAnswer:equalToWord:,
//  -genericAnswerString:), with the language options of the preferences.
//

#import <XCTest/XCTest.h>
#import "ProVocSilentTester.h"
#import "PVTestSupport.h"
#import "ProVocPreferences.h"

#define PVRight(answer, word) XCTAssertTrue([mTester isString:answer equalToString:word], @"\"%@\" should be accepted for \"%@\"", answer, word)
#define PVWrong(answer, word) XCTAssertFalse([mTester isString:answer equalToString:word], @"\"%@\" should be refused for \"%@\"", answer, word)

@interface ProVocAnswerTests : XCTestCase {
	ProVocDocument *mDocument;
	ProVocSilentTester *mTester;
	NSDictionary *mSavedDefaults;
}
@end

@implementation ProVocAnswerTests

-(void)setUp
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary *saved = [NSMutableDictionary dictionary];
	for (NSString *key in @[PVPrefsUseSynonymSeparator, PVPrefSynonymSeparator, PVPrefsUseCommentsSeparator, PVPrefCommentsSeparator])
		saved[key] = [defaults objectForKey:key];
	mSavedDefaults = [saved copy];
	[defaults setBool:YES forKey:PVPrefsUseSynonymSeparator];
	[defaults setObject:@"/" forKey:PVPrefSynonymSeparator];
	[defaults setBool:NO forKey:PVPrefsUseCommentsSeparator];
	[defaults setObject:@";" forKey:PVPrefCommentsSeparator];
	mDocument = [PVNewDocumentWithWords(@[]) retain];
	mTester = [[ProVocSilentTester alloc] initWithDocument:mDocument];
	[self setCase:YES accents:YES punctuation:YES spaces:YES determinants:@""];
}

-(void)tearDown
{
	[[NSUserDefaults standardUserDefaults] setValuesForKeysWithDictionary:mSavedDefaults];
	[mSavedDefaults release];
	[mTester release];
	mTester = nil;
	PVCloseDocument(mDocument);
	[mDocument release];
	mDocument = nil;
}

-(void)setCase:(BOOL)inCase accents:(BOOL)inAccents punctuation:(BOOL)inPunctuation spaces:(BOOL)inSpaces determinants:(NSString *)inDeterminants
{
	[mTester setLanguageSettings:@{PVCaseSensitive: @(inCase), PVAccentSensitive: @(inAccents), PVPunctuationSensitive: @(inPunctuation),
								   PVSpaceSensitive: @(inSpaces), @"FacultativeDeterminents": inDeterminants}];
}

-(void)testExactAnswer
{
	PVRight(@"maison", @"maison");
	PVWrong(@"maisons", @"maison");
	PVWrong(@"", @"maison");
}

-(void)testCaseSensitivity
{
	PVWrong(@"Maison", @"maison");
	PVWrong(@"berlin", @"Berlin");
	[self setCase:NO accents:YES punctuation:YES spaces:YES determinants:@""];
	PVRight(@"Maison", @"maison");
	PVRight(@"berlin", @"Berlin");
	PVRight(@"ÉTÉ", @"été");
	PVWrong(@"ETE", @"été");
}

-(void)testAccentSensitivity
{
	PVWrong(@"ete", @"été");
	PVWrong(@"garcon", @"garçon");
	[self setCase:YES accents:NO punctuation:YES spaces:YES determinants:@""];
	PVRight(@"ete", @"été");
	PVRight(@"été", @"ete");
	PVRight(@"a bientot", @"à bientôt");
	PVRight(@"nino", @"niño");
	PVWrong(@"Ete", @"été");
	[self setCase:NO accents:NO punctuation:YES spaces:YES determinants:@""];
	PVRight(@"Ete", @"été");
}

-(void)testFrenchAccentedInput
{
	for (NSString *word in @[@"être", @"Noël", @"garçon", @"où", @"à bientôt", @"cœur", @"aiguë", @"hôtel", @"déjà vu", @"L'été", @"naïf", @"ÇA", @"œuvre"])
		PVRight(word, word);
	PVWrong(@"etre", @"être");
	PVWrong(@"Noel", @"Noël");
	// the same letters composed (typed with a dead key) or decomposed (pasted, imported): equal
	PVRight(@"être", @"être");
	PVRight(@"être", @"être");
	PVRight(@"naïf", @"naïf");
}

-(void)testParenthesesAreOptional
{
	PVRight(@"maison", @"maison (f)");
	PVRight(@"maison (f)", @"maison (f)");
	PVRight(@"maison", @"(la) maison");
	PVRight(@"aller", @"aller (verbe) (irrégulier)");
	PVRight(@"to go", @"to go (went, gone)");
	PVWrong(@"maison f", @"maison (f)");
	PVWrong(@"mais", @"maison (f)");
	// the answer may carry its own optional part
	PVRight(@"maison (f)", @"maison");
}

-(void)testOptionalDeterminants
{
	PVWrong(@"maison", @"la maison");
	[self setCase:NO accents:YES punctuation:NO spaces:YES determinants:@"le, la, les, un, une, l'"];
	PVRight(@"maison", @"la maison");
	PVRight(@"la maison", @"maison");
	PVRight(@"une maison", @"la maison");
	PVRight(@"été chaud", @"l'été chaud");
	// a determinant is only optional next to other words: a word alone is never emptied
	PVWrong(@"été", @"l'été");
	PVWrong(@"lama", @"la ma");
	PVWrong(@"la", @"la maison");
}

-(void)testSynonymsAndSeparators
{
	PVRight(@"maison", @"maison/demeure");
	PVRight(@"demeure", @"maison/demeure");
	PVRight(@"demeure/maison", @"maison/demeure");
	PVRight(@"maison / demeure", @"maison/demeure");
	PVRight(@"maison", @"maison / demeure");
	PVWrong(@"chat", @"maison/demeure");
	PVWrong(@"maison/chat", @"maison/demeure");
	// a separator inside brackets does not separate
	PVRight(@"he/she (m/f)", @"he/she (m/f)");
	PVRight(@"il", @"il (m/f)/elle");
	// another separator
	[[NSUserDefaults standardUserDefaults] setObject:@"," forKey:PVPrefSynonymSeparator];
	PVRight(@"demeure", @"maison, demeure");
	PVWrong(@"demeure", @"maison/demeure");
	// no separator at all
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:PVPrefsUseSynonymSeparator];
	PVWrong(@"demeure", @"maison, demeure");
	PVRight(@"maison, demeure", @"maison, demeure");
}

-(void)testCommentSeparator
{
	PVWrong(@"maison", @"maison; nom féminin");
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:PVPrefsUseCommentsSeparator];
	PVRight(@"maison", @"maison; nom féminin");
	PVRight(@"maison; nom féminin", @"maison; nom féminin");
	PVWrong(@"nom féminin", @"maison; nom féminin");
}

-(void)testSpaces
{
	PVRight(@" maison ", @"maison");
	PVRight(@"maison", @"  maison");
	PVRight(@"la  maison", @"la maison");
	PVRight(@"la maison", @"la maison");	// no-break space
	PVWrong(@"lamaison", @"la maison");
	[self setCase:YES accents:YES punctuation:YES spaces:NO determinants:@""];
	PVRight(@"lamaison", @"la maison");
	PVRight(@"la maison", @"lamaison");
}

-(void)testPunctuation
{
	PVWrong(@"Hello", @"Hello!");
	PVWrong(@"quest-ce", @"qu'est-ce");
	PVRight(@"wait...", @"wait…");	// ellipsis character
	[self setCase:YES accents:YES punctuation:NO spaces:YES determinants:@""];
	PVRight(@"Hello", @"Hello!");
	PVRight(@"quest ce", @"qu'est ce?");
	PVRight(@"¿Cómo estás?", @"Cómo estás");
	PVWrong(@"Hallo", @"Hello!");
}

@end
