#! /bin/bash

# Run like this:
#  git clean -fdx && bash RUNME.sh
# OR:
#  git clean -fdx && RUN_YARN=1 USE_PURE=1 bash RUNME.sh

# Adding "RUN_YARN=1" makes it run a "yarn install" after doing the
# yalc setup. Adding USE_PURE=1 or USE_LINK=1 or USE_ADDLINK=1 makes
# yalc use "add --pure", "link", or "add --link" respectively.

# If you have "tree" installed it'll use that for prettier output

############ NOTES:
# no args: works OK
# USE_ADDLINK=1: works OK
# USE_LINK=1: works OK
# USE_PURE=1: fails, because --pure makes yalc do nothing

# RUN_YARN=1: works OK
# RUN_YARN=1 USE_ADDLINK=1: works OK
# RUN_YARN=1 USE_LINK=1: fails because prod node_modules is empty
# RUN_YARN=1 USE_PURE=1: fails because prod node_modules doesn't exist

# "add --pure" and "link" don't change package.json, the others do.
# Only the ones that change package.json work.


set -e
set -x
command -v yalc || echo "Need yalc installed to run this test"

TREE=$(command -v xtree >/dev/null 2>&1 && echo "tree -a" || echo "ls -R -A")

# Clean before starting:
yalc installations clean @garyo-test/common
git restore app/package.json # remove anything yalc added

# Publish common module
cd common
yarn build                      # does a "yalc publish"

# Update in app
cd -
cd app
# This copies @garyo-test/common into .yalc and symlinks that into node_modules/@garyo-test
# Only need to do this once
if [ -n "$USE_LINK" ]; then
    yalc link @garyo-test/common
elif [ -n "$USE_PURE" ]; then
    yalc add --pure @garyo-test/common
elif [ -n "$USE_ADDLINK" ]; then
    # Also adds a link: dependency to .yalc/@garyo-test/common
    yalc add --link @garyo-test/common #
else
    yalc add @garyo-test/common
fi
git diff package.json
$TREE . || /bin/true

# If "yalc link" was used above, this creates top-level
# node_modules/@garyo-test/common symlink and _removes_
# @garyo-test/common from app/node_modules!
if [ -n "$RUN_YARN" ]; then
    cd ..
    yarn
    $TREE . -I .git
    cd -
fi

yarn build
ts-node index.ts
cd -

# Simulate production build by copying "app" dir to /tmp and building
# without the rest of the monorepo:

PROD="/tmp/PROD-app-$$"
cp -R app "$PROD"
cd "$PROD"
$TREE .
yarn build
node dist/index.js

# clean up
rm -rf "$PROD"
