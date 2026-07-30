#!/bin/bash

BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

cd "$BASEDIR/Utilities"

swift run main boilerplate-generator "$BASEDIR"
swift run main swift-package-generator "$BASEDIR"
