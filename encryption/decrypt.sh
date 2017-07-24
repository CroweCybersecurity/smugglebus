#!/usr/bin/env bash

OUTPUT_LOCATION=''
PRIVATE_KEY=''
ENCRYPTED_KEY='key.enc'
FILE_DIRECTORY=''
SAM_FILE='SAM.enc'
SYSTEM_FILE='SYSTEM.enc'
SECURITY_FILE='SECURITY.enc'
RUN_SECRETSDUMP=false
SECRETSDUMP='secretsdump.py'

function print_usage () {
    printf "%s\n" "Usage:"
    printf "\t%s\n" "$(basename $0) [arguments]"
    
    printf "%s\n" "Required arguments:"
    printf "\t%-15s %-54s\n" "-i DIRECTORY" "Directory with SAM/SYSTEM/SECURITY & key.enc files"
    printf "\t%-15s %-54s\n" "-o DIRECTORY" "Output location"
    printf "\t%-15s %-54s\n" "-p FILE" "Private key location"

    printf "%s\n" "Optional arguments:"
    printf "\t%-15s %-54s\n" "-x" "Run secretsdump.py when done (Default: False)"
}

while getopts ":o:p:i:xh" OPT; do
  case $OPT in
    o)
        OUTPUT_LOCATION=$OPTARG
        ;;
    p)
        PRIVATE_KEY=$OPTARG
        ;;
    i)
        FILE_DIRECTORY=$OPTARG
        ;;
    x)
        RUN_SECRETSDUMP=true
        ;;
    h)
        print_usage
        exit
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        print_usage
        exit 1
        ;;
    :)
        echo "-$OPTARG requires an argument."
        print_usage
        exit 1
        ;;
  esac
done


# Check for required args
if [ -z "$OUTPUT_LOCATION" ] || [ -z "$PRIVATE_KEY" ] || [ -z "$FILE_DIRECTORY" ]; then
    echo "Error: -i, -o and -p are required"
    print_usage
    exit 1
fi

# Look for the SAM/SYSTEM/SECURITY files
if [ ! -e $FILE_DIRECTORY/$SAM_FILE ] || [ ! -e $FILE_DIRECTORY/$SYSTEM_FILE ] || [ ! -e $FILE_DIRECTORY/$SECURITY_FILE ]; then
    echo "SAM/SYSTEM/SECURITY files not found"
    exit 1
fi

# Look for the key.enc file
if [ ! -e $FILE_DIRECTORY/$ENCRYPTED_KEY ]; then
    echo "key.enc file not found"
    exit 1
fi

# Look for the key.enc file
if [ ! -e $PRIVATE_KEY ]; then
    echo "Private key not found"
    exit 1
fi

# Use the input folder name as the output folder name
OUTPUT_LOCATION=$OUTPUT_LOCATION"$(basename $FILE_DIRECTORY)"
mkdir -p $OUTPUT_LOCATION

# Decrypt SAM SYSTEM SECURITY
KEY=$(openssl rsautl -decrypt -inkey $PRIVATE_KEY -in $FILE_DIRECTORY/$ENCRYPTED_KEY)
openssl enc -d -aes-256-cbc -md sha256 -in $FILE_DIRECTORY/$SAM_FILE -out $OUTPUT_LOCATION/SAM -k $KEY
openssl enc -d -aes-256-cbc -md sha256 -in $FILE_DIRECTORY/$SYSTEM_FILE -out $OUTPUT_LOCATION/SYSTEM -k $KEY
openssl enc -d -aes-256-cbc -md sha256 -in $FILE_DIRECTORY/$SECURITY_FILE -out $OUTPUT_LOCATION/SECURITY -k $KEY
KEY=''

# Run secretsdump.py
if $RUN_SECRETSDUMP ; then
    $SECRETSDUMP -sam $OUTPUT_LOCATION/SAM -system $OUTPUT_LOCATION/SYSTEM -security $OUTPUT_LOCATION/SECURITY -outputfile $OUTPUT_LOCATION/secretsdump LOCAL
fi