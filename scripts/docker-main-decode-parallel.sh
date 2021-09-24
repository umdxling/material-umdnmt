export PYTHONIOENCODING=UTF-8

### Decoding only script
lang_src=$1
lang_tgt=$2
input_type=$3
nbest_word_list_size=$4
gpus=$5
proc_per_gpu=$6

input_dir=/app/input
output_dir=/app/output

## Software bits
moses_scripts_path=/mosesdecoder/scripts
bpe_scripts_path=/subword-nmt/subword_nmt
spm_scripts_path=/sentencepiece
fast_bpe_path=/fastBPE

date;

if [[ $lang_src == en ]]; then
	lang=$lang_tgt
else
	lang=$lang_src
fi;

if [[ $lang_tgt == en ]]; then
	system_list="models models-stem-en"
else
	system_list="models"
fi;

for system in $system_list; do
	if [[ $input_type == audio ]] && [[ $system == models ]] && [[ $lang_tgt == en ]]; then
		echo "-> Running system: models-asr"
		model_dir=/app/models-asr/$lang_src-$lang_tgt
	else
		echo "-> Running system: $system"
		model_dir=/app/$system/$lang_src-$lang_tgt
	fi;
	normalization_script=normalization

	rm -rf $output_dir/tmp*
	temp_dir=$(mktemp -d -p $output_dir)
	url_table=$temp_dir/url_table.json
	sid_file=$temp_dir/sid
	chmod -R 777 $output_dir

	# Concatenation
	echo " * Concatenating input files ..."
	ls $input_dir | while read input; do
		cat $input_dir/$input >> $temp_dir/input.pre
	done;

	# Sentence splitting
	cat $temp_dir/input.pre \
		| python3 /app/scripts/split-sentences.py $sid_file \
		> $temp_dir/input
	
	if [[ $lang == fa ]]; then
		decode_data_in=$temp_dir/input.tok.tc.spm.tag
      	decode_data_out=$temp_dir/output.tok.tc.spm
      	subword_model=$model_dir/data/spm_en$lang.model
      	if [ ! -f $subword_model ]; then
      		subword_model=$model_dir/data/spm_${lang}en.model
      	fi;
	else
		decode_data_in=$temp_dir/input.tok.tc.bpe.tag
        decode_data_out=$temp_dir/output.tok.tc.bpe
        subword_model=$model_dir/data/bpe.$lang_src-$lang_tgt
	fi;

	# Preprocessing
	echo " * Preprocessing $input ..."
	CHARS=$(echo -ne '\u200f')
	if [[ $lang == ka ]]; then
		cat $temp_dir/input \
        	| sed 's/['"$CHARS"']//g'  \
        	| python3 -c "import sys;[sys.stdout.write(line.strip()+'\n') for line in sys.stdin]" \
        	| python3 /app/scripts/replace-urls-in-text.py $url_table \
        	| python3 /app/scripts/$normalization_script.py $lang \
        	| $moses_scripts_path/tokenizer/normalize-punctuation.perl -l en \
        	| $moses_scripts_path/tokenizer/tokenizer.perl -l en -a -no-escape -q -threads 8 -lines 10000 \
        	| $moses_scripts_path/recaser/truecase.perl -model $model_dir/data/tc.$lang_src \
			> $decode_data_in.pre
        $fast_bpe_path/fast applybpe \
        		$decode_data_in.pre.bpe \
                $decode_data_in.pre \
                $subword_model
        cat $decode_data_in.pre.bpe \
        	| sed "s/^/<2$lang_tgt> /" | sed "s/^<2$lang_tgt> $//" \
        	> $decode_data_in
    elif [[ $lang == fa ]]; then
		cat $temp_dir/input \
        	| sed 's/['"$CHARS"']//g'  \
        	| python3 -c "import sys;[sys.stdout.write(line.strip()+'\n') for line in sys.stdin]" \
        	| python3 /app/scripts/replace-urls-in-text.py $url_table \
        	| python3 /app/scripts/$normalization_script.py $lang \
        	| $moses_scripts_path/tokenizer/normalize-punctuation.perl -l en \
        	| $moses_scripts_path/tokenizer/tokenizer.perl -l en -a -no-escape -q -threads 8 -lines 10000 \
        	| $moses_scripts_path/recaser/truecase.perl -model $model_dir/data/tc.$lang_src \
			> $decode_data_in.pre
        python3 /app/scripts/spm_segmenter.py \
                --in_file $decode_data_in.pre \
                --seg_model $subword_model \
                --transform enc \
        	| sed "s/^/<2$lang_tgt> /" | sed "s/^<2$lang_tgt> $//" \
        	> $decode_data_in
	else
        cat $temp_dir/input \
			| sed 's/['"$CHARS"']//g'  \
			| python3 -c "import sys;[sys.stdout.write(line.strip()+'\n') for line in sys.stdin]" \
			| python3 /app/scripts/replace-urls-in-text.py $url_table \
			| python3 /app/scripts/$normalization_script.py $lang \
			| $moses_scripts_path/tokenizer/normalize-punctuation.perl -l en \
			| $moses_scripts_path/tokenizer/tokenizer.perl -l en -a -no-escape -q -threads 8 -lines 10000 \
			| $moses_scripts_path/recaser/truecase.perl -model $model_dir/data/tc.$lang_src \
			| python3 $bpe_scripts_path/apply_bpe.py --codes $subword_model \
			| sed "s/^/<2$lang_tgt> /" | sed "s/^<2$lang_tgt> $//" \
			> $decode_data_in
	fi;

	# Building the model list
	model_list=""
	if [[ $lang == ka ]]; then
		for i in $(seq 1 4); do
			model_list="$model_list $model_dir/model-$i"
	    done;
	elif [[ $lang == ps ]]; then
		for i in $(seq 1 4); do
			model_list="$model_list $model_dir/model-$i"
		done;
	elif [[ $lang == bg ]] || [[ $lang == lt ]]; then
		if [[ $system == models ]] && [[ $input_type != audio ]]; then
			for i in $(seq 1 2); do
				model_list="$model_list $model_dir/model-$i"
		    done;
		else
	    	model_list="$model_list $model_dir/model-1"
	    fi;
	elif [[ $lang == kk ]]; then
		for i in $(seq 1 4); do
			model_list="$model_list $model_dir/model-$i"
	    done;
	else
	    for i in $(seq 1 4); do
		    model_list="$model_list $model_dir/model-$i"
	    done;
	fi;
	# Parallel decoding
	echo $model_list
    if [ ! -f $decode_data_out ]; then
		decode_data_in_tmp_dir=$decode_data_out.chunks.input
		decode_data_out_tmp_dir=$decode_data_out.chunks.output
		mkdir -p $decode_data_out_tmp_dir
		
		IFS=',' read -r -a gpu_array <<< "$gpus"
		gpu_n=${#gpu_array[@]}
		chunk_num=$((gpu_n*proc_per_gpu))
		if [ ! -d $decode_data_in_tmp_dir ]; then
			mkdir -p $decode_data_in_tmp_dir
			echo " * Splitting $decode_data_in into $chunk_num chunks ..."
			split -a 2 -dn l/$chunk_num $decode_data_in $decode_data_in_tmp_dir/input.
		fi;

		for i in ${!gpu_array[@]}; do
			gpu_i=${gpu_array[i]}
			for j in $(seq 0 $((proc_per_gpu-1))); do
				chunk_i=`printf "%02d" $((i*proc_per_gpu+j))`
				if [ ! -f $decode_data_out_tmp_dir/output.$chunk_i ]; then
					( echo " * Decoding chunk-$chunk_i on GPU-$gpu_i ..."
				  	python3 -m sockeye.translate \
						--input $decode_data_in_tmp_dir/input.$chunk_i   \
						--output $decode_data_out_tmp_dir/output.$chunk_i \
						--beam-size 5       \
						--batch-size 16      \
						--chunk-size 1024     \
						--models $model_list   \
						--ensemble-mode linear  \
						--disable-device-locking \
						--output-type nbest_words \
						--nbest-word-list-size $nbest_word_list_size \
						--device-ids $gpu_i ) &
				fi;
			done;
		done;
		wait

		echo " * Concatenating translations ..."
		for i in $(seq -f "%02g" 0 $((chunk_num-1))); do
			cat $decode_data_out_tmp_dir/output.$i >> $decode_data_out
		done;
		n_in=$(wc -l < $decode_data_in)
		n_out=$(wc -l < $decode_data_out)
		if [[ $n_in == $n_out ]]; then
			echo " * Decoding finished."
		else
			echo " * Decoding finished incorrectly."
			exit;
		fi;
	fi;

	# Post-processing
	echo " * Post-processing ..."
	if [[ $lang == fa ]]; then
		cat $decode_data_out \
        	| python3 /app/scripts/extract-translation-from-json.py \
        	> $temp_dir/output.pre
	    python3 /app/scripts/spm_segmenter.py \
	            --in_file $temp_dir/output.pre \
	            --seg_model $subword_model \
	            --transform dec \
	    	| $moses_scripts_path/recaser/detruecase.perl 2>/dev/null \
	    	| $moses_scripts_path/tokenizer/detokenizer.perl -q -l en 2>/dev/null \
	    	| python3 /app/scripts/merge-sentences.py $sid_file \
	    	> $temp_dir/output
    else
    	cat $decode_data_out \
			| python3 /app/scripts/extract-translation-from-json.py \
			| sed -r 's/(@@ )|(@@ ?$)//g' 2>/dev/null                \
			| $moses_scripts_path/recaser/detruecase.perl 2>/dev/null \
			| $moses_scripts_path/tokenizer/detokenizer.perl -q -l en 2>/dev/null \
			| python3 /app/scripts/recover-urls.py $url_table \
			| python3 /app/scripts/merge-sentences.py $sid_file \
			> $temp_dir/output
	fi;
	# Splitting
	echo " * Splitting into output files ..."
	if [[ $system == models-stem-en ]]; then
		output_suffix=.stem
	else
		output_suffix=""
	fi;
	cumulation=0
	ls $input_dir | while read input; do
		line_count=`wc -l $input_dir/$input | cut -d' ' -f1`
		cumulation_new=$((cumulation+line_count))
		head -n $cumulation_new $temp_dir/output | tail -n $line_count \
			> $output_dir/$input$output_suffix
		head -n $cumulation_new $decode_data_out | tail -n $line_count \
			> $output_dir/$input$output_suffix.nbest-words
		cumulation=$cumulation_new
	done;

	chmod -R 777 $output_dir
	rm -rf $output_dir/tmp*

	date;
done;
