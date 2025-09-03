#!/bin/bash

# Set Java environment
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
export PATH=$JAVA_HOME/bin:$PATH

# check names in the db
java -jar snpEff/snpEff.jar dump BDGP6.28.99 | head -20