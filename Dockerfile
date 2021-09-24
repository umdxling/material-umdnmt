# Use Nvidia image: 10.1-cudnn7-devel
FROM nvidia/cuda:10.1-cudnn7-devel

# Link to correct CUDA lib
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64
#ENV LD_LIBRARY_PATH=/usr/local/cuda-10.1/targets/x86_64-linux/lib 

# Install necessary tools.
WORKDIR /
RUN apt-get update && apt-get install --no-install-recommends -y \
    git python3-pip python3-dev python3 wget \
    && rm -rf /var/lib/apt/lists
RUN pip3 install asyncio websockets
RUN pip3 install --upgrade pip setuptools wheel

# Copy models to the image
WORKDIR /app
COPY ./umd-nmt-v8.2/models /app/models
COPY ./umd-nmt-v8.2/models-stem-en /app/models-stem-en
COPY ./umd-nmt-v8.2/models-asr /app/models-asr

# Copy scripts to the image
COPY ./scripts /app/scripts
COPY ./configs /app/configs
COPY ./requirements.txt /app/requirements.txt
COPY ./Makefile /app/Makefile

WORKDIR /app
RUN make python-requirements
RUN make tools

# Setup entrypoint
ENTRYPOINT ["bash","/app/scripts/entrypoint.sh"]
