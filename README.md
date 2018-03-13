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
    [--keepalive] [--daemon] [--dockindock]

    Sets up an interactive docker container environment session with user
    privileges. If --daemon option then just launches the docker container as a
    daemon without interactive session. Attach via:
        "docker exec -it <dockname> bash"
    Use equal sign "=" for arguments, do not separate by space.

    --dockname - Name to use when launching container.
        Default: mydock

    --container - Docker container tag/url.
        Default: tensorflow/tensorflow:1.3.0-devel-gpu

    --entrypoint - Entrypoint override. If not specified runs the containers
        entrypoint. For generic entrypoint specify bash. Default: default

    --workdir - Work directory in which to launch main container session.
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

    -h|--help - Displays this help.
```


