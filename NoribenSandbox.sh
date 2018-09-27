#!/bin/bash
#Noriben Sandbox Automation Script
#Responsible for:
#* Copying malware into a known VM
#* Running malware sample
#* Copying off results
#
#Ensure you set the environment variables below to match your system

NORIBEN_DEBUG=""
DELAY=10
WORKINGDIR=`pwd`
USEVBOX=""

# VMWare Options
VMW_RUN=/Applications/VMware\ Fusion.app/Contents/Library/VMW_RUN
VMX=~/VMs/Win7_VICTIM.vmwarevm/Win7_VICTIM.vmx

# VirtualBox Options
VBX_RUN=vboxmanage
VM_NAME="Win7_VICTIM"

# VM Options
VM_SNAPSHOT="init"
VM_USER=Administrator
VM_PASS=password
NORIBEN_PATH="C:\\Documents and Settings\\$VM_USER\\Desktop\\Noriben.py"
ZIP_PATH=C:\\gnuwin32\\bin\\zip.exe
LOG_PATH=C:\\Noriben_Logs


MALWAREFILE=$1
if [ ! -f $1 ]; then
    echo "Please provide executable filename as an argument."
    echo "For example:"
    echo "$0 ~/malware/ef8188aa1dfa2ab07af527bab6c8baf7"
    exit
fi


vmware_execute(){
	FILENAME=$(basename $MALWAREFILE)
	if [ ! -z $NORIBEN_DEBUG ]; then echo "$VMW_RUN" -T ws revertToSnapshot "$VMX" $VM_SNAPSHOT; fi
	"$VMW_RUN" -T ws revertToSnapshot "$VMX" $VM_SNAPSHOT

	if [ ! -z $NORIBEN_DEBUG ]; then echo "$VMW_RUN" -T ws start "$VMX"; fi
	"$VMW_RUN" -T ws start "$VMX"

	if [ ! -z $NORIBEN_DEBUG ]; then echo "$VMW_RUN" -gu $VM_USER  -gp $VM_PASS copyFileFromHostToGuest "$VMX" "$MALWAREFILE" C:\\Malware\\malware.exe; fi
	"$VMW_RUN" -gu $VM_USER  -gp $VM_PASS copyFileFromHostToGuest "$VMX" "$MALWAREFILE" C:\\Malware\\malware.exe

	if [ ! -z $NORIBEN_DEBUG ]; then echo "$VMW_RUN" -T ws -gu $VM_USER -gp $VM_PASS runProgramInGuest "$VMX" -activeWindow -interactive C:\\Python27\\Python.exe "$NORIBEN_PATH" -d -t $DELAY --cmd "C:\\Malware\\Malware.exe" --output "$LOG_PATH"; fi
	"$VMW_RUN" -T ws -gu $VM_USER -gp $VM_PASS runProgramInGuest "$VMX" -activeWindow -interactive C:\\Python27\\Python.exe "$NORIBEN_PATH" -d -t $DELAY --cmd "C:\\Malware\\Malware.exe" --output "$LOG_PATH"
	if [ $? -gt 0 ]; then
	    echo "[!] File did not execute in VM correctly."
	    exit
	fi

	if [ ! -z $NORIBEN_DEBUG ]; then "$VMW_RUN" -T ws -gu $VM_USER -gp $VM_PASS runProgramInGuest "$VMX" -activeWindow -interactive "$ZIP_PATH" -j C:\\NoribenReports.zip "$LOG_PATH\\*.*"; fi
	"$VMW_RUN" -T ws -gu $VM_USER -gp $VM_PASS runProgramInGuest "$VMX" -activeWindow -interactive "$ZIP_PATH" -j C:\\NoribenReports.zip "$LOG_PATH\\*.*"
	if [ $? -eq 12 ]; then
	    echo "[!] ERROR: No files found in Noriben output folder to ZIP."
	    exit
	fi
	"$VMW_RUN" -gu $VM_USER -gp $VM_PASS copyFileFromGuestToHost "$VMX" C:\\NoribenReports.zip $PWD/NoribenReports_$FILENAME.zip
}


vbox_shutdown(){
	if [ ! -z $NORIBEN_DEBUG ]; then echo "$VMW_RUN" controlvm "$VM_NAME" poweroff; fi
	"$VBX_RUN" controlvm "$VM_NAME" poweroff

	if [ ! -z $NORIBEN_DEBUG ]; then echo "$VMW_RUN" snapshot "$VM_NAME" restore "$VM_SNAPSHOT"; fi
	"$VBX_RUN" snapshot "$VM_NAME" restore "$VM_SNAPSHOT"
}

vbox_execute(){
	# Shutdown if VM running
	if [ ! -z $NORIBEN_DEBUG ]; then echo "$VMW_RUN" controlvm "$VM_NAME" poweroff; fi
	"$VBX_RUN" controlvm "$VM_NAME" poweroff

    # Restore Snapshot 
	if [ ! -z $NORIBEN_DEBUG ]; then echo "$VMW_RUN" snapshot "$VM_NAME" restore "$VM_SNAPSHOT"; fi
	"$VBX_RUN" snapshot "$VM_NAME" restore "$VM_SNAPSHOT"

	# Start VM
	if [ ! -z $NORIBEN_DEBUG ]; then echo "$VMW_RUN" startvm "$VM_NAME"; fi
	"$VBX_RUN" startvm "$VM_NAME"

	# Copy file to VM
	# To use copyto (at least on Linux) always use foward-slash
	if [ ! -z $NORIBEN_DEBUG ]; then echo "$VBX_RUN" guestcontrol "$VM_NAME" copyto "$MALWAREFILE" C:\\Malware\\malware.exe --username $VM_USER  --password $VM_PASS ; fi
	"$VBX_RUN" guestcontrol "$VM_NAME" copyto --target-directory "C:/vnsdf.exe" --username $VM_USER --password $VM_PASS "$MALWAREFILE" 
	if [ $? -gt 0 ]; then
	    echo "[!] File did not execute in VM correctly."
	    vbox_shutdown
	    exit
	fi

	#Untested below
	if [ ! -z $NORIBEN_DEBUG ]; then echo "$VBX_RUN" guestcontrol "$VM_NAME" run --exe "C:\\Python27\\Python.exe" --username $VM_USER --password $VM_PASS -- -l  "\"$NORIBEN_PATH\" -t $DELAY --cmd \"C:\\vnsdf.exe\" --output \"$LOG_PATH\""; fi
	"$VBX_RUN" guestcontrol "$VM_NAME" run --exe "C:\\Python27\\Python.exe" --username $VM_USER --password $VM_PASS -- -l  "\"$NORIBEN_PATH\" -t $DELAY --cmd \"C:\\vnsdf.exe\" --output \"$LOG_PATH\""
	
	if [ $? -gt 0 ]; then
	    echo "[!] File did not execute in VM correctly."
	    vbox_shutdown
	    exit
	fi

	if [ ! -z $NORIBEN_DEBUG ]; then "$VBX_RUN" guestcontrol "$VM_NAME" run --exe "$ZIP_PATH" --username $VM_USER --password $VM_PASS -- -l  " -j C:\\NoribenReports.zip \"$LOG_PATH\\*.*\""; fi
	"$VBX_RUN" guestcontrol "$VM_NAME" run --exe "$ZIP_PATH" --username $VM_USER --password $VM_PASS -- -l  " -j C:\\NoribenReports.zip \"$LOG_PATH\\*.*\""
	if [ $? -eq 12 ]; then #Need to check
	    echo "[!] ERROR: No files found in Noriben output folder to ZIP."
	    exit
	fi

	"$VBX_RUN" guestcontrol "$VM_NAME" copyfrom --target-directory "$PWD/NoribenReports_$FILENAME.zip" --username $VM_USER --password $VM_PASS "C:/NoribenReports.zip"

}

if [ ! -z $USEVBOX ]; 
then
	vbox_execute
else
	vmware_execute
fi
