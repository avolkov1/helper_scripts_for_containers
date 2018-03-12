#!/bin/bash

_basedir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

dockname='mydock'
container=tensorflow/tensorflow:1.3.0-devel-gpu
datamnts=''

envlist=''

bashinit="${_basedir}/blank_init.sh"

keepalive=false

daemon=false

usage() {
cat <<EOF
Usage: $(basename $0) [-h|--help]
    [--dockname=name] [--container=docker-container] [--envlist=env1,env2,...]
    [--datamnts=dir1,dir2,...] [--bashinit=some_bash_script]
    [--keepalive] [--daemon]

    Sets up an interactive docker container environment session with user
    privileges. If --daemon option then just launches the docker container as a
    daemon without interactive session. Attach via:
        "docker exec -it <dockname> bash"
    Use equal sign "=" for arguments, do not separate by space.

    --dockname - Name to use when launching container.
        Default: ${dockname}

    --container - Docker container tag/url.
        Default: ${container}

    --envlist - Environment variable(s) to add into the container. Comma separated.
        Useful for CUDA_VISIBLE_DEVICES for example.

    --datamnts - Data directory(s) to mount into the container. Comma separated.

    --bashinit - Optional bash init file when starting an interactive session
        in the container.

    --keepalive - Do not stop/rm docker container after exiting interactive
        session. Default: ${keepalive}

    --daemon - Do not start an interactive session in container. Just launch
        a daemon session. Default: ${daemon}

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
        --envlist ) larguments=yes; envlist="$OPTARG"  ;;
        --datamnts ) larguments=yes; datamnts="$OPTARG"  ;;
        --keepalive ) larguments=no; keepalive=true  ;;
        --daemon ) larguments=no; daemon=true  ;;
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

envvars=''
if [ ! -z "${envlist// }" ]; then
    for evar in ${envlist//,/ } ; do
        envvars="-e ${evar}=${!evar} ${envvars}"
    done
fi


# mntdata=$([[ ! -z "${datamnt// }" ]] && echo "-v ${datamnt}:${datamnt}:ro" )
mntdata=''
if [ ! -z "${datamnts// }" ]; then
    for mnt in ${datamnts//,/ } ; do
        mntdata="-v ${mnt}:${mnt} ${mntdata}"
    done
fi

# deb/ubuntu based containers
SOMECONTAINER=$container  # deb/ubuntu based containers

RECOMMENDEDOPTS="--shm-size=1g --ulimit memlock=-1 --ulimit stack=67108864"
USEROPTS="-u $(id -u):$(id -g) -e HOME=$HOME -e USER=$USER -v $HOME:$HOME"
getent group > group
getent passwd > passwd

USERGROUPOPTS="-v $PWD/passwd:/etc/passwd:ro -v $PWD/group:/etc/group:ro"

# append any special users from the container
nvidia-docker run --rm -ti \
  $USEROPTS \
  -w $PWD --entrypoint=bash $SOMECONTAINER -c 'cat /etc/passwd' >> passwd

# run as user with my privileges and group mapped into the container
# "$(hostname)_contain" \
# nvidia-docker run --rm -ti --name=mydock \
nvidia-docker run -d -t --name=${dockname} --net=host \
  $USEROPTS $USERGROUPOPTS $mntdata $envvars $RECOMMENDEDOPTS \
  --hostname "$(hostname)_contain" \
  -w $PWD --entrypoint=bash $SOMECONTAINER


if [ "$daemon" = false ] ; then
    # running some init makes a performance difference??? I don't know why.
    docker exec -it ${dockname} bash --init-file ${bashinit}

fi


if [ "$keepalive" = false ] && [ "$daemon" = false ] ; then
    docker stop ${dockname} && docker rm ${dockname}
fi
