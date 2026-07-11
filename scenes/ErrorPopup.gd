## ErrorPopup.gd
## 通用错误弹窗，显示错误信息并提供重试/返回选项

extends CenterContainer

# ================================================================
# 信号
# ================================================================
signal retry_requested    ## 用户点击“重试”
signal back_requested     ## 用户点击“上一步”

# ================================================================
# 节点引用
# ================================================================
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var message_label: Label = $Panel/VBox/MessageLabel
@onready var retry_button: Button = $Panel/VBox/ButtonContainer/RetryButton
@onready var back_button: Button = $Panel/VBox/ButtonContainer/BackButton

# ================================================================
# 生命周期
# ================================================================

func _ready() -> void:
	hide()
	retry_button.pressed.connect(func(): retry_requested.emit())
	back_button.pressed.connect(func(): back_requested.emit())

# ================================================================
# 公共方法
# ================================================================

## 显示弹窗并设置错误信息
func show_error(title: String, message: String) -> void:
	title_label.text = title
	message_label.text = message
	show()

## 隐藏弹窗
func hide_error() -> void:
	hide()
