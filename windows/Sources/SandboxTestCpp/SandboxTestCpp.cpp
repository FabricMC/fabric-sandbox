#include "SandboxTestCpp.h"

#include <sapi.h>
#include <AtlBase.h>
#include <atlconv.h>

HRESULT sapi_speak(const std::string& text) {
    CComPtr<ISpVoice> cpVoice;
    HRESULT hr = cpVoice.CoCreateInstance(CLSID_SpVoice);

    if (!SUCCEEDED(hr)) {
        return hr;
    }

    return cpVoice->Speak(CA2W(text.c_str()), SPF_IS_NOT_XML, NULL);
}