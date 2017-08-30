# SmuggleBus

SmuggleBus is a Crowe developed USB bootable tool, built on a bare-bones Linux OS. It was designed to aid penetration testers and red teamers performing physical social engineering exercises. 

Upon obtaining physical premises access to the target organization, the tool can be used to aid in collection of local credentials and implanting backdoors. This is accomplished by taking advantage of unencrypted system hard drives. 

A typical attack flow would consist of the following:

	- Pentester obtains a physical access and identifies a desktop system not in use
            - unattended, conference room, or kiosk 
	- The pentester shuts down the target system and boots into the SmuggleBus
	- In seconds, SmuggleBus will then:
		- Mount the unencrypted system hard drive
		- Copy local hives (SAM, SYSTEM, SECURITY)onto the SmuggleBus.
                - Uses a combination of symmetric and asymmetric cryptography
                - files get encrypted prior to being saved. 
		- Implant a payload (Meterpreter, Empire, or Cobalt Strike), configured to run as SYSTEM. 
		- The SmuggleBus will then safely shutdown and return to the standard Windows OS boot. 
	- Upon boot the system executes the payload.  Any uploaded or modified files and registry keys get cleaned up.
  


## Operating System
The SmuggleBus is built on Tiny Core Linux OS (http://distro.ibiblio.org/tinycorelinux), with only the essential packages loaded in. No networking is loaded to avoid tripping any Network Access Controls. 

When imaged, the following will reside in the SmuggleBus home folder under /home/tc/:

| File | Description |
| --- | --- |
|startup.sh| Executed on boot. Launches modified hashgrab.py script, restarts the system upon completion.|
|hashgrab.py|	Python code that will identify, mount the Windows OS partition, export the hashes, and setup the backdoor. (Original HashGrab2 code created by s3my0n, under GNU General Public License)|
|public_key.pem|	Public key used to encrypt the exported hives prior to writing to flash memory.|
|shell_files|	Placeholder location for the backdoor implant files.|
|reged|	Registry editor, export and import tool. Used when injecting backdoors from Linux OS. (Part of chntpw, the Offline Windows Password Editor, under GNU Lesser General Public License.) https://github.com/rescatux/chntpw|
|.profile| Used to Launch startup.sh when TinyCore is fully loaded|


## Encryption
Using a combination of symmetric and asymmetric cryptography, files get encrypted prior to being saved. 

Setup:

    1. Generate RSA public/private key pair ./generate_keys.sh
    2. Copy the public key onto the SmuggleBus home directory /home/tc/public_key.pem
		
Execution Workflow:

	1. SmuggleBus generates a random 32 byte value (symmetric-key)
	2. The symmetric-key is used to AES 256 encrypt the collected registry hives
	3. Public key is used to encrypt the symmetric-key
	4. Once ran, new folder will be created in home directory, containing:
		- SAM.enc
		- SYSTEM.enc
		- SECURITY.enc
		- KEY.enc

Decryption:

    1. Private key is used to decrypt the symmetric-key
    2. Decrypted symmetric-key is used to decrypt the registry hives ./decrypt.sh [arguments]
		
		Required arguments:
			-i DIRECTORY    Directory with SAM/SYSTEM/SECURITY & key.enc files    
			-o DIRECTORY    Output location                                       
			-p FILE         Private key location                                  
		Optional arguments:
			-x              Run secretsdump.py when done (Default: False) 
		
		
## Backdoor Implant
The design goal of the SmuggleBus payload injection was to have minimal impact on the targeted system. Any added or modified files and registry keys get cleaned-up upon successful execution. 

Since pentesters often times will target machines onto which users rarely log into (conference room PCs, kiosks, etc.) the payload needs to execute prior to user logon with "NT AUTHORITY\SYSTEM" account. Currently two techniques are supported. Upon SmuggleBus execution, OS version check is performed. Scheduled Task implant is used if Win7 is detected, and service implant if Win10. 

Due to updates/enhancements, Scheduled Task implant technique no longer works on Win10. For technical details and analysis, see BlackHat Arsenal slide deck.

### Scheduled Task
Two scheduled tasks are injected, configured with a short execution delay with "At startup" trigger. Task 1 launches the payload, Task 2 performs the clean-up. 

To create the implant files, run the ScheduleTask.ps1 script on a test system matching the OS version (Win7 implants need to be created on Win7 test box). This script will output files that will need to be placed in the SmuggleBus "shell_files/win7" folder. 

### Service
The service backdoor implant works by swapping a Windows service binary with attacker's binary. Upon system boot, attacker's exe will execute, which has been configured to launch a PowerShell download cradle. The web hosted PowerShell code will then create two scheduled tasks: a payload task, and a clean-up task. 

Use spoolsv.c and after updating the URL, compile it with MinGW (x86_64-w64-mingw32-gcc spoolsv.c -o spoolsv.exe) and place it under "shell_files/win10" folder. The following is the execution flow:

	1. Backdoor is injected
		• Offline drive, "spoolsv.exe" is renamed to "spoolsv.exe.bak"
		• Hacked spoolsv.exe is uploaded
	2. System reboots, hacked spoolsv.exe executes
		• Configured to execute a web hosted PowerShell one-liner
	3. New Scheduled Task is created (payload)
		• SYSTEM shell 
	4. 2nd task is created (clean-up)
		• Cleans up the scheduled tasks
		• Deletes hacked spoolsv.exe and restores original exe
		• Fixes temporarily modified service permissions
		• Service is started, resumes normal operation

# Installing TinyCore
1. Download Core Plus from http://www.tinycorelinux.net/downloads.html
2. Install Tinycore to a USB flashdrive,
    - Use Ext2 as the partition
    - Select “Core Only” for the installation
3. Mount the flash drive into a linux distribution
4. Open boot/extlinux/extlinux.conf in an editior
5. Copy your UUID from the last line and append home=UUID=”YOUR UUID” and opt=UUID=”YOUR UUID”. This should all be on one line
    - Example: 
    APPEND initrd=/boot/core.gz quiet norestore waitusb=5:UUID="a13c5174-bde8-48f2-ac19-d9a6b73bb7c5" tce=UUID="a13c5174-bde8-48f2-ac19-d9a6b73bb7c5" home=UUID="a13c5174-bde8-48f2-ac19-d9a6b73bb7c5" opt=UUID="a13c5174-bde8-48f2-ac19-d9a6b73bb7c5"
6. Download Python and OpenSSL tcz packages from http://distro.ibiblio.org/tinycorelinux/8.x/x86/tcz/
7. Place Python and OpenSSL inside /tce/optional
8. Edit OnBoot.lst and add the entries, separated by a new line:
    - python.tcz 
    - openssl.tcz
9. Overwrite tc folder with the one in github.
