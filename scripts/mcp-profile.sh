#!/usr/bin/env sh
# Dynamic MCP Profile Switcher for POSIX environments (Linux / macOS).
# Switches active MCP servers across agent configurations.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROFILE="${1:-core}"

case "$PROFILE" in
    core|ui|compression|all) ;;
    *)
        echo "Error: Unknown profile '$PROFILE'. Valid options: core, ui, compression, all" >&2
        exit 1
        ;;
esac

echo "Switching MCP profile to '$PROFILE' in $PROJECT_ROOT..."

python3 -c "
import json, sys, os

project_root = '''$PROJECT_ROOT'''
profile = '''$PROFILE'''

graphify_active = True
ui_active = profile in ('ui', 'all')
headroom_active = profile in ('compression', 'all')

# 1. Update opencode.json
opencode_path = os.path.join(project_root, 'opencode.json')
if os.path.exists(opencode_path):
    try:
        with open(opencode_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        if 'mcp' in data:
            if 'graphify' in data['mcp']:
                data['mcp']['graphify']['enabled'] = graphify_active
            if 'ui-registry' in data['mcp']:
                data['mcp']['ui-registry']['enabled'] = ui_active
            if 'headroom' in data['mcp']:
                data['mcp']['headroom']['enabled'] = headroom_active
        with open(opencode_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)
        print('[OK] Updated opencode.json')
    except Exception as e:
        print(f'[WARN] Failed to update opencode.json: {e}')

# 2. Update .antigravity/mcp_config.json
mcp_path = os.path.join(project_root, '.antigravity', 'mcp_config.json')
if os.path.exists(mcp_path):
    try:
        with open(mcp_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        if 'mcpServers' in data:
            if 'graphify' in data['mcpServers']:
                data['mcpServers']['graphify']['disabled'] = not graphify_active
            if 'ui-registry' in data['mcpServers']:
                data['mcpServers']['ui-registry']['disabled'] = not ui_active
            if 'headroom' in data['mcpServers']:
                data['mcpServers']['headroom']['disabled'] = not headroom_active
        with open(mcp_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)
        print('[OK] Updated .antigravity/mcp_config.json')
    except Exception as e:
        print(f'[WARN] Failed to update .antigravity/mcp_config.json: {e}')

# 3. Update .antigravity/settings.json
settings_path = os.path.join(project_root, '.antigravity', 'settings.json')
if os.path.exists(settings_path):
    try:
        with open(settings_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        if 'context' in data:
            data['context']['mcp_profile'] = profile
        with open(settings_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)
        print('[OK] Updated .antigravity/settings.json')
    except Exception as e:
        print(f'[WARN] Failed to update .antigravity/settings.json: {e}')
"

echo "Successfully applied MCP Profile: '$PROFILE'"
exit 0
