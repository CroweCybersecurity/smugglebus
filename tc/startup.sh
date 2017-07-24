#!/bin/sh
echo "Running SmuggleBus"
sudo python /home/tc/hashgrab.py
echo "Done. Powering off"
sudo poweroff
