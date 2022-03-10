FROM ubuntu:20.04

ENV VERSION 2.18.1

RUN apt-get update -qq
RUN apt-get install -qqy --force-yes build-essential curl

WORKDIR /tmp
RUN curl -L# https://github.com/luvit/luvit/archive/$VERSION.tar.gz | tar xz
RUN cd luvit-$VERSION && make && make install
RUN rm -fr luvit-$VERSION.tar.gz

WORKDIR /
CMD ["luvit", "Main"]