#!/bin/bash

bundle install
export EDITOR="/usr/bin/vim"
export PATH=$PATH:$GEM_HOME/bin
rake spec
