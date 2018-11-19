#!/bin/bash

_basedir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

dockname="${USER}_dock"
container=""
datamnts=""

entrypoint=""

workdir=$PWD

envlist=""

network=""
dockopts=""
dockcmd=""

bashinit="${_basedir}/blank_init.sh"

keepalive=false

daemon=false
noninteractive=false

dockindock=false

privileged=false

usage() {
cat <<EOF
Usage: $(basename $0) [-h|--help]
    [--dockname=name] [--container=docker-container] [--entrypoint=bash]
    [--workdir=dir]
    [--envlist=env1,env2,...]
    [--net=network_option]
    [--datamnts=dir1,dir2,...] [--bashinit=some_bash_script]
    [--keepalive] [--daemon] [--dockindock] [--privileged]
    [--dockopts="--someopt1=opt1 --someopt2=opt2"]

    Sets up an interactive docker container environment session with user
    privileges. If --daemon option then just launches the docker container as a
    daemon without interactive session. Attach via:
        "docker exec -it <dockname> bash"
    Use equal sign "=" for arguments, do not separate by space.

    Some common issues to be aware of:
        1. If you get an error:
             container init caused \"mkdir <HOME>/<somedir>: permission denied\""
           You need to set the execute bit on your home directory for others
           and recursively to the desired <somedir> or workdir option.
            chmod o+x <HOME>

    --dockname - Name to use when launching container.
        Default: <USER>_dock

    --container - Docker container tag/url. Required parameter.

    --entrypoint - Entrypoint override. If not specified runs the containers
        entrypoint. For generic entrypoint specify bash. Default: default

    --workdir - Work directory in which to launch main container session.
        Set to "default" to use the container's default workdir.
        Default: Current Working Directory i.e. PWD

    --envlist - Environment variable(s) to add into the container. Comma separated.
        Useful for CUDA_VISIBLE_DEVICES for example.

    --net - Passthrough for docker. Typically one of: bridge, host, overlay
        Refer to: https://docs.docker.com/network/

    --datamnts - Data directory(s) to mount into the container. Comma separated.

    --bashinit - Optional bash init file when starting an interactive session
        in the container.

    --keepalive - Do not stop/rm docker container after exiting interactive
        session. Default: ${keepalive}

    --daemon - Do not start an interactive session in container. Just launch
        a daemon session. Default: ${daemon}

    --dockindock - Special options to enable docker in docker. Default: ${dockindock}

    --privileged - Certain features of docker containers need to run in
        privileged mode. Refer to docker documentation for the privileged option
        explanation. With privileged option the NV_GPU (or NVIDIA_VISIBLE_DEVICES)
        environment variable is ignored. Use CUDA_VISIBLE_DEVICES for GPU
        isolation at application layer.

    --dockopts - Additional docker options not covered above. These are passed
        to the docker service session. Use quotes to keep the additional
        options together. Example:
            --dockopts="--ipc=host -e MYVAR=SOMEVALUE -v /datasets:/data"
        The "--ipc=host" can be used for MPS with nvidia-docker2. Any
        additional docker option that is not exposed above can be set through
        this option. In the example the "/datasets" is mapped to "/data" in the
        container instead of using "--datamnts".

    --dockcmd - Commands to pass to the container. I.e. when running like this:
        docker run <dockopts> <entrypoint> <container> <dockcmd>
        Where the other options are as documented above. 

    --noninteractive - Typically the container is launched as a service and
        attached to interactively or if daemon option then just left in the
        background. This option is meant for containers that just run some
        utility code and are not meant to be used interactively or as a service.
        An example would be running p2pBandwidthLatencyTest in a container.
            run_dock_asuser.sh --container=<p2pBandwidthContainer> --noninteractive --workdir=default

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
        --bashinit ) larguments=yes; bashinit="$OPTARG"  ;;
        --dockname ) larguments=yes; dockname="$OPTARG"  ;;
        --container ) larguments=yes; container="$OPTARG"  ;;
        --entrypoint ) larguments=yes; entrypoint="$OPTARG"  ;;
        --workdir ) larguments=yes; workdir="$OPTARG"  ;;
        --envlist ) larguments=yes; envlist="$OPTARG"  ;;
        --datamnts ) larguments=yes; datamnts="$OPTARG"  ;;
        --keepalive ) larguments=no; keepalive=true  ;;
        --daemon ) larguments=no; daemon=true  ;;
        --noninteractive ) larguments=no; noninteractive=true  ;;
        --dockindock ) larguments=no; dockindock=true  ;;
        --privileged ) larguments=no; privileged=true  ;;
        --net ) larguments=yes;
            network="$( cut -d '=' -f 2- <<< "$_OPTION" )";  ;;
        --dockopts ) larguments=yes;
            # https://unix.stackexchange.com/questions/53310/splitting-string-by-the-first-occurrence-of-a-delimiter
            dockopts="$( cut -d '=' -f 2- <<< "$_OPTION" )";  ;;
        --dockcmd ) larguments=yes;
            dockcmd="$( cut -d '=' -f 2- <<< "$_OPTION" )";  ;;
        --help ) usage; exit 2 ;;
        --* ) remain_args+=($_OPTION) ;;
        esac
        OPTIND=1
        shift
        ;;
    esac
done

if [ -z "$container" ]; then
    echo "ERROR: CONTAINER NOT SPECIFIED. Specify via --container=<tag/url>. Refer to --help"
    exit 2
fi

# grab all other remaning args.
remain_args+=($@)

# Set the NV_GPU to allocated GPUs (useful if using a resource manager).
# This does not guarantee CPU-Cores or affinities set via resource manager.
if [ -z ${NV_GPU:+x} ]; then
    export NV_GPU="$(nvidia-smi -q | grep UUID | awk '{ print $4 }' | tr '\n' ',')"
fi

envvars=''
if [ ! -z "${envlist// }" ]; then
    for evar in ${envlist//,/ } ; do
        envvars="-e ${evar}=${!evar} ${envvars}"
    done
fi
# echo envvars: ${envvars}

# mntdata=$([[ ! -z "${datamnt// }" ]] && echo "-v ${datamnt}:${datamnt}:ro" )
mntdata=''
if [ ! -z "${datamnts// }" ]; then
    for mnt in ${datamnts//,/ } ; do
        mntdata="-v ${mnt}:${mnt} ${mntdata}"
    done
fi

networkopts=''
if [ ! -z "${network}" ]; then
    networkopts="--net=${network}"
fi


entrypointopt=''
if [ ! -z "${entrypoint}" ]; then
    entrypointopt="--entrypoint=${entrypoint}"
fi

workdiropt=''
if [ ! "${workdir}" = "default" ]; then
    workdiropt="--workdir=${workdir}"
fi

# deb/ubuntu based containers
SOMECONTAINER=$container  # deb/ubuntu based containers

RECOMMENDEDOPTS="--shm-size=1g --ulimit memlock=-1 --ulimit stack=67108864"
USEROPTS="-u $(id -u):$(id -g) -e HOME=$HOME -e USER=$USER -v $HOME:$HOME"
getent group > group
getent passwd > passwd

USERGROUPOPTS="-v $PWD/passwd:/etc/passwd:ro -v $PWD/group:/etc/group:ro"

# append any special users from the container
nvidia-docker run --rm \
  $USEROPTS \
  -w $PWD --entrypoint=bash $SOMECONTAINER -c 'cat /etc/passwd' >> passwd

dockindockopts=''
if [ "$dockindock" = true ] ; then
    dockindockopts="--group-add $(stat -c %g /var/run/docker.sock) \
      -v /var/run/docker.sock:/var/run/docker.sock "
fi

privilegedopt=''
if [ "$privileged" = true ] ; then
    privilegedopt="--privileged"
fi

if [ "$noninteractive" = true ] ; then
  nvidia-docker run --rm -t --name=${dockname} $dockopts $networkopts ${privilegedopt} \
    $USEROPTS $USERGROUPOPTS $mntdata $envvars $RECOMMENDEDOPTS \
    --hostname "$(hostname)-contain" \
    ${dockindockopts} \
    ${workdiropt} $entrypointopt $SOMECONTAINER $dockcmd

  exit

fi

# run as user with my privileges and group mapped into the container
# echo dockopts: $dockopts
nvidia-docker run -d -t --name=${dockname} $dockopts $networkopts ${privilegedopt} \
  $USEROPTS $USERGROUPOPTS $mntdata $envvars $RECOMMENDEDOPTS \
  --hostname "$(hostname)-contain" \
  ${dockindockopts} \
  ${workdiropt} $entrypointopt $SOMECONTAINER $dockcmd


if [ "$dockindock" = true ] ; then
    # load all the nvml stuff. Not sure if this is needed in everything.
    docker exec -it -u root ${dockname} bash -c 'ldconfig'
fi


if [ "$daemon" = false ] ; then
    # running some init makes a performance difference??? I don't know why.
    docker exec -it ${dockname} bash --init-file ${bashinit}

fi


if [ "$keepalive" = false ] && [ "$daemon" = false ] ; then
    docker stop ${dockname} && docker rm ${dockname}
fi
