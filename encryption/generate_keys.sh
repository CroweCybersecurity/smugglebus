#!/usr/bin/env bash

## Generate Private Key
openssl genpkey -algorithm RSA -out private_key.pem -pkeyopt rsa_keygen_bits:2048	

## Generate Public Key (from the private key)
openssl rsa -pubout -in private_key.pem -out public_key.pem
