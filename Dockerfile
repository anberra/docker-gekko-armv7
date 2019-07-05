FROM balenalib/armv7hf-debian-node:8

ENV HOST localhost
ENV PORT 3000

# cross-build to build arm containers on dockerhub
RUN [ "cross-build-start" ]

# Create app directory
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app


## install phyton
# remove several traces of debian python
RUN apt-get purge -y python.*

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

# key 63C7CC90: public key "Simon McVittie <smcv@pseudorandom.co.uk>" imported
# key 3372DCFA: public key "Donald Stufft (dstufft) <donald@stufft.io>" imported
RUN gpg --batch --keyserver keyring.debian.org --recv-keys 4DE8FF2A63C7CC90 \
	&& gpg --batch --keyserver keyserver.ubuntu.com --recv-key 6E3CBCE93372DCFA \
	&& gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 0x52a43a1e4b77b059

ENV PYTHON_VERSION 2.7.16

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 19.1

ENV SETUPTOOLS_VERSION 41.0.1

RUN set -x \
	&& curl -SLO "http://resin-packages.s3.amazonaws.com/python/v$PYTHON_VERSION/Python-$PYTHON_VERSION.linux-armv7hf-openssl1.1.tar.gz" \
	&& echo "ac7038b91e2f60e99949373f412bdbbf2628b2bb243ba21a97b98d8f2afcde67  Python-$PYTHON_VERSION.linux-armv7hf-openssl1.1.tar.gz" | sha256sum -c - \
	&& tar -xzf "Python-$PYTHON_VERSION.linux-armv7hf-openssl1.1.tar.gz" --strip-components=1 \
	&& rm -rf "Python-$PYTHON_VERSION.linux-armv7hf-openssl1.1.tar.gz" \
	&& ldconfig \
	&& if [ ! -e /usr/local/bin/pip ]; then : \
		&& curl -SLO "https://raw.githubusercontent.com/pypa/get-pip/430ba37776ae2ad89f794c7a43b90dc23bac334c/get-pip.py" \
		&& echo "19dae841a150c86e2a09d475b5eb0602861f2a5b7761ec268049a662dbd2bd0c  get-pip.py" | sha256sum -c - \
		&& python get-pip.py \
		&& rm get-pip.py \
	; fi \
	&& pip install --no-cache-dir --upgrade --force-reinstall pip=="$PYTHON_PIP_VERSION" setuptools=="$SETUPTOOLS_VERSION" \
	&& find /usr/local \
		\( -type d -a -name test -o -name tests \) \
		-o \( -type f -a -name '*.pyc' -o -name '*.pyo' \) \
		-exec rm -rf '{}' + \
	&& cd / \
	&& rm -rf /usr/src/python ~/.cache

# install "virtualenv", since the vast majority of users of this image will want it
RUN pip install --no-cache-dir virtualenv

ENV PYTHON_DBUS_VERSION 1.2.4

# install dbus-python dependencies 
RUN apt-get update && apt-get install -y --no-install-recommends \
		libdbus-1-dev \
		libdbus-glib-1-dev \
	&& rm -rf /var/lib/apt/lists/* \
	&& apt-get -y autoremove

# install dbus-python
RUN set -x \
	&& mkdir -p /usr/src/dbus-python \
	&& curl -SL "http://dbus.freedesktop.org/releases/dbus-python/dbus-python-$PYTHON_DBUS_VERSION.tar.gz" -o dbus-python.tar.gz \
	&& curl -SL "http://dbus.freedesktop.org/releases/dbus-python/dbus-python-$PYTHON_DBUS_VERSION.tar.gz.asc" -o dbus-python.tar.gz.asc \
	&& gpg --verify dbus-python.tar.gz.asc \
	&& tar -xzC /usr/src/dbus-python --strip-components=1 -f dbus-python.tar.gz \
	&& rm dbus-python.tar.gz* \
	&& cd /usr/src/dbus-python \
	&& PYTHON=python$(expr match "$PYTHON_VERSION" '\([0-9]*\.[0-9]*\)') ./configure \
	&& make -j$(nproc) \
	&& make install -j$(nproc) \
	&& cd / \
	&& rm -rf /usr/src/dbus-python

# https://github.com/docker-library/python/issues/147
ENV PYTHONIOENCODING UTF-8

# set PYTHONPATH to point to dist-packages
ENV PYTHONPATH /usr/lib/python2.7/dist-packages:/usr/lib/python2.7/site-packages:$PYTHONPATH


# Install GYP dependencies globally, will be used to code build other dependencies
RUN npm install -g --production node-gyp && \
    npm cache clean --force

# Install Gekko dependencies
COPY package.json .
RUN npm install --production && \
    npm install --production redis@0.10.0 talib@1.0.2 tulind@0.8.7 pg && \
    npm cache clean --force

# Install Gekko Broker dependencies
WORKDIR exchange
COPY exchange/package.json .
RUN npm install --production && \
    npm cache clean --force
WORKDIR ../

# Bundle app source
COPY . /usr/src/app

# timezone
RUN unlink /etc/localtime
RUN ln -s /usr/share/zoneinfo/Europe/Madrid /etc/localtime

EXPOSE 3000
RUN chmod +x /usr/src/app/docker-entrypoint.sh
ENTRYPOINT ["/usr/src/app/docker-entrypoint.sh"]

# cross-build to build arm containers on dockerhub
RUN [ "cross-build-end" ]

CMD ["--config", "config.js", "--ui"]
