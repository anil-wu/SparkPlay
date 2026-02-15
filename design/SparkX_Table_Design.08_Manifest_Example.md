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
            "hash": "md5:1234567890abcdef1234567890abcdef",
            "type": "text",
            "format": "ts"
        },
        {
            "path": "assets/images/player.png",
            "file_id": 202,
            "file_version_id": 2005,
            "hash": "md5:1234567890abcdef1234567890abcdef",
            "type": "image",
            "format": "png"
        },
        {
            "path": "assets/audio/jump.wav",
            "file_id": 303,
            "file_version_id": 3002,
            "hash": "md5:1234567890abcdef1234567890abcdef",
            "type": "audio",
            "format": "wav"
        }
    ],
    "folders": [
        "src",
        "assets/images",
        "assets/audio"
    ]
}
```

