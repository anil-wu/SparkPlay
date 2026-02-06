#!/usr/bin/env python3
"""
仓库拉取脚本 (Python)
基于 repos.yaml 配置文件拉取或更新所有仓库
"""

import os
import sys
import argparse
import subprocess
import yaml
from pathlib import Path
from typing import Dict, List, Optional, Any


def load_yaml_config(file_path: str) -> Dict[str, Any]:
    """加载并解析 YAML 配置文件"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f)
    except FileNotFoundError:
        print(f"错误: 配置文件 {file_path} 不存在", file=sys.stderr)
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"错误: YAML 解析失败: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"错误: 读取配置文件失败: {e}", file=sys.stderr)
        sys.exit(1)


def check_repo_status(repo_path: str, repo_url: str, branch: str) -> Dict[str, Any]:
    """检查仓库状态"""
    repo_dir = Path(repo_path)
    
    # 检查仓库目录是否存在
    if not repo_dir.exists():
        return {
            'exists': False,
            'is_git': False,
            'is_up_to_date': False,
            'current_branch': None,
            'remote_url': None,
            'needs_clone': True
        }
    
    # 检查是否是 git 仓库
    git_dir = repo_dir / '.git'
    if not git_dir.exists():
        return {
            'exists': True,
            'is_git': False,
            'is_up_to_date': False,
            'current_branch': None,
            'remote_url': None,
            'needs_clone': False
        }
    
    try:
        # 获取当前分支
        result = subprocess.run(
            ['git', 'branch', '--show-current'],
            cwd=repo_path,
            capture_output=True,
            text=True,
            encoding='utf-8'
        )
        current_branch = result.stdout.strip() if result.returncode == 0 else None
        
        # 获取远程 URL
        result = subprocess.run(
            ['git', 'remote', 'get-url', 'origin'],
            cwd=repo_path,
            capture_output=True,
            text=True,
            encoding='utf-8'
        )
        remote_url = result.stdout.strip() if result.returncode == 0 else None
        
        # 检查是否有更新
        # 先拉取远程信息
        subprocess.run(
            ['git', 'fetch', 'origin'],
            cwd=repo_path,
            capture_output=True,
            text=True,
            encoding='utf-8'
        )
        
        # 比较本地和远程
        result = subprocess.run(
            ['git', 'rev-list', '--count', f'HEAD..origin/{branch}'],
            cwd=repo_path,
            capture_output=True,
            text=True,
            encoding='utf-8'
        )
        behind_count = int(result.stdout.strip()) if result.returncode == 0 else 0
        
        is_up_to_date = behind_count == 0
        
        return {
            'exists': True,
            'is_git': True,
            'is_up_to_date': is_up_to_date,
            'current_branch': current_branch,
            'remote_url': remote_url,
            'needs_clone': False,
            'behind_count': behind_count
        }
        
    except Exception as e:
        print(f"警告: 检查仓库状态时出错 {repo_path}: {e}", file=sys.stderr)
        return {
            'exists': True,
            'is_git': False,
            'is_up_to_date': False,
            'current_branch': None,
            'remote_url': None,
            'needs_clone': False
        }


def display_repo_status(repo: Dict[str, Any], status: Dict[str, Any]) -> None:
    """显示仓库状态"""
    print(f"仓库: {repo['name']}")
    print(f"  路径: {repo['path']}")
    print(f"  URL: {repo['url']}")
    print(f"  分支: {repo.get('branch', 'main')}")
    
    if not status['exists']:
        print("  状态: 目录不存在 - 需要克隆", file=sys.stderr)
    elif not status['is_git']:
        print("  状态: 不是 Git 仓库 - 需要重新克隆", file=sys.stderr)
    else:
        print(f"  当前分支: {status['current_branch']}")
        print(f"  远程 URL: {status['remote_url']}")
        if status['is_up_to_date']:
            print("  状态: 已是最新")
        else:
            print(f"  状态: 落后 {status.get('behind_count', 0)} 个提交 - 需要更新")


def clone_repository(repo: Dict[str, Any], global_config: Dict[str, Any]) -> bool:
    """克隆仓库"""
    repo_path = repo['path']
    repo_url = repo['url']
    branch = repo.get('branch', 'main')
    
    print(f"正在克隆仓库 {repo['name']} 到 {repo_path}...")
    
    # 构建克隆命令
    cmd = ['git', 'clone']
    
    # 添加分支参数
    cmd.extend(['-b', branch])
    
    # 添加深度参数
    default_depth = global_config.get('default_depth')
    if default_depth is not None:
        cmd.extend(['--depth', str(default_depth)])
    
    # 添加递归参数
    if global_config.get('recursive', False):
        cmd.append('--recursive')
    
    cmd.extend([repo_url, repo_path])
    
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding='utf-8'
        )
        
        if result.returncode != 0:
            print(f"错误: 克隆失败: {result.stderr}", file=sys.stderr)
            return False
        
        print(f"成功克隆仓库 {repo['name']}")
        
        # 如果需要更新子模块
        if global_config.get('update_submodules', False):
            print(f"正在更新子模块...")
            subprocess.run(
                ['git', 'submodule', 'update', '--init', '--recursive'],
                cwd=repo_path,
                capture_output=True,
                text=True,
                encoding='utf-8'
            )
        
        return True
        
    except Exception as e:
        print(f"错误: 克隆过程异常: {e}", file=sys.stderr)
        return False


def update_repository(repo: Dict[str, Any], global_config: Dict[str, Any]) -> bool:
    """更新仓库"""
    repo_path = repo['path']
    branch = repo.get('branch', 'main')
    
    print(f"正在更新仓库 {repo['name']}...")
    
    try:
        # 检查当前分支
        result = subprocess.run(
            ['git', 'branch', '--show-current'],
            cwd=repo_path,
            capture_output=True,
            text=True,
            encoding='utf-8'
        )
        
        current_branch = result.stdout.strip()
        
        # 如果不在目标分支，切换到目标分支
        if current_branch != branch:
            print(f"  切换到分支 {branch}...")
            subprocess.run(
                ['git', 'checkout', branch],
                cwd=repo_path,
                capture_output=True,
                text=True,
                encoding='utf-8'
            )
        
        # 拉取更新
        print(f"  拉取更新...")
        result = subprocess.run(
            ['git', 'pull', 'origin', branch],
            cwd=repo_path,
            capture_output=True,
            text=True,
            encoding='utf-8'
        )
        
        if result.returncode != 0:
            print(f"错误: 拉取失败: {result.stderr}", file=sys.stderr)
            return False
        
        # 如果需要更新子模块
        if global_config.get('update_submodules', False):
            print(f"  更新子模块...")
            subprocess.run(
                ['git', 'submodule', 'update', '--init', '--recursive'],
                cwd=repo_path,
                capture_output=True,
                text=True,
                encoding='utf-8'
            )
        
        print(f"成功更新仓库 {repo['name']}")
        return True
        
    except Exception as e:
        print(f"错误: 更新过程异常: {e}", file=sys.stderr)
        return False


def process_repository(repo: Dict[str, Any], global_config: Dict[str, Any], 
                      status_only: bool = False) -> bool:
    """处理单个仓库"""
    status = check_repo_status(repo['path'], repo['url'], repo.get('branch', 'main'))
    
    if status_only:
        display_repo_status(repo, status)
        return True
    
    if status['needs_clone'] or not status['is_git']:
        return clone_repository(repo, global_config)
    elif not status['is_up_to_date']:
        return update_repository(repo, global_config)
    else:
        print(f"仓库 {repo['name']} 已是最新，跳过")
        return True


def main():
    """主函数"""
    parser = argparse.ArgumentParser(description='基于 repos.yaml 拉取或更新仓库')
    parser.add_argument('--repo', '-r', type=str, help='指定要处理的仓库名称')
    parser.add_argument('--status', '-s', action='store_true', help='只显示状态，不执行更新')
    parser.add_argument('--config', '-c', type=str, default='repos.yaml', 
                       help='配置文件路径 (默认: repos.yaml)')
    
    args = parser.parse_args()
    
    # 获取项目根目录
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    config_file = project_root / args.config
    
    # 加载配置
    config = load_yaml_config(str(config_file))
    
    # 验证配置结构
    if 'repositories' not in config:
        print("错误: 配置文件中缺少 'repositories' 部分", file=sys.stderr)
        sys.exit(1)
    
    # 获取全局配置
    global_config = config.get('global', {})
    
    # 获取仓库列表
    repositories = config['repositories']
    
    # 如果指定了仓库名称，过滤列表
    if args.repo:
        filtered_repos = [repo for repo in repositories if repo['name'] == args.repo]
        if not filtered_repos:
            print(f"错误: 未找到名为 '{args.repo}' 的仓库", file=sys.stderr)
            sys.exit(1)
        repositories = filtered_repos
    
    print(f"开始处理 {len(repositories)} 个仓库...")
    print("=" * 50)
    
    success_count = 0
    for repo in repositories:
        try:
            if process_repository(repo, global_config, args.status):
                success_count += 1
        except Exception as e:
            print(f"处理仓库 '{repo['name']}' 时出错: {e}", file=sys.stderr)
        print()
    
    print("=" * 50)
    print("=== 完成 ===")
    print(f"成功处理: {success_count}/{len(repositories)} 个仓库")
    
    if success_count == len(repositories):
        print("所有仓库处理成功")
        sys.exit(0)
    else:
        print("部分仓库处理失败", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    # 检查 yaml 模块
    try:
        import yaml
    except ImportError:
        print("错误: 缺少 PyYAML 模块", file=sys.stderr)
        print("请安装: pip install PyYAML", file=sys.stderr)
        sys.exit(1)
    
    main()