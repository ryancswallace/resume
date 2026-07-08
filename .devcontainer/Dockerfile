# syntax=docker/dockerfile:1

FROM mcr.microsoft.com/devcontainers/javascript-node:1-24-bookworm

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash-completion \
        biber \
        build-essential \
        ca-certificates \
        chktex \
        curl \
        ghostscript \
        gh \
        git \
        git-lfs \
        gnupg \
        graphviz \
        imagemagick \
        jq \
        latexmk \
        less \
        libfontconfig1 \
        make \
        pandoc \
        poppler-utils \
        python3 \
        python3-pip \
        python3-venv \
        ripgrep \
        shellcheck \
        texlive-base \
        texlive-bibtex-extra \
        texlive-extra-utils \
        texlive-fonts-recommended \
        texlive-lang-english \
        texlive-latex-base \
        texlive-latex-extra \
        texlive-latex-recommended \
        texlive-luatex \
        texlive-pictures \
        texlive-plain-generic \
        texlive-science \
        texlive-xetex \
        unzip \
        vim \
        wget \
        xz-utils \
        zip \
        zsh \
    && git lfs install --system \
    && npm install --global \
        cspell \
        markdownlint-cli2 \
        prettier \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir -p /workspaces/.cache/latexmk \
    && chown -R node:node /workspaces/.cache
