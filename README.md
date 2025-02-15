# Repackaging of OpenSSL Libraries for Windows

This project contains the scripts to build a Windows installer which contains
the OpenSSL libraries for Win32, Win64 and Arm64. This is an architecture-
neutral installer which can be installed on all Windows systems. On that
system, using Visual Studio, developers can build applications using OpenSSL
for the three target architectures.

## Building the installer

To build the installer, just run the PowerShell script `build.ps1`. The resulting
installer is left in directory `installers`, for instance `OpenSSL-WinLibs-3.4.1.exe`.

The installer is an x86 executable which can be run on all Windows platforms
(on Arm64, the execution is emulated).

IMPORTANT: The script shall be run on an Arm64 Windows system. See details below.

## Using OpenSSL from applications

Once installed, the environment variable `OPENSSL_WINLIBS` is defined to the installation
path of the OpenSSL libraries. The default is `C:\Program Files\OpenSSL-WinLibs`.

An application can use either the OpenSSL DLL's or the static libraries.

To use the OpenSSL DLL's, manually add the following line at the end of the
application project file (the `.vcxproj` file), just before the final `</Project>`:
~~~
<Import Project="$(OPENSSL_WINLIBS)\openssl-dll.props"/>
~~~

To use the OpenSSL static librarie, use the following line instead:
~~~
<Import Project="$(OPENSSL_WINLIBS)\openssl-static.props"/>
~~~

## Original delivery of OpenSSL binaries for Windows

The official OpenSSL binaries for Windows are available here:
https://slproweb.com/products/Win32OpenSSL.html

There are installers for Win32, Win64 and Arm64. Each installer provides a complete
OpenSSL infrastructure: command line tools, libraries, examples.

It you need to use the OpenSSL command line tools, just install the binaries for your
system. If you want to develop and build applications for your infrastructure only,
there is nothing else to install. However, if you want to build your application for
the three architectures, then you need the libraries for these three architectures.
So, you need to install the three installers on the same system. This is possible
because each installer creates its own directory tree.

So far, so good, nothing else is needed and this project seems useless.

However, the situation is not so simple, especially on Intel systems. The current
status, as of OpenSSL 3.4.1, is the following:

- On Arm64 systems, you can install OpenSSL binaries for all architectures, Win32,
  Win64 and Arm64.
- On Intel systems, however, you can only install OpenSSL for Win32 and Win64. The
  installation of the Arm64 version fails. The installer itself is a x86 executable
  and it correctly executes on Intel systems. However, the installation code tests
  the system architecture and refuses to continue on Intel systems.
  
This is a huge problem because most Windows build servers run on Intel systems.
Using the official OpenSSL binaries, it is consequently impossible to build
applications for Arm64 from Intel systems when they use OpenSSL.

This project is designed to solve that problem. It creates one single installer
which contains the OpenSSL libraries for all architectures and it can be installed
on any system.

The build script first downloads and installs the latest official OpenSSL binaries
for all three architectures. Then, it extracts the libraries for all architectures
and repackages them into one single installer.

Because the script needs to install the OpenSSL binaries for all architectures,
it must be run on an Arm64 machine. If the script is run from an Intel machine
(32 or 64 bits), an installer is successfully built but it will contains the
libraries for Win32 and Win64 only. The libraries for Arm64 will not be present.
