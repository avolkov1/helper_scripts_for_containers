Helper Scripts to Orchestrate Containers
----------------------------------------

* [`run_dock_asuser.sh`](run_dock_asuser.sh)

    See help `--help`. Used to help users run nvidia docker containers as users
    with containers inheriting their privileges within. Works for most Ubuntu
    and RHEL based containers. Basics:

```bash
Usage: run_dock_asuser.sh [-h|--help]
    [--dockname=name] [--container=docker-container] [--entrypoint=bash]
    [--workdir=dir]
    [--envlist=env1,env2,...]
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

    --container - Docker container tag/url.
        Default: nvidia/cuda:9.0-runtime-ubuntu16.04

    --entrypoint - Entrypoint override. If not specified runs the containers
        entrypoint. For generic entrypoint specify bash. Default: default

    --workdir - Work directory in which to launch main container session.
        Set to "default" to use the container's default workdir.
        Default: Current Working Directory i.e. PWD

    --envlist - Environment variable(s) to add into the container. Comma separated.
        Useful for CUDA_VISIBLE_DEVICES for example.

    --datamnts - Data directory(s) to mount into the container. Comma separated.

    --bashinit - Optional bash init file when starting an interactive session
        in the container.

    --keepalive - Do not stop/rm docker container after exiting interactive
        session. Default: false

    --daemon - Do not start an interactive session in container. Just launch
        a daemon session. Default: false

    --dockindock - Special options to enable docker in docker. Default: false

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
```
