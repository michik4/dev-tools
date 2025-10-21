#!/bin/bash

# ==============================================================================
# shelli.sh (v6) - Утилита для модульной настройки конфигурации Bash и Zsh
# ==============================================================================

# --- Цвета и функции логирования ---
C_RESET='\033[0m'; C_RED='\033[0;31m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[0;33m'; C_CYAN='\033[0;36m'
log_info() { echo -e "${C_CYAN}[INFO]${C_RESET} $1"; }
log_success() { echo -e "${C_GREEN}[SUCCESS]${C_RESET} $1"; }
log_warn() { echo -e "${C_YELLOW}[WARNING]${C_RESET} $1"; }
log_error() { echo -e "${C_RED}[ERROR]${C_RESET} $1" >&2; }

# --- Глобальные переменные и маркеры ---
CONFIGS_BASE_DIR="$HOME/.config"
CURRENT_SHELL=$(basename "$SHELL")
START_MARKER="# --- Managed by shelli.sh: Load modular configs ---"
END_MARKER="# --- End of shelli.sh block ---"

# --- Функция помощи ---
usage() {
    echo "Использование: $0 [флаг]"
    echo ""
    echo "Флаги:"
    echo "  (нет флага)     - Установить конфигурацию."
    echo "  -d, --delete    - Удалить конфигурацию."
    echo "  -r, --rewrite   - Перезаписать конфигурацию."
    echo "  -h, --help      - Показать это сообщение."
    exit 0
}

# ==============================================================================
# --- ОСНОВНЫЕ ФУНКЦИИ ---
# ==============================================================================

# --- Функция удаления конфигурации ---
do_delete() {
    log_info "Запуск процесса удаления..."
    if [ -d "$TARGET_DIR" ]; then
        log_info "Удаление каталога '$TARGET_DIR'..."
        rm -rf "$TARGET_DIR"
        log_success "Каталог удален."
    else
        log_warn "Каталог '$TARGET_DIR' не найден. Пропускаем."
    fi
    if [ ! -f "$SHELL_CONFIG_FILE" ]; then
        log_warn "Файл '$SHELL_CONFIG_FILE' не найден. Пропускаем."; return;
    fi
    if grep -q "$START_MARKER" "$SHELL_CONFIG_FILE"; then
        log_info "Удаление блока конфигурации из '$SHELL_CONFIG_FILE'..."
        sed -i.bak "/$START_MARKER/,/$END_MARKER/d" "$SHELL_CONFIG_FILE"
        log_success "Блок конфигурации удален. Создана резервная копия: ${SHELL_CONFIG_FILE}.bak"
    else
        log_warn "Блок конфигурации не найден в '$SHELL_CONFIG_FILE'. Пропускаем."
    fi
}

# --- Функция установки конфигурации ---
do_install() {
    log_info "Запуск процесса установки..."
    mkdir -p "$CONFIGS_BASE_DIR"
    if [ ! -d "$SOURCE_DIR" ]; then
        log_error "Исходный каталог '$SOURCE_DIR' не найден! Установка невозможна."; return 1;
    fi
    cp -r "$SOURCE_DIR" "$TARGET_DIR"
    log_success "Каталог '$SOURCE_DIR' скопирован в '$TARGET_DIR'."
    if [ -f "$SHELL_CONFIG_FILE" ] && grep -q "$START_MARKER" "$SHELL_CONFIG_FILE"; then
        log_warn "Конфигурация для загрузки модулей уже присутствует в '$SHELL_CONFIG_FILE'."; return 0;
    fi
    log_info "Добавляем код для загрузки модулей в '$SHELL_CONFIG_FILE'..."
    
    CODE_BLOCK=""
    if [ "$CURRENT_SHELL" = "zsh" ]; then
        # ZSH-СПЕЦИФИЧНЫЙ КОД
        CODE_BLOCK=$(cat <<EOF

$START_MARKER
if [ -d "$TARGET_DIR" ]; then
  for config_file in "$TARGET_DIR"/*(D.); do
    [ -r "\$config_file" ] && . "\$config_file"
  done
  unset config_file
fi
$END_MARKER
EOF
)
    else
        # BASH (и другие) - стандартный код
        CODE_BLOCK=$(cat <<EOF

$START_MARKER
if [ -d "$TARGET_DIR" ]; then
  # ПРАВИЛЬНО: $TARGET_DIR раскрывается здесь, \$config_file - при выполнении bashrc
  for config_file in "$TARGET_DIR"/* "$TARGET_DIR"/.*; do
    if [ -f "\$config_file" ] && [ -r "\$config_file" ]; then
      . "\$config_file"
    fi
  done
  unset config_file
fi
$END_MARKER
EOF
)
    fi
    
    echo "$CODE_BLOCK" >> "$SHELL_CONFIG_FILE"
    log_success "Конфигурация успешно добавлена."
    return 0
}

# ==============================================================================
# --- ГЛАВНАЯ ЛОГИКА ---
# ==============================================================================

ACTION="install"
case "$1" in
    -d|--delete) ACTION="delete" ;;
    -r|--rewrite) ACTION="rewrite" ;;
    -h|--help) usage ;;
    "") ;;
    *) log_error "Неизвестный флаг: $1"; usage ;;
esac

if [ "$CURRENT_SHELL" = "bash" ]; then
    SHELL_CONFIG_DIR_NAME=".bashrc.d"; SHELL_CONFIG_FILE="$HOME/.bashrc";
elif [ "$CURRENT_SHELL" = "zsh" ]; then
    SHELL_CONFIG_DIR_NAME=".zshrc.d"; SHELL_CONFIG_FILE="$HOME/.zshrc";
else
    log_error "Эта оболочка ($CURRENT_SHELL) не поддерживается скриптом."; exit 1;
fi

SOURCE_DIR="./$SHELL_CONFIG_DIR_NAME"
TARGET_DIR="$CONFIGS_BASE_DIR/$SHELL_CONFIG_DIR_NAME"

INSTALL_SUCCESS=true
case "$ACTION" in
    install) log_info "РЕЖИМ: УСТАНОВКА"; do_install || INSTALL_SUCCESS=false ;;
    delete) log_info "РЕЖИМ: УДАЛЕНИЕ"; do_delete ;;
    rewrite) log_info "РЕЖИМ: ПЕРЕЗАПИСЬ"; do_delete; echo ""; do_install || INSTALL_SUCCESS=false ;;
esac

echo ""
if [ "$INSTALL_SUCCESS" = true ]; then
    log_success "Операция завершена!"
    if [ "$ACTION" != "delete" ]; then
        log_info "Чтобы изменения вступили в силу, перезапустите терминал или выполните:"
        log_info "$C_YELLOW source $SHELL_CONFIG_FILE$C_RESET"
    fi
else
    log_error "Операция завершилась с ошибкой!"; exit 1;
fi