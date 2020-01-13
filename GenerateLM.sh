#!/bin/bash

set -xe

all_train_csv="$(find ./datacorpus/extracted/data/ -type f -name '*train.csv' -printf '%p,' | sed -e 's/,$//g')"
all_dev_csv="$(find ./datacorpus/extracted/data/ -type f -name '*dev.csv' -printf '%p,' | sed -e 's/,$//g')"
all_test_csv="$(find ./datacorpus/extracted/data/ -type f -name '*test.csv' -printf '%p,' | sed -e 's/,$//g')"
EARLY_STOP_FLAG="1"
BATCH_SIZE="96"
N_HIDDEN="2048"
EPOCHS="100"
LEARNING_RATE="0.00001"
DROPOUT="0.15"
LM_ALPHA="0.65"
LM_BETA="1.45"
DS_SHA1="73278cf8d6214d67deab30684803f84354fba378"

ENGLISH_COMPATIBLE="0"



pushd ./datacorpus/extracted
	if [ "${ENGLISH_COMPATIBLE}" = "1" ]; then
		OLD_LANG=${LANG}
		export LANG=fr_FR.UTF-8
	fi;

	if [ ! -f "wiki_fr_lower.txt" ]; then
		curl -sSL https://github.com/Common-Voice/commonvoice-fr/releases/download/lm-0.1/wiki.txt.xz | pixz -d | tr '[:upper:]' '[:lower:]' > wiki_fr_lower.txt
	fi;

	if [ ! -f "debats-assemblee-nationale.txt" ]; then
		curl -sSL https://github.com/Common-Voice/commonvoice-fr/releases/download/lm-0.1/debats-assemblee-nationale.txt.xz | pixz -d | tr '[:upper:]' '[:lower:]' > debats-assemblee-nationale.txt
	fi;

	if [ "${ENGLISH_COMPATIBLE}" = "1" ]; then
		mv wiki_fr_lower.txt wiki_fr_lower_accents.txt
		# Locally force LANG= to make iconv happy and avoid errors like:
		# iconv: illegal input sequence at position 4468
		# Also required locales and locales-all to be installed
		head -n 5 wiki_fr_lower_accents.txt
		iconv -f UTF-8 -t ASCII//TRANSLIT//IGNORE < wiki_fr_lower_accents.txt > wiki_fr_lower.txt
		head -n 5 wiki_fr_lower.txt
		> wiki_fr_lower_accents.txt
	fi;

	cat wiki.txt wiki_fr_lower.txt debats-assemblee-nationale.txt > sources_lm.txt

	if [ ! -f "./datacorpus/lm/lm.binary" ]; then
		lmplz	--order 4 \
			--temp_prefix ./datacorpus/tmp/ \
			--memory 80% \
			--text sources_lm.txt \
			--arpa ./datacorpus/lm/lm.arpa \
			--skip_symbols \
			--prune 0 0 1

		build_binary -a 255 \
			-q 8 \
			trie \
			./datacorpus/lm/lm.arpa \
			./datacorpus/lm/lm.binary

		rm ./datacorpus/lm/lm.arpa
	fi;

	if [ ! -f "./datacorpus/lm/trie" ]; then
		echo "test"
		curl -sSL https://community-tc.services.mozilla.com/api/index/v1/task/project.deepspeech.deepspeech.native_client.master.${DS_SHA1}.cpu/artifacts/public/native_client.tar.xz | pixz -d | tar -xf -
		./generate_trie ./datacorpus/models/alphabet.txt ./datacorpus/lm/lm.binary ./datacorpus/lm/trie
	fi;

	if [ "${ENGLISH_COMPATIBLE}" = "1" ]; then
		export LANG=${OLD_LANG}
	fi;
popd

