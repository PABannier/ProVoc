//
//  main.c
//  ProVoc Spotlight importer
//
//  The CFPlugIn part of a Spotlight importer (the code that every importer has). The
//  importer of the original application was a PowerPC / Intel 32-bit binary; this one
//  does the same job (see GetMetadataForFile.m) for the processors of today.
//

#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFPlugInCOM.h>
#include <CoreServices/CoreServices.h>

// the factory declared in Info.plist (CFPlugInFactories)
#define PLUGIN_ID "52CE5235-7E23-49E2-8376-087085BF791E"

Boolean GetMetadataForFile(void *thisInterface, CFMutableDictionaryRef attributes, CFStringRef contentTypeUTI, CFStringRef pathToFile);

typedef struct __MetadataImporterPluginType {
	MDImporterInterfaceStruct *conduitInterface;
	CFUUIDRef factoryID;
	UInt32 refCount;
} MetadataImporterPluginType;

static HRESULT MetadataImporterQueryInterface(void *thisInstance, REFIID iid, LPVOID *ppv);
static ULONG MetadataImporterPluginAddRef(void *thisInstance);
static ULONG MetadataImporterPluginRelease(void *thisInstance);

static MDImporterInterfaceStruct sInterface = {
	NULL,
	MetadataImporterQueryInterface,
	MetadataImporterPluginAddRef,
	MetadataImporterPluginRelease,
	GetMetadataForFile
};

static MetadataImporterPluginType *AllocMetadataImporterPluginType(CFUUIDRef inFactoryID)
{
	MetadataImporterPluginType *instance = (MetadataImporterPluginType *)malloc(sizeof(MetadataImporterPluginType));
	memset(instance, 0, sizeof(MetadataImporterPluginType));
	instance->conduitInterface = &sInterface;
	instance->factoryID = CFRetain(inFactoryID);
	CFPlugInAddInstanceForFactory(inFactoryID);
	instance->refCount = 1;
	return instance;
}

static void DeallocMetadataImporterPluginType(MetadataImporterPluginType *inInstance)
{
	CFUUIDRef factoryID = inInstance->factoryID;
	free(inInstance);
	if (factoryID) {
		CFPlugInRemoveInstanceForFactory(factoryID);
		CFRelease(factoryID);
	}
}

static HRESULT MetadataImporterQueryInterface(void *thisInstance, REFIID iid, LPVOID *ppv)
{
	CFUUIDRef interfaceID = CFUUIDCreateFromUUIDBytes(kCFAllocatorDefault, iid);
	if (CFEqual(interfaceID, kMDImporterInterfaceID) || CFEqual(interfaceID, IUnknownUUID)) {
		((MetadataImporterPluginType *)thisInstance)->conduitInterface->AddRef(thisInstance);
		*ppv = thisInstance;
		CFRelease(interfaceID);
		return S_OK;
	}
	*ppv = NULL;
	CFRelease(interfaceID);
	return E_NOINTERFACE;
}

static ULONG MetadataImporterPluginAddRef(void *thisInstance)
{
	return ++((MetadataImporterPluginType *)thisInstance)->refCount;
}

static ULONG MetadataImporterPluginRelease(void *thisInstance)
{
	MetadataImporterPluginType *instance = (MetadataImporterPluginType *)thisInstance;
	if (--instance->refCount == 0) {
		DeallocMetadataImporterPluginType(instance);
		return 0;
	}
	return instance->refCount;
}

void *MetadataImporterPluginFactory(CFAllocatorRef allocator, CFUUIDRef typeID)
{
	if (CFEqual(typeID, kMDImporterTypeID)) {
		CFUUIDRef factoryID = CFUUIDCreateFromString(kCFAllocatorDefault, CFSTR(PLUGIN_ID));
		MetadataImporterPluginType *instance = AllocMetadataImporterPluginType(factoryID);
		CFRelease(factoryID);
		return instance;
	}
	return NULL;
}
