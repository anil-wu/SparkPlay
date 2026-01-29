# 七、工程元数据文件示例

```json
{
    "engine": {
        "name": "phaser",
        "version": "3.80.0"
    },
    "entry": "src/main.ts",
    "files": [
        {
            "path": "src/main.ts",
            "file_id": 101,
            "file_version_id": 1001,
            "type": "text",
            "format": "ts"
        },
        {
            "path": "assets/images/player.png",
            "file_id": 202,
            "file_version_id": 2005,
            "type": "image",
            "format": "png"
        },
        {
            "path": "assets/audio/jump.wav",
            "file_id": 303,
            "file_version_id": 3002,
            "type": "audio",
            "format": "wav"
        }
    ],
    "folders": [
        "src",
        "assets/images",
        "assets/audio"
    ],
    "agents": [
        {
            "agent_id": 1,
            "name": "code_agent",
            "llm_model_id": 501
        },
        {
            "agent_id": 2,
            "name": "asset_agent",
            "llm_model_id": 502
        }
    ]
}
```

