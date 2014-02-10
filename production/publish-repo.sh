#!/usr/bin/env bash
#

if [ $# -ne 1 ]; then
    echo USAGE: $0 env_file
    exit 1
fi

if [ ! -r "$1" ]; then
    echo "$1" cannot be read
    echo USAGE: $0 env_file
    exit 1
fi

SCRIPT_PATH=${SCRIPT_PATH:-$(pwd)}

source $SCRIPT_PATH/build-functions.shsource

source "$1"

# derived values
gitCache=$( fn-git-cache "$BUILD_ROOT" "$BRANCH" )
aggDir=$( fn-git-dir "$gitCache" "$AGGREGATOR_REPO" )

if [ -z "$BUILD_ID" ]; then
    BUILD_ID=$(fn-build-id "$BUILD_TYPE" )
fi

buildDirectory=$( fn-build-dir "$BUILD_ROOT" "$BUILD_ID" "$STREAM" )
basebuilderDir=$( fn-basebuilder-dir "$BUILD_ROOT" "$BUILD_ID" "$STREAM" )

$SCRIPT_PATH/getEBuilderForDropDir.sh $buildDirectory $EBUILDER_HASH

fn-checkout-basebuilder "$basebuilderDir"

launcherJar=$( fn-basebuilder-launcher "$basebuilderDir" )

EBuilderDir="$buildDirectory"/eclipse.platform.releng.aggregator/eclipse.platform.releng.tychoeclipsebuilder

# compute update site on build server
function updateSiteOnBuildMachine()
{
    checkNArgs $# 3
    ROOT="$1"; shift
    BUILD_ID="$1"; shift
    STREAM="$1"; shift

    buildType=${BUILD_ID:0:1}


    # contrary to intuition (and previous behavior, bash 3.1) do NOT use quotes around right side of expression.
    if [[ "${STREAM}" =~ ^([[:digit:]]+)\.([[:digit:]]+)\.([[:digit:]]+)$ ]]
    then
        eclipseStreamMajor=${BASH_REMATCH[1]}
        eclipseStreamMinor=${BASH_REMATCH[2]}
        eclipseStreamService=${BASH_REMATCH[3]}
    else
        echo "STREAM, $STREAM, must contain major, minor, and service versions, such as 4.3.0" >${TRACE_OUTPUT}
        return 1
    fi

    siteDir=${ROOT}/siteDir
    updatesSuffix="builds"
    siteDirOnBuildMachine=$siteDir/updates/${eclipseStreamMajor}.${eclipseStreamMinor}-${buildType}-${updatesSuffix}/${BUILD_ID}
    mkdir -p ${siteDirOnBuildMachine}
    RC=$?
    if [[ $RC != 0 ]]
    then 
        echo "ERROR: could not create update site on build machine. RC: $RC" >${TRACE_OUTPUT}
        echo "       obtained error trying to create ${siteDirOnBuildMachine}" >${TRACE_OUTPUT}
        return 1
    fi

    echo $siteDirOnBuildMachine
}

siteDirOnBuildMachine=$( updateSiteOnBuildMachine "$BUILD_ROOT" "$BUILD_ID" "$STREAM" )
echo "siteDirOnBuildMachine: ${siteDirOnBuildMachine}"
repositoryDir=${buildDirectory}/repository
echo "repositoryDir: ${repositoryDir}"

# leave both old and new methods for now, so true (1) ==> old straight copy. 
# change to false (0) to test new method.
if (( 1 )) 
then
    DO_NOT_MIRROR_IN_ASSEMBLY="-DdoNotMirror=true"
    # for now, straight copy from what was produced to local build machine directory. 
    # This is partially done so that 
    #   rest of scripts stay common
    #   but eventually, we might put in some mirror/comparator/remove tasks here.

    # NOTE: we are using the "safe copy" we put in drop directory on build machine.

    # make posiitive ${repositoryDir} is not empty, or we are basically copying
    # all of root! (and, if repositoryDir is empty if we had a failed build! 
    # and should not be calling this method, anyway.)
    if [[ -n "${repositoryDir}" && -d "${repositoryDir}" && -n "${siteDirOnBuildMachine}" && -d "${siteDirOnBuildMachine}" ]]
    then
        rsync --times --omit-dir-times --recursive "${repositoryDir}/" "${siteDirOnBuildMachine}/"
        RC=$? 
        if [[ $RC != 0 ]]
        then 
            echo "ERROR: rsync of repo returned error. RC: $RC"
            echo "       obtained while copying"
            echo "       from ${repositoryDir}"
            echo "       to ${siteDirOnBuildMachine}"
           #exit $RC
        fi

    else
        echo "ERROR: Some directory didn't exist for update site copy."
        echo "  repositoryDir: ${repositoryDir}"
        echo "  siteDirOnBuildMachine: ${siteDirOnBuildMachine}"
        #exit $RC
    fi 

fi

java -Djava.io.tmpdir=$TMP_DIR -jar "$launcherJar" \
    -data ${buildDirectory}/workspace-mirrorRepo \
    -application org.eclipse.ant.core.antRunner \
    -v \
    -buildfile "$EBuilderDir"/eclipse/buildScripts/process-artifacts.xml \
    -DrepositoryDir=${repositoryDir} \
    -Dbuildlogs=$logsDirectory/comparatorlogs \
    -DsiteDirOnBuildMachine=$siteDirOnBuildMachine \
    -DcomparatorRepository=$comparatorRepository \
    -Djava.io.tmpdir=$TMP_DIR ${DO_NOT_MIRROR_IN_ASSEMBLY}

RC=$? 
if [[ $RC != 0 ]]
then 
    echo "ERROR: java invocation to process-artifacts did not return normally: $RC"
    #exit $RC
fi


# copy "human readable" (user friendly) HTML file
buildType=${BUILD_ID:0:1}
rsync --times --omit-dir-times --recursive "${EBuilderDir}/eclipse/publishingFiles/staticRepoSiteFiles/${buildType}builds/simple/" "${siteDirOnBuildMachine}/"
RC=$? 
if [[ $RC != 0 ]]
then 
    echo "ERROR: rsync of repo returned error. RC: $RC"
    echo "       obtained while copying"
    echo "       from ${EBuilderDir}/eclipse/publishingFiles/staticRepoSiteFiles/${buildType}builds/simple/"
    echo "       to ${siteDirOnBuildMachine}"
    #exit $RC
fi

exit 0

