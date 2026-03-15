// build/windows/DeckLinkAPIDispatch.cpp
//
// Windows COM-based implementation of the DeckLink factory functions.
// The DeckLink SDK ships a Linux/macOS version that uses dlopen(); this
// file replaces it for Windows builds using MinGW64/MSYS2.
//
// Compile alongside your project with DeckLinkAPI.h and DeckLinkAPI_i.c
// generated from DeckLinkAPI.idl via widl (see build/windows/build.sh).

#include <objbase.h>
#include "DeckLinkAPI.h"
#include "DeckLinkAPI_i.c"

IDeckLinkIterator* CreateDeckLinkIteratorInstance(void)
{
    IDeckLinkIterator* iterator = nullptr;
    CoCreateInstance(CLSID_CDeckLinkIterator, nullptr, CLSCTX_ALL,
                     IID_IDeckLinkIterator, reinterpret_cast<void**>(&iterator));
    return iterator;
}

IDeckLinkAPIInformation* CreateDeckLinkAPIInformationInstance(void)
{
    IDeckLinkAPIInformation* info = nullptr;
    CoCreateInstance(CLSID_CDeckLinkAPIInformation, nullptr, CLSCTX_ALL,
                     IID_IDeckLinkAPIInformation, reinterpret_cast<void**>(&info));
    return info;
}

IDeckLinkVideoConversion* CreateDeckLinkVideoConversionInstance(void)
{
    IDeckLinkVideoConversion* conv = nullptr;
    CoCreateInstance(CLSID_CDeckLinkVideoConversion, nullptr, CLSCTX_ALL,
                     IID_IDeckLinkVideoConversion, reinterpret_cast<void**>(&conv));
    return conv;
}

IDeckLinkDiscovery* CreateDeckLinkDiscoveryInstance(void)
{
    IDeckLinkDiscovery* disc = nullptr;
    CoCreateInstance(CLSID_CDeckLinkDiscovery, nullptr, CLSCTX_ALL,
                     IID_IDeckLinkDiscovery, reinterpret_cast<void**>(&disc));
    return disc;
}

IDeckLinkVideoFrameAncillaryPackets* CreateDeckLinkVideoFrameAncillaryPacketsInstance(void)
{
    IDeckLinkVideoFrameAncillaryPackets* packets = nullptr;
    CoCreateInstance(CLSID_CDeckLinkVideoFrameAncillaryPackets, nullptr, CLSCTX_ALL,
                     IID_IDeckLinkVideoFrameAncillaryPackets, reinterpret_cast<void**>(&packets));
    return packets;
}

bool IsDeckLinkAPIPresent(void)
{
    IDeckLinkIterator* iterator = nullptr;
    HRESULT hr = CoCreateInstance(CLSID_CDeckLinkIterator, nullptr, CLSCTX_ALL,
                                  IID_IDeckLinkIterator, reinterpret_cast<void**>(&iterator));
    if (SUCCEEDED(hr) && iterator) {
        iterator->Release();
        return true;
    }
    return false;
}
