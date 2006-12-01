SetCompressor bzip2

!define MUI_VERSION "0.62"
!define MUI_NAME    "parl"
!define PERL_PATH   "C:\perl"

XPStyle On
Name "PAR Loader"
DirText "Select the location of parl.exe:"
OutFile "${MUI_NAME}-${MUI_VERSION}-win32.exe"
InstallDir $SYSDIR
AutoCloseWindow true
ShowInstDetails hide
InstallColors /windows
InstProgressFlags smooth colored

Section "Install"
    SetOverwrite try
    SetOutPath $INSTDIR
    File "${PERL_PATH}\bin\parl.exe"
    File "${PERL_PATH}\bin\perl*.dll"
SectionEnd
