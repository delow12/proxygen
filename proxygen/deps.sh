#!/bin/bash

## Run this script to build proxygen and run the tests. If you want to
## install proxygen to use in another C++ project on this machine, run
## the sibling file `reinstall.sh`.

set -e
start_dir=`pwd`
trap "cd $start_dir" EXIT

# Must execute from the directory containing this script
cd "$(dirname "$0")"

# Some extra dependencies for Ubuntu 13.10 and 14.04
sudo apt-get install \
    flex \
    bison \
    libkrb5-dev \
    libsasl2-dev \
    libnuma-dev \
    pkg-config \
    libssl-dev \
    libcap-dev \
    ruby \
    gperf \
    autoconf-archive \
    libevent-dev \
    wget

# Adding support for Ubuntu 12.04.x
# Needs glog, snappy, google-gflags and double-conversion
# deps.sh in fbthrift and folly builds anyways (no trap there)
sudo apt-get install libsnappy-dev

if ! sudo apt-get install libgoogle-glog-dev; 
then
	echo "fetching glog from svn (apt-get fails)"
	if [ ! -e google-glog ]; then
		svn checkout http://google-glog.googlecode.com/svn/trunk/ google-glog
		cd google-glog
		./configure
		make
		sudo make install
		cd ..
	fi
fi

if ! sudo apt-get install libgflags-dev; 
then
	if [ ! -e google-gflags ]; then
		echo "Fetching and building libgflags"
		wget https://github.com/schuhschuh/gflags/archive/v2.0.tar.gz
		mkdir google-gflags
		tar xf v2.0.tar.gz -C google-gflags
		cd google-gflags/gflags-2.0/
		./configure
		make
		sudo make install
		cd ../../
	fi
fi

if  ! sudo apt-get install libdouble-conversion-dev; 
then
	if [ ! -e double-conversion ]; then
		git clone https://code.google.com/p/double-conversion double-conversion
		cd double-conversion
		cmake . -DBUILD_SHARED_LIBS=ON
		sudo make install
		cd ..
	fi
fi


git clone https://github.com/facebook/fbthrift || true
cd fbthrift/thrift

# Rebase in case we've already downloaded thrift and folly
git fetch && git rebase origin/master
if [ -e folly/folly ]; then
    # We have folly already downloaded
    cd folly/folly
    git fetch && git rebase origin/master
    cd ../..
fi

# Build folly and fbthrift
if ! ./deps.sh; then
	echo "fatal: fbthrift+folly build failed"
	exit -1
fi

# Build proxygen
cd ../..
autoreconf -ivf
CPPFLAGS=" -I`pwd`/fbthrift/thrift/folly/ -I`pwd`/fbthrift/" \
    LDFLAGS="-L`pwd`/fbthrift/thrift/lib/cpp/.libs/ -L`pwd`/fbthrift/thrift/lib/cpp2/.libs/ -L`pwd`/fbthrift/thrift/folly/folly/.libs/" ./configure
make -j8

# Run tests
make check
