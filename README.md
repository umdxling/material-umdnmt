# material-umdnmt

## Introduction

This is a pipeline for building and releasing neural machine translation systems. It can be used to translate a directory of small documents.

The system runs in one [Docker](https://www.docker.com/) container using the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html#docker) to expose GPUs.


## Supported language directions and features

Supported language directions include English to/from Swahili (sw), Tagalog (tl), Somali (so), Pashto (ps), Lithuanian (lt), Bulgarian (bg), Farsi (fa), Kazakh (kk), and Georgian (ka). Not all language directions support all features. The following table lists the features supported for each language direction (as of models v7.2).

- Text is normal text translation.
- Stem are models that translate from non-English into lemmatized English sentences.
- Audio are models that were trained with ASR outputs in mind.

|       |text |stem   |audio  |
|-------|-----|-------|-------|
|en<>sw |ok   |sw->en |sw->en |
|en<>tl |ok   |tl->en |tl->en |
|en<>so |ok   |so->en |so->en |
|en<>ps |ok   |ps->en |ps->en |
|en<>lt |ok   |lt->en |lt->en |
|en<>bg |ok   |bg->en |bg->en |
|en<>fa |ok   |fa->en |fa->en |
|en<>kk |ok   |kk->en |kk->en |
|en<>ka |ok   |ka->en |ka->en |


## Requirements

- [Docker](https://www.docker.com/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html#docker) (to use GPUs)


## Run the Docker translator to translate a single folder

The Docker image comes with a translation function that translates input folders on the command line (note that the directories need to be located where docker has read/write permissions). For this, you need to mount volumes in the docker container as shown in the examples below:

```
docker run --gpus all --rm \
   -v <input_dir>:/mt/input_dir \
   -v <output_dir>:/mt/output_dir \
   --name umdnmt \
   umd-nmt:v8.2 \
   translate <src_lang> <tgt_lang> <input-type> \
   <nbest-size> <gpu-ids> <jobs-per-gpu>
```

### Input/Output Format

The input to the command is a directory (possibly with subdirectories) containing all files to be translated. The output is a new directory with the same subdirectories and the same file names, but containing standard/stemmed translations and nbest-words in JSON format for each input file. Given an input file `file.txt`, it produces:

- `file.txt`: plain translation file aligned with the input.
- `file.txt.nbest-words`: nbest-words lists for each line/translation. They are structured in json-lines format that looks like this:
```
{
  "id": 4,
  "nbest_words": [
    {"w11": score11, "w12": score12, ..., "w1N": score1N},
    {"w21": score21, "w22": score22, ..., "w2N": score2N},
                ...
    {"wT1": scoreT1, "wT2": scoreT2, ..., "wTN": scoreTN}
  ],
  "translation": "The sentence translation."
}
```
- `file.txt.stem`: plain stemmed translation file aligned with the input. (only if tgt_lang=en)
- `file.txt.stem.nbest-words`: nbest-words lists for each stemmed translation. (only if tgt_lang=en)


## Building the Docker image

The Makefile includes commands for `docker-build` for convenience. You can always invoke `docker build` manually with your own settings instead. 

To build, you will need the model directories for text, stem, and audia, each of which contains subdirectories for each of the translation directions. The subdirectory should contain all of the necessary bpe model, truecase model, the MT models themselves, etc., for example:

```
models
├── ka-en
│   ├── data
│   │    ├── bpe.ka-en
│   │    ├── tc.ka
│   ├── model-1
│   │    ├── args.yaml
│   │    ├── config
│   │    ├── data.info
│   │    ├── params.best
│   │    ├── symbol.json
│   │    ├── version
│   │    ├── vocab.src.0.json
│   │    ├── vocab.trg.0.json
│   ├── model-2
│   │    ├── args.yaml
│   │    ├── config
│   │    ├── data.info
│   │    ├── params.best
│   │    ├── symbol.json
│   │    ├── version
│   │    ├── vocab.src.0.json
│   │    ├── vocab.trg.0.json
│   ├── model-3
│   │    ├── args.yaml
│   │    ├── config
│   │    ├── data.info
│   │    ├── params.best
│   │    ├── symbol.json
│   │    ├── version
│   │    ├── vocab.src.0.json
│   │    ├── vocab.trg.0.json
│   ├── model-4
│   │    ├── args.yaml
│   │    ├── config
│   │    ├── data.info
│   │    ├── params.best
│   │    ├── symbol.json
│   │    ├── version
│   │    ├── vocab.src.0.json
│   │    ├── vocab.trg.0.json
models-stem-en
├── ka-en
│   ├── data
│   │    ├── bpe.ka-en
│   │    ├── tc.ka
│   ├── model-1
│   │    ├── args.yaml
│   │    ├── config
│   │    ├── data.info
│   │    ├── params.best
│   │    ├── symbol.json
│   │    ├── version
│   │    ├── vocab.src.0.json
│   │    ├── vocab.trg.0.json
│   ├── ...
models-asr
├── ka-en
│   ├── data
│   │    ├── bpe.ka-en
│   │    ├── tc.ka
│   ├── model-1
│   │    ├── args.yaml
│   │    ├── config
│   │    ├── data.info
│   │    ├── params.best
│   │    ├── symbol.json
│   │    ├── version
│   │    ├── vocab.src.0.json
│   │    ├── vocab.trg.0.json
│   ├── ...
...
``` 

To build, run:

```
make docker-build
```

This is equivalent to:

```
docker build ​​-t umd-nmt:${DOCKER_VERSION} -f Dockerfile .
```

where `${DOCKER_VERSION}` is found in `configs/env_build.sh` by the `Makefile`.


## For Developers

### Creating a new release

#### Adding text pre-/post-processing plugins

If your model uses a new data pre-/post-processing pipeline, you will need to add it to the preprocessing pipeline in `scripts/docker-main-decode-parallel.sh` (line 75-122).

#### Release

Next, follow these steps to create a new docker image and publish a new version of this repo:

1. Update `configs/env_build.sh` with a new model version and other docker build settings.
2. Build the docker:
```
make docker-build
```
3. Save the docker into a tar file:
```
make docker-save
```

### Code walkthrough

The following is a brief walkthrough of some of the included files, to aid in development and debugging:

- *Dockerfile*: creates the docker image

- *entrypoint.sh*: the Docker entrypoint with `translate` directive

- *Makefile*: used for building both the docker, and the internal systems
   - Includes `docker-build` command, which read from configs so developer-users only need to make small changes to rebuild with new settings.
   - Contains commands to build tools and systems, which can be used by developer-users to build everything locally (outside of Docker) and which are also used by the Dockerfile to build tools and systems.

- *configs/*: central location for any type of configuration files

- *configs/env_build.sh*: config for `docker build`, including URLs of where to download systems and tools, the MODEL_VERSION, and other docker build settings

- *scripts/*: central location for any scripts having to do with `translate`