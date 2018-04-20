#!/bin/bash

# e - exit immediately when a command fails.
# u - treat unset variables as an error and exit immediately
# o pipefile - sets the exit code of a pipeline to that of the rightmost
#   command to exit with a non-zero status, or zero if all commands of the
#   pipeline exit successfully.
# set -euo pipefail

basedir="$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd)"

# container="/cm/shared/singularity/tensorflow_tensorflow_1.2.1-devel-gpu-2017-06-29-082f52c0fafd.img"
container="/cm/shared/singularity/nvcr.io_nvidia_tensorflow_17.09-2017-09-05-9daee5ebe54d.img"
_defvenvpy=pyenvs/py-keras-gen
venvpy=${HOME}/${_defvenvpy}
scripts=''

datamnts=''

usage() {
cat <<EOF
Usage: $0 [-h|--help]
    [--container=singularity-container] [--datamnts=dir1,dir2,...]
    [--venvpy=<path>] [--scripts=script1,script2] [--<remain_args>]

    Sets up a singularity container environment with a python virtualenv.
    Specify --scripts option to run python scripts. Otherwise run in
    interactive session. Use equal sign "=" for argruments, do not separate
    by space.

    --container - Path to the singularity container.
        Default: ${container}

    --datamnts - Data directory(s) to mount into the container. Comma separated.

    --venvpy - Specify the path for the virtualenv. If the path is invalid will
        print an error and attempt to use container's internal python. If it's
        the default path and venv doesn't exist, will create a default venv
        with keras.
        Default path: ~/${_defvenvpy}

    --scripts - Specify a python script or a comma separated list of multiple
        python scripts to run. If scripts are not specified then an interactive
        session is started in venvpy environment. Specify scripts with full
        or relative paths (relative to current working directory). Ex.:
            --scripts=examples/ex1.py,examples/ex2.py
        Default: "${scripts}"

    --<remain_args> - Additional args to pass through to scripts such as --mgpu
        for running on multiple-gpus. All of these are passed through to all
        scripts so make sure the arguments are applicable. Otherwise call one
        script at a time.

    -h|--help - Displays this help.

EOF
}

remain_args=()

while getopts ":h-" arg; do
    case "${arg}" in
    h ) usage
        exit 2
        ;;
    - ) [ $OPTIND -ge 1 ] && optind=$(expr $OPTIND - 1 ) || optind=$OPTIND
        eval _OPTION="\$$optind"
        OPTARG=$(echo $_OPTION | cut -d'=' -f2)
        OPTION=$(echo $_OPTION | cut -d'=' -f1)
        case $OPTION in
        --container ) larguments=yes; container="$OPTARG"  ;;
        --datamnts ) larguments=yes; datamnts="$OPTARG"  ;;
        --venvpy ) larguments=yes; venvpy="$OPTARG"  ;;
        --scripts ) larguments=yes; scripts="$OPTARG"  ;;
        --help ) usage; exit 2 ;;
        --* ) remain_args+=($_OPTION) ;;
        esac
        OPTIND=1
        shift
        ;;
    esac
done

# grab all other remaning args.
remain_args+=($@)

_defvenvpy=~/${_defvenvpy}

# formulate -B option for singularity if datamnts is not empty.

# mntdata=$([[ ! -z "${datamnt// }" ]] && echo "-B ${datamnt}:${datamnt}" )
mntdata=''
if [ ! -z "${datamnts// }" ]; then
    for mnt in ${datamnts//,/ } ; do
        mntdata="-B ${mnt}:${mnt} ${mntdata}"
    done
fi

# echo MNTDATA: ${mntdata}


function join { local IFS="$1"; shift; echo "$*"; }

abspath() {                                               
    cd "$(dirname "$1")"
    printf "%s/%s\n" "$(pwd)" "$(basename "$1")"
    cd "$OLDPWD"
}

# resolve home ~
eval venvpy=$venvpy

if [ ! -d "$venvpy" ] && [ "${venvpy}" == "${_defvenvpy}" ] ; then
    echo "PLEASE WAIT. Creating virtualenv ${venvpy} with: keras numpy scipy matplotlib ipython jupyter"
    mkdir -p $(dirname ${venvpy})
    virtualenv ${venvpy}
    source ${venvpy}/bin/activate
    pip install -U pip
    pip install keras PyYaml h5py --no-deps
    pip install numpy scipy matplotlib ipython jupyter
    ipython -c "import sys"  # make sure ipython works
    deactivate
fi

module load singularity || true

if [ -z ${scripts:+x} ]; then
# =============================================================================
# RUNNING IN SHELL INTERACTIVELY
# =============================================================================
shellcmd=$(cat <<EOF
export PS1="[\\\u@\\\h \\\W singularity]\$ ";\
export LD_LIBRARY_PATH=/.singularity.d/libs:$LD_LIBRARY_PATH;\
source ${venvpy}/bin/activate
EOF
)

SINGULARITYENV_SHELLCMD=$shellcmd \
    singularity shell --nv $mntdata \
    ${container} -c 'bash --init-file <(echo "$SHELLCMD")'

else

# =============================================================================
# EXECUTING SCRIPTS
# =============================================================================
remain_args="$(join : ${remain_args[@]})"

SINGULARITYENV_SCRIPTS=$scripts \
SINGULARITYENV_REMAINARGS=$remain_args \
SINGULARITYENV_VENVPY=$venvpy \
singularity exec --nv $mntdata ${container} \
    bash -c 'LD_LIBRARY_PATH=/.singularity.d/libs:$LD_LIBRARY_PATH
if [ -d "$VENVPY" ]; then
    source ${VENVPY}/bin/activate
else
    echo "Warning - Path Does not Exist: ${VENVPY}"
    echo "Using container'\''s python"
fi

# echo VENVPY: ${VENVPY}
# echo REMAINARGS: ${REMAINARGS}
# echo SCRIPTS: ${SCRIPTS}

rargs=${REMAINARGS//:/ }
# echo "remaining args: ${rargs}"

for script in ${SCRIPTS//,/ } ; do
    # echo "running script: $script"

cat <<HERE


===============================================================================
Running script: $script

HERE

    eval script=$script  # resolve home tilde
    python $script ${rargs}

done

    '

fi

