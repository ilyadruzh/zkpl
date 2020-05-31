#!/bin/bash

./compile-computehash-zok.sh
./compute-hash-witness.sh
./compile-checkhash-zok.sh
./trusted-setup.sh
./create-smart-contract.sh
./compute-new-witness.sh
./generate-proof.sh