# This Makefile is used inside the Docker container to build MarianNMT,
# and other tools (e.g. moses, subword-nmt, sentencepiece, etc). It also
# includes steps to make it quicker to rerun the docker build and docker run
# commands themselves.

#expose environment variables for docker build and run in this Makefile
include configs/env_build.sh
export $(shell sed 's/=.*//' configs/env_build.sh)


all: python-requirements tools systems

# docker
docker-build:
	docker build -t umd-nmt:${DOCKER_VERSION} -f Dockerfile .

docker-save:
	docker save umd-nmt:$(DOCKER_VERSION) > umd-nmt:$(DOCKER_VERSION).tar

#other tools
tools: tools/moses-scripts tools/subword-nmt tools/fastBPE tools/sockeye

tools/moses-scripts:
	git clone $(MOSES_REPO_URL) -b $(MOSES_BRANCH_NAME) $@
tools/subword-nmt:
	git clone $(SUBWORDNMT_REPO_URL) -b $(SUBWORDNMT_BRANCH_NAME) $@ && cd $@ && git checkout $(SUBWORDNMT_COMMIT_ID)
tools/fastBPE:
	git clone $(FASTBPE_REPO_URL) -b $(FASTBPE_BRANCH_NAME) $@
	cd $@ && g++ -std=c++11 -pthread -O3 fastBPE/main.cc -IfastBPE -o fast
tools/sockeye:
	git clone $(SOCKEYE_REPO_URL) -b $(SOCKEYE_BRANCH_NAME) $@ && cd $@ && git checkout $(SOCKEYE_COMMIT_ID)
	cd $@ && pip3 install . --no-deps -r requirements/requirements.gpu-cu101.txt

python-requirements:
	pip install --upgrade pip
	pip install -r requirements.txt

.PHONY: all python-requirements systems.$(MODEL_VERSION) tools