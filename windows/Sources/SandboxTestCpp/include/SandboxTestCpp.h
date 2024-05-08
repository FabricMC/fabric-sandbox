#include <string>
#include <windows.h>

// Function to speak text, returns true if successful
HRESULT sapi_speak(const std::string& text);