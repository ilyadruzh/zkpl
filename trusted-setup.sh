#!/bin/bash

# STEP 4
./toolbox/ZoKrates/target/release/zokrates setup -i examples/zokrates/checkhash/build/checkhash 

mv verification.key examples/zokrates/checkhash/build/setup/checkhash
mv proving.key examples/zokrates/checkhash/build/setup/checkhash
