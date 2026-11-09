#!/bin/bash

# Script completo para configuração do ambiente de desenvolvimento Fedora
# Autor: Guilherme Celso (adaptado)
# Descrição: Automatiza a instalação e a validação de ferramentas essenciais
#            no Fedora (dnf/rpm). Outras famílias de distro são recusadas.

set -Eeuo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status()  { echo -e "${BLUE}🔧 $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error()   { echo -e "${RED}❌ $1${NC}"; }

command_exists()    { command -v "$1" >/dev/null 2>&1; }
package_installed() { rpm -q "$1" >/dev/null 2>&1; }
docker_compose_exists() { command_exists docker && docker compose version >/dev/null 2>&1; }

# ====================================
# VALIDAÇÃO ITEM A ITEM
# Cada programa da lista registra aqui a função que prova que ele
# está instalado; ao final tudo é verificado e reportado.
# ====================================
VALIDATION_NAMES=()
VALIDATION_CHECKS=()
VALIDATION_FAILURES=0

register_validation() {
    VALIDATION_NAMES+=("$1")
    VALIDATION_CHECKS+=("$2")
}

run_validations() {
    local index name check
    VALIDATION_FAILURES=0

    echo ""
    print_status "Validando item a item se cada programa está instalado..."
    echo ""

    for index in "${!VALIDATION_NAMES[@]}"; do
        name="${VALIDATION_NAMES[$index]}"
        check="${VALIDATION_CHECKS[$index]}"
        if "$check"; then
            print_success "$(printf '%-30s' "$name") INSTALADO"
        else
            print_error "$(printf '%-30s' "$name") NÃO INSTALADO"
            VALIDATION_FAILURES=$((VALIDATION_FAILURES + 1))
        fi
    done

    echo ""
    if [ "$VALIDATION_FAILURES" -eq 0 ]; then
        print_success "Validação concluída: todos os ${#VALIDATION_NAMES[@]} itens estão instalados!"
    else
        print_error "Validação concluída: $VALIDATION_FAILURES item(ns) não instalado(s)."
        print_warning "Corrija o erro acima e execute o script novamente; o que já foi instalado será mantido."
        exit 1
    fi
}

check_curl()      { command_exists curl; }
check_git()       { command_exists git; }
check_docker()    { command_exists docker && docker_compose_exists; }
check_node()      { command_exists node && [[ "$(node --version)" == v24* ]]; }
check_npm()       { command_exists npm; }
check_zsh()       { command_exists zsh; }
check_omz()       { [ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; }
check_zsh_login_shell() {
    local zsh_path current_shell
    zsh_path="$(command -v zsh 2>/dev/null)" || return 1
    current_shell="$(getent passwd "$(id -un)" | cut -d: -f7)"
    [ -n "$current_shell" ] && [ "$current_shell" = "$zsh_path" ]
}

# Plugins externos clonados em ~/.oh-my-zsh/custom/plugins (nome=repositório).
# history-substring-search já vem junto do Oh My Zsh; autojump vem do dnf.
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
ZSH_EXTERNAL_PLUGINS=(
    "zsh-autosuggestions=https://github.com/zsh-users/zsh-autosuggestions"
    "zsh-completions=https://github.com/zsh-users/zsh-completions"
    "zsh-syntax-highlighting=https://github.com/zsh-users/zsh-syntax-highlighting"
)
# zsh-syntax-highlighting deve ser o último da lista.
ZSH_PLUGIN_LIST="git zsh-autosuggestions zsh-completions history-substring-search autojump zsh-syntax-highlighting"

check_zsh_plugins() {
    local entry plugin
    for entry in "${ZSH_EXTERNAL_PLUGINS[@]}"; do
        [ -d "$ZSH_CUSTOM_DIR/plugins/${entry%%=*}" ] || return 1
    done
    [ -d "$HOME/.oh-my-zsh/plugins/history-substring-search" ] || return 1
    package_installed autojump || return 1
    for plugin in $ZSH_PLUGIN_LIST; do
        grep -Eq "^plugins=\(.*\b${plugin}\b.*\)" "$HOME/.zshrc" || return 1
    done
}

# Fedora: ID do /etc/os-release.
is_fedora() {
    [ "${ID:-}" = "fedora" ]
}

on_error() {
    local exit_code=$?
    print_error "A instalação falhou na linha ${BASH_LINENO[0]} (comando: ${BASH_COMMAND})."
    print_warning "Corrija o erro acima e execute o script novamente; as etapas já concluídas serão preservadas."
    exit "$exit_code"
}

trap on_error ERR

echo "🚀 Iniciando configuração completa do ambiente de desenvolvimento Fedora..."
echo "⏱️  Este processo pode levar alguns minutos..."
echo ""

if [ "$(id -u)" -eq 0 ]; then
    print_error "Execute este script como usuário comum, não como root."
    print_warning "O script usa sudo internamente quando necessário."
    exit 1
fi

if ! command_exists sudo; then
    print_error "O comando sudo não está instalado."
    exit 1
fi

print_status "Validando acesso administrativo..."
sudo -v

# ====================================
# 0. VERIFICAÇÃO DO SISTEMA OPERACIONAL (FEDORA)
# ====================================
print_status "Verificando distribuição..."
if [ ! -r /etc/os-release ]; then
    print_error "Não foi possível identificar o sistema operacional."
    exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release

if ! is_fedora; then
    print_error "Este script foi feito para Fedora (dnf/rpm)."
    print_warning "Sistema detectado: ${PRETTY_NAME:-desconhecido}"
    exit 1
fi

print_success "Fedora detectado! (${PRETTY_NAME})"
echo ""

# ====================================
# 1. ATUALIZAÇÃO DO SISTEMA
# ====================================
print_status "Atualizando pacotes do sistema..."
# nodejs* fica de fora: o do Fedora (22) conflita com o do NodeSource (24) e
# é tratado na etapa 6, que remove o do Fedora antes de instalar o 24.
sudo dnf upgrade -y --refresh --exclude='nodejs*'
print_success "Sistema atualizado!"

# ====================================
# 2. DEPENDÊNCIAS BÁSICAS
# ====================================
print_status "Verificando/Instalando dependências básicas..."
sudo dnf install -y ca-certificates curl gnupg2
register_validation "curl" check_curl
print_success "Dependências básicas instaladas!"

# ====================================
# 3. GIT
# ====================================
register_validation "Git" check_git
print_status "Verificando/Instalando Git..."
if ! command_exists git; then
    sudo dnf install -y git
    print_success "Git instalado!"
else
    print_success "Git já está instalado!"
fi

# ====================================
# 4. GITHUB CLI (gh)
# Autenticação fica a cargo do usuário: rode "gh auth login" depois.
# ====================================
check_gh() { command_exists gh; }
register_validation "GitHub CLI (gh)" check_gh
print_status "Verificando/Instalando GitHub CLI (gh)..."
if ! check_gh; then
    sudo dnf install -y gh
    hash -r
    command_exists gh
    print_success "GitHub CLI instalado! ($(gh --version | head -n1))"
else
    print_success "GitHub CLI já está instalado! ($(gh --version | head -n1))"
fi

# ====================================
# 4.1 IDENTIDADE DO GIT (user.name / user.email globais)
# Só pergunta em terminal; Enter mantém o valor atual (se houver).
# ====================================
print_status "Configurando identidade global do Git..."
if [ ! -t 0 ]; then
    print_warning "Execução não interativa: identidade do Git pulada."
else
    for git_key in name email; do
        git_current="$(git config --global "user.$git_key" 2>/dev/null || true)"
        git_value=""
        while [ -z "$git_value" ]; do
            if ! read -r -p "git user.$git_key${git_current:+ [$git_current]}: " git_value; then
                echo ""
                print_error "Entrada cancelada pelo usuário."
                exit 1
            fi
            git_value="${git_value:-$git_current}"
            if [ -z "$git_value" ] || { [ "$git_key" = email ] && [[ "$git_value" != *@* ]]; }; then
                print_warning "Informe um valor válido para user.$git_key."
                git_value=""
                git_current=""
            fi
        done
        git config --global "user.$git_key" "$git_value"
    done
    print_success "Git: $(git config --global user.name) <$(git config --global user.email)>"
fi

# ====================================
# 5. DOCKER (repositório oficial para Fedora)
# ====================================
register_validation "Docker Engine + Compose" check_docker
print_status "Verificando/Instalando Docker Engine e Docker Compose..."
if ! check_docker; then
    # Repositório oficial do Docker (dnf) com a chave GPG dele.
    sudo curl -fsSL https://download.docker.com/linux/fedora/docker-ce.repo -o /etc/yum.repos.d/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Atualiza o cache de comandos do shell e comprova os executáveis.
    hash -r
    command_exists docker
    docker compose version >/dev/null

    print_success "Docker Engine e Docker Compose instalados!"
else
    print_success "Docker Engine e Docker Compose já estão instalados!"
fi

# Corrige também instalações existentes que estejam com o serviço parado ou
# sem permissão para o usuário atual.
sudo systemctl enable --now docker
sudo usermod -aG docker "$(id -un)"
sudo docker info >/dev/null
print_success "Serviço Docker ativo e usuário adicionado ao grupo docker!"

# ====================================
# 6. NODE.JS LTS (NodeSource 24.x)
# ====================================
register_validation "Node.js 24 LTS" check_node
register_validation "npm" check_npm
print_status "Verificando/Instalando Node.js 24..."
if ! check_node || ! command_exists npm; then
    # Repositório oficial NodeSource (rpm). A validação da versão 24.x acontece logo abaixo.
    nodesource_setup_tmp="$(mktemp)"
    curl -fsSL https://rpm.nodesource.com/setup_24.x -o "$nodesource_setup_tmp"
    sudo -E bash "$nodesource_setup_tmp"
    rm -f "$nodesource_setup_tmp"
    # O Fedora traz nodejs 22 (com npm próprio em /usr/bin/npm), que conflita com
    # o pacote do NodeSource: remove os nodejs* do Fedora antes de instalar o 24.
    fedora_node_pkgs=()
    mapfile -t fedora_node_pkgs < <(rpm -qa --qf '%{NAME}\n' | grep -E '^nodejs' || true)
    if [ "${#fedora_node_pkgs[@]}" -gt 0 ]; then
        print_warning "Removendo Node.js da base do Fedora para instalar o 24: ${fedora_node_pkgs[*]}"
        sudo dnf remove -y "${fedora_node_pkgs[@]}"
    fi
    sudo dnf install -y nodejs

    hash -r
    if ! command_exists node || ! command_exists npm; then
        print_error "O pacote nodejs foi processado, mas os comandos node e npm não ficaram disponíveis."
        exit 1
    fi

    if [[ "$(node --version)" != v24* ]]; then
        print_error "Era esperado Node.js 24.x, mas foi instalado $(node --version)."
        exit 1
    fi

    print_success "Node.js $(node --version) e npm $(npm --version) instalados!"
else
    print_success "Node.js 24 e npm já estão instalados!"
fi

# ====================================
# 6.1 ZSH + OH MY ZSH + AUTOCOMPLETE (terminal principal)
# ====================================
register_validation "Zsh" check_zsh
register_validation "Oh My Zsh" check_omz
register_validation "Plugins do Zsh" check_zsh_plugins
register_validation "Zsh como shell padrão" check_zsh_login_shell

print_status "Verificando/Instalando Zsh..."
if ! command_exists zsh; then
    sudo dnf install -y zsh
    hash -r
    if ! command_exists zsh; then
        print_error "O Zsh não ficou disponível após a instalação."
        exit 1
    fi
    print_success "Zsh instalado! ($(zsh --version))"
else
    print_success "Zsh já está instalado! ($(zsh --version))"
fi

print_status "Verificando/Instalando Oh My Zsh..."
if ! check_omz; then
    omz_installer_tmp="$(mktemp)"
    if ! curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$omz_installer_tmp"; then
        rm -f "$omz_installer_tmp"
        print_error "Falha ao baixar o instalador do Oh My Zsh."
        exit 1
    fi

    # --unattended: não pergunta nem troca o shell sozinho (fazemos abaixo).
    # --keep-zshrc: preserva um ~/.zshrc já existente em reexecuções.
    sh "$omz_installer_tmp" --unattended --keep-zshrc
    rm -f "$omz_installer_tmp"

    if ! check_omz; then
        print_error "Oh My Zsh não foi instalado em $HOME/.oh-my-zsh."
        exit 1
    fi
    print_success "Oh My Zsh instalado em $HOME/.oh-my-zsh!"
else
    print_success "Oh My Zsh já está instalado!"
fi

print_status "Instalando plugins do Zsh (autosuggestions, completions, syntax highlighting)..."
sudo dnf install -y autojump
for entry in "${ZSH_EXTERNAL_PLUGINS[@]}"; do
    plugin_dir="$ZSH_CUSTOM_DIR/plugins/${entry%%=*}"
    if [ -d "$plugin_dir" ]; then
        print_success "${entry%%=*} já está instalado!"
    else
        git clone --depth 1 "${entry#*=}" "$plugin_dir"
        print_success "${entry%%=*} instalado!"
    fi
done

# ponytail: substitui a linha plugins=(...) inteira; plugins extras seus nela são perdidos.
touch "$HOME/.zshrc"
if grep -q '^plugins=(' "$HOME/.zshrc"; then
    sed -i "s/^plugins=(.*)/plugins=($ZSH_PLUGIN_LIST)/" "$HOME/.zshrc"
else
    echo "plugins=($ZSH_PLUGIN_LIST)" >> "$HOME/.zshrc"
fi
print_success "Plugins ativados no ~/.zshrc!"

print_status "Definindo Zsh como terminal/shell padrão..."
zsh_path="$(command -v zsh)"
if check_zsh_login_shell; then
    print_success "Zsh já é o shell padrão de $(id -un)!"
elif ! grep -qxF "$zsh_path" /etc/shells; then
    print_error "O Zsh ($zsh_path) não está listado em /etc/shells; não é possível defini-lo como shell padrão."
    exit 1
else
    sudo chsh -s "$zsh_path" "$(id -un)"
    if check_zsh_login_shell; then
        print_success "Zsh definido como shell padrão ($zsh_path) para $(id -un)!"
    else
        print_error "Não foi possível definir o Zsh como shell padrão."
        exit 1
    fi
fi

# ====================================
# 6.2 NEOVIM (nvim)
# ====================================
check_nvim() { command_exists nvim; }
register_validation "Neovim (nvim)" check_nvim
print_status "Verificando/Instalando Neovim..."
if ! check_nvim; then
    sudo dnf install -y neovim
    hash -r
    command_exists nvim
    print_success "Neovim instalado! ($(nvim --version | head -n1))"
else
    print_success "Neovim já está instalado! ($(nvim --version | head -n1))"
fi

# ====================================
# 7. VALIDAÇÃO FINAL (item a item)
# ====================================
run_validations

# ====================================
# FINALIZAÇÃO
# ====================================
echo ""
echo "🎉 CONFIGURAÇÃO COMPLETA!"
echo ""
print_success "Todas as ferramentas foram instaladas e validadas com sucesso!"
echo ""
echo "🔄 Faça logout/login para aplicar as configurações do Docker (grupo docker)"
echo "🔄 Faça logout/login para entrar no seu novo terminal padrão (zsh + Oh My Zsh)"
echo "🔧 VERSÕES INSTALADAS:"
if command_exists git;    then echo "   Git:        $(git --version)"; fi
if command_exists curl;   then echo "   Curl:       $(curl --version | head -n1)"; fi
if command_exists docker; then echo "   Docker:     $(docker --version)"; fi
if command_exists node;   then echo "   Node.js:    $(node --version)"; fi
if command_exists npm;    then echo "   NPM:        $(npm --version)"; fi
if command_exists zsh;    then echo "   Zsh:        $(zsh --version)"; fi
if check_omz;             then echo "   Oh My Zsh:  $(git -C "$HOME/.oh-my-zsh" describe --tags 2>/dev/null || echo 'instalado')"; fi
if command_exists nvim;   then echo "   Neovim:     $(nvim --version | head -n1)"; fi
if command_exists gh;     then echo "   GitHub CLI: $(gh --version | head -n1)"; fi
echo ""

echo "🔑 Para autenticar no GitHub, execute: gh auth login"
echo ""

# A identidade dos commits (user.name/user.email) não é cadastrada por este
# script; ela só é avisada aqui se ainda não existir.
if ! git config --global user.name >/dev/null 2>&1 || ! git config --global user.email >/dev/null 2>&1; then
    print_warning "Identidade do Git não configurada (usada no autor dos commits). Configure quando quiser com:"
    echo "  git config --global user.name 'Seu Nome'"
    echo "  git config --global user.email 'seu.email@exemplo.com'"
    echo ""
fi
print_success "Ambiente de desenvolvimento pronto para uso! 🚀"
