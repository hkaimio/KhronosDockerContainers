# Copyright (c) 2019-2021, The Khronos Group Inc.
#
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This is a Docker container for OpenXR specification builds

FROM ruby:2.7-buster as builder
LABEL maintainer="Ryan Pavlik <ryan.pavlik@collabora.com>"

# Basic spec build and check packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y -qq \
    bison \
    build-essential \
    cmake \
    flex \
    fonts-lyx \
    ghostscript \
    git \
    imagemagick \
    libpango1.0-dev \
    libreadline-dev \
    pdftk \
    poppler-utils \
    python3 \
    python3-dev \
    python3-attr \
    python3-chardet \
    python3-lxml \
    python3-networkx \
    python3-pillow \
    python3-pip \
    python3-requests \
    python3-setuptools \
    python3-wheel \
    wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
# Basic gems
RUN gem install rake asciidoctor coderay json-schema asciidoctor-pdf rghost
RUN MATHEMATICAL_SKIP_STRDUP=1 gem install asciidoctor-mathematical

# Basic pip packages
RUN python3 -m pip install --no-cache-dir codespell pypdf2 pdoc3 reuse jinja2-cli
# pdf-diff pip package
RUN python3 -m pip install --no-cache-dir git+https://github.com/rpavlik/pdf-diff

# ImageMagick font config file - assuming the minimal install is why this didn't happen automatically
# RUN wget http://www.imagemagick.org/Usage/scripts/imagick_type_gen && \
#     mkdir -p ~/.magick && \
#     find /usr/share/fonts/ -name '*.ttf' | perl imagick_type_gen -f - > ~/.magick/type.xml
COPY imagick_type_gen /
RUN mkdir -p ~/.magick && \
    find /usr/share/fonts/ -name '*.ttf' | perl imagick_type_gen -f - > ~/.magick/type.xml


# For non-root execution https://github.com/tianon/gosu/releases
# ENV GOSU_VERSION 1.11
# RUN set -eux \
# dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
# 	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
# 	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
# 	\
# # verify the signature
# 	export GNUPGHOME="$(mktemp -d)"; \
# # for flaky keyservers, consider https://github.com/tianon/pgp-happy-eyeballs, ala https://github.com/docker-library/php/pull/666
# 	gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
# 	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
# 	command -v gpgconf && gpgconf --kill all || :; \
# 	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
# 	\
# 	chmod +x /usr/local/bin/gosu; \
# # verify that the binary works
# 	gosu --version; \
# 	gosu nobody true

# Second stage: start a simpler image that doesn't have the dev packages
FROM ruby:2.7-buster

# Copy the generated font list
COPY --from=builder /root/.magick/type.xml /root/.magick/type.xml
COPY --from=builder /root/.magick /etc/skel/.magick
# Copy locally-installed gems and python packages
COPY --from=builder /usr/local/ /usr/local/

# Runtime-required packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y -qq \
    fonts-lyx \
    ghostscript \
    git \
    gosu \
    imagemagick \
    jing \
    libpango1.0-0 \
    libreadline7 \
    libxml2-utils \
    pdftk \
    poppler-utils \
    python3 \
    python3-attr \
    python3-chardet \
    python3-lxml \
    python3-networkx \
    python3-pillow \
    python3-pytest \
    python3-requests \
    python3-utidylib \
    trang \
    wget \
    xmlstarlet && \
    apt-get clean

# Don't delete /var/lib/apt/lists/ before this command!
COPY release-codename.py /usr/bin/release-codename.py
RUN set -e && release-codename.py | tee /codename

# Install clang-format-6.0 - don't need a separate repo for that on Buster
# RUN echo "deb http://apt.llvm.org/$(cat /codename)/ llvm-toolchain-$(cat /codename)-6.0 main" >> /etc/apt/sources.list.d/llvm.list && \
#     cat /etc/apt/sources.list.d/llvm.list 1>&2
# RUN curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key | gpg --dearmor > /etc/apt/trusted.gpg.d/llvm-snapshot.gpg
RUN apt-get update -qq && apt-get install --no-install-recommends -y -qq clang-format-6.0 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

