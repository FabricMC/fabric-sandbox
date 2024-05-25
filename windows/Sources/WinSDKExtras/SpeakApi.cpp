#include "SpeakApi.h"

#include <atlbase.h>
#include <sapi.h>

class SpeakApi::Impl {
    public:
    CComPtr<ISpVoice> spVoice;
};

SpeakApi::SpeakApi(): pImpl{std::make_shared<Impl>()} {
    pImpl->spVoice.CoCreateInstance(CLSID_SpVoice);
}

SpeakApi::~SpeakApi() {
}

SpeakApi::SpeakApi(const SpeakApi& other): pImpl{other.pImpl} {
}

HRESULT SpeakApi::Speak(std::wstring text, DWORD dwFlags) {
    return pImpl->spVoice->Speak(text.c_str(), dwFlags, NULL);
}

HRESULT SpeakApi::Skip() {
    return pImpl->spVoice->Skip(L"Sentence", 0x7fffffff, NULL);
}