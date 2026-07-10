from flask import Flask, render_template, request, redirect, url_for, session, abort
import json
import os
import time
import requests
import random
from datetime import datetime

app = Flask(__name__, static_folder='static', static_url_path='/')
app.secret_key = 'your-secret-key-here'  # 用于会话管理

# 验证码存储：{phone: {'code': 'xxx', 'timestamp': xxx}}
sms_codes = {}
# 短信发送记录：{phone: last_send_time}
sms_send_records = {}

# 添加时间戳格式化过滤器
@app.template_filter('datetimeformat')
def datetimeformat(timestamp):
    from datetime import datetime
    return datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d %H:%M:%S')

# 存储IP请求记录：{ip: [timestamp1, timestamp2, ...]}
ip_requests = {}
MAX_REQUESTS = 60  # 1分钟最大请求数
TIME_WINDOW = 60    # 时间窗口（秒）

# 存储用户违规记录：{user_identifier: {'offenses': [timestamp1, timestamp2, ...], 'banned_until': timestamp, 'ban_level': 0}}
user_offenses = {}

# 封禁等级配置
BAN_CONFIG = {
    1: {'window': 60 * 60, 'limit': 3, 'ban_duration': 60 * 60},  # 60分钟内3条，封禁60分钟
    2: {'window': 6 * 60 * 60, 'limit': 5, 'ban_duration': 24 * 60 * 60},  # 6小时内5条，封禁24小时
    3: {'window': 12 * 60 * 60, 'limit': 8, 'ban_duration': 7 * 24 * 60 * 60}  # 12小时内8条，封禁7天
}

def generate_user_identifier():
    """生成用户标识，基于IP地址和浏览器信息"""
    ip = request.remote_addr
    user_agent = request.headers.get('User-Agent', '')
    # 简单的用户标识生成
    return f"{ip}_{hash(user_agent) % 1000000}"

@app.before_request
def limit_requests():
    ip = request.remote_addr
    current_time = time.time()
    
    # 允许被封禁的用户访问申诉页面
    if request.path == '/appeal':
        # 记录新请求
        if ip not in ip_requests:
            ip_requests[ip] = []
        ip_requests[ip] = [t for t in ip_requests[ip] if current_time - t < TIME_WINDOW]
        if len(ip_requests[ip]) < MAX_REQUESTS:
            ip_requests[ip].append(current_time)
        return
    
    # 初始化IP记录
    if ip not in ip_requests:
        ip_requests[ip] = []
    
    # 清理过期记录
    ip_requests[ip] = [t for t in ip_requests[ip] if current_time - t < TIME_WINDOW]
    
    # 检查请求频率
    if len(ip_requests[ip]) >= MAX_REQUESTS:
        abort(429)
    
    # 检查用户是否被封禁
    user_identifier = generate_user_identifier()
    ip_identifier = f"{ip}_ban"  # 基于IP的标识
    
    # 检查基于用户标识的封禁
    if user_identifier in user_offenses:
        ban_info = user_offenses[user_identifier]
        if ban_info.get('banned_until', 0) > current_time:
            abort(403)
    
    # 检查基于IP的封禁
    if ip_identifier in user_offenses:
        ban_info = user_offenses[ip_identifier]
        if ban_info.get('banned_until', 0) > current_time:
            abort(403)
    
    # 记录新请求
    ip_requests[ip].append(current_time)

# 确保数据文件夹存在
DATA_DIR = 'data'
if not os.path.exists(DATA_DIR):
    os.makedirs(DATA_DIR)

# 表白数据文件路径
CONFESSIONS_FILE = os.path.join(DATA_DIR, 'confessions.json')

# 初始化表白数据文件
if not os.path.exists(CONFESSIONS_FILE):
    with open(CONFESSIONS_FILE, 'w', encoding='utf-8') as f:
        json.dump([], f, ensure_ascii=False, indent=2)

# 管理员配置文件路径
ADMIN_CONFIG_FILE = os.path.join(DATA_DIR, 'admin_config.json')

# 初始化管理员配置文件
def init_admin_config():
    if not os.path.exists(ADMIN_CONFIG_FILE):
        admin_config = {
            'admins': [
                {
                    'username': 'admin',
                    'password': 'admin',
                    'role': 'main',
                    'status': 'active'
                }
            ]
        }
        with open(ADMIN_CONFIG_FILE, 'w', encoding='utf-8') as f:
            json.dump(admin_config, f, ensure_ascii=False, indent=2)

# 加载管理员配置
def load_admin_config():
    init_admin_config()
    with open(ADMIN_CONFIG_FILE, 'r', encoding='utf-8') as f:
        return json.load(f)

# 保存管理员配置
def save_admin_config(config):
    with open(ADMIN_CONFIG_FILE, 'w', encoding='utf-8') as f:
        json.dump(config, f, ensure_ascii=False, indent=2)

# 根据用户名获取管理员信息
def get_admin_by_username(username):
    config = load_admin_config()
    for admin in config.get('admins', []):
        if admin.get('username') == username:
            return admin
    return None

# 字体配置文件路径
FONT_CONFIG_FILE = os.path.join(DATA_DIR, 'font_config.json')

# 初始化字体配置文件
def init_font_config():
    if not os.path.exists(FONT_CONFIG_FILE):
        font_config = {
            'font': 'default'
        }
        with open(FONT_CONFIG_FILE, 'w', encoding='utf-8') as f:
            json.dump(font_config, f, ensure_ascii=False, indent=2)

# 加载字体配置
def load_font_config():
    init_font_config()
    with open(FONT_CONFIG_FILE, 'r', encoding='utf-8') as f:
        return json.load(f)

# 保存字体配置
def save_font_config(config):
    with open(FONT_CONFIG_FILE, 'w', encoding='utf-8') as f:
        json.dump(config, f, ensure_ascii=False, indent=2)

# 敏感词库文件路径
SENSITIVE_WORDS_FILE = os.path.join(DATA_DIR, 'sensitives.json')

# 初始化敏感词库文件
def init_sensitive_words():
    if not os.path.exists(SENSITIVE_WORDS_FILE):
        sensitive_config = {
            "categories": {
                "obscenity": {
                    "name": "色情内容",
                    "words": [
                        "操",
                        "色情",
                        "情色",
                        "黄色",
                        "淫秽",
                        " porn",
                        "做爱",
                        "性交",
                        "性行为",
                        "性器官",
                        "乳房",
                        "阴茎",
                        "阴道",
                        "强奸",
                        "轮奸",
                        "卖淫",
                        "嫖娼",
                        "招妓",
                        "援交",
                        "露点",
                        "裸照",
                        "三级片",
                        "AV女优"
                    ]
                },
                "violence": {
                    "name": "暴力内容",
                    "words": [
                        "暴力",
                        "杀人",
                        "谋杀",
                        "自杀",
                        "自残",
                        "打架",
                        "斗殴",
                        "流血",
                        "死亡",
                        "血腥",
                        "恐怖",
                        "爆炸",
                        "枪击",
                        "刀砍"
                    ]
                },
                "politics": {
                    "name": "政治敏感",
                    "words": [
                        "政治",
                        "政府",
                        "共产党",
                        "民主",
                        "自由",
                        "抗议",
                        "示威",
                        "游行",
                        "罢工",
                        "颠覆",
                        "叛乱"
                    ]
                },
                "gambling": {
                    "name": "赌博内容",
                    "words": [
                        "赌博",
                        "赌场",
                        "赌钱",
                        "六合彩",
                        "时时彩",
                        "彩票"
                    ]
                },
                "drugs": {
                    "name": "毒品内容",
                    "words": [
                        "毒品",
                        "大麻",
                        "海洛因",
                        "冰毒",
                        "摇头丸",
                        "吸毒",
                        "贩毒"
                    ]
                },
                "fraud": {
                    "name": "诈骗违法",
                    "words": [
                        "诈骗",
                        "骗钱",
                        "传销",
                        "非法集资",
                        "网络诈骗",
                        "盗窃",
                        "抢劫",
                        "绑架",
                        "敲诈勒索"
                    ]
                },
                "cyber": {
                    "name": "网络安全",
                    "words": [
                        "黑客",
                        "病毒",
                        "黑客攻击",
                        "网络攻击",
                        "个人信息",
                        "身份证",
                        "银行卡",
                        "密码",
                        "账号"
                    ]
                },
                "illegal": {
                    "name": "其他违法",
                    "words": [
                        "诈骗电话",
                        "虚假广告",
                        "假冒",
                        "盗版",
                        "侵权",
                        "黄色网站",
                        "赌博网站",
                        "毒品网站",
                        "违法网站"
                    ]
                }
            }
        }
        with open(SENSITIVE_WORDS_FILE, 'w', encoding='utf-8') as f:
            json.dump(sensitive_config, f, ensure_ascii=False, indent=2)

# 加载敏感词库
def load_sensitive_words():
    init_sensitive_words()
    with open(SENSITIVE_WORDS_FILE, 'r', encoding='utf-8') as f:
        config = json.load(f)
        return config.get('categories', {})

# 检测敏感词并返回级别
def check_sensitive_words(content):
    categories = load_sensitive_words()
    for level, level_data in categories.items():
        for word in level_data.get('words', []):
            if word in content:
                return level  # 返回敏感词级别
    return None

# 替换敏感词为*
def censor_content(content):
    categories = load_sensitive_words()
    censored_content = content
    for level, level_data in categories.items():
        for word in level_data.get('words', []):
            if word in censored_content:
                censored_content = censored_content.replace(word, '*' * len(word))
    return censored_content

# 初始化字体配置
init_font_config()

# 初始化敏感词库
init_sensitive_words()

# 初始化管理员配置
init_admin_config()

# 加载表白数据
def load_confessions():
    with open(CONFESSIONS_FILE, 'r', encoding='utf-8') as f:
        return json.load(f)

# 保存表白数据
def save_confessions(confessions):
    try:
        import fcntl
        with open(CONFESSIONS_FILE, 'r+', encoding='utf-8') as f:
            # 获取文件锁
            fcntl.flock(f, fcntl.LOCK_EX)
            try:
                # 清空文件并写入新数据
                f.seek(0)
                f.truncate()
                json.dump(confessions, f, ensure_ascii=False, indent=2)
            finally:
                # 释放文件锁
                fcntl.flock(f, fcntl.LOCK_UN)
    except ImportError:
        # Windows系统不支持fcntl，使用简单的文件写入
        with open(CONFESSIONS_FILE, 'w', encoding='utf-8') as f:
            json.dump(confessions, f, ensure_ascii=False, indent=2)

@app.route('/')
def index():
    confessions = load_confessions()
    # 只显示未封禁的表白
    active_confessions = [c for c in confessions if c.get('status', 'active') == 'active']
    # 按置顶状态和创建时间排序：置顶的在前，然后按创建时间倒序
    active_confessions.sort(key=lambda x: (not x.get('pinned', False), x['created_at']), reverse=False)
    # 确保置顶的表白信息显示在最前面，未置顶的按创建时间倒序
    pinned_confessions = [c for c in active_confessions if c.get('pinned', False)]
    unpinned_confessions = [c for c in active_confessions if not c.get('pinned', False)]
    # 未置顶的按创建时间倒序
    unpinned_confessions.sort(key=lambda x: x['created_at'], reverse=True)
    # 合并列表：置顶的在前，未置顶的在后
    active_confessions = pinned_confessions + unpinned_confessions
    # 加载字体配置
    font_config = load_font_config()
    return render_template('index.html', confessions=active_confessions, is_admin=session.get('is_admin', False), current_font=font_config['font'])

@app.route('/confess', methods=['GET', 'POST'])
def confess():
    if request.method == 'POST':
        content = request.form.get('content')
        
        # 检查用户是否已经通过手机验证
        if not session.get('verified_phone'):
            return jsonify({"code": 401, "msg": "请先完成手机验证"}), 401
            
        if content:
            # 检测敏感词级别
            sensitive_level = check_sensitive_words(content)
            
            # 处理不同级别的敏感词
            if sensitive_level == 'level3':
                # 三级敏感词，拒绝发布并记录违规
                current_time = time.time()
                user_identifier = generate_user_identifier()
                user_ip = request.remote_addr
                
                # 初始化用户档案
                if user_ip not in user_profiles:
                    user_profiles[user_ip] = {
                        'violations': [],
                        'banned_content': []
                    }
                
                # 保存违规内容到用户档案
                user_profiles[user_ip]['banned_content'].append({
                    'content': content,
                    'created_at': current_time,
                    'sensitive_level': sensitive_level
                })
                
                # 记录违规历史
                user_profiles[user_ip]['violations'].append({
                    'timestamp': current_time,
                    'sensitive_level': sensitive_level,
                    'content': content[:100] + ('...' if len(content) > 100 else '')  # 保存内容摘要
                })
                
                # 初始化用户违规记录
                if user_identifier not in user_offenses:
                    user_offenses[user_identifier] = {
                        'offenses': [],
                        'banned_until': 0,
                        'ban_level': 0
                    }
                
                # 清理过期的违规记录
                ban_level = user_offenses[user_identifier]['ban_level']
                if ban_level < 3:
                    # 根据当前封禁等级获取时间窗口
                    window_config = BAN_CONFIG.get(ban_level + 1, BAN_CONFIG[3])
                    time_window = window_config['window']
                    
                    # 清理过期记录
                    user_offenses[user_identifier]['offenses'] = [
                        t for t in user_offenses[user_identifier]['offenses'] 
                        if current_time - t < time_window
                    ]
                    
                    # 记录新的违规
                    user_offenses[user_identifier]['offenses'].append(current_time)
                    
                    # 检查是否达到封禁条件
                    offense_count = len(user_offenses[user_identifier]['offenses'])
                    if offense_count >= window_config['limit']:
                        # 升级封禁等级
                        new_ban_level = min(ban_level + 1, 3)
                        user_offenses[user_identifier]['ban_level'] = new_ban_level
                        user_offenses[user_identifier]['banned_until'] = current_time + window_config['ban_duration']
                        user_offenses[user_identifier]['offenses'] = []  # 重置违规记录
                        
                        # 同时封禁用户IP，确保在用户IP管理中显示
                        user_ip = request.remote_addr
                        ip_identifier = f"{user_ip}_ban"
                        if ip_identifier not in user_offenses:
                            user_offenses[ip_identifier] = {
                                'offenses': [],
                                'banned_until': 0,
                                'ban_level': 0
                            }
                        # 更新IP封禁信息
                        user_offenses[ip_identifier]['ban_level'] = new_ban_level
                        user_offenses[ip_identifier]['banned_until'] = current_time + window_config['ban_duration']
                        user_offenses[ip_identifier]['offenses'].append(current_time)
                
                font_config = load_font_config()
                return render_template('confess.html', is_admin=session.get('is_admin', False), current_font=font_config['font'], has_sensitive=True, has_pending=False)
            elif sensitive_level in ['level1', 'level2']:
                # 一级和二级敏感词，用*代替
                censored_content = censor_content(content)
                # 加载现有数据
                confessions = load_confessions()
                # 创建新表白
                new_confession = {
                    'id': len(confessions) + 1,
                    'content': censored_content,
                    'original_content': content,  # 保存原始内容
                    'created_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                    'status': 'pending' if sensitive_level == 'level2' else 'active',  # 二级敏感词需要审核
                    'pinned': False,  # 添加置顶字段，默认为False
                    'sensitive_level': sensitive_level,  # 记录敏感词级别
                    'ip_address': request.remote_addr  # 记录用户IP地址
                }
                # 添加到列表
                confessions.append(new_confession)
                # 保存数据
                save_confessions(confessions)
                if sensitive_level == 'level2':
                    # 二级敏感词，提示需要审核
                    font_config = load_font_config()
                    return render_template('confess.html', is_admin=session.get('is_admin', False), current_font=font_config['font'], has_sensitive=False, has_pending=True)
            else:
                # 无敏感词，直接发布
                # 加载现有数据
                confessions = load_confessions()
                # 创建新表白
                new_confession = {
                    'id': len(confessions) + 1,
                    'content': content,
                    'created_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                    'status': 'active',  # 添加状态字段
                    'pinned': False,  # 添加置顶字段，默认为False
                    'ip_address': request.remote_addr  # 记录用户IP地址
                }
                # 添加到列表
                confessions.append(new_confession)
                # 保存数据
                save_confessions(confessions)
            return redirect(url_for('index'))
    # 加载字体配置
    font_config = load_font_config()
    return render_template('confess.html', is_admin=session.get('is_admin', False), current_font=font_config['font'], has_sensitive=False, has_pending=False)

# 管理员登录
@app.route('/admin/login', methods=['GET', 'POST'])
def admin_login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        admin = get_admin_by_username(username)
        if admin and password == admin.get('password') and admin.get('status') == 'active':
            session['is_admin'] = True
            session['admin_username'] = username
            session['admin_role'] = admin.get('role')
            return redirect(url_for('admin_dashboard'))
        return render_template('admin_login.html', error='账号或密码错误，或账号已被封禁')
    # 加载字体配置
    font_config = load_font_config()
    return render_template('admin_login.html', current_font=font_config['font'])

# 修改管理员密码
@app.route('/admin/change-password', methods=['GET', 'POST'])
def change_password():
    if not session.get('is_admin'):
        return redirect(url_for('admin_login'))
    
    if request.method == 'POST':
        current_password = request.form.get('current_password')
        new_password = request.form.get('new_password')
        confirm_password = request.form.get('confirm_password')
        
        admin_config = load_admin_config()
        
        # 验证当前密码
        if current_password != admin_config['password']:
            return render_template('change_password.html', error='当前密码错误')
        
        # 验证新密码
        if new_password != confirm_password:
            return render_template('change_password.html', error='两次输入的新密码不一致')
        
        if not new_password:
            return render_template('change_password.html', error='新密码不能为空')
        
        # 更新密码
        admin_config['password'] = new_password
        save_admin_config(admin_config)
        
        # 加载字体配置
        font_config = load_font_config()
        return render_template('change_password.html', success='密码修改成功', is_admin=True, current_font=font_config['font'])
    
    # 加载字体配置
    font_config = load_font_config()
    return render_template('change_password.html', is_admin=True, current_font=font_config['font'])

# 管理员登出
@app.route('/admin/logout')
def admin_logout():
    session.pop('is_admin', None)
    session.pop('admin_username', None)
    session.pop('admin_role', None)
    return redirect(url_for('index'))

# 管理员后台
@app.route('/admin')
def admin_dashboard():
    if not session.get('is_admin'):
        return redirect(url_for('admin_login'))
    
    confessions = load_confessions()
    search_query = request.args.get('search', '')
    status_filter = request.args.get('status', '')
    
    # 搜索功能
    if search_query:
        filtered_confessions = [c for c in confessions if search_query in c.get('content', '') or search_query in c.get('original_content', '')]
    else:
        filtered_confessions = confessions
    
    # 状态过滤
    if status_filter:
        filtered_confessions = [c for c in filtered_confessions if c.get('status') == status_filter]
    
    # 加载字体配置
    font_config = load_font_config()
    # 加载管理员配置
    admin_config = load_admin_config()
    
    # 准备IP封禁和申诉数据
    current_time = time.time()
    ip_offenses = {}
    for key, value in user_offenses.items():
        if '_ban' in key:
            ip_offenses[key] = value
    
    return render_template('admin_dashboard.html', 
                          confessions=filtered_confessions, 
                          search_query=search_query, 
                          status_filter=status_filter,
                          is_admin=True, 
                          admin_role=session.get('admin_role'), 
                          admin_username=session.get('admin_username'),
                          admins=admin_config.get('admins', []),
                          current_font=font_config['font'],
                          ip_offenses=ip_offenses,
                          ip_appeals=ip_appeals,
                          user_profiles=user_profiles,
                          current_time=current_time)

# 管理表白（封禁/解封/删除/置顶/取消置顶/审核通过/拒绝）
@app.route('/admin/manage/<int:confession_id>', methods=['POST'])
def manage_confession(confession_id):
    if not session.get('is_admin'):
        return redirect(url_for('admin_login'))
    
    action = request.form.get('action')
    admin_role = session.get('admin_role')
    
    # 检查权限：副管理员只能执行封禁/解封操作
    if admin_role == 'sub' and action not in ['ban', 'unban', 'approve', 'reject']:
        return redirect(url_for('admin_dashboard'))
    
    confessions = load_confessions()
    
    for confession in confessions:
        if confession.get('id') == confession_id:
            if action == 'ban':
                confession['status'] = 'banned'
            elif action == 'unban':
                confession['status'] = 'active'
            elif action == 'delete' and admin_role == 'main':
                confessions.remove(confession)
            elif action == 'pin' and admin_role == 'main':
                confession['pinned'] = True
            elif action == 'unpin' and admin_role == 'main':
                confession['pinned'] = False
            elif action == 'approve':
                confession['status'] = 'active'
            elif action == 'reject' and admin_role == 'main':
                confessions.remove(confession)
            break
    
    save_confessions(confessions)
    return redirect(url_for('admin_dashboard'))

# 切换字体
@app.route('/admin/change-font', methods=['POST'])
def change_font():
    if not session.get('is_admin'):
        return redirect(url_for('admin_login'))
    
    font = request.form.get('font')
    if font:
        # 加载字体配置
        font_config = load_font_config()
        # 更新字体
        font_config['font'] = font
        # 保存配置
        save_font_config(font_config)
    
    return redirect(url_for('admin_dashboard'))

# 管理副管理员账号（封禁/解封）
@app.route('/admin/manage-admin/<username>', methods=['POST'])
def manage_admin(username):
    if not session.get('is_admin') or session.get('admin_role') != 'main':
        return redirect(url_for('admin_login'))
    
    action = request.form.get('action')
    admin_config = load_admin_config()
    
    for admin in admin_config.get('admins', []):
        if admin.get('username') == username and admin.get('role') == 'sub':
            if action == 'ban':
                admin['status'] = 'banned'
            elif action == 'unban':
                admin['status'] = 'active'
            break
    
    save_admin_config(admin_config)
    return redirect(url_for('admin_dashboard'))

# 存储IP申诉记录：{ip: [{'content': '申诉内容', 'created_at': '时间戳'}]}
ip_appeals = {}

# 存储IP最后申诉时间：{ip: timestamp}
last_appeal_time = {}

# 存储用户档案：{ip: {'violations': [], 'banned_content': []}}
user_profiles = {}

# 封禁IP
@app.route('/admin/ban-ip', methods=['POST'])
def ban_ip():
    if not session.get('is_admin'):
        return redirect(url_for('admin_login'))
    
    ip = request.form.get('ip')
    duration = int(request.form.get('duration', 3600))
    
    if ip:
        current_time = time.time()
        # 生成基于IP的用户标识
        user_identifier = f"{ip}_ban"
        
        # 设置封禁信息
        user_offenses[user_identifier] = {
            'offenses': [],
            'banned_until': current_time + duration,
            'ban_level': 3  # 设置为最高级别
        }
    
    return redirect(url_for('admin_dashboard'))

# 处理账号申诉
@app.route('/appeal', methods=['GET', 'POST'])
def appeal():
    global ip_appeals, last_appeal_time
    if request.method == 'POST':
        content = request.form.get('appeal_content')
        if content:
            ip = request.remote_addr
            current_time = time.time()
            
            # 检查10分钟内是否已提交过申诉
            if ip in last_appeal_time and current_time - last_appeal_time[ip] < 600:
                # 加载字体配置
                font_config = load_font_config()
                return render_template('403.html', is_admin=False, current_font=font_config['font'], appeal_error='10分钟内只能提交1次申诉')
            
            # 初始化申诉记录
            if ip not in ip_appeals:
                ip_appeals[ip] = []
            
            # 添加申诉内容
            ip_appeals[ip].append({
                'content': content,
                'created_at': current_time,
                'status': 'pending'  # 待处理状态
            })
            
            # 更新最后申诉时间
            last_appeal_time[ip] = current_time
            
            # 加载字体配置
            font_config = load_font_config()
            return render_template('appeal_submitted.html', is_admin=False, current_font=font_config['font'])
    
    # 加载字体配置
    font_config = load_font_config()
    return render_template('403.html', is_admin=False, current_font=font_config['font'])

# 解封IP
@app.route('/admin/unban-ip', methods=['POST'])
def unban_ip():
    if not session.get('is_admin'):
        return redirect(url_for('admin_login'))
    
    ip = request.form.get('ip')
    if ip:
        user_identifier = f"{ip}_ban"
        if user_identifier in user_offenses:
            del user_offenses[user_identifier]
    
    return redirect(url_for('admin_dashboard'))

# 处理IP申诉
@app.route('/admin/handle-appeal', methods=['POST'])
def handle_appeal():
    global ip_appeals
    if not session.get('is_admin'):
        return redirect(url_for('admin_login'))
    
    ip = request.form.get('ip')
    appeal_index = int(request.form.get('appeal_index', 0))
    action = request.form.get('action')
    
    if ip and ip in ip_appeals and 0 <= appeal_index < len(ip_appeals[ip]):
        # 更新申诉状态
        ip_appeals[ip][appeal_index]['status'] = 'approved' if action == 'approve' else 'rejected'
        
        # 如果通过申诉，自动解封IP和用户标识
        if action == 'approve':
            # 解除IP封禁
            ip_identifier = f"{ip}_ban"
            if ip_identifier in user_offenses:
                del user_offenses[ip_identifier]
            
            # 解除基于IP的用户标识封禁
            # 注意：由于用户标识是基于IP和浏览器信息生成的，这里无法直接获取
            # 但我们可以遍历所有用户标识，解除与该IP相关的封禁
            for user_id in list(user_offenses.keys()):
                if user_id.startswith(ip):
                    del user_offenses[user_id]
    
    return redirect(url_for('admin_dashboard'))

# 发送验证码
@app.route('/send-sms', methods=['POST'])
def send_sms():
    import json
    data = request.get_json()
    phone = data.get('phone', '')
    
    # 验证手机号格式
    if not phone or not phone.isdigit() or len(phone) != 11:
        return json.dumps({'success': False, 'message': '请输入正确的手机号'})
    
    # 检查60秒内是否已发送
    current_time = time.time()
    if phone in sms_send_records and current_time - sms_send_records[phone] < 60:
        return json.dumps({'success': False, 'message': '请60秒后再获取验证码'})
    
    # 生成6位验证码
    import random
    code = ''.join([str(random.randint(0, 9)) for _ in range(6)])
    
    # 存储验证码，有效期5分钟
    sms_codes[phone] = {
        'code': code,
        'timestamp': current_time
    }
    
    # 更新发送记录
    sms_send_records[phone] = current_time
    
    # 模拟发送短信（实际应用中调用阿里云短信API）
    print(f"发送验证码到 {phone}: {code}")
    
    return json.dumps({'success': True, 'message': '验证码已发送'})

# 用户登录
@app.route('/login', methods=['POST'])
def login():
    import json
    data = request.get_json()
    phone = data.get('phone', '')
    code = data.get('code', '')
    
    # 验证手机号和验证码
    if not phone or not code:
        return json.dumps({'success': False, 'message': '请填写手机号和验证码'})
    
    # 检查验证码是否存在
    if phone not in sms_codes:
        return json.dumps({'success': False, 'message': '请先获取验证码'})
    
    # 检查验证码是否过期（5分钟）
    current_time = time.time()
    if current_time - sms_codes[phone]['timestamp'] > 5 * 60:
        del sms_codes[phone]
        return json.dumps({'success': False, 'message': '验证码已过期，请重新获取'})
    
    # 验证验证码
    if sms_codes[phone]['code'] != code:
        return json.dumps({'success': False, 'message': '验证码错误'})
    
    # 登录成功，保存会话
    session['username'] = phone
    session['phone'] = phone
    
    # 清除验证码（一次性使用）
    del sms_codes[phone]
    
    return json.dumps({'success': True, 'message': '登录成功'})

# 用户登出
@app.route('/logout')
def logout():
    session.pop('username', None)
    session.pop('phone', None)
    return redirect(url_for('index'))

@app.errorhandler(429)
def too_many_requests(error):
    # 加载字体配置
    font_config = load_font_config()
    return render_template('429.html', is_admin=False, current_font=font_config['font']), 429

@app.errorhandler(403)
def forbidden(error):
    # 加载字体配置
    font_config = load_font_config()
    return render_template('403.html', is_admin=False, current_font=font_config['font']), 403

# ========== 短信验证码相关 ==========
from flask import jsonify

# 初始化 Redis（用于频率限制和验证标记）
redis_client = None
try:
    import redis
    redis_client = redis.Redis(host='localhost', port=6379, db=0, decode_responses=True, socket_timeout=2, socket_connect_timeout=2)
    redis_client.ping()
    print("Redis 连接成功")
except Exception as e:
    print(f"Redis 连接失败或未安装，将使用内存存储: {e}")
    redis_client = None

# Spug 配置
SPUG_TEMPLATE_ID = 'X4PBx8E5L48YAny5'
SPUG_API_URL = f'https://push.spug.cc/send/{SPUG_TEMPLATE_ID}'

@app.route('/check_verification', methods=['GET'])
def check_verification():
    verified_phone = session.get('verified_phone')
    return jsonify({
        'verified': verified_phone is not None,
        'phone': verified_phone
    })

@app.route('/send_code', methods=['POST'])
def send_code():
    data = request.get_json()
    phone = data.get('phone')
    if not phone:
        return jsonify({"code": 400, "msg": "手机号不能为空"}), 400

    # 频率限制（Redis）
    if redis_client and redis_client.get(f"send_limit:{phone}"):
        return jsonify({"code": 429, "msg": "请求过于频繁，请稍后再试"}), 429

    # 生成6位随机验证码
    code = str(random.randint(100000, 999999))

    # 调用 Spug API 发送
    params = {
        "code": code,
        "number": "5",
        "targets": phone
    }
    try:
        resp = requests.get(SPUG_API_URL, params=params, timeout=10)
        result = resp.json()
        if result.get('code') == 0:
            # 发送成功，将验证码存入 Redis，5分钟过期
            if redis_client:
                redis_client.setex(f"code:{phone}", 300, code)
                redis_client.setex(f"send_limit:{phone}", 60, "1")
            else:
                # 如果没有Redis，使用内存存储
                sms_codes[phone] = {
                    'code': code,
                    'timestamp': time.time()
                }
                sms_send_records[phone] = time.time()
            return jsonify({"code": 0, "msg": "验证码发送成功"})
        else:
            print(f"Spug 发送失败: {result}")
            return jsonify({"code": 500, "msg": "验证码发送失败"}), 500
    except Exception as e:
        print(f"请求 Spug 异常: {e}")
        return jsonify({"code": 500, "msg": "服务器错误"}), 500

@app.route('/verify_code', methods=['POST'])
def verify_code():
    data = request.get_json()
    phone = data.get('phone')
    code = data.get('code')
    if not phone or not code:
        return jsonify({"code": 400, "msg": "手机号和验证码不能为空"}), 400

    # 使用 Redis 验证（如果可用）
    if redis_client:
        stored_code = redis_client.get(f"code:{phone}")
        if not stored_code:
            return jsonify({"code": 400, "msg": "请先获取验证码"}), 400
        
        if stored_code != code:
            return jsonify({"code": 400, "msg": "验证码错误或已过期"}), 400
        
        # 验证成功，清除验证码
        redis_client.delete(f"code:{phone}")
    else:
        # 使用内存存储验证
        if phone not in sms_codes:
            return jsonify({"code": 400, "msg": "请先获取验证码"}), 400
        
        current_time = time.time()
        if current_time - sms_codes[phone]['timestamp'] > 5 * 60:
            del sms_codes[phone]
            return jsonify({"code": 400, "msg": "验证码已过期，请重新获取"}), 400
        
        if sms_codes[phone]['code'] != code:
            return jsonify({"code": 400, "msg": "验证码错误或已过期"}), 400
        
        del sms_codes[phone]

    # 验证成功，将手机号存入 session
    session['verified_phone'] = phone
    session['username'] = phone
    
    return jsonify({"code": 0, "msg": "验证成功"})

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)