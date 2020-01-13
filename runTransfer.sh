#!/bin/bash

set -xe

all_train_csv="$(find ./datacorpus/extracted/data/cv-fr/ -type f -name '*train.csv' -printf '%p,' | sed -e 's/,$//g')"
all_dev_csv="$(find ./datacorpus/extracted/data/cv-fr/ -type f -name '*dev.csv' -printf '%p,' | sed -e 's/,$//g')"
all_test_csv="$(find ./datacorpus/extracted/data/cv-fr/ -type f -name '*test.csv' -printf '%p,' | sed -e 's/,$//g')"
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



mkdir -p ./datacorpus/sources/feature_cache || true


if [ ! -f "./datacorpus/models/output_graph.pb" ]; then
	EARLY_STOP_FLAG="--early_stop"
	if [ "${EARLY_STOP}" = "0" ]; then
		EARLY_STOP_FLAG="--noearly_stop"
	fi;

	python3 -u DeepSpeech.py \
		--show_progressbar True \
		--fine_tune True \
		--use_cudnn_rnn True \
		--load 'transfer' --drop_source_layers 1 \
		--automatic_mixed_precision True \
		--alphabet_config_path ./datacorpus/models/alphabet.txt \
		--lm_binary_path ./datacorpus/lm/lm.binary \
		--lm_trie_path ./datacorpus/lm/trie \
		--feature_cache ./datacorpus/sources/feature_cache \
		--train_files ${all_train_csv} \
		--dev_files ${all_dev_csv} \
		--test_files ${all_test_csv} \
		--train_batch_size ${BATCH_SIZE} \
		--dev_batch_size ${BATCH_SIZE} \
		--test_batch_size ${BATCH_SIZE} \
		--n_hidden ${N_HIDDEN} \
		--epochs ${EPOCHS} \
		--learning_rate ${LEARNING_RATE} \
		--dropout_rate ${DROPOUT} \
		--lm_alpha ${LM_ALPHA} \
		--lm_beta ${LM_BETA} \
		${EARLY_STOP_FLAG} \
		--checkpoint_dir ./datacorpus/checkpoints/ \
		--source_model_checkpoint_dir ./datacorpus/sourcecheckpoints/ \
		--export_dir ./datacorpus/models/ \
		--export_language "fra"
fi;


if [ ! -f "./datacorpus/models/output_graph.pbmm" ]; then
	./convert_graphdef_memmapped_format --in_graph=./datacorpus/models/output_graph.pb --out_graph=./datacorpus/models/output_graph.pbmm
fi;


	if [ -z "${LM_EVALUATE_RANGE}" ]; then
		echo "No language model evaluation range, skipping"
		exit 0
	fi;

	for lm_range in ${LM_EVALUATE_RANGE}; do
		LM_ALPHA="$(echo ${lm_range} |cut -d',' -f1)"
		LM_BETA="$(echo ${lm_range} |cut -d',' -f2)"
		
		python -u evaluate.py \
			--show_progressbar True \
			--use_cudnn_rnn True \
			--alphabet_config_path ./datacorpus/models/alphabet.txt \
			--lm_binary_path ./datacorpus/lm/lm.binary \
			--lm_trie_path ./datacorpus/lm/trie \
			--feature_cache ./datacorpus/sources/feature_cache \
			--test_files ${all_test_csv} \
			--test_batch_size ${BATCH_SIZE} \
			--n_hidden ${N_HIDDEN} \
			--lm_alpha ${LM_ALPHA} \
			--lm_beta ${LM_BETA} \
			--checkpoint_dir ./datacorpus/checkpoints/
	done;
















