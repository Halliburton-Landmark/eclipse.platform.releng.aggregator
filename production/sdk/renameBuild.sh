#!/usr/bin/env bash

# Important: it is assumed this script is ran from the directory
# that is the parent of the directory to rename

# CAUTION: this is hard coded for going from "I" build to "S" build. 
# Needs adjustment for "R" build.

# its assumed oldname is old name of directory and buildId, such as I20120503-1800
# newdirname is new name for directory, such as S-3.8M7-201205031800 and
# newlabel is the new "short name" of the deliverables, such as 3.8M7
oldname=$1
newdirname=$2
newlabel=$3

function renamefile ()
{
    # file name is input parameter
    if [[ $1 =~ (.*)($oldname)(.*) ]]
    then
        echo "changing $1 to ${BASH_REMATCH[1]}$newlabel${BASH_REMATCH[3]}"
        mv "$1" "${BASH_REMATCH[1]}$newlabel${BASH_REMATCH[3]}"

    fi

}

if [[ $# != 3 ]]
then
    # usage:
    scriptname=$(basename $0)
    printf "\n\t%s\n" "This script, $scriptname requires three arguments, in order: "
    printf "\t\t%s\t%s\n" "oldname" "(e.g. I20120503-1800) "
    printf "\t\t%s\t%s\n" "newdirname" "(e.g. S-3.8M7-201205031800) "
    printf "\t\t%s\t%s\n" "newlabel" "(e.g. 3.8M7 or 4.2M7 or KeplerM3) "
    printf "\t%s\n" "for example,"
    printf "\t%s\n\n" "./$scriptname I20120503-1800 S-3.8M7-201205031800 3.8M7"
    exit 1
fi
echo "Renaming build $oldname to $newdirname with $newlabel"

fromString=$oldname
toString=$newlabel
replaceCommand="s!${fromString}!${toString}!g"

# not all these file types may exist, we include all the commonly used ones, though,
# just in case future changes to site files started to have them. There is no harm, per se,
# if the perl command fails.
# TODO: could add some "smarts" here to see if all was as expected before making changes.
perl -w -pi -e ${replaceCommand} ${oldname}/*.php
perl -w -pi -e ${replaceCommand} ${oldname}/*.map
perl -w -pi -e ${replaceCommand} ${oldname}/*.html
perl -w -pi -e ${replaceCommand} ${oldname}/*.xml
perl -w -pi -e ${replaceCommand} ${oldname}/checksum/*

# TODO: need to make this part of case statement, to handle
# Integration --> Stable
# Integration --> Release Candidate
# Integration --> Release
# These are for cases where used in headers, titles, etc.
# TODO: final "fall through" case should be based on matching
# new label with digits only, such as "4.3" ... not sure 
# if this would work for Equinox "Kepler" or "Kepler Released Build"? 
oldString="Integration Build"

if [[ "${newlabel}" =~ .*RC.* ]]
then 
    newString="Release Candidate Build"
elif [[ "${newlabel}" =~ .*R.* ]]
then
    newString="Release Build"
elif [[ "${newlabel}" =~ .*S.* ]]
then
    newString="Stable Build"
else 
    newString="Release Build"
fi

replaceBuildNameCommand="s!${oldString}!${newString}!g"
# quotes are critical here, since strings contain spaces!
perl -w -pi -e "${replaceBuildNameCommand}" ${oldname}/*.php

# some special cases, for the buildproperties.php file
# Note, we do php only, since that's what we need, and if we did want 
# to rebuild, say using buildproperties.shsource, would be best to work 
# from original values. Less sure what to do with Ant properties, 
# buildproperties.properties ... but, we'll decide when needed.
# TODO: New label doesn't have "R" in it ... just, for example, "4.3". 
# for now, we'll "fall through" to "R",  if doesn't match anything else, 
# but this won't work well if/when we add others, such as X or T for test 
# builds. 
oldString="BUILD_TYPE = \"I\""
if [[ "${newlabel}" =~ .*RC.* ]]
then 
    newString="BUILD_TYPE = \"S\""
elif [[ "${newlabel}" =~ .*R.* ]]
then
    newString="BUILD_TYPE = \"R\""
elif [[ "${newlabel}" =~ .*S.* ]]
then
    newString="BUILD_TYPE = \"S\""
else 
    newString="BUILD_TYPE = \"R\""
fi

replaceBuildNameCommand="s!${oldString}!${newString}!g"
# quotes are critical here, since strings contain spaces!
perl -w -pi -e "${replaceBuildNameCommand}" ${oldname}/buildproperties.php

oldString="BUILD_TYPE_NAME = \"Integration\""
if [[ "${newlabel}" =~ .*RC.* ]]
then 
    newString="BUILD_TYPE_NAME = \"Release Candidate\""
elif [[ "${newlabel}" =~ .*R.* ]]
then
    newString="BUILD_TYPE_NAME = \"Release\""
elif [[ "${newlabel}" =~ .*S.* ]]
then
    newString="BUILD_TYPE_NAME = \"Stable\""
else 
    newString="BUILD_TYPE_NAME = \"Release\""
fi
replaceBuildNameCommand="s!${oldString}!${newString}!g"
# quotes are critical here, since strings might contain spaces!
perl -w -pi -e "${replaceBuildNameCommand}" ${oldname}/buildproperties.php

# One special case for promoted builds, is the "FAILED" icons are 
# changed to "OK", since all unit tests accounted for, if not fixed. 
oldString="FAIL.gif"
newString="OK.gif"
replaceBuildNameCommand="s!${oldString}!${newString}!g"
# quotes are critical here, since strings might contain spaces!
perl -w -pi -e "${replaceBuildNameCommand}" ${oldname}/index.php

# move directory before file renames, so it won't be in file path name twice
mv $oldname $newdirname

for file in `find ./${newdirname} -name "*${oldname}*" -print `
do
    renamefile $file
done
