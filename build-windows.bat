rmdir /S /Q .\build
mkdir .\build
odin build . -out:.\build\frog-buster.exe
xcopy .\sprites .\build\sprites /E /H /I
