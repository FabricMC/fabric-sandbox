# Fabric Sandbox
Highly experimental windows sandbox for Fabric. The sandbox aims to act as protection not prevention, thus any exploits / security issues should be made publicly to this repo.

This sandbox should have little to no performance overhead as it runs the game within a [Windows App Container](https://learn.microsoft.com/en-us/windows/win32/secauthz/appcontainer-isolation).

### Testing tips
To validate that the game is running within a sandbox use [Process Monitor](https://learn.microsoft.com/en-us/sysinternals/downloads/procmon) and enable the "Integrity" column and check for "AppContainer"

File access should be limited as follows:
- Read+Write working directory
- Read .minecraft
- Read Java home (of the JDK being used)
- No registry access

Network access is enabled, but may have restricted access to localhost as per the UWP defaults. For debugging purposes use `CheckNetIsolation.exe LoopbackExempt -is -p=<CONTAINER_SID>` from an elevated command prompt. See [here](https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/windows-firewall/troubleshooting-uwp-firewall#debugging-uwp-app-loopback-scenarios) for more info.

### Future improvements
- Less Privileged AppContainer (LPAC), allows for fine grain control to almost all aspects of a machine.
- Access token protection
- MacOS and possibly Linux support

### Requirements for building
- Requires ARM64 or x64 Windows 10 or 11
- Swift for windows either official or from (github.com/thebrowsercompany/swift-build)[https://github.com/thebrowsercompany/swift-build]
- Wix installer tools `dotnet tool install --global wix --version 5.0.0` (Used to extract the swift redistributables)

### FAQ
- Why swift?
  - Writing new security software in C++ does not seem like a good idea
- Why Windows only?
  - The vast majority of players and malicious code is on Windows.
- Where is the swift source code
  - Its in `windows/Sources`

### License
This repository does not have an official license yet as I do not want people using this in production. You may learn from the code and improve it but please don't distribute this, as it's far from battle tested. I would strongly recommend opening an issue before thinking about creating a PR. Thanks for understanding.