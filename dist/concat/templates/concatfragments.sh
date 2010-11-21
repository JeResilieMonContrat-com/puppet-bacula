#!/bin/bash

# Script to concat files to a config file.
#
# Given a directory like this:
# /path/to/conf.d
# |-- fragments
# |   |-- 00_named.conf
# |   |-- 10_domain.net
# |   `-- zz_footer
#
# The script supports a test option that will build the concat file to a temp location and 
# use /usr/bin/cmp to verify if it should be run or not.  This would result in the concat happening
# twice on each run but gives you the option to have an unless option in your execs to inhibit rebuilds.
# 
# Without the test option and the unless combo your services that depend on the final file would end up 
# restarting on each run, or in other manifest models some changes might get missed.
#
# OPTIONS:
#  -o	The file to create from the sources
#  -d	The directory where the fragments are kept
#  -t	Test to find out if a build is needed, basically concats the files to a temp
#       location and compare with what's in the final location, return codes are designed
#       for use with unless on an exec resource
#  -n	Sort the output numerically rather than the default alpha sort
#
# the command: 
#
#   concatfragments.sh -o /path/to/conffile.cfg -d /path/to/conf.d
#
# creates /path/to/conf.d/fragments.concat and copies the resulting 
# file to /path/to/conffile.cfg.  The files will be sorted alphabetically
# pass the -n switch to sort numerically.
# 
# The script does error checking on the various dirs and files to make
# sure things don't fail.

OUTFILE=""
WORKDIR=""
TEST=""
SORTARG="-z"

while getopts "o:d:tn" options; do
	case $options in
		o ) OUTFILE=$OPTARG;;
		d ) WORKDIR=$OPTARG;;
		n ) SORTARG="-zn";;
		t ) TEST="true";;
		* ) echo "Specify output file with -o and fragments directory with -d"
		    exit 1;;
	esac
done

# do we have -o?
if [ x${OUTFILE} = "x" ]; then
	echo "Please specify an output file with -o"
	exit 1
fi

# do we have -d?
if [ x${WORKDIR} = "x" ]; then
	echo "Please fragments directory with -d"
	exit 1
fi

# can we write to -o?
if [ -a ${OUTFILE} ]; then
	if [ ! -w ${OUTFILE} ]; then
		echo "Cannot write to ${OUTFILE}"
		exit 1
	fi
else
	if [ ! -w `dirname ${OUTFILE}` ]; then
		echo "Cannot write to `dirname ${OUTFILE}` to create ${OUTFILE}"
		exit 1
	fi
fi

# do we have a fragments subdir inside the work dir?
if [ ! -d "${WORKDIR}/fragments" ]  && [ ! -x "${WORKDIR}/fragments" ]; then
	echo "Cannot access the fragments directory"
	exit 1
fi

# are there actually any fragments?
if [ ! "$(ls -A ${WORKDIR}/fragments)" ]; then
	echo "The fragments directory is empty, cowardly refusing to make empty config files"
	exit 1
fi

cd ${WORKDIR}

# find all the files in the fragments directory, sort them numerically and concat to fragments.concat in the working dir
/usr/bin/find fragments/ -type f -print0 |<%= sortpath %> ${SORTARG}|/usr/bin/xargs -0 /bin/cat >|"fragments.concat"

if [ x${TEST} = "x" ]; then
	# This is a real run, copy the file to outfile
	/bin/cp fragments.concat ${OUTFILE}
	RETVAL=$?
else
	# Just compare the result to outfile to help the exec decide
	/usr/bin/cmp ${OUTFILE} fragments.concat
	RETVAL=$?
fi

exit $RETVAL
