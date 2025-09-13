FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git
RUN  apt-get install -y \
    curl

RUN curl https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh

RUN echo 'eval "$(mise activate bash)"' >> /etc/bash.bashrc