# ffmpeg-transcode

`ffmpeg-transcode` 是一个面向 Linux 服务器的视频批量转码脚本，适合把目录或单个视频转成 MP4，并保留源目录下的相对目录结构。脚本默认偏向 RockChip MPP 硬件编解码场景，也可以在交互模式中选择软件编解码。

## 文件说明

- `transcode.sh`：Bash 转码脚本，负责扫描源目录、复制字幕和其他文件、调用 `ffmpeg` 转码视频，并把日志写入脚本同目录下的 `transcode.log`。

## 使用方法

从工具站下载脚本并赋予执行权限：

```bash
curl -fsSL https://<tools-origin>/source/ffmpeg-transcode/transcode.sh -o transcode.sh
chmod +x transcode.sh
```

本地交互模式会依次询问源路径、目标路径、输出格式、编解码方案、视频高度和目标码率：

```bash
bash ./transcode.sh
```

提供源路径和目标路径时会进入静默模式，使用默认配置转码：

```bash
bash ./transcode.sh /path/to/source_videos /path/to/output_videos
```

转码单个文件：

```bash
bash ./transcode.sh /path/to/source_videos/movie.mkv /path/to/output_videos
```

只检查将要执行的 `ffmpeg` 命令，不实际转码或复制文件：

```bash
bash ./transcode.sh --dry-run /path/to/source_videos /path/to/output_videos
```

安装 `transcode` 别名到 `~/.bashrc` 或 `~/.zshrc`：

```bash
bash ./transcode.sh --install
```

查看帮助：

```bash
bash ./transcode.sh --help
```

## 参数说明

- `--dry-run`：启用预演模式，只输出将执行的 `ffmpeg` 命令，不转码、不复制文件。
- `--install`：把当前脚本路径注册为 `transcode` 命令别名，支持 Bash 和 Zsh。
- `--help`：显示脚本帮助。
- `源目录或源文件`：包含待转码视频的目录，或一个具体视频文件路径。省略时进入交互模式。
- `目标目录`：输出文件目录。提供源路径时必须同时提供目标目录；目标目录不存在时脚本会尝试创建。

静默模式默认配置：

- 输出格式：`hevc`
- 编解码方案：RockChip MPP 硬件解码 + RockChip MPP 硬件编码
- 输出高度：`720p`，不会主动放大低分辨率视频
- 目标视频码率：`2000 kbps`

交互模式可选择：

- 输出格式：`h264` 或 `hevc`
- 编解码方案：软件解码 + MPP 硬件编码、MPP 硬件解码 + MPP 硬件编码、软件解码 + 软件编码
- 输出高度：`4K`、`1080p`、`720p`、`480p`、`360p` 或保持原始高度
- 目标码率：`1000`、`2000`、`4000`、`6000`、`8000 kbps`，或输入自定义 kbps 数值

支持的视频扩展名包括 `mp4`、`mkv`、`avi`、`wmv`、`flv`、`mov`、`m4v`、`rm`、`rmvb`、`3gp`、`vob`。支持复制的字幕扩展名包括 `srt`、`ass`、`ssa`、`vtt`、`sub`、`idx`。

## 注意事项

- 脚本需要 Linux Bash，并且 `ffmpeg` 与 `ffprobe` 必须已经安装且可在 `PATH` 中找到。
- 静默模式默认使用 `h264_rkmpp` / `hevc_rkmpp` 和 `rkmpp` 硬件解码参数；非 RockChip 设备建议使用交互模式选择软件编解码，或先执行 `--dry-run` 检查命令。
- 目录模式会把字幕和其他非视频文件复制到目标目录，并保持相对目录结构；视频输出扩展名固定为 `.mp4`。
- 源路径和目标路径不能相同，避免覆盖源文件。
- 输出文件已存在时，`ffmpeg` 会直接覆盖；转码失败时脚本会尝试删除部分生成的输出文件。
- 脚本会在自身所在目录写入 `transcode.log`，请确认运行用户对该目录有写权限。
- `--install` 会修改当前用户的 `~/.bashrc` 或 `~/.zshrc`。执行前建议确认没有同名 `transcode` 别名。
