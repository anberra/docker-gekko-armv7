FROM balenalib/armv7hf-debian-node:10

ENV HOST localhost
ENV PORT 3000

# cross-build to build arm containers on dockerhub
RUN [ "cross-build-start" ]

# Create app directory
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

# install dbus-python dependencies 
#RUN apt-get update && apt-get install -y \
#		linux-headers make python \
#	&& rm -rf /var/lib/apt/lists/* 
RUN ln -s "$(which nodejs)" /usr/bin/node
  
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
