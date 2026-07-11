## LoginUI.gd
## 登录/注册界面控制器
## 挂载到登录场景的根节点

extends Control

# ================================================================
# 节点引用
# ================================================================
@onready var tab_container: TabContainer = $TabContainer
@onready var login_username: LineEdit   = $TabContainer/登录/VBox/UsernameInput
@onready var login_password: LineEdit   = $TabContainer/登录/VBox/PasswordInput
@onready var login_btn: Button          = $TabContainer/登录/VBox/LoginBtn
@onready var login_error: Label         = $TabContainer/登录/VBox/ErrorLabel

@onready var reg_username: LineEdit     = $TabContainer/注册/VBox/UsernameInput
@onready var reg_password: LineEdit     = $TabContainer/注册/VBox/PasswordInput
@onready var reg_confirm: LineEdit      = $TabContainer/注册/VBox/ConfirmInput
@onready var reg_btn: Button            = $TabContainer/注册/VBox/RegisterBtn
@onready var reg_error: Label           = $TabContainer/注册/VBox/ErrorLabel

@onready var status_label: Label        = $StatusLabel

# ================================================================
# 初始化
# ================================================================

func _ready() -> void:
	login_btn.pressed.connect(_on_login_pressed)
	reg_btn.pressed.connect(_on_register_pressed)
	login_password.secret = true
	reg_password.secret = true
	reg_confirm.secret = true

	NetworkManager.login_success.connect(_on_login_success)
	NetworkManager.login_failed.connect(_on_login_failed)
	NetworkManager.register_success.connect(_on_register_success)
	NetworkManager.register_failed.connect(_on_register_failed)
	NetworkManager.connected_to_server.connect(_on_server_connected)
	NetworkManager.disconnected_from_server.connect(_on_server_disconnected)

# ================================================================
# 按钮事件
# ================================================================

func _on_login_pressed() -> void:
	var user := login_username.text.strip_edges()
	var pass_ := login_password.text
	if user == "" or pass_ == "":
		login_error.text = "请输入用户名和密码"
		return
	login_error.text = ""
	login_btn.disabled = true
	login_btn.text = "登录中..."
	NetworkManager.login(user, pass_)

func _on_register_pressed() -> void:
	var user := reg_username.text.strip_edges()
	var pass_ := reg_password.text
	var confirm := reg_confirm.text

	if user == "" or pass_ == "":
		reg_error.text = "请填写所有字段"
		return
	if pass_ != confirm:
		reg_error.text = "两次密码不一致"
		return
	if pass_.length() < 6:
		reg_error.text = "密码至少6位"
		return

	reg_error.text = ""
	reg_btn.disabled = true
	reg_btn.text = "注册中..."
	NetworkManager.register(user, pass_)

# ================================================================
# 回调
# ================================================================

func _on_login_success(player_data: Dictionary) -> void:
	status_label.text = "登录成功，正在连接服务器..."
	login_btn.text = "登录"

func _on_login_failed(error: String) -> void:
	login_error.text = error
	login_btn.disabled = false
	login_btn.text = "登录"

func _on_register_success() -> void:
	reg_error.text = ""
	reg_btn.disabled = false
	reg_btn.text = "注册"
	# 切换到登录标签
	tab_container.current_tab = 0
	login_username.text = reg_username.text
	status_label.text = "注册成功，请登录"

func _on_register_failed(error: String) -> void:
	reg_error.text = error
	reg_btn.disabled = false
	reg_btn.text = "注册"

func _on_server_connected() -> void:
	status_label.text = "已连接到服务器"
	# 跳转到大厅
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _on_server_disconnected() -> void:
	status_label.text = "与服务器断开连接"
