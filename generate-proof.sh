#!/bin/bash

# STEP 7
./compile-checkhash-zok.sh 
./compute-new-witness.sh 

cp examples/zokrates/checkhash/build/checkhash out
cp examples/zokrates/checkhash/build/witness witness
cp examples/zokrates/checkhash/build/setup/checkhash/proving.key proving.key
./toolbox/ZoKrates/target/release/zokrates generate-proof

mv proof.json examples/zokrates/checkhash/build/proof/
rm out witness proving.key