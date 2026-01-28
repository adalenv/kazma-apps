# Kazma Desktop Templates

This repository contains desktop templates for the Kazma Web Desktop Platform.

## Template Structure

Each template must contain:

```
template-name/
├── kazma.yaml          # Template manifest (required)
├── Dockerfile          # Container build file (required)
├── config/             # Configuration files (optional)
│   ├── supervisord.conf
│   └── startwm.sh
└── scripts/            # Startup scripts (optional)
    └── startup.sh
```

## kazma.yaml Manifest

```yaml
name: "Template Display Name"
slug: "template-slug"           # URL-safe identifier (must match folder name)
description: "Description of the template"
icon: "monitor"                 # Icon name for UI
version: "1.0.0"

resources:
  cpu_limit: 2.0                # CPU cores
  memory_limit: "2g"            # Memory limit
  disk_limit: "10g"             # Disk limit
  gpu_enabled: false            # GPU support

options:
  persistent_home: true         # Enable persistent storage
  security_relaxed: false       # Relaxed security for Chrome/TeamViewer
  enabled: true                 # Template available for users
  is_default: false             # Default workspace selection
  sort_order: 0                 # Display order in UI
```

## Available Templates

| Template | Description | Resources |
|----------|-------------|-----------|
| debian | Full-featured Debian 12 with XFCE | 2 CPU, 2GB RAM |
| alpine | Lightweight Alpine Linux (fast startup) | 1 CPU, 512MB RAM |
| ubuntu | Ubuntu 22.04 LTS with XFCE | 2 CPU, 2GB RAM |
| dev | Development tools (Node, Python, Git) | 4 CPU, 4GB RAM |
| support | Remote support with Chrome, AnyDesk, TeamViewer | 2 CPU, 2GB RAM |

## Creating a New Template

1. Create a new folder with your template slug name
2. Add a `Dockerfile` for building the container
3. Create a `kazma.yaml` manifest with template metadata
4. Add any necessary config files and scripts
5. Commit and push to this repository
6. Sync templates in Kazma Admin UI

## Base Image Requirements

Templates should include:
- XRDP server (port 3389)
- Supervisor for process management
- A desktop environment (XFCE recommended)
- Health check endpoint (nc -z localhost 3389)

See existing templates for reference implementations.
