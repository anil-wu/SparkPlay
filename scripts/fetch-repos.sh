#!/bin/bash
#
# 项目仓库拉取脚本
# 根据 repos.yaml 配置文件拉取或更新独立仓库
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# 默认配置
CONFIG_FILE="../repos.yaml"
REPO_NAME=""
SHOW_STATUS=false

# 使用说明
usage() {
    cat << EOF
项目仓库管理工具

用法: $0 [选项]

选项:
    -c, --config <文件>    指定配置文件 (默认: repos.yaml)
    -r, --repo <名称>      仅操作指定名称的仓库
    -s, --status           查看仓库状态
    -h, --help             显示此帮助信息

示例:
    $0                     克隆或更新所有仓库
    $0 -r service          仅克隆或更新名为 service 的仓库
    $0 -s                  查看所有仓库的状态
EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -r|--repo)
            REPO_NAME="$2"
            shift 2
            ;;
        -s|--status)
            SHOW_STATUS=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}未知选项: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# 检查依赖
check_dependencies() {
    if ! command -v git &> /dev/null; then
        echo -e "${RED}错误: 未找到 git，请确保已安装${NC}"
        exit 1
    fi
}

# 简单的 YAML 解析函数
parse_yaml() {
    local yaml_file="$1"
    local prefix="$2"
    local s='[[:space:]]*'
    local w='[a-zA-Z0-9_]*'

    sed -ne "s|^\(${s}\)- ${s}name: ${s}\(.*\)|${prefix}names+=(\"\2\");|p" \
           -e "s|^${s}\(${w}\)${s}:${s}\(.*\)|${prefix}\1=\"\2\";|p" "$yaml_file" 2>/dev/null || true
}

# 提取仓库列表
extract_repos() {
    local yaml_file="$1"
    local in_repos=false
    local current_repo=""
    local repo_index=-1

    declare -g -a repo_names
    declare -g -a repo_paths
    declare -g -a repo_urls
    declare -g -a repo_branches
    declare -g -a repo_descriptions

    while IFS= read -r line || [[ -n "$line" ]]; do
        # 跳过空行和注释
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # 检测 repositories 部分
        if [[ "$line" =~ ^repositories: ]]; then
            in_repos=true
            continue
        fi

        # 检测其他顶级部分
        if [[ "$line" =~ ^[a-zA-Z]+: ]] && ! [[ "$line" =~ ^repositories: ]]; then
            in_repos=false
            continue
        fi

        if $in_repos; then
            # 新的仓库条目
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*(.+)$ ]]; then
                ((repo_index++))
                repo_names[$repo_index]="${BASH_REMATCH[1]}"
                repo_branches[$repo_index]="main"
            fi

            # 仓库属性
            if [[ $repo_index -ge 0 ]]; then
                if [[ "$line" =~ ^[[:space:]]*path:[[:space:]]*(.+)$ ]]; then
                    repo_paths[$repo_index]="${BASH_REMATCH[1]}"
                elif [[ "$line" =~ ^[[:space:]]*url:[[:space:]]*(.+)$ ]]; then
                    repo_urls[$repo_index]="${BASH_REMATCH[1]}"
                elif [[ "$line" =~ ^[[:space:]]*branch:[[:space:]]*(.+)$ ]]; then
                    repo_branches[$repo_index]="${BASH_REMATCH[1]}"
                elif [[ "$line" =~ ^[[:space:]]*description:[[:space:]]*(.+)$ ]]; then
                    repo_descriptions[$repo_index]="${BASH_REMATCH[1]}"
                fi
            fi
        fi
    done < "$yaml_file"
}

# 克隆或更新仓库
sync_repo() {
    local name="$1"
    local path="$2"
    local url="$3"
    local branch="$4"

    echo -e "\n${BLUE}[$name]${NC}"
    echo -e "${GRAY}  URL: $url${NC}"
    echo -e "${GRAY}  Path: $path${NC}"
    echo -e "${GRAY}  Branch: $branch${NC}"

    if [[ -d "$path" ]]; then
        echo -e "${YELLOW}  目录已存在，执行更新...${NC}"

        cd "$path"

        if [[ ! -d ".git" ]]; then
            echo -e "${YELLOW}  警告: $path 存在但不是 git 仓库，跳过${NC}"
            cd - > /dev/null
            return
        fi

        local current_branch
        current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        echo -e "${GRAY}  当前分支: $current_branch${NC}"

        echo -e "${GRAY}  正在拉取更新...${NC}"
        if git pull origin "$branch" 2>/dev/null; then
            echo -e "${GREEN}  更新成功${NC}"
        else
            echo -e "${YELLOW}  更新失败或没有更新${NC}"
        fi

        # 切换分支（如果需要）
        if [[ "$current_branch" != "$branch" ]]; then
            echo -e "${GRAY}  切换到分支: $branch${NC}"
            git checkout "$branch" 2>/dev/null || true
        fi

        cd - > /dev/null
    else
        echo -e "${YELLOW}  目录不存在，执行克隆...${NC}"

        local clone_args=()

        if [[ -n "$branch" ]]; then
            clone_args+=("--branch" "$branch")
        fi

        echo -e "${GRAY}  执行: git clone ${clone_args[*]} $url $path${NC}"

        if git clone "${clone_args[@]}" "$url" "$path" 2>/dev/null; then
            echo -e "${GREEN}  克隆成功${NC}"
        else
            echo -e "${RED}  克隆失败${NC}"
        fi
    fi
}

# 查看仓库状态
show_repo_status() {
    local name="$1"
    local path="$2"

    echo -e "\n${BLUE}[$name]${NC}"

    if [[ ! -d "$path" ]]; then
        echo -e "  状态: ${RED}未克隆${NC}"
        return
    fi

    cd "$path"

    if [[ ! -d ".git" ]]; then
        echo -e "  状态: ${RED}不是 git 仓库${NC}"
        cd - > /dev/null
        return
    fi

    local current_branch commit_hash remote_url
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    commit_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    remote_url=$(git remote get-url origin 2>/dev/null || echo "unknown")

    # 检查未提交更改
    local status_output
    status_output=$(git status --porcelain 2>/dev/null || true)

    # 检查与远程的差异
    local ahead behind
    ahead=$(git rev-list --count "@{u}..HEAD" 2>/dev/null || echo "0")
    behind=$(git rev-list --count "HEAD..@{u}" 2>/dev/null || echo "0")

    echo -ne "  状态: "
    if [[ -n "$status_output" ]]; then
        echo -e "${YELLOW}有未提交更改${NC}"
    else
        echo -e "${GREEN}干净${NC}"
    fi

    echo "  分支: $current_branch"
    echo "  Commit: $commit_hash"
    echo "  远程: $remote_url"

    if [[ "$ahead" -gt 0 ]]; then
        echo -e "  领先远程: ${YELLOW}$ahead 个提交${NC}"
    fi
    if [[ "$behind" -gt 0 ]]; then
        echo -e "  落后远程: ${YELLOW}$behind 个提交${NC}"
    fi

    cd - > /dev/null
}

# 主函数
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  项目仓库管理工具${NC}"
    echo -e "${BLUE}========================================${NC}"

    # 检查依赖
    check_dependencies

    # 检查配置文件
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}错误: 配置文件不存在: $CONFIG_FILE${NC}"
        exit 1
    fi

    echo -e "\n${GRAY}读取配置文件: $CONFIG_FILE${NC}"

    # 提取仓库配置
    extract_repos "$CONFIG_FILE"

    local repo_count=${#repo_names[@]}
    echo -e "${GRAY}发现 $repo_count 个仓库配置${NC}"

    if [[ $repo_count -eq 0 ]]; then
        echo -e "${YELLOW}警告: 未找到任何仓库配置${NC}"
        exit 0
    fi

    # 处理每个仓库
    for ((i=0; i<repo_count; i++)); do
        local name="${repo_names[$i]}"
        local path="${repo_paths[$i]}"
        local url="${repo_urls[$i]}"
        local branch="${repo_branches[$i]}"

        # 如果指定了仓库名称，则过滤
        if [[ -n "$REPO_NAME" && "$name" != "$REPO_NAME" ]]; then
            continue
        fi

        if $SHOW_STATUS; then
            show_repo_status "$name" "$path"
        else
            sync_repo "$name" "$path" "$url" "$branch"
        fi
    done

    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}  操作完成${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# 执行主函数
main
