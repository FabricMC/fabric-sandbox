#include "SpeakApi.h"

#include <atlbase.h>
#include <atlconv.h>
#include <sapi.h>
#include <stdexcept>

class SpeakApi::Impl {
    public:
    Impl() {
        auto result = spVoice.CoCreateInstance(CLSID_SpVoice);
        if (!SUCCEEDED(result)) {
            throw std::runtime_error("Failed to create ISpVoice instance");
        }
    }

    CComPtr<ISpVoice> spVoice;
};

SpeakApi::SpeakApi(): pImpl{std::make_shared<Impl>()} {
}

SpeakApi::~SpeakApi() {
}

SpeakApi::SpeakApi(const SpeakApi& other): pImpl{other.pImpl} {
}

HRESULT SpeakApi::Speak(std::string text, DWORD dwFlags) {
    CA2W textw(text.c_str());
    return pImpl->spVoice->Speak(textw, dwFlags, NULL);
}

HRESULT SpeakApi::Skip() {
    return pImpl->spVoice->Skip(L"Sentence", 0x7fffffff, NULL);
}