```@meta
CurrentModule = ReplExit
```

# Reference

Nothing is exported; every name is called as `ReplExit.name`.

## Module

```@docs
ReplExit
```

## Enabling and disabling

```@docs
ReplExit.enable!
ReplExit.disable!
ReplExit.isenabled
```

## Wiring into `startup.jl`

```@docs
ReplExit.install
ReplExit.uninstall
ReplExit.startup_file
ReplExit.config_dir
```

## Internals

These are documented for the curious and for contributors. They are not part
of the package's public interface and may change between minor versions.

```@docs
ReplExit.transform
ReplExit.ast_transforms
ReplExit.strip_block
ReplExit.in_default_environment
ReplExit.UUID
```

## Index

```@index
```
